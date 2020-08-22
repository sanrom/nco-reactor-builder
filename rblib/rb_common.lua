--[[
NCO Reactor Builder Common Stuff by Sanrom
--]]

local robot = require("robot")
local filesystem = require("filesystem")

local module = {util = {}, movement = {}, flags = {}}

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
  for filename in filesystem.list("rblib/blockmaps") do
    if string.find(filename, baseFileName) and string.find(filename, ".map") then
      local file = assert(io.open(filename, "r"))
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

function module.movement.traceOutline(reactor)

  module.movement.protectedMove(robot.forward, 1)

  --X
  module.movement.protectedMove(robot.forward, reactor.size.x)
  module.movement.protectedMove(robot.back, reactor.size.x)

  --Y
  module.movement.protectedMove(robot.up, reactor.size.y)
  module.movement.protectedMove(robot.down, reactor.size.y)

  --Z
  module.movement.protectedTurn(robot.turnRight)
  module.movement.protectedMove(robot.forward, reactor.size.z)
  module.movement.protectedMove(robot.back, reactor.size.z)
  module.movement.protectedTurn(robot.turnLeft)

  module.movement.protectedMove(robot.back, 1)
end

return module