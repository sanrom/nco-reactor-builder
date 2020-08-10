--[[
NCO Reactor Builder by Sanrom
v0.2.1

LINKS:
NCO: https://github.com/turbodiesel4598/NuclearCraft
NCPF Format: https://docs.google.com/document/d/1dzU2arDrD7n9doRua8laxzRy9_RtX-cuv1sUJBB5aGY/edit#
--]]


local component = require("component")
local parser = require("config2_parser")
local sides = require("sides")
local shell = require("shell")
-- local os = require("os")
local event = require("event")

if not component.isAvailable("robot") then error("This program can only be run from a robot") end
local robot = require("robot")

if not component.isAvailable("inventory_controller") then error("This program requires an inventory controller to run") end
local inv_controller = component.inventory_controller

local flags = {}
local map = {
  --General
  ["Fuel Cell"] = {name = "nuclearcraft:solid_fission_cell", damage = 0},
  ["Fuel Vessel"] = {name = "nuclearcraft:salt_fission_vessel", damage = 0},
  ["Neutron Irradiator"] = {name = "nuclearcraft:fission_irradiator", damage = 0},
  ["Conductor"] = {name = "nuclearcraft:fission_conductor", damage = 0},

  --Reflectors
  ["Beryllium-Carbon Reflector"] = {name = "nuclearcraft:fission_reflector", damage = 0},
  ["Lead-Steel Reflector"] = {name = "nuclearcraft:fission_reflector", damage = 1},

  --Shields
  ["Boron-Silver Neutron Shield"] = {name = "nuclearcraft:fission_shield", damage = 0},

  --Moderators
  ["Graphite Moderator"] = {name = "nuclearcraft:ingot_block", damage = 8},
  ["Beryllium Moderator"] = {name = "nuclearcraft:ingot_block", damage = 9},
  ["Heavy Water Moderator"] = {name = "nuclearcraft:heavy_water_moderator", damage = 0},

  --Heat Sink 1
  ["Water Heat Sink"] = {name = "nuclearcraft:solid_fission_sink", damage = 0},
  ["Iron Heat Sink"] = {name = "nuclearcraft:solid_fission_sink", damage = 1},
  ["Redstone Heat Sink"] = {name = "nuclearcraft:solid_fission_sink", damage = 2},
  ["Quartz Heat Sink"] = {name = "nuclearcraft:solid_fission_sink", damage = 3},
  ["Obsidian Heat Sink"] = {name = "nuclearcraft:solid_fission_sink", damage = 4},
  ["Nether Brick Heat Sink"] = {name = "nuclearcraft:solid_fission_sink", damage = 5},
  ["Glowstone Heat Sink"] = {name = "nuclearcraft:solid_fission_sink", damage = 6},
  ["Lapis Heat Sink"] = {name = "nuclearcraft:solid_fission_sink", damage = 7},
  ["Gold Heat Sink"] = {name = "nuclearcraft:solid_fission_sink", damage = 8},
  ["Prismarine Heat Sink"] = {name = "nuclearcraft:solid_fission_sink", damage = 9},
  ["Slime Heat Sink"] = {name = "nuclearcraft:solid_fission_sink", damage = 10},
  ["End Stone Heat Sink"] = {name = "nuclearcraft:solid_fission_sink", damage = 11},
  ["Purpur Heat Sink"] = {name = "nuclearcraft:solid_fission_sink", damage = 12},
  ["Diamond Heat Sink"] = {name = "nuclearcraft:solid_fission_sink", damage = 13},
  ["Emerald Heat Sink"] = {name = "nuclearcraft:solid_fission_sink", damage = 14},
  ["Copper Heat Sink"] = {name = "nuclearcraft:solid_fission_sink", damage = 15},

  --Heat Sink 2
  ["Tin Heat Sink"] = {name = "nuclearcraft:solid_fission_sink2", damage = 0},
  ["Lead Heat Sink"] = {name = "nuclearcraft:solid_fission_sink2", damage = 1},
  ["Boron Heat Sink"] = {name = "nuclearcraft:solid_fission_sink2", damage = 2},
  ["Lithium Heat Sink"] = {name = "nuclearcraft:solid_fission_sink2", damage = 3},
  ["Magnesium Heat Sink"] = {name = "nuclearcraft:solid_fission_sink2", damage = 4},
  ["Manganese Heat Sink"] = {name = "nuclearcraft:solid_fission_sink2", damage = 5},
  ["Aluminum Heat Sink"] = {name = "nuclearcraft:solid_fission_sink2", damage = 6},
  ["Silver Heat Sink"] = {name = "nuclearcraft:solid_fission_sink2", damage = 7},
  ["Fluorite Heat Sink"] = {name = "nuclearcraft:solid_fission_sink2", damage = 8},
  ["Villiaumite Heat Sink"] = {name = "nuclearcraft:solid_fission_sink2", damage = 9},
  ["Carobbiite Heat Sink"] = {name = "nuclearcraft:solid_fission_sink2", damage = 10},
  ["Arsenic Heat Sink"] = {name = "nuclearcraft:solid_fission_sink2", damage = 11},
  ["Liquid Nitrogen Heat Sink"] = {name = "nuclearcraft:solid_fission_sink2", damage = 12},
  ["Liquid Helium Heat Sink"] = {name = "nuclearcraft:solid_fission_sink2", damage = 13},
  ["Enderium Heat Sink"] = {name = "nuclearcraft:solid_fission_sink2", damage = 14},
  ["Cryotheum Heat Sink"] = {name = "nuclearcraft:solid_fission_sink2", damage = 15},

  --Coolant Heater 1
  ["Standard Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater", damage = 0},
  ["Iron Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater", damage = 1},
  ["Redstone Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater", damage = 2},
  ["Quartz Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater", damage = 3},
  ["Obsidian Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater", damage = 4},
  ["Nether Brick Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater", damage = 5},
  ["Glowstone Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater", damage = 6},
  ["Lapis Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater", damage = 7},
  ["Gold Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater", damage = 8},
  ["Prismarine Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater", damage = 9},
  ["Slime Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater", damage = 10},
  ["End Stone Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater", damage = 11},
  ["Purpur Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater", damage = 12},
  ["Diamond Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater", damage = 13},
  ["Emerald Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater", damage = 14},
  ["Copper Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater", damage = 15},

  --Coolant Heater 2
  ["Tin Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater2", damage = 0},
  ["Lead Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater2", damage = 1},
  ["Boron Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater2", damage = 2},
  ["Lithium Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater2", damage = 3},
  ["Magnesium Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater2", damage = 4},
  ["Manganese Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater2", damage = 5},
  ["Aluminum Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater2", damage = 6},
  ["Silver Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater2", damage = 7},
  ["Fluorite Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater2", damage = 8},
  ["Villiaumite Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater2", damage = 9},
  ["Carobbiite Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater2", damage = 10},
  ["Arsenic Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater2", damage = 11},
  ["Liquid Nitrogen Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater2", damage = 12},
  ["Liquid Helium Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater2", damage = 13},
  ["Enderium Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater2", damage = 14},
  ["Cryotheum Coolant Heater"] = {name = "nuclearcraft:salt_fission_heater2", damage = 15},
}

