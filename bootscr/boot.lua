-- Originally written by the OpenComputers developers & contributors, shared under the MIT License
-- This version of the file is modified by Ruika and shared under the same license

-- called from /init.lua
local raw_loadfile = ...

_G._OSVERSION = "OpenOS 1.7.4"

-- luacheck: globals component computer unicode _OSVERSION
local component = component
local computer = computer
local unicode = unicode

-- Runlevel information.
_G.runlevel = "S"
local shutdown = computer.shutdown
computer.runlevel = function() return _G.runlevel end
computer.shutdown = function(reboot)
  _G.runlevel = reboot and 6 or 0
  if os.sleep then
    computer.pushSignal("shutdown")
    os.sleep(0.1) -- Allow shutdown processing.
  end
  shutdown(reboot)
end

local w, h
local screen = component.list("screen", true)()
local gpu = screen and component.list("gpu", true)()
if gpu then
  gpu = component.proxy(gpu)
  if not gpu.getScreen() then
    gpu.bind(screen)
  end
  _G.boot_screen = gpu.getScreen()
  w, h = gpu.maxResolution()
  gpu.setResolution(w, h)
  gpu.setBackground(0x000000)
  gpu.setForeground(0xFFFFFF)
  gpu.fill(1, 1, w, h, " ")
  local t = {
    " ▄▄▄▄▄▄▄▄▄▄▄▄▄  ",
    " █ █  █  ▄ █ ▀█ ",
    " █ █  █  ▀ █  █ ",
    " █ ▀▀▀▀▀▀▀▀▀  █ ",
    " █ █▀▀▀▀▀▀▀▀█ █ ",
    " █ █        █ █ ",
    " █ █        █ █ ",
    " ▀▀▀▀▀▀▀▀▀▀▀▀▀▀ ",
  }
  for y = 1,#t do
    gpu.set(math.floor(w / 2) - 8, math.floor(h / 2) - 5 + y, t[y])
  end
end

-- Report boot progress if possible.
local y = 1
local uptime = computer.uptime
-- we actually want to ref the original pullSignal here because /lib/event intercepts it later
-- because of that, we must re-pushSignal when we use this, else things break badly
local pull = computer.pullSignal
local last_sleep = uptime()
local function status(msg,v,l)
  if gpu then
    local n = " "
    local p = "█"
    gpu.set(
      1,
      math.floor(h / 2) + 5,
      n:rep(math.floor((w - msg:len()) / 2)) .. msg .. n:rep(math.floor(w / 2 + msg:len()))
    )
    if v then
      gpu.set(
        math.floor(w / 2) - 5,
        math.floor(h / 2) + 4,
        "[" .. p:rep(math.floor(8 / l * v)) .. n:rep(8 - math.floor(8 / l * v)) .. "]"
      )
    end
  end
  -- boot can be slow in some environments, protect from timeouts
  if uptime() - last_sleep > 1 then
    local signal = table.pack(pull(0))
    -- there might not be any signal
    if signal.n > 0 then
      -- push the signal back in queue for the system to use it
      computer.pushSignal(table.unpack(signal, 1, signal.n))
    end
    last_sleep = uptime()
  end
end

status("Booting " .. _OSVERSION .. "...")

-- Custom low-level dofile implementation reading from our ROM.
local function dofile(file)
  local program, reason = raw_loadfile(file)
  if program then
    local result = table.pack(pcall(program))
    if result[1] then
      return table.unpack(result, 2, result.n)
    else
      error(result[2])
    end
  else
    error(reason)
  end
end

status("Initializing package management...")

-- Load file system related libraries we need to load other stuff moree
-- comfortably. This is basically wrapper stuff for the file streams
-- provided by the filesystem components.
local package = dofile("/lib/package.lua")

do
  -- Unclutter global namespace now that we have the package module and a filesystem
  _G.component = nil
  _G.computer = nil
  _G.process = nil
  _G.unicode = nil
  -- Inject the package modules into the global namespace, as in Lua.
  _G.package = package

  -- Initialize the package module with some of our own APIs.
  package.loaded.component = component
  package.loaded.computer = computer
  package.loaded.unicode = unicode
  package.loaded.buffer = dofile("/lib/buffer.lua")
  package.loaded.filesystem = dofile("/lib/filesystem.lua")

  -- Inject the io modules
  _G.io = dofile("/lib/io.lua")
end

status("Initializing file system...")

-- Mount the ROM and temporary file systems to allow working on the file
-- system module from this point on.
require("filesystem").mount(computer.getBootAddress(), "/")

status("Running boot scripts...")

-- Run library startup scripts. These mostly initialize event handlers.
local function rom_invoke(method, ...)
  return component.invoke(computer.getBootAddress(), method, ...)
end

local scripts = {}
for _, file in ipairs(rom_invoke("list", "boot")) do
  local path = "boot/" .. file
  if not rom_invoke("isDirectory", path) then
    table.insert(scripts, path)
  end
end
table.sort(scripts)
for i = 1, #scripts do
  status("Loading " .. scripts[i], i, #scripts)
  dofile(scripts[i])
end

status("Initializing components...")

for c, t in component.list() do
  computer.pushSignal("component_added", c, t)
end

status("Initializing system...")

computer.pushSignal("init") -- so libs know components are initialized.
require("event").pull(1, "init") -- Allow init processing.
_G.runlevel = 1
