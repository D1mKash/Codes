local _0xA={}local _0x1=nil

local function _0x2(_0x3)
local _0x4=game:GetService("Players").LocalPlayer
local _0x5=_0x4:FindFirstChild("Backpack")if not _0x5 then return false end

local _0x6=_0x5:FindFirstChild(_0x3)
if not _0x6 or not _0x6:IsA("Configuration")then return false end

local _0x7=_0x6:GetAttribute("COOLDOWN")
if _0x7==nil or _0x7==20 then return true end

return false
end

function _0xA.Start()
local _0x8=game:GetService("UserInputService")
local _0x9=game:GetService("RunService")
local _0x10=game:GetService("VirtualInputManager")
local _0x11=game:GetService("Workspace")

local _0x12=_0x11:WaitForChild("Live")

local function _0x13()
_0x10:SendMouseButtonEvent(0,0,0,true,game,0)
_0x10:SendMouseButtonEvent(0,0,0,false,game,0)
end

_0x1=_0x8.InputBegan:Connect(function(_0x14,_0x15)
if _0x15 then return end

local _0x16=nil

if _0x14.KeyCode==Enum.KeyCode.One then
_0x16="Bisecting Slash"
elseif _0x14.KeyCode==Enum.KeyCode.Two then
_0x16="7:3 Combo"
elseif _0x14.KeyCode==Enum.KeyCode.Three then
_0x16="Hair Grab"
elseif _0x14.KeyCode==Enum.KeyCode.Four then
_0x16="Retirement Kick"
end

if not _0x16 then return end
if not _0x2(_0x16)then return end

local _0x17

local _0x18
_0x18=_0x12.DescendantAdded:Connect(function(_0x19)
if _0x19.Name~="NanamiCutGUI"then return end

local _0x1A=_0x19:FindFirstChild("MainBar")
local _0x1B=_0x1A and _0x1A:FindFirstChild("Cutter")

if _0x1B then
_0x17=_0x1B
_0x18:Disconnect()
end
end)

local _0x1C
_0x1C=_0x9.Heartbeat:Connect(function()
if not _0x17 then return end

if _0x17.Position.X.Scale>=0.7 then
_0x13()
_0x1C:Disconnect()
end
end)

end)
end

function _0xA.Stop()
if _0x1 then _0x1:Disconnect()_0x1=nil end
end

return _0xA
