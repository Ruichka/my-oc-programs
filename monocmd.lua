local component = require("component")
local gpu = component.gpu
local fs = require("filesystem")
local term = require("term")
local unicode = require("unicode")
local event = require("event")
local colors = require("colors")
local string = require("string")
local text = require("text")
local w,h = gpu.getResolution()

local lists = {
  {
    x = 2,
    dir = "/",
    prev = {},
    contents = {}
  },
  {
    x = w/2+2,
    dir = "/home/",
    prev = {},
    contents = {}
  }
}
local currentList = 1
local currentAction = 1
local selection = 1
local currentCopy = nil

local function getOtherList()
  if currentList == 1 then return 2 else return 1 end
end

local function fixnil(d)
  if d == nil then return "" else return d end
end

local function redraw(full)
  if full then
    gpu.setBackground(9,true)
    gpu.fill(1,1,w,h," ")
    gpu.fill(1,2,w/2-2,1,"=")
    gpu.fill(w/2+1,2,w/2-2,1,"=")
    gpu.fill(1,h-1,w/2-2,1,"=")
    gpu.fill(w/2+1,h-1,w/2,1,"=")
    gpu.fill(w/2-1,1,2,h,"#")
    gpu.set(2,1,lists[1].dir)
    gpu.set(w/2+2,1,lists[2].dir)
    local unshown = 0
    for l,d in pairs(lists) do
      for i in pairs(lists[l].contents) do
        if selection == i and currentList == l then
          gpu.setBackground(colors.white,true)
          gpu.setForeground(colors.black,true)
        end
        local blankSpace = " "
        gpu.set(d.x,i+2,d.contents[i]..blankSpace:rep(w/2-3-d.contents[i]:len()))
        gpu.setBackground(9,true)
        gpu.setForeground(colors.white,true)
      end
    end
  else
    local blankSpace = " "
    local cl = lists[currentList]
    local clc = cl.contents
    local ol = lists[getOtherList()]
    local olc = ol.contents
    gpu.setBackground(colors.white,true)
    gpu.setForeground(colors.black,true)
    gpu.set(cl.x,selection+2,clc[selection]..blankSpace:rep(w/2-3-clc[selection]:len()))
    gpu.setBackground(9,true)
    gpu.setForeground(colors.white,true)
    if clc[selection-1] then gpu.set(cl.x,selection+1,clc[selection-1]..blankSpace:rep(w/2-3-clc[selection-1]:len())) end
    if clc[selection+1] then gpu.set(cl.x,selection+3,clc[selection+1]..blankSpace:rep(w/2-3-clc[selection+1]:len())) end
    if olc[selection] then gpu.set(ol.x,selection+2,olc[selection]..blankSpace:rep(w/2-3-olc[selection]:len())) end
  end
end

local function fullSelection()
  return lists[currentList].dir..lists[currentList].contents[selection]
end

local function updateContents()
  for i,d in pairs(lists) do
    d.contents = {".."}
    for f in fs.list(lists[i].dir) do
      d.contents[#d.contents + 1] = f
    end
  end
end

updateContents()
redraw(true)

while true do
  updateContents()
  term.setCursor(1,h)
  term.write("(E)xit  (C)opy  (P)aste  (R)ename  (U)pdate  (A)bout")
  local _,_,code,special = event.pull("key_down")
  local action = unicode.char(code):lower()
  
  -- Arrows (up = 200, right = 205, down = 208, left = 203)
  if special == 200 and selection > 1 then
    selection = selection - 1
    redraw()
  end
  if special == 208 and selection < #lists[currentList].contents then
    selection = selection + 1
    redraw()
  end
  if special == 205 and currentList == 1 then
    if selection > #lists[2].contents then
      selection = #lists[2].contents    
    end
    currentList = 2
    redraw()
  end  
  if special == 203 and currentList == 2 then
    if selection > #lists[1].contents then
      selection = #lists[1].contents
    end
    currentList = 1
    redraw()
  end

  -- Selection
  if special == 28 then
    if selection == 1 then
      local path = {}
      local newDir = "/"
      for d in string.gmatch(lists[currentList].dir,"[^:/]+") do
        path[#path + 1] = d
      end
      table.remove(path,#path)
      for _,d in pairs(path) do
        newDir = newDir..d
      end
      lists[currentList].dir = newDir.."/"
    elseif fs.isDirectory(fullSelection()) then
      lists[currentList].dir = fullSelection()
    else
      os.execute(fullSelection())
    end
    redraw()
    selection = 1
    updateContents()
    redraw(true)
  end

  -- Actions
  if action == "e" then
    gpu.setBackground(15,true)
    gpu.setForeground(0,true)
    term.clear()
    return true
  end
  if action == "c" and fs.list(lists[currentList].dir)() then
    currentCopy = fullSelection()
  end
  if action == "p" and currentCopy then
    fs.copy(currentCopy,lists[currentList].dir..fs.name(currentCopy))
    redraw(true)
  end
  if action == "r" and selection ~= 1 then
    term.setCursor(1,h)
    term.clearLine()
    term.write("New name (leave empty to discard): ")
    local newName = text.trim(term.read())
    if newName ~= "" then
      fs.rename(fullSelection(),lists[currentList].dir..newName)
    end
    redraw(true)
  end
  if action == "u" then
    redraw(true)
  end
  if action == "a" then
    gpu.setBackground(15,true)
    gpu.setForeground(0,true)
    gpu.fill(1,1,w,h," ")
    gpu.set(w/2-7,h/2-1, "Mono Commander")
    gpu.set(w/2-7,h/2, "    v1.0.0    ")
    gpu.set(w/2-9,h,"Press any key to exit")
    event.pull("key_down")
    gpu.setBackground(9,true)
    redraw(true)
  end
end
