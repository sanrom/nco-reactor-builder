--[[
NCO Reactor Builder by Sanrom
v0.3.2

LINKS:
NCO: https://github.com/turbodiesel4598/NuclearCraft
NCPF Format: https://docs.google.com/document/d/1dzU2arDrD7n9doRua8laxzRy9_RtX-cuv1sUJBB5aGY/edit#
--]]


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

local id_map = {[1] = "fissionSFR", [2] = "fissionMSR"}
local blockmap_paths = {[1] = "overhaulSFR", [2] = "overhaulMSR"}

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

  if ops.l or ops.pauseOnLayer then
    flags.pauseOnLayer = true
  end
  
  return args
end

--LOAD

local function loadReactor(filename, startOffset)

  local reactor = {map = {}, size = {}, startOffset = startOffset or {x = 1, y = 1, z = 1}}

  --Parse the file using config2_parser
  local configs = parser.ncpf(filename)

  --Print all the reactors available
  local id = 0
  if configs.header.count > 1 then
    for i = 1, configs.header.count do
      if configs[i].id >= 1 and configs[i].id <= 2 then
        if configs[i].metadata then
          print(string.format("ID: %2d  Size: %2d x %2d x %2d  Name: %s  Author: %s",
              i, configs[i].size[1], configs[i].size[2], configs[i].size[3],
              configs[i].metadata.Name or "", configs[i].metadata.Author or ""))
        else
          print(string.format("ID: %2d  Size: %2d x %2d x %2d", 
              i, configs[i].size[1], configs[i].size[2], configs[i].size[3]))
        end
      end
    end

    --Prompt user to select one of the reactors
    id = 0
    io.write("Please enter the ID of the reactor to load: ")
    id = not flags.disablePrompts and tonumber(io.read()) or 1
  else
    id = 1
  end

  if id < 1 or id > configs.header.count then
    return nil, "ID not valid!"

  --Check format
  elseif configs[id].id == 3 then
    return nil, "This is a turbine, please use turbine_builder instead"
  elseif configs[id].id < 1 or configs[id].id > 2 then
    return nil, "Only Overhaul SFRs and MSRs are supported right now. Other types of reactors will be added soon"
  elseif not configs[id].compact then
    return nil, "Only compact format is supported right now. Other formats will be added soon"
  end

  --Generate ID map
  local blockMap = common.util.blockMapLoad(blockmap_paths[configs[id].id])
  for i, v in ipairs(configs.configuration.overhaul[id_map[configs[id].id]].blocks) do
    if not blockMap[v.name] then
      error("Missing map entry: " .. v.name)
    else
      reactor.map[i] = blockMap[v.name]
      reactor.map[i].count = 0 --Init count of blocks to 0
    end
  end

  reactor.map_inverse = common.util.blockMapInverse(blockMap)

  --Load reactor size
  reactor.size.x = configs[id].size[1]
  reactor.size.y = configs[id].size[2]
  reactor.size.z = configs[id].size[3]

  --Check startOffset
  for k, v in pairs(reactor.startOffset) do
    if v < 1 or v > reactor.size[k] then return nil, "Start offset is invalid" end
  end

  --Load reactor blocks
  local blockPos = 1
  reactor.blocks = {}
  for x = 1, reactor.size.x do
    reactor.blocks[x] = {}
    for y = 1, reactor.size.y do
      reactor.blocks[x][y] = {}
      for z = 1, reactor.size.z do
        local blockId = configs[id].blocks[blockPos] --Get the block Id from the ncpf table
        reactor.blocks[x][y][z] = blockId --Set the block in the 3d array to that id
        if blockId ~= 0 then
          reactor.map[blockId].count = reactor.map[blockId].count + 1 --Incremenet the count of type of block by one
        end
        blockPos = blockPos + 1 --Increment the blockPos by one to read the next block
      end
    end
  end

  --Check block count and inv size with user
  local sum = 0
  local stacks = 0
  print("Block count: ")
  for i, v in ipairs(reactor.map) do
    print(common.util.getBlockName(v, reactor.map_inverse) .. ": " .. v.count)
    sum = sum + v.count
    stacks = stacks + math.ceil(v.count / 64)
  end

  local maxInvSlots = math.max(stacks, #reactor.map)
  print("Total types of blocks: " .. #reactor.map)
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

  return reactor
end

--MOVEMENT: SEE RBUTIL

--BUILD

local function stockUp(offset, reactor)

  if flags.debug then print("[INFO] Stocking Up") end

  local invSize = robot.inventorySize()
  local blockStacks = {}

  if flags.debug then print("[INFO] Emptying Slots") end

  --Unload inventory if possible
  for i = 1, invSize do
    robot.select(i)
    local slot = inv_controller.getStackInInternalSlot(i)
    if slot then
      for e = 1, common.util.protectedMethod(inv_controller.getInventorySize, sides.bottom) do
        local v = inv_controller.getStackInSlot(sides.bottom, e)
        if not v or (v.name == slot.name and v.damage == slot.damage and v.size < v.maxSize) then
          local dropAmount = not v and slot.size or math.min(slot.size, (v.maxSize - v.size))
          common.util.protectedMethod(inv_controller.dropIntoSlot, sides.bottom, e, dropAmount)
          if dropAmount == slot.size then break end
        end
      end
    end
  end

  if flags.debug then print("[INFO] Indexing Internal Slots") end

  --Count/Load still occupied slots
  local availableSlots = invSize
  for i = 1, invSize do
    robot.select(i)
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
  for y = offset.y, reactor.size.y do
    for z = offset.z, reactor.size.z do
      for x = offset.x, reactor.size.x do
        local block = reactor.map[reactor.blocks[x][y][z]]
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

  if flags.debug then print("[INFO] Loading Inventory") end

  --Fill up all slots to max from external inv
  for i = 1, invSize do
    local slot = blockStacks[i]
    robot.select(i)
    if slot then
      local toLoad = math.min(slot.maxSize - slot.size, slot.toLoad)
      if toLoad > 0 then
        if flags.debug then print("[INFO] Looking for " .. toLoad .. " " .. common.util.getBlockName(slot, reactor.map_inverse)) end
        for e = 1, common.util.protectedMethod(inv_controller.getInventorySize, sides.bottom) do
          if toLoad <= 0 then break end
          local v = inv_controller.getStackInSlot(sides.bottom, e)
          if v and slot.name == v.name and slot.damage == v.damage then
            toLoad = toLoad - common.util.protectedMethod(inv_controller.suckFromSlot, sides.bottom, e, toLoad)
          end
        end
      end
    end
  end

  if flags.debug then print("[INFO] Done Loading Inventory") end

  robot.select(1) --go back to first slot
end

local function getBlock(block, offset, reactor)

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
    stockUp(offset, reactor)

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

    common.util.errorState("Could not find " .. common.util.getBlockName(block, reactor.map_inverse))
  end
end

local function build(reactor)

  --set robot color to active
  robot.setLightColor(0x00ff00)

  --stock up
  stockUp(reactor.startOffset, reactor)

  --move to start offset
  common.movement.protectedMove(robot.up, reactor.startOffset.y - 1)
  common.movement.protectedMove(robot.forward, 1)
  common.movement.protectedTurn(robot.turnRight)
  common.movement.protectedMove(robot.forward, reactor.startOffset.z - 1)
  common.movement.protectedTurn(robot.turnLeft)
  common.movement.protectedMove(robot.forward, reactor.startOffset.x - 2)

  --build reactor
  for y = reactor.startOffset.y, reactor.size.y do
    for z = reactor.startOffset.z, reactor.size.z do
      for x = reactor.startOffset.x, reactor.size.x do
        local block = reactor.blocks[x][y][z]
        if flags.debug then print(string.format("[BLOCK] x: %d, y: %d, z: %d =>", x, y, z) .. common.util.getBlockName(reactor.map[block], reactor.map_inverse)) end
        getBlock(reactor.map[block], {x = x, y = y, z = z}, reactor)
        if x < reactor.size.x then common.movement.nextBlock() end
      end
      if z < reactor.size.z then common.movement.nextLine(reactor.size.x - 1) end
    end
    if flags.pauseOnLayer then common.util.errorState("Pause on layer mode activated. Waiting for user to resume operation") end
    if y < reactor.size.y then common.movement.nextLayer(reactor.size.z - 1, reactor.size.x - 1) end
  end

  common.movement.protectedMove(robot.back, reactor.size.x - 1)
  common.movement.protectedTurn(robot.turnRight)
  common.movement.protectedMove(robot.back, reactor.size.z - 1)
  common.movement.protectedTurn(robot.turnLeft)
  common.movement.protectedMove(robot.back, 1)
  common.movement.protectedMove(robot.down, reactor.size.y - 1)
  print("Finished Building Reactor!")
  robot.setLightColor(0x000000)

end

--[[
SYNTAX: reactor_builder [-d/g/o/s/I/p/l] <filename> [<x> <y> <z>]
<filename>: filename of reactor (only ncpf files are supported right now)
[<x> <y> <z>]: start offset of reactor: useful if program crashed and you want to finish the reactor from x, y, z

-d/--debug: enable debug mode, prints more to output
-g/--ghost: enable ghost mode (robot does all moves, but does not place blocks) (still checks for inventory space and blocks)
-o/--outline: trace the outline of the reactor before building anything. Robot will move along x, y and z axis and return home
-s/--stationary/--disableMovement: disables robot movement (also enables ghost mode)
-I/--disableInvCheck: disables the inventory check
-p/--disablePrompts: disables all prompts, defaulting reactor ID to 1. Useful for running programs into output files. If in an error state, will always exit the program
-l/--pauseOnLayer: pauses the robot on each layer to allow manually filtering cells
--]]

local args = loadArgs(...)
local filename = args[1]
local startOffset = {x = tonumber(args[2]) or 1, y = tonumber(args[3]) or 1, z = tonumber(args[4]) or 1}
local reactor, msg = loadReactor(filename, startOffset)

--Error checking
if not reactor then
  print("[ERROR] " .. msg)
  os.exit()
end

if flags.outline then
  common.movement.traceOutline(reactor)
else
  build(reactor)
end