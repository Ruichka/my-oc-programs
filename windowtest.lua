local pos = {x=5,y=5,w=20,h=6}
local state = 0
local dragPos = 0
local gpu = require("component").gpu
local event = require("event")
local w,h = gpu.getResolution()

local function redraw()
  gpu.setForeground(15,true)
  gpu.setBackground(15,true)
  gpu.fill(1,1,w,h," ")
  gpu.setBackground(3,true)
  gpu.set(pos.x,pos.y,string.rep(" ",pos.w-1))
  gpu.set(pos.x,pos.y,"Hello")
  gpu.setBackground(14,true)
  gpu.setForeground(0,true)
  gpu.set(pos.x+pos.w-1,pos.y,"X")
  gpu.setBackground(0,true)
  gpu.fill(pos.x,pos.y+1,pos.w,pos.h," ")
  gpu.setForeground(15,true)
  gpu.set(pos.x,pos.y+1,"Hello world!")
  gpu.set(pos.x,pos.y+2,"This is a test")
  gpu.set(pos.x,pos.y+3,"Press X to exit")
  gpu.setBackground(15,true)
  gpu.setForeground(0,true)
end

redraw()

while true do
  local e,_,a,b = event.pull()
  if e == "touch" and a >= pos.x and a < pos.x+pos.w-1 and b == pos.y then
    state = 1
    dragPos = a - pos.x
  end
  if e == "touch" and a == pos.x + pos.w - 1 and b == pos.y then
    gpu.fill(0,0,w,h," ")
    break
  end
  if e == "drag" and state == 1 then
    pos.x = a - dragPos
    pos.y = b
    redraw()
  end
  if e == "drop" then
    state = 0
  end
end
