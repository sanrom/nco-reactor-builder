--[[
Config2 Parser by Sanrom
v0.1.0

LINKS:
NCPF Format: https://docs.google.com/document/d/1dzU2arDrD7n9doRua8laxzRy9_RtX-cuv1sUJBB5aGY/edit#
Config2 Code: https://github.com/computerneek/SimpleLibrary/tree/master/simplelibrary/config2
DataInput Ref: https://docs.oracle.com/javase/8/docs/api/java/io/DataInput.html
--]]

local parser = {}
local util = {}
local configTypes = {}

--Config()
configTypes[1] = function (file)
  local result = {}
  local index = util.readByte(file)
  while index > 0 do
    local data = util.readConfig(file, index)
    local key = util.readUTF(file)
    result[key] = data
    index = util.readByte(file)
  end
  return result
end

--ConfigString()
configTypes[2] = function (file)
  return util.readUTF(file)
end

--ConfigInteger()
configTypes[3] = function (file)
  return util.readInt(file)
end

--ConfigFloat()
configTypes[4] = function (file)
  return util.readFloat(file)
end

--ConfigBoolean()
configTypes[5] = function (file)
  return util.readBoolean(file)
end

--ConfigLong()
configTypes[6] = function (file)
  return util.readLong(file)
end

--ConfigDouble()
configTypes[7] = function (file)
  return util.readDouble(file)
end

--ConfigHugeLong /!\ REMOVED
configTypes[8] = function (file)
  return nil
end

--ConfigList
configTypes[9] = function (file)
  local list = {}
  local oneType = util.readByte(file)
  if oneType == 0 then return list end
  if oneType == 1 then
    local count = util.readInt(file)
    local index = util.readByte(file)
    for i = 1, count do
      local data = util.readConfig(file, index)
      list[i] = data
    end
    return list
  else
    local index = util.readByte(file)
    local i = 1
    while index > 0 do
      local data = util.readConfig(file, index)
      list[i] = data
      i = i + 1
      index = util.readByte(file)
    end
    return list
  end
end

--ConfigByte
configTypes[10] = function (file)
  return util.readByte(file)
end

--ConfigShort
configTypes[11] = function (file)
  return util.readShort(file)
end

--ConfigNumberList
configTypes[12] = function (file)
  local list = {}

  local abyte = util.readByte(file)
  local sizeClass = (abyte & 0xc0) >> 6
  local size = 0

  if sizeClass == 0 then
    size = abyte & 0x3f
  elseif sizeClass == 1 then
    size = ((abyte & 0x3f) << 8) + util.readByte(file)
  elseif sizeClass == 2 then
    size = ((abyte & 0x3f) << 24) + (util.readByte(file) << 16) + util.readShort(file)
  elseif sizeClass == 3 then
    size = util.readInt(file)
  end

  if size == 0 then return list end
  local digits = util.readByte(file)
  local verbatum = (digits & 0x80) > 0
  if verbatum then
    for i = 1, size do
      list[i] = util.readLong(file)
    end
    return list
  end

  local hasNeg = (digits & 0x40) > 0
  digits = digits & 0x3f
  if digits == 0 then
    for i = 1, size do
      list[i] = 0
    end
    return list
  end

  local currentByte, left, number, nextLeft = 0, 0, 0, 0
  local isNeg = false
  local bits, mask, txfr

  for i = 1, size do
    if left < 1 then
      currentByte = util.readByte(file)
      left = 8
    end
    if hasNeg then
      isNeg = (currentByte & (1 << (left - 1))) > 0
      left = left - 1
    end
    number = 0
    nextLeft = digits
    while nextLeft > 0 do
      if left < 1 then
        currentByte = util.readByte(file)
        left = 8
      end
      bits = math.min(nextLeft, left)
      mask = (0xff >> (8 - bits)) << (left - bits)
      txfr = (currentByte & mask) >> (left - bits)
      number = number | (txfr << (nextLeft - bits))
      nextLeft = nextLeft - bits
      left = left - bits
    end
    if (isNeg) then number = -number end
    list[i] = number
  end
  return list
end

--Default
configTypes["default"] = function (file)
  return nil
end

function util.readConfig(file, index)
  if configTypes[index] then
    return configTypes[index](file)
  else
    return configTypes["default"](file)
  end
end

--UTIL FUNCTIONS

