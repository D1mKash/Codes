local _0xA={}local _0x1=nil

local function _0x2()
local _0x3=game:GetService("Players").LocalPlayer
local _0x4=_0x3:FindFirstChild("Backpack")if not _0x4 then return false end

local _0x5=_0x4:FindFirstChild("Black Flash")or _0x4:FindFirstChild("Taijutsu Combo")
if not _0x5 or not _0x5:IsA("Configuration")then return false end

local _0x6=_0x5:GetAttribute("COOLDOWN")
if _0x6==nil or _0x6==20 then return true end

return false
end

function _0xA.Start()
local _0x7=game:GetService("UserInputService")
local _0x8=game:GetService("VirtualInputManager")

local function _0x9()
_0x8:SendMouseButtonEvent(0,0,0,true,game,0)
_0x8:SendMouseButtonEvent(0,0,0,false,game,0)
end

_0x1=_0x7.InputBegan:Connect(function(_0x10,_0x11)
if _0x11 then return end

if _0x10.KeyCode==Enum.KeyCode.Two then
if not _0x2()then return end
task.wait(0.6)
_0x9()
end

end)
end

function _0xA.Stop()
if _0x1 then _0x1:Disconnect()_0x1=nil end
end

return _0xA