local id_map = {"fissionSFR", "fissionMSR"}

--UTIL

local function errorState(msg)
  msg = msg or "Unkown Error"
  robot.setLightColor(0xff0000)
  io.write("[ERROR] " .. msg .. "\n")
  io.write("Resume [Y/n]? ")
  if flags.disablePrompts or string.lower(io.read()) == "n" then 
    io.write("Are you sure you want to exit the program? This will lose all saved progress!\n")
    io.write("Type 'yes' to confirm exit of program: ")
    if flags.disablePrompts or string.lower(io.read()) == "yes" then
      robot.setLightColor(0x000000)
      os.exit()
    end
  end
  robot.setLightColor(0x00ff00)
end

local map_inverse = {}
for k, v in pairs(map) do
  map_inverse[v.name .. ":" .. v.damage] = k
end

local function interruptHandler()
  errorState("User interrupted the program")
end

event.listen("interrupted", interruptHandler)

local function getBlockName(block)
  return block and (block.name and block.damage and map_inverse[block.name .. ":" .. math.tointeger(block.damage)] or "Unknown") or "Air"
end

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
      if configs[i].metadata then
        print(string.format("ID: %2d  Size: %2d x %2d x %2d  Name: %s  Author: %s",
            i, configs[i].size[1], configs[i].size[2], configs[i].size[3],
            configs[i].metadata.Name or "", configs[i].metadata.Author or ""))
      else
        print(string.format("ID: %2d  Size: %2d x %2d x %2d", 
            i, configs[i].size[1], configs[i].size[2], configs[i].size[3]))
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
  elseif not configs[id].compact then
    return nil, "Only compact format is supported right now. Other formats will be added soon"
  elseif configs[id].id < 1 or configs[id].id > 2 then
    return nil, "Only Overhaul SFRs and MSRs are supported right now. Other types of reactors will be added soon"
  end

  --Generate ID map 
  for i, v in ipairs(configs.configuration.overhaul[id_map[configs[id].id]].blocks) do
    if not map[v.name] then
      error("Missing map entry: " .. v.name)
    else
      reactor.map[i] = map[v.name]
      reactor.map[i].count = 0 --Init count of blocks to 0
    end
  end

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
    local k = v.name .. ":" .. v.damage
    print(map_inverse[k] .. ": " .. v.count)
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

