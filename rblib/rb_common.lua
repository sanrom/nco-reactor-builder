--[[
NCO Reactor Builder Common Stuff by Sanrom
--]]

local robot = require("robot")
local filesystem = require("filesystem")
local component = require("component")
local sides = require("sides")
local shell = require("shell")

if not component.isAvailable("inventory_controller") then error("This program requires an inventory controller to run") end
local inv_controller = component.inventory_controller

local module = {util = {}, movement = {}, inventory = {}, flags = {}}

--LOCAL FUNCTIONS

local function parseLine(str)
  local key, name, damage = string.match(str, "%[([%g%s]+)%]%s*=%s*([_%a]+:[_%a%d]+):(%d+)") --Lua patterns are more cursed than regex
  if not key then return nil end
  return key, {name = name, damage = tonumber(damage)}
end

--UTIL

function module.util.blockMapLoad(baseFileName)

  local map = {}
  --Get all maps which share the base file name
  for filename in filesystem.list(filesystem.concat(shell.getWorkingDirectory(),"rblib/blockmaps")) do
    if string.find(filename, baseFileName) and string.find(filename, ".map") then
      local file = assert(io.open(filesystem.concat(shell.getWorkingDirectory(),"rblib/blockmaps", filename), "r"))
      for line in file:lines() do
        local k, v = parseLine(line)
        if k and v then
          map[k] = v
        end
      end
      file:close()
    end
  end
  return map
end

function module.util.blockMapInverse(map)
  local map_inverse = {}
  for k, v in pairs(map) do
    map_inverse[v.name .. ":" .. v.damage] = k
  end
  return map_inverse
end

function module.util.getBlockName(block, map_inverse)
  return block and (block.name and block.damage and map_inverse[block.name .. ":" .. math.tointeger(block.damage)] or "Unknown") or "Air"
end

function module.util.errorState(msg)
  msg = msg or "Unkown Error"
  robot.setLightColor(0xff0000)
  io.write("[ERROR] " .. msg .. "\n")
  io.write("Resume [Y/n]? ")
  if module.flags.disablePrompts or string.lower(io.read()) == "n" then 
    io.write("Are you sure you want to exit the program? This will lose all saved progress!\n")
    io.write("Type 'yes' to confirm exit of program: ")
    if module.flags.disablePrompts or string.lower(io.read()) == "yes" then
      robot.setLightColor(0x000000)
      os.exit()
    end
  end
  robot.setLightColor(0x00ff00)
end

function module.util.protectedPlaceBlock()
  if not module.flags.ghost then
    local res, msg
    repeat
      res, msg = robot.placeDown()
      if not res then
        module.util.errorState("Error placing block: " .. (msg or "[unknown]"))
      end
    until res
  end
end

function module.util.protectedMethod(method, ...)
  local res, msg
  repeat
    res, msg = method(...)
    if not res then
      module.util.errorState(msg)
    end
  until res
  return res
end

--FLAGS

function module.flags.setFlags(flags)
  module.flags = nil
  module.flags = flags
end

--MOVEMENT

function module.movement.protectedMove(move, steps)
  steps = steps or 1
  if not module.flags.disableMovement then
    for i = 1, steps do
      local res, msg
      repeat
        res, msg = move()
        if not res then
          module.util.errorState(msg)
        end
      until res
    end
  end
end

function module.movement.protectedTurn(turn)
  if not module.flags.disableMovement then
    local res, msg
    repeat
      res, msg = turn()
      if not res then
        module.util.errorState(msg)
      end
    until res
  end
end

function module.movement.nextLayer(x, z)
  if module.flags.debug then print("[MOVE] Next Layer") end
  module.movement.protectedMove(robot.back, z)
  module.movement.protectedTurn(robot.turnLeft)
  module.movement.protectedMove(robot.forward, x)
  module.movement.protectedTurn(robot.turnRight)
  module.movement.protectedMove(robot.up, 1)
end

function module.movement.nextLine(z)
  if module.flags.debug then print("[MOVE] Next Line") end
  module.movement.protectedMove(robot.back, z) --back z
  module.movement.protectedTurn(robot.turnRight) --shift 1 right
  module.movement.protectedMove(robot.forward, 1)
  module.movement.protectedTurn(robot.turnLeft)
end

function module.movement.nextBlock()
  if module.flags.debug then print("[MOVE] Next Block") end
  module.movement.protectedMove(robot.forward, 1) --forward 1
end

function module.movement.traceOutline(multiblock)

  module.movement.protectedMove(robot.forward, 1)

  --X
  module.movement.protectedMove(robot.forward, multiblock.size.x)
  module.movement.protectedMove(robot.back, multiblock.size.x)

  --Y
  module.movement.protectedMove(robot.up, multiblock.size.y)
  module.movement.protectedMove(robot.down, multiblock.size.y)

  --Z
  module.movement.protectedTurn(robot.turnRight)
  module.movement.protectedMove(robot.forward, multiblock.size.z)
  module.movement.protectedMove(robot.back, multiblock.size.z)
  module.movement.protectedTurn(robot.turnLeft)

  module.movement.protectedMove(robot.back, 1)
end

--INVENTORY

