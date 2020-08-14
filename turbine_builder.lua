--[[[
NCO Turbine Builder by Sanrom
v0.1.4

LINKS:
NCO: https://github.com/turbodiesel4598/NuclearCraft
NCPF Format: https://docs.google.com/document/d/1dzU2arDrD7n9doRua8laxzRy9_RtX-cuv1sUJBB5aGY/edit#
]]

local component = require("component")
local sides = require("sides")
local shell = require("shell")
-- local os = require("os")
local event = require("event")

local parser = require("rblib.config2_parser")
local common = require("rblib.rb_common")

if not component.isAvailable("robot") then error("This program can only be run from a robot") end
local robot = require("robot")

if not component.isAvailable("inventory_controller") then error("This program requires an inventory controller to run") end
local inv_controller = component.inventory_controller

local flags = {}

local blockmap_paths = {blocks = "rblib/blockmaps/overhaulTurbineBlocks.map", blades = "rblib/blockmaps/overhaulTurbineBlades.map"}

--UTIL

local function loadArgs(...)
  local args, ops = shell.parse(...)

  if ops.d or ops.debug then
    flags.debug = true
  end

  if ops.g or ops.ghost then
    flags.ghost = true
  end

  if ops.o or ops.outline then
    flags.outline = true
  end

  if ops.s or ops.stationary or ops.disableMovement then
    flags.ghost = true
    flags.disableMovement = true
  end

  if ops.I or ops.disableInvCheck then
    flags.disableInvCheck = true
  end

  if ops.p or ops.disablePrompts then
    flags.disablePrompts = true
  end

  if ops.glass then
    flags.glass = true
  end

  return args
end

--LOAD

local function loadTurbine(filename, startOffset)

  local turbine = {map = {}, size = {}, shaft = {}, startOffset = startOffset or {x = 1, y = 1, z = 1}}

  --Parse the file using config2_parser
  local configs = parser.ncpf(filename)

  --Print all the turbines available
  local id = 0
  if configs.header.count > 1 then
    for i = 1, configs.header.count do
      if configs[i].id == 3 then
        if configs[i].metadata then
          print(string.format("ID: %2d  Internal Length: %2d  Diameter (excl. casing): %2d  Name: %s  Author: %s",
              i, configs[i].size[1], configs[i].size[2],
              configs[i].metadata.Name or "", configs[i].metadata.Author or ""))
        else
          print(string.format("ID: %2d  Internal Length: %2d  Radius (excl. casing): %2d", 
              i, configs[i].size[1], configs[i].size[2]))
        end
      end
    end

    --Prompt user to select one of the turbines
    id = 0
    io.write("Please enter the ID of the turbine to load: ")
    id = not flags.disablePrompts and tonumber(io.read()) or 1
  else
    id = 1
  end

  if id < 1 or id > configs.header.count then
    return nil, "ID not valid!"

  --Check format
  elseif configs[id].id ~= 3 then
    return nil, "Only turbines are supported in this program. Maybe you wanted to use reactor_builder?"
  end

  --Generate ID map for coils
  local blockMap = common.util.blockMapLoad(blockmap_paths.blocks)

  turbine.map[1] = blockMap["Turbine Casing"]
  turbine.map[1].count = 0
  turbine.map[2] = blockMap["Turbine Glass"]
  turbine.map[2].count = 0
  turbine.map[3] = blockMap["Rotor Shaft"]
  turbine.map[3].count = 0

  local coilOffset = #turbine.map
  for i, v in ipairs(configs.configuration.overhaul.turbine.coils) do
    if not blockMap[v.name] then
      error("Missing map entry: " .. v.name)
    else
      turbine.map[coilOffset + i] = blockMap[v.name]
      turbine.map[coilOffset + i].count = 0 --Init count of coils to 0
    end
  end

  --blades
  local bladeOffset = #turbine.map
  local bladeMap = common.util.blockMapLoad(blockmap_paths.blades)
  for i, v in ipairs(configs.configuration.overhaul.turbine.blades) do
    if not bladeMap[v.name] then
      error("Missing map entry: " .. v.name)
    else
      turbine.map[bladeOffset + i] = bladeMap[v.name]
      turbine.map[bladeOffset + i].count = 0 --Init count of blades to 0
    end
  end

  --Generate inverse map
  turbine.map_inverse = common.util.blockMapInverse(blockMap)

  --check turbine dimensions
  local internalDiameter = configs[id].size[1]
  if internalDiameter < 3 then return nil, "Internal Diameter is too small!" end

  local oallLength = configs[id].size[2] + 2
  if oallLength < 3 then return nil, "Turbine length is too small!" end

  local bearingDiameter = configs[id].size[3]
  if bearingDiameter < 1 then return nil, "Bearing diameter is too small" end
  if bearingDiameter > (internalDiameter - 2) then return nil, "Bearing diameter is too large" end

  --calc and store general turbine dims
  local externalDiameter = internalDiameter + 2
  turbine.size.x = externalDiameter --Add 2 for casing
  turbine.size.y = externalDiameter
  turbine.size.z = oallLength

  if flags.debug then print(string.format("[INFO] Turbine Dimensions: x = %2d, y = %2d, z = %2d", turbine.size.x, turbine.size.y, turbine.size.z)) end

  if (internalDiameter % 2 == 0 and bearingDiameter % 2 == 0) 
        or (internalDiameter % 2 == 1 and bearingDiameter % 2 == 1) then
    turbine.shaft.center = (internalDiameter + 1) / 2
    turbine.shaft.min = turbine.shaft.center - ((bearingDiameter - 1) / 2)
    turbine.shaft.max = turbine.shaft.center + ((bearingDiameter - 1) / 2)
  else
    return nil, "Internal diameter and bearing diameter are not compatible"
  end

  if flags.debug then print(string.format("[INFO] Turbine Shaft Dimensions: c = %2d, >= %2d, <= %2d", turbine.shaft.center, turbine.shaft.min, turbine.shaft.max)) end

  --Generate Block map
  local coilPos = 1
  turbine.blocks = {}
  for x = 1, turbine.size.x do
    turbine.blocks[x] = {}
    for y = 1, turbine.size.y do
      turbine.blocks[x][y] = {}
      for z = 1, turbine.size.z do

        --Frame
        if (x == 1 and (y == 1 or z == 1 or y == turbine.size.y or z == turbine.size.z)) --Check for corners and edges of front
            or (x == turbine.size.x and (y == 1 or z == 1 or y == turbine.size.y or z == turbine.size.z)) -- back face
            or (z == 1 and (y == 1 or y == turbine.size.y)) or (z == turbine.size.z and (y == 1 or y == turbine.size.y)) then -- x parallel axes
          turbine.blocks[x][y][z] = 1 --Casing
          turbine.map[1].count = turbine.map[1].count + 1 --Increment block count

        --Casing Faces
        elseif x == 1 or y == 1 or x == turbine.size.x or y == turbine.size.y then
          turbine.blocks[x][y][z] = 1 --Casing
          turbine.map[1].count = turbine.map[1].count + 1 --Increment block count

        --Coil Faces
        elseif z == 1 or z == turbine.size.z then
          local coilId = configs[id].coils[coilPos]
          turbine.blocks[x][y][z] = coilId == 0 and 1 or coilOffset + coilId
          if coilId ~= 0 then turbine.map[coilOffset + coilId].count = turbine.map[coilOffset + coilId].count + 1 end--Increment block count
          coilPos = coilPos + 1

        --Inside
        else

          --Shaft
          if (x >= turbine.shaft.min and x <= turbine.shaft.max) and (y >= turbine.shaft.min and y <= turbine.shaft.max) then
            turbine.blocks[x][y][z] = 3
            turbine.map[3].count = turbine.map[3].count + 1 --Increment block count

          --Blade
          elseif (x < turbine.shaft.min or x > turbine.shaft.max) and (y >= turbine.shaft.min and y <= turbine.shaft.max)
              or (y < turbine.shaft.min or y > turbine.shaft.max) and (x >= turbine.shaft.min and x <= turbine.shaft.max) then
            local bladeId = configs[id].blades[z - 1]
            turbine.blocks[x][y][z] = bladeId == 0 and 0 or bladeOffset + bladeId
            if bladeId ~= 0 then turbine.map[bladeOffset + bladeId].count = turbine.map[bladeOffset + bladeId].count + 1 end--Increment block count

          --Air
          else
            turbine.blocks[x][y][z] = 0
          end
        end

      end
    end
  end

  --Check startOffset
  for k, v in pairs(turbine.startOffset) do
    if v < 1 or v > turbine.size[k] then return nil, "Start offset is invalid" end
  end

  -- Check block count and inv size with user
  local sum = 0
  local stacks = 0
  print("Block count: ")
  for i, v in ipairs(turbine.map) do
    print(common.util.getBlockName(v, turbine.map_inverse) .. ": " .. v.count)
    sum = sum + v.count
    stacks = stacks + math.ceil(v.count / 64)
  end

  local maxInvSlots = math.max(stacks, #turbine.map)
  print("Total types of blocks: " .. #turbine.map)
  print("Total number of blocks: " .. sum)
  print("Number of inventory slots required: " .. maxInvSlots)

  local robotInvSize = robot.inventorySize()
  if robotInvSize == 0 and not flags.disableInvCheck then return nil, "Robot does not have any inventory slots!" end

  if robotInvSize < maxInvSlots then
    local externalInvSize, msg = inv_controller.getInventorySize(sides.down)
    if not externalInvSize and not flags.disableInvCheck then return nil, "External Inventory Error: " .. msg end
    if (robotInvSize + externalInvSize) < maxInvSlots then
      print("[WARN] Available inventory size may be too small.")
    end
  end

  if not flags.disableInvCheck and not flags.disablePrompts then
    print("Continue? [Y/n]")
    if string.lower(io.read()) == "n" then return nil, "User stopped the process" end
  end

  return turbine
end

local function stockUp(offset, turbine)

  if flags.debug then print("[INFO] Stocking Up") end

  local invSize = robot.inventorySize()
  local blockStacks = {}

  if flags.debug then print("[INFO] Indexing Internal Slots") end

  --Count/Load already occupied slots
  local availableSlots = invSize
  for i = 1, invSize do
    local slot = inv_controller.getStackInInternalSlot(i)
    if slot then
      blockStacks[i] = slot
      blockStacks[i].toLoad = 0
      availableSlots = availableSlots - 1
    end
  end

  if flags.debug then print("[INFO] Available slots: " .. availableSlots) end
  if flags.debug then print("[INFO] Generating future block map") end

  --Find which blocks will be used next and fill up remaining slots with those
  local full = false
  for y = offset.y, turbine.size.y do
    for z = offset.z, turbine.size.z do
      for x = offset.x, turbine.size.x do
        local block = turbine.map[turbine.blocks[x][y][z]]
        local loaded = false
        if block then
          for i = 1, invSize do
            if blockStacks[i] then
              if blockStacks[i].name == block.name and blockStacks[i].damage == block.damage and (blockStacks[i].size + blockStacks[i].toLoad) <= blockStacks[i].maxSize then
                blockStacks[i].toLoad = blockStacks[i].toLoad + 1
                loaded = true
              end
            else
              blockStacks[i] = {name = block.name, damage = block.damage, size = 0, maxSize = 64, toLoad = 1}
              loaded = true
            end
            if loaded then break end
          end
          full = not loaded
        end
        if full then break end
      end
      if full then break end
    end
    if full then break end
  end

  if flags.debug then print("[INFO] Finished future block map") end
  if flags.debug then print("[INFO] Loading Inventory") end

  --Fill up all slots to max from external inv
  for i = 1, invSize do
    local slot = blockStacks[i]
    if slot then
      local availableSpace = slot.maxSize - slot.size
      if availableSpace > 0 then
        if flags.debug then print("[INFO] Looking for " .. availableSpace .. " " .. common.util.getBlockName(slot, turbine.map_inverse)) end
        for e = 1, common.util.protectedMethod(inv_controller.getInventorySize, sides.bottom) do
          if availableSpace <= 0 then break end
          local v = inv_controller.getStackInSlot(sides.bottom, e)
          if v and slot.name == v.name and slot.damage == v.damage then
            availableSpace = availableSpace - common.util.protectedMethod(inv_controller.suckFromSlot, sides.bottom, e, availableSpace)
          end
        end
      end
    end
  end

  if flags.debug then print("[INFO] Done Loading Inventory") end
end

local function getBlock(block, offset, turbine)

  local currentSlot = inv_controller.getStackInInternalSlot()

  if not block then return end --Air/nil

  --Check if block is in current slot
  if currentSlot and currentSlot.name == block.name and currentSlot.damage == block.damage then
    if flags.debug then print("[INFO] Found block in slot") end
    common.util.protectedPlaceBlock()
    return
  end

  if flags.debug then print("[INFO] Block not in current slot, looking in local inventory") end

  --Check if block is in robot inventory
  for i = 1, robot.inventorySize() do
    currentSlot = inv_controller.getStackInInternalSlot(i)
    if currentSlot and currentSlot.name == block.name and currentSlot.damage == block.damage then
      robot.select(i)
      common.util.protectedPlaceBlock()
      return
    end
  end

  if flags.debug then print("[INFO] Block not found in local inventory, going back to stock up") end

  --Repeat block fetch until block is placed or user exits
  while true do
    --Go back to base chest
    robot.setLightColor(0xffff00)
    common.movement.protectedMove(robot.back, offset.x - 1)
    common.movement.protectedTurn(robot.turnRight)
    common.movement.protectedMove(robot.back, offset.z - 1)
    common.movement.protectedTurn(robot.turnLeft)
    common.movement.protectedMove(robot.back, 1)
    common.movement.protectedMove(robot.down, offset.y - 1)

    --Stock up
    stockUp(offset, turbine)

    --Do the same moves, in reverse!
    common.movement.protectedMove(robot.up, offset.y - 1)
    common.movement.protectedMove(robot.forward, 1)
    common.movement.protectedTurn(robot.turnRight)
    common.movement.protectedMove(robot.forward, offset.z - 1)
    common.movement.protectedTurn(robot.turnLeft)
    common.movement.protectedMove(robot.forward, offset.x - 1)
    robot.setLightColor(0x00ff00)

    --Again, check if block is in local inv
    for i = 1, robot.inventorySize() do
      currentSlot = inv_controller.getStackInInternalSlot(i)
      if currentSlot and currentSlot.name == block.name and currentSlot.damage == block.damage then
        robot.select(i)
        common.util.protectedPlaceBlock()
        return
      end
    end

    common.util.errorState("Could not find " .. common.util.getBlockName(block, turbine.map_inverse))
  end
end

local function build(turbine)

  --set robot color to active
  robot.setLightColor(0x00ff00)

  --stock up
  stockUp(turbine.startOffset, turbine)

  --move to start offset
  common.movement.protectedMove(robot.up, turbine.startOffset.y - 1)
  common.movement.protectedMove(robot.forward, 1)
  common.movement.protectedTurn(robot.turnRight)
  common.movement.protectedMove(robot.forward, turbine.startOffset.z - 1)
  common.movement.protectedTurn(robot.turnLeft)
  common.movement.protectedMove(robot.forward, turbine.startOffset.x - 2)

  --build turbine
  for y = turbine.startOffset.y, turbine.size.y do
    for z = turbine.startOffset.z, turbine.size.z do
      for x = turbine.startOffset.x, turbine.size.x do
        local block = turbine.blocks[x][y][z]
        if flags.debug then print(string.format("[BLOCK] x: %d, y: %d, z: %d =>", x, y, z) .. common.util.getBlockName(turbine.map[block], turbine.map_inverse)) end
        getBlock(turbine.map[block], {x = x, y = y, z = z}, turbine)
        if x < turbine.size.x then common.movement.nextBlock() end
      end
      if z < turbine.size.z then common.movement.nextLine(turbine.size.x - 1) end
    end
    if flags.pauseOnLayer then common.util.errorState("Pause on layer mode activated. Waiting for user to resume operation") end
    if y < turbine.size.y then common.movement.nextLayer(turbine.size.z - 1, turbine.size.x - 1) end
  end

  common.movement.protectedMove(robot.back, turbine.size.x - 1)
  common.movement.protectedTurn(robot.turnRight)
  common.movement.protectedMove(robot.back, turbine.size.z - 1)
  common.movement.protectedTurn(robot.turnLeft)
  common.movement.protectedMove(robot.back, 1)
  common.movement.protectedMove(robot.down, turbine.size.y - 1)
  print("Finished Building turbine!")
  robot.setLightColor(0x000000)

end

--[[
SYNTAX: turbine_builder [-d/g/o/s/I/p/l] <filename> [<x> <y> <z>]
<filename>: filename of turbine (only ncpf files are supported right now)
[<x> <y> <z>]: start offset of turbine: useful if program crashed and you want to finish the turbine from x, y, z

-d/--debug: enable debug mode, prints more to output
-g/--ghost: enable ghost mode (robot does all moves, but does not place blocks) (still checks for inventory space and blocks)
-o/--outline: trace the outline of the turbine before building anything. Robot will move along x, y and z axis and return home
-s/--stationary/--disableMovement: disables robot movement (also enables ghost mode)
-I/--disableInvCheck: disables the inventory check
-p/--disablePrompts: disables all prompts, defaulting turbine ID to 1. Useful for running programs into output files. If in an error state, will always exit the program
--]]

local args = loadArgs(...)
local filename = args[1]
local startOffset = {x = tonumber(args[2]) or 1, y = tonumber(args[3]) or 1, z = tonumber(args[4]) or 1}
local turbine, msg = loadTurbine(filename, startOffset)

--Error checking
if not turbine then
  print("[ERROR] " .. msg)
  os.exit()
end

if flags.outline then
  common.movement.traceOutline(turbine)
else
  build(turbine)
end