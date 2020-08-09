--[[
NCO Reactor Builder Download Script by Sanrom
v0.1.0
]]
local component = require("component")
local shell = require("shell")

if not component.isAvailable("internet") then error("Internet Card not installed") end

local args, ops = shell.parse(...)

local repo = "https://raw.githubusercontent.com/sanrom/nco-reactor-builder/"
local branch = args[1] or "master"

local function downloadFile(filename)
  local res, msg = shell.execute("wget -f " .. filename)
  if not res and msg then error("Error downloading file: " .. msg) elseif not res then error("Unknown error downloading file") end
end

downloadFile(repo .. branch .. "/config2_parser.lua")
downloadFile(repo .. branch .. "/reactor_builder.lua")