--MOVEMENT

local function protectedMove(move, steps)
  steps = steps or 1
  if not flags.disableMovement then
    for i = 1, steps do
      local res, msg
      repeat
        res, msg = move()
        if not res then
          errorState(msg)
        end
      until res
    end
  end
end

local function protectedTurn(turn)
  if not flags.disableMovement then
    local res, msg
    repeat
      res, msg = turn()
      if not res then
        errorState(msg)
      end
    until res
  end
end

local function nextLayer(x, z)
  if flags.debug then print("[MOVE] Next Layer") end
  protectedMove(robot.back, z)
  protectedTurn(robot.turnLeft)
  protectedMove(robot.forward, x)
  protectedTurn(robot.turnRight)
  protectedMove(robot.up, 1)
end

local function nextLine(z)
  if flags.debug then print("[MOVE] Next Line") end
  protectedMove(robot.back, z) --back z
  protectedTurn(robot.turnRight) --shift 1 right
  protectedMove(robot.forward, 1)
  protectedTurn(robot.turnLeft)
end

local function nextBlock()
  if flags.debug then print("[MOVE] Next Block") end
  protectedMove(robot.forward, 1) --forward 1
end

--TRACE/BUILD

local function traceOutline(reactor)

  protectedMove(robot.forward, 1)

  --X
  protectedMove(robot.forward, reactor.size.x)
  protectedMove(robot.back, reactor.size.x)

  --Y
  protectedMove(robot.up, reactor.size.y)
  protectedMove(robot.down, reactor.size.y)

  --Z
  protectedTurn(robot.turnRight)
  protectedMove(robot.forward, reactor.size.z)
  protectedMove(robot.back, reactor.size.z)
  protectedTurn(robot.turnLeft)

  protectedMove(robot.back, 1)
end

local function protectedPlaceBlock()
  if not flags.ghost then
    local res, msg
    repeat
      res, msg = robot.placeDown()
      if not res then
        errorState("Error placing block: " .. (msg or "[unknown]"))
      end
    until res
  end
end

local function protectedMethod(method, ...)
  local res, msg
  repeat
    res, msg = method(...)
    if not res then
      errorState(msg)
    end
  until res
  return res
end

local function stockUp(offset, reactor)

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

  if flags.debug then print("[INFO] Finished future block map") end
  if flags.debug then print("[INFO] Loading Inventory") end

  --Fill up all slots to max from external inv
  for i = 1, invSize do
    local slot = blockStacks[i]
    if slot then
      local availableSpace = slot.maxSize - slot.size
      if availableSpace > 0 then
        if flags.debug then print("[INFO] Looking for " .. availableSpace .. " " .. getBlockName(slot)) end
        for e = 1, protectedMethod(inv_controller.getInventorySize, sides.bottom) do
          if availableSpace <= 0 then break end
          local v = inv_controller.getStackInSlot(sides.bottom, e)
          if v and slot.name == v.name and slot.damage == v.damage then
            availableSpace = availableSpace - protectedMethod(inv_controller.suckFromSlot, sides.bottom, e, availableSpace)
          end
        end
      end
    end
  end

  if flags.debug then print("[INFO] Done Loading Inventory") end