function util.loadFile(filename)
  local file = assert(io.open(filename, "rb"))
  return file
end

function util.readByte(file)
  return string.byte(file:read(1))
end

function util.readUShort(file)
  return (((util.readByte(file) & 0xff) << 8) | (util.readByte(file) & 0xff))
end

function util.readUTF(file)
  local len = util.readUShort(file)
  local bytes = {}
  local str = ""

  for i = 1, len do
    bytes[i] = util.readByte(file)
  end

  for i = 1, len do
    if (bytes[i] & 0x80) == 0x00 then
      str = str .. utf8.char(bytes[i])
    elseif (bytes[i] & 0xe0) == 0xc0 then
      if (bytes[i+1] & 0xc0) == 0x80 then
        str = str .. utf8.char(((bytes[i] & 0x1f) << 6) | (bytes[i+1] & 0x3f))
      end
    elseif (bytes[i] & 0xf0) == 0xe0 then
      if ((bytes[i+1] & 0xc0) == 0x80) and ((bytes[i+2] & 0xc0) == 0x80) then
        str = str .. utf8.char(((bytes[i] & 0x0f) << 12) | ((bytes[i+1] & 0x3f) << 6) | (bytes[i+2] & 0x3f))
      end
    end
  end

  return str
end

function util.readInt(file)
  return (((util.readByte(file) & 0xff) << 24) |
  ((util.readByte(file) & 0xff) << 16) |
  ((util.readByte(file) & 0xff) <<  8) |
  (util.readByte(file) & 0xff))
end

--Impl from: https://docs.oracle.com/javase/7/docs/api/java/lang/Float.html#intBitsToFloat(int)
function util.readFloat(file)
  local int = util.readInt(file)

  if int == 0x7f800000 then --Pos inf
    return math.huge

  elseif int == 0xff800000 then --Neg inf
    return -math.huge

  elseif (int >= 0x7f800001 and int <= 0x7fffffff) or (int >= 0xff800001 and int <= 0xffffffff) then --NaN
    return 0/0
  else

    s = ((int >> 31) == 0) and 1 or -1
    e = ((int >> 23) & 0xff)
    m = (e == 0) and (int & 0x7fffff) << 1 or (int & 0x7fffff) | 0x800000

    return s * m * 2 ^ (e - 150)
  end
end

function util.readBoolean(file)
  return util.readByte(file) ~= 0x00
end

function util.readLong(file)
  return (((util.readByte(file) & 0xff) << 56) |
  ((util.readByte(file) & 0xff) << 48) |
  ((util.readByte(file) & 0xff) << 40) |
  ((util.readByte(file) & 0xff) << 32) |
  ((util.readByte(file) & 0xff) << 24) |
  ((util.readByte(file) & 0xff) << 16) |
  ((util.readByte(file) & 0xff) <<  8) |
  ((util.readByte(file) & 0xff)))
end

function util.readDouble(file)
  local int = util.readLong(file)

  if int == 0x7ff0000000000000 then --Pos inf
    return math.huge

  elseif int == 0xfff0000000000000 then --Neg inf
    return -math.huge

  elseif (int >= 0x7ff0000000000001 and int <= 0x7fffffffffffffff) or
      (int >= 0xfff0000000000001 and int <= 0xffffffffffffffff) then --NaN
    return 0/0
  else

    local s = ((int >> 63) == 0) and 1 or -1
    local e = ((int >> 52) & 0x7ff)
    local m = (e == 0) and (int & 0xfffffffffffff) << 1 or (int & 0xfffffffffffff) | 0x10000000000000

    return s * m * 2 ^ (e - 1075)
  end
end

function util.readShort(file)
  return ((util.readByte(file) << 8) | (util.readByte(file) & 0xff))
end

--PARSER FUNCTIONS

--Parse a NCPF file
function parser.ncpf(filename)
  local configs = {}
  local file = util.loadFile(filename)
  configs["header"] = parser.parse(file)
  configs["configuration"] = parser.parse(file)
  for i = 1, configs.header["count"] do
    configs[i] = parser.parse(file)
  end
  file:close()
  return configs
end

--Parse a single configuration object in the given file
function parser.parse(file)
  local ver = util.readShort(file)
  local result = configTypes[1](file)
  result["config2_version"] = ver
  return result
end

return parser