function module.inventory.stockUp(offset, multiblock)

  if module.flags.debug then print("[INFO] Stocking Up") end

  local invSize = robot.inventorySize()
  local blockStacks = {}

  if module.flags.debug then print("[INFO] Emptying Slots") end

  --Unload inventory if possible
  for i = 1, invSize do
    robot.select(i)
    local slot = inv_controller.getStackInInternalSlot(i)
    if slot then
      for e = 1, module.util.protectedMethod(inv_controller.getInventorySize, sides.bottom) do
        local v = inv_controller.getStackInSlot(sides.bottom, e)
        if not v or (v.name == slot.name and v.damage == slot.damage and v.size < v.maxSize) then
          local dropAmount = not v and slot.size or math.min(slot.size, (v.maxSize - v.size))
          module.util.protectedMethod(inv_controller.dropIntoSlot, sides.bottom, e, dropAmount)
          if dropAmount == slot.size then break end
        end
      end
    end
  end

  if module.flags.debug then print("[INFO] Indexing Internal Slots") end

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

  if module.flags.debug then print("[INFO] Available slots: " .. availableSlots) end
  if module.flags.debug then print("[INFO] Generating future block map") end

  --Find which blocks will be used next and fill up remaining slots with those
  local full = false
  local passedOffset = false
  for y = 1, multiblock.size.y do
    for z = 1, multiblock.size.z do
      for x = 1, multiblock.size.x do
        if not passedOffset and x == offset.x and y == offset.y and z == offset.z then passedOffset = true end --check if we are passed the current offset
        if passedOffset then
          local block = multiblock.map[multiblock.blocks[x][y][z]] --get the block id from the design
          local loaded = false --if loaded is true, try the next block
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
            full = not loaded --if block was not able to be loaded, then robot inv must be full, exit the loop
          end
        end
        if full then break end
      end
      if full then break end
    end
    if full then break end
  end

  if module.flags.debug then print("[INFO] Sorting blockmap") end

  table.sort(blockStacks, function(a, b)
    return a.toLoad > b.toLoad
  end
  )

  if module.flags.debug then print("[INFO] Loading Inventory") end

  --Fill up all slots to max from external inv
  local lastPos = 0
  for i = 1, invSize do
    local slot = blockStacks[i]
    robot.select(i)
    if slot then
      local toLoad = math.min(slot.maxSize - slot.size, slot.toLoad)
      if toLoad > 0 then
        if module.flags.debug then print("[INFO] Looking for " .. toLoad .. " " .. module.util.getBlockName(slot, multiblock.map_inverse)) end
        local externalInvSize = module.util.protectedMethod(inv_controller.getInventorySize, sides.bottom)
        for e = 1, externalInvSize do
          local searchPos = (e + lastPos) % externalInvSize
          local searchSlot = inv_controller.getStackInSlot(sides.bottom, searchPos)
          if searchSlot and slot.name == searchSlot.name and slot.damage == searchSlot.damage then
            toLoad = toLoad - module.util.protectedMethod(inv_controller.suckFromSlot, sides.bottom, searchPos, toLoad)
          end
          if toLoad <= 0 then
            lastPos = searchPos - 1
            break
          end
        end
      end
    end
  end

  if module.flags.debug then print("[INFO] Done Loading Inventory") end

  robot.select(1) --go back to first slot
end

function module.inventory.getBlock(block, offset, multiblock)

  if not block then return end --Air/nil

  local currentSlot = inv_controller.getStackInInternalSlot()

  --Check if block is in current slot
  if currentSlot and currentSlot.name == block.name and currentSlot.damage == block.damage then
    if module.flags.debug then print("[INFO] Found block in slot") end
    module.util.protectedPlaceBlock()
    return
  end

  if module.flags.debug then print("[INFO] Block not in current slot, looking in local inventory") end

  --Check if block is in robot inventory
  for i = 1, robot.inventorySize() do
    currentSlot = inv_controller.getStackInInternalSlot(i)
    if currentSlot and currentSlot.name == block.name and currentSlot.damage == block.damage then
      robot.select(i)
      module.util.protectedPlaceBlock()
      return
    end
  end

  if module.flags.debug then print("[INFO] Block not found in local inventory, going back to stock up") end

  --Repeat block fetch until block is placed or user exits
  while true do
    --Go back to base chest
    robot.setLightColor(0xffff00)
    module.movement.protectedMove(robot.back, offset.x - 1)
    module.movement.protectedTurn(robot.turnRight)
    module.movement.protectedMove(robot.back, offset.z - 1)
    module.movement.protectedTurn(robot.turnLeft)
    module.movement.protectedMove(robot.back, 1)
    module.movement.protectedMove(robot.down, offset.y - 1)

    --Stock up
    module.inventory.stockUp(offset, multiblock)

    --Do the same moves, in reverse!
    module.movement.protectedMove(robot.up, offset.y - 1)
    module.movement.protectedMove(robot.forward, 1)
    module.movement.protectedTurn(robot.turnRight)
    module.movement.protectedMove(robot.forward, offset.z - 1)
    module.movement.protectedTurn(robot.turnLeft)
    module.movement.protectedMove(robot.forward, offset.x - 1)
    robot.setLightColor(0x00ff00)

    --Again, check if block is in local inv
    for i = 1, robot.inventorySize() do
      currentSlot = inv_controller.getStackInInternalSlot(i)
      if currentSlot and currentSlot.name == block.name and currentSlot.damage == block.damage then
        robot.select(i)
        module.util.protectedPlaceBlock()
        return
      end
    end

    module.util.errorState("Could not find " .. module.util.getBlockName(block, multiblock.map_inverse))
  end
end

return module