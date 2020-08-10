--[[
NCO Reactor Builder Download Script by Sanrom
v0.1.1

Syntax: 
rb_installer [<branch>]
or
rb_installer -d [-f] {--google-drive|--dropbox} <id>

--googleDrive: file must be public, id is fileid
--dropbox: file must be public, id is everything after /s/

-f: Force download, overwrites existing files
]]
local component = require("component")
local shell = require("shell")

if not component.isAvailable("internet") then error("Internet Card not installed") end

local function downloadFile(filename, force)
  local res, msg = shell.execute("wget ".. (force and "-f " or "") .. filename)
  if not res and msg then error("Error downloading file: " .. msg) elseif not res then error("Unknown error downloading file") end
end

local args, ops = shell.parse(...)

local repo = "https://raw.githubusercontent.com/sanrom/nco-reactor-builder/"
local branch = args[1] or "master"
local force = ops.f or ops.force

if ops.d then
  if ops["google-drive"] then
    downloadFile("https://drive.google.com/uc?export=download&id=" .. (args[1] or "") .. " " .. (args[2] or "reactor.ncpf"), force)
  elseif ops["dropbox"] then
    downloadFile("https://dl.dropboxusercontent.com/s/" .. (args[1] or "") .. " " .. (args[2] or "reactor.ncpf"), force)
  end
else
  --Always force download scripts to allow updating
  downloadFile(repo .. branch .. "/config2_parser.lua", true)
  downloadFile(repo .. branch .. "/reactor_builder.lua", true)
end