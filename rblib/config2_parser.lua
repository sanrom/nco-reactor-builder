--[[
Config2 Parser by Sanrom
v0.1.1 fork by Bob
- Changes : a lot of good stuff
Refractored util : unpacked from private tables mostly everything
Removed some of the useless parenthesis, in an interpreted lang they do matter
readUTF : redone to eliminate bad excessive concatenation with immutable strings and instead reuse the bytes table
readFloat : localized the float parts, what the fuck man, globals rly
readConfig : used nil instead of a default empty function

LINKS:
NCPF Format: https://docs.google.com/document/d/1dzU2arDrD7n9doRua8laxzRy9_RtX-cuv1sUJBB5aGY/edit#
Config2 Code: https://github.com/computerneek/SimpleLibrary/tree/master/simplelibrary/config2
DataInput Ref: https://docs.oracle.com/javase/8/docs/api/java/io/DataInput.html
NC Discord : https://discord.gg/YH2CjE
--]]



local byte = string.byte
local function readByte(file)
  return byte(file:read(1))
end

local function readUShort(file)
  return ((readByte(file) & 0xff) << 8) | (readByte(file) & 0xff)
end

local utf8_string = require("utf8").char
local function readUTF(file)
  local len = readUShort(file)
  local bytes = {}

  for i = 1, len do
    bytes[i] = readByte(file)
  end

  for i = 1, len do -- we aint' checking the previous state so we can put the character back direclty at the spot then concat the bytes table as it becames the chars one
    if bytes[i] & 0x80 == 0x00 then
      bytes[i] = utf8_c(bytes[i])
    elseif bytes[i] & 0xe0 == 0xc0 then
      if (bytes[i+1] & 0xc0) == 0x80 then
        bytes[i] = utf8_c(((bytes[i] & 0x1f) << 6) | (bytes[i+1] & 0x3f))
      end
    elseif (bytes[i] & 0xf0) == 0xe0 then
      if bytes[i+1] & 0xc0 == 0x80 and bytes[i+2] & 0xc0 == 0x80 then
        bytes[i] = utf8_c(((bytes[i] & 0x0f) << 12) | ((bytes[i+1] & 0x3f) << 6) | (bytes[i+2] & 0x3f))
      end
    end
  end

  return concat(bytes)
end

local function readInt(file)
  return ((readByte(file) & 0xff) << 24) |
  ((readByte(file) & 0xff) << 16) |
  ((readByte(file) & 0xff) <<  8) |
  (readByte(file) & 0xff)
end

--Impl from: https://docs.oracle.com/javase/7/docs/api/java/lang/Float.html#intBitsToFloat(int)
local function readFloat(file)
  local int = readInt(file)

  if int == 0x7f800000 then --Pos inf
    return 1/0

  elseif int == 0xff800000 then --Neg inf
    return -1/0

  elseif int >= 0x7f800001 and int <= 0x7fffffff or int >= 0xff800001 and int <= 0xffffffff then --NaN
    return 0/0
  else

    local s = (int >> 31) == 0 and 1 or -1
    local e = (int >> 23) & 0xff
    local m = e == 0 and (int & 0x7fffff) << 1 or (int & 0x7fffff) | 0x800000

    return s * m * 2 ^ (e - 150)
  end
end

local function readBoolean(file)
  return readByte(file) ~= 0x00
end

local function readLong(file)
  return (((readByte(file) & 0xff) << 56) |
  ((readByte(file) & 0xff) << 48) |
  ((readByte(file) & 0xff) << 40) |
  ((readByte(file) & 0xff) << 32) |
  ((readByte(file) & 0xff) << 24) |
  ((readByte(file) & 0xff) << 16) |
  ((readByte(file) & 0xff) <<  8) |
  ((readByte(file) & 0xff)))
end