end

local function getBlock(block, offset, reactor)

  local currentSlot = inv_controller.getStackInInternalSlot()

  if not block then return end --Air/nil

  --Check if block is in current slot
  if currentSlot and currentSlot.name == block.name and currentSlot.damage == block.damage then
    if flags.debug then print("[INFO] Found block in slot") end
    protectedPlaceBlock()
    return
  end

  if flags.debug then print("[INFO] Block not in current slot, looking in local inventory") end

  --Check if block is in robot inventory
  for i = 1, robot.inventorySize() do
    currentSlot = inv_controller.getStackInInternalSlot(i)
    if currentSlot and currentSlot.name == block.name and currentSlot.damage == block.damage then
      robot.select(i)
      protectedPlaceBlock()
      return
    end
  end

  if flags.debug then print("[INFO] Block not found in local inventory, going back to stock up") end

  --Repeat block fetch until block is placed or user exits
  while true do
    --Go back to base chest
    robot.setLightColor(0xffff00)
    protectedMove(robot.back, offset.x - 1)
    protectedTurn(robot.turnRight)
    protectedMove(robot.back, offset.z - 1)
    protectedTurn(robot.turnLeft)
    protectedMove(robot.back, 1)
    protectedMove(robot.down, offset.y - 1)

    --Stock up
    stockUp(offset, reactor)

    --Do the same moves, in reverse!
    protectedMove(robot.up, offset.y - 1)
    protectedMove(robot.forward, 1)
    protectedTurn(robot.turnRight)
    protectedMove(robot.forward, offset.z - 1)
    protectedTurn(robot.turnLeft)
    protectedMove(robot.forward, offset.x - 1)
    robot.setLightColor(0x00ff00)

    --Again, check if block is in local inv
    for i = 1, robot.inventorySize() do
      currentSlot = inv_controller.getStackInInternalSlot(i)
      if currentSlot and currentSlot.name == block.name and currentSlot.damage == block.damage then
        robot.select(i)
        protectedPlaceBlock()
        return
      end
    end

    errorState("Could not find " .. getBlockName(block))
  end
end

local function build(reactor)

  --set robot color to active
  robot.setLightColor(0x00ff00)

  --stock up
  stockUp(reactor.startOffset, reactor)

  --move to start offset
  protectedMove(robot.up, reactor.startOffset.y - 1)
  protectedMove(robot.forward, 1)
  protectedTurn(robot.turnRight)
  protectedMove(robot.forward, reactor.startOffset.z - 1)
  protectedTurn(robot.turnLeft)
  protectedMove(robot.forward, reactor.startOffset.x - 2)

  --build reactor
  for y = reactor.startOffset.y, reactor.size.y do
    for z = reactor.startOffset.z, reactor.size.z do
      for x = reactor.startOffset.x, reactor.size.x do
        local block = reactor.blocks[x][y][z]
        if flags.debug then print(string.format("[BLOCK] x: %d, y: %d, z: %d =>", x, y, z) .. getBlockName(reactor.map[block])) end
        getBlock(reactor.map[block], {x = x, y = y, z = z}, reactor)
        if x < reactor.size.x then nextBlock() end
      end
      if z < reactor.size.z then nextLine(reactor.size.x - 1) end
    end
    if flags.pauseOnLayer then errorState("Pause on layer mode activated. Waiting for user to resume operation") end
    if y < reactor.size.y then nextLayer(reactor.size.z - 1, reactor.size.x - 1) end
  end

  protectedMove(robot.back, reactor.size.x - 1)
  protectedTurn(robot.turnRight)
  protectedMove(robot.back, reactor.size.z - 1)
  protectedTurn(robot.turnLeft)
  protectedMove(robot.back, 1)
  protectedMove(robot.down, reactor.size.y - 1)
  print("Finished Building Reactor!")
  robot.setLightColor(0x000000)

end

--[[
SYNTAX: [-d/g/o/s/I/p/l] <filename> [<x> <y> <z>]
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
  traceOutline(reactor)
else
  build(reactor)
end