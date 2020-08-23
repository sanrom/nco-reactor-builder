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

  if ops.S or ops.stationary or ops.disableMovement then
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

  if ops.c or ops.casing then
    flags.casing = true
  end

  flags.glass = {}
  if ops.glass then
    flags.glass.front = true
    flags.glass.back = true
    flags.glass.top = true
    flags.glass.left = true
    flags.glass.right = true
  end

  if ops["glass-top"] then flags.glass.top = true end
  if ops["glass-bottom"] then flags.glass.bottom = true end
  if ops["glass-front"] then flags.glass.front = true end
  if ops["glass-back"] then flags.glass.back = true end
  if ops["glass-left"] then flags.glass.front = true end
  if ops["glass-right"] then flags.glass.back = true end

  if ops.s or ops.sources then
    flags.sources = true
  end

  common.util.setFlags(flags)
  
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
      reactor.map[i].blocksLOS = v.blocksLOS
      reactor.map[i].count = 0 --Init count of blocks to 0
      if v.fuelCell or v.fuelVessel then
        reactor.map[i].fuelContainer = true
      end
    end
  end

  --Load neutron sources if they are required
  local sourceOffset = #reactor.map
  if flags.sources then
    for i, v in ipairs(configs.configuration.overhaul[id_map[configs[id].id]].sources) do
      if not blockMap[v.name] then
        error("Missing map entry: " .. v.name)
      else
        reactor.map[sourceOffset + i] = blockMap[v.name]
        reactor.map[sourceOffset + i].count = 0 --Init count of blades to 0
        reactor.map[sourceOffset + i].replace = true
      end
    end
  end

  reactor.map_inverse = common.util.blockMapInverse(blockMap)

  --If casing mode is enabled
  if flags.casing then

    --Get additional blocks needed for casing
    local casingIdOffset = #reactor.map
    reactor.map[casingIdOffset + 1] = blockMap["Fission Reactor Casing"] or error("Missing map entry: Fission Reactor Casing")
    reactor.map[casingIdOffset + 1].count = 0

    reactor.map[casingIdOffset + 2] = blockMap["Fission Reactor Glass"] or error("Missing map entry: Fission Reactor Glass")
    reactor.map[casingIdOffset + 2].count = 0

    --Load reactor size and add two for casing
    reactor.size.x = configs[id].size[1] + 2
    reactor.size.y = configs[id].size[2] + 2
    reactor.size.z = configs[id].size[3] + 2

    --Generate block map
    local blockPos = 1
    local fuelContainerPos = 1
    reactor.blocks = {}
    reactor.fuelContainers = {}
    for x = 1, reactor.size.x do
      reactor.blocks[x] = {}
      reactor.fuelContainers[x] = {}
      for y = 1, reactor.size.y do
        reactor.blocks[x][y] = {}
        reactor.fuelContainers[x][y] = {}
        for z = 1, reactor.size.z do
          --Frame
          if (x == 1 and (y == 1 or z == 1 or y == reactor.size.y or z == reactor.size.z)) --Check for corners and edges of front
              or (x == reactor.size.x and (y == 1 or z == 1 or y == reactor.size.y or z == reactor.size.z)) -- back face
              or (z == 1 and (y == 1 or y == reactor.size.y)) or (z == reactor.size.z and (y == 1 or y == reactor.size.y)) then -- x parallel axes
            reactor.blocks[x][y][z] = casingIdOffset + 1 --Casing
            reactor.map[casingIdOffset + 1].count = reactor.map[casingIdOffset + 1].count + 1 --Increment block count

          --Casing Faces
          elseif x == 1 or y == 1 or z == 1 or x == reactor.size.x or y == reactor.size.y or z == reactor.size.z then
            local faceBlock = casingIdOffset + 1 --Set face block

            --Glass logic
            if x == 1 and flags.glass.front then faceBlock = faceBlock + 1 end
            if x == reactor.size.x and flags.glass.back then faceBlock = faceBlock + 1 end
            if y == 1 and flags.glass.bottom then faceBlock = faceBlock + 1 end
            if y == reactor.size.y and flags.glass.top then faceBlock = faceBlock + 1 end
            if z == 1 and flags.glass.left then faceBlock = faceBlock + 1 end
            if z == reactor.size.z and flags.glass.right then faceBlock = faceBlock + 1 end

            reactor.blocks[x][y][z] = faceBlock --Casing
            reactor.map[faceBlock].count = reactor.map[faceBlock].count + 1 --Increment block count
          
          --Inside reactor
          else
            local blockId = configs[id].blocks[blockPos] --Get the block Id from the ncpf table
            reactor.blocks[x][y][z] = blockId --Set the block in the 3d array to that id
            if blockId ~= 0 then
              reactor.map[blockId].count = reactor.map[blockId].count + 1 --Incremenet the count of type of block by one
              if reactor.map[blockId].fuelContainer then --If the block is a fuel container (fuel cell or fuel vessel) get fuel and source
                reactor.fuelContainers[x][y][z] = {fuelId = configs[id].fuels[fuelContainerPos], sourceId = configs[id].sources[fuelContainerPos], sourcePlaced = false}
                fuelContainerPos = fuelContainerPos + 1
              end
            end
            blockPos = blockPos + 1 --Increment the blockPos by one to read the next block
          end
        end
      end
    end

    --Source Logic
    if flags.sources then

      local function raytrace(axis, flip, x, y, z)
        local searchStart = flip and reactor.size[axis] - 1 or 2
        local searchEnd = flip and 2 or reactor.size[axis] - 1
        local step = flip and -1 or 1
        for inside = searchStart, searchEnd, step do
          local insideX = axis == "x" and inside or x
          local insideY = axis == "y" and inside or y
          local insideZ = axis == "z" and inside or z
          if reactor.map[reactor.blocks[insideX][insideY][insideZ]] and reactor.map[reactor.blocks[insideX][insideY][insideZ]].blocksLOS then
            local fuelContainer = reactor.fuelContainers[insideX][insideY][insideZ]
            if fuelContainer and fuelContainer.sourceId ~= 0 and not fuelContainer.sourcePlaced then
              -- reactor.blocks[x][y][z] = sourceOffset + fuelContainer.sourceId
              reactor.blocks[x][y][z] = 0 --Sources will NOT be placed, instead holes will be placed
              reactor.map[sourceOffset + fuelContainer.sourceId].count = reactor.map[sourceOffset + fuelContainer.sourceId].count + 1
              fuelContainer.sourcePlaced = true
            end
            break --If blocks LOS then break, no need to search further
          end
        end
      end

      --Order: top => bottom, left => right, front => back
      for y = reactor.size.y, 1, -1 do
        for z = 1, reactor.size.z do
          for x = 1, reactor.size.x do
            if x == 1 then raytrace("x", false, x, y, z) end --front
            if x == reactor.size.x then raytrace("x", true, x, y, z) end --back
            if y == 1 then raytrace("y", false, x, y, z) end --bottom
            if y == reactor.size.y then raytrace("y", true, x, y, z) end --top
            if z == 1 then raytrace("z", false, x, y, z) end --left
            if z == reactor.size.z then raytrace("z", true, x, y, z) end --right
          end
        end
      end

    end


  else
    --Load reactor size
    reactor.size.x = configs[id].size[1]
    reactor.size.y = configs[id].size[2]
    reactor.size.z = configs[id].size[3]

    --Generate block map
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
  end

  --Check startOffset
  for k, v in pairs(reactor.startOffset) do
    if v < 1 or v > reactor.size[k] then return nil, "Start offset is invalid" end
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

local function build(reactor)

  --set robot color to active
  robot.setLightColor(0x00ff00)

  --stock up
  common.inventory.stockUp(reactor.startOffset, reactor)

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
        common.inventory.getBlock(reactor.map[block], {x = x, y = y, z = z}, reactor)
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
-S/--stationary/--disableMovement: disables robot movement (also enables ghost mode)
-I/--disableInvCheck: disables the inventory check
-p/--disablePrompts: disables all prompts, defaulting reactor ID to 1. Useful for running programs into output files. If in an error state, will always exit the program
-l/--pauseOnLayer: pauses the robot on each layer to allow manually filtering cells

-c/--casing: adds casing to reactor. Finished reactor will be 2 blocks larger in each dimension than what is stated
--glass: Use glass for front, back, sides and top faces of reactor. Equivalent to using --glass-front --glass-back --glass-top --glass-left --glass-right
--glass-all: Use glass for all faces of the reactor.
--glass-{front|back|top|bottom|left|right}: Use glass instead of wall for specified reactor face.
-s/--sources: Automatically calculates where neutron sources should be placed and leaves a gap in the casing there.
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
  common.util.time(build, reactor)
end