local function readDouble(file)
  local int = readLong(file)

  if int == 0x7ff0000000000000 then --Pos inf
    return 1/0

  elseif int == 0xfff0000000000000 then --Neg inf
    return -1/0

  elseif int >= 0x7ff0000000000001 and int <= 0x7fffffffffffffff or
      int >= 0xfff0000000000001 and int <= 0xffffffffffffffff then --NaN
    return 0/0
  else

    local s = (int >> 63) == 0 and 1 or -1
    local e = (int >> 52) & 0x7ff
    local m = e == 0 and int & 0xfffffffffffff << 1 or (int & 0xfffffffffffff) | 0x10000000000000

    return s * m * 2 ^ (e - 1075)
  end
end

local function readShort(file)
  return (readByte(file) << 8) | (readByte(file) & 0xff)
end

local configTypes = {}

--Config()
configTypes[1] = function (file)
  local result = {}
  local index = readByte(file)
  while index > 0 do
    local data = readConfig(file, index)
    local key = readUTF(file)
    result[key] = data
    index = readByte(file)
  end
  return result
end

configTypes[2] = readUTF --ConfigString()

configTypes[3] = readInt --ConfigInteger()

configTypes[4] = readFloat --ConfigFloat()

configTypes[5] = readBoolean --ConfigBoolean()

configTypes[6] = readLong --ConfigLong()

configTypes[7] = readDouble --ConfigDouble()

configTypes[10] = readByte --ConfigByte()

configTypes[11] = readShort --ConfigShort()

-- configTypes[8] = error --ConfigHugeLong() /!\ REMOVED

--ConfigList
configTypes[9] = function (file)
  local list = {}
  local oneType = readByte(file)
  if oneType == 0 then return list end
  if oneType == 1 then
    local count = readInt(file)
    local index = readByte(file)
    for i = 1, count do
      list[i] = readConfig(file, index)
    end
  else
    local index = readByte(file)
    local i = 1
    while index > 0 do
      list[i] = readConfig(file, index);i = i + 1
      index = readByte(file)
    end
  end
  return list
end

--ConfigNumberList
local min = math.min
configTypes[12] = function (file)
  local list = {}

  local abyte = readByte(file)
  local sizeClass = (abyte & 0xc0) >> 6
  local size = 0

  if sizeClass == 0 then
    size = abyte & 0x3f
  elseif sizeClass == 1 then
    size = ((abyte & 0x3f) << 8) + readByte(file)
  elseif sizeClass == 2 then
    size = ((abyte & 0x3f) << 24) + (readByte(file) << 16) + readShort(file)
  elseif sizeClass == 3 then
    size = readInt(file)
  end

  if size == 0 then return list end
  local digits = readByte(file)
  local verbatum = (digits & 0x80) > 0
  if verbatum then
    for i = 1, size do
      list[i] = readLong(file)
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

  local currentByte, left, nextLeft = 0, 0, 0
  local isNeg = false
  local bits, mask, txfr

  for i = 1, size do
    if left < 1 then
      currentByte = readByte(file)
      left = 8
    end
    if hasNeg then
      isNeg = (currentByte & (1 << (left - 1))) > 0
      left = left - 1
    end
    local number = 0
    nextLeft = digits
    while nextLeft > 0 do
      if left < 1 then
        currentByte = readByte(file)
        left = 8
      end
      bits = min(nextLeft, left)
      mask = (0xff >> (8 - bits)) << (left - bits)
      txfr = (currentByte & mask) >> (left - bits)
      number = number | (txfr << (nextLeft - bits))
      nextLeft = nextLeft - bits
      left = left - bits
    end
    list[i] = isNeg and -number or number
  end
  return list
end

--Default
--configTypes["default"] = function() end

local function readConfig(file, index)
  if configTypes[index] then
    return configTypes[index](file)
  else
    return nil -- configTypes["default"](file) -- returs nil so ?
  end
end

--Parse a single configuration object in the given file
local function parse(file)
  local ver = readShort(file)
  local result = configTypes[1](file)
  result["config2_version"] = ver
  return result
end

--Parse a NCPF file
local function ncpf(filename)
  local configs = {}
  local file = assert(io.open(filename, "rb"))
  configs["header"] = parse(file)
  configs["configuration"] = parse(file)
  for i = 1, configs.header["count"] do
    configs[i] = parse(file)
  end
  file:close()
  return configs
end

return {parse=parse,ncpf=ncpf}
