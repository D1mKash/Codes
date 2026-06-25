local _0xA={}local _0x1=game local _0x2=_0x1.GetService local _0x3=_0x2(_0x1,"Players")local _0x4=_0x2(_0x1,"VirtualInputManager")local _0x5=_0x2(_0x1,"RunService")local _0x6=_0x2(_0x1,"UserInputService")
local _0x7=_0x3.LocalPlayer

local _0x8=nil local _0x9=nil local _0x10=nil local _0x11=nil local _0x12=nil
local _0x13=0 local _0x14=nil
local _0x15=false local _0x16=nil
local _0x17=workspace:WaitForChild("Live")
local _0x18=false local _0x19=0

local _0x92=0
local _0x93=nil

local function _0x20(_0x21)
_0x4:SendKeyEvent(true,_0x21,false,_0x1)
_0x4:SendKeyEvent(false,_0x21,false,_0x1)
end

local function _0x94()
local _0x95=_0x14 or (_0x7.Character and _0x7.Character:FindFirstChildOfClass("Humanoid"))
if not _0x95 then return end

_0x92=_0x92+1
local _0x96=_0x92

if not _0x93 or _0x93.h~=_0x95 then
_0x93={
h=_0x95,
jp=_0x95.JumpPower,
jh=_0x95.JumpHeight,
ujp=_0x95.UseJumpPower
}
end

pcall(function()
_0x95:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
_0x95.Jump=false
_0x95.JumpPower=0
_0x95.JumpHeight=0
end)

task.delay(3,function()
if _0x96~=_0x92 then return end
local _0x97=_0x93
_0x93=nil

if _0x97 and _0x97.h and _0x97.h.Parent then
pcall(function()
_0x97.h.UseJumpPower=_0x97.ujp
_0x97.h.JumpPower=_0x97.jp
_0x97.h.JumpHeight=_0x97.jh
_0x97.h:SetStateEnabled(Enum.HumanoidStateType.Jumping,true)
end)
end
end)
end

local function _0x98()
_0x92=_0x92+1

local _0x97=_0x93
_0x93=nil

if _0x97 and _0x97.h and _0x97.h.Parent then
pcall(function()
_0x97.h.UseJumpPower=_0x97.ujp
_0x97.h.JumpPower=_0x97.jp
_0x97.h.JumpHeight=_0x97.jh
_0x97.h:SetStateEnabled(Enum.HumanoidStateType.Jumping,true)
end)
end
end

local function _0x22()
if not _0x14 then return false end
local _0x23=_0x14:GetState()
return _0x23==Enum.HumanoidStateType.Freefall
end

local function _0x24()
local _0x25=_0x7:FindFirstChild("Stats")if not _0x25 then return end
local _0x26=_0x25:FindFirstChild("Damage")if not _0x26 then return end

local _0x27=_0x26.Value local _0x28=false
local _0x29

_0x29=_0x26.Changed:Connect(function()
local _0x30=_0x26.Value-_0x27
if _0x30>=4 and _0x30<=5.5 and not _0x28 then
_0x28=true
if _0x22()then _0x20(Enum.KeyCode.Three)else _0x20(Enum.KeyCode.Two)end
if _0x29 then _0x29:Disconnect()end
end
end)

task.delay(0.5,function()
if _0x29 then _0x29:Disconnect()end
end)
end

local function _0x31(_0x32,_0x33)
_0x33=_0x33 or 0.05
_0x4:SendKeyEvent(true,_0x32,false,_0x1)
task.wait(_0x33)
_0x4:SendKeyEvent(false,_0x32,false,_0x1)
end

local function _0x90()
_0x4:SendMouseButtonEvent(0,0,0,true,_0x1,0)
task.wait(0.1)
_0x4:SendMouseButtonEvent(0,0,0,false,_0x1,0)
end

-- ============================================================
-- FIX 1: Auto-guard break now checks if YOU are blocking.
-- If you are blocking, it cancels. No more F tap.
-- ============================================================
local function _0x34()
if _0x18 then return end
_0x18 = true

-- Check if WE (the local player) are currently holding block
local myModel = _0x17:FindFirstChild(_0x7.Name)
local amIBlocking = false
if myModel then
    local myBlocking = myModel:FindFirstChild("Blocking")
    if myBlocking and myBlocking.Value == true then
        amIBlocking = true
    end
end

-- If we ARE blocking, DO NOT use the ability. Just reset and exit.
if amIBlocking then
    _0x18 = false
    return
end

-- (REMOVED the F tap entirely: no more _0x31(Enum.KeyCode.F,0.05) )

-- Execute the guard-break combo
_0x20(Enum.KeyCode.LeftShift)
_0x20(Enum.KeyCode.One)
_0x20(Enum.KeyCode.LeftShift)

task.delay(1, function() _0x18 = false end)
end

local function _0x37()
_0x11=_0x5.Heartbeat:Connect(function(_0x38)
_0x19=_0x19+_0x38 if _0x19<0.1 then return end _0x19=0

local _0x39=_0x7.Character if not _0x39 then return end
local _0x40=_0x39:FindFirstChild("HumanoidRootPart")if not _0x40 then return end

for _,_0x41 in ipairs(_0x17:GetChildren())do
if _0x41~=_0x39 and _0x41~=_0x16 then
local _0x42=_0x41:FindFirstChild("HumanoidRootPart")
local _0x43=_0x41:FindFirstChild("Blocking")
if _0x42 and _0x43 and _0x43.Value==true then
local _0x44=(_0x42.Position-_0x40.Position).Magnitude
if _0x44<=5 then _0x34()return end
end
end
end
end)
end

local function _0x59(_0x60)
if not _0x60 or not _0x60:IsA("Model")then return false end

local _0x61=_0x7.Character

if _0x60==_0x61 or _0x60.Name==_0x7.Name then
return false
end

if _0x16 and _0x60==_0x16 then
return false
end

local _0x62=_0x3:FindFirstChild(_0x60.Name)

if _0x62 then
if _0x62==_0x7 then return false end

if _0x7.Team~=nil and _0x62.Team~=nil and _0x62.Team==_0x7.Team then
return false
end
end

return true
end

local function _0x63()
local _0x64=_0x7.Character
if not _0x64 then return nil end

local _0x65=_0x64:FindFirstChild("HumanoidRootPart")
if not _0x65 then return nil end

local _0x66=nil
local _0x67=math.huge

for _,_0x68 in ipairs(_0x17:GetChildren())do
if _0x59(_0x68)then
local _0x69=_0x68:FindFirstChild("HumanoidRootPart",true)
if _0x69 then
local _0x70=(_0x69.Position-_0x65.Position).Magnitude
if _0x70<_0x67 then
_0x67=_0x70
_0x66=_0x68
end
end
end
end

return _0x66
end

local function _0x71(_0x72,_0x73,_0x91)
local _0x74=_0x7.Character
if not _0x74 then return end

if _0x74:GetAttribute(_0x72)~=true then return end

local _0x75=_0x74:FindFirstChild("HumanoidRootPart")
if not _0x75 then return end

local _0x76=_0x63()
if not _0x76 then return end

local _0x77=_0x76:FindFirstChild("HumanoidRootPart",true)
if not _0x77 then return end

local _0x78=_0x77.CFrame*CFrame.new(0,0,_0x91)
local _0x79=CFrame.new(_0x78.Position,_0x77.Position)

_0x75.CFrame=_0x79
_0x74:PivotTo(_0x79)

_0x75.AssemblyLinearVelocity=Vector3.zero
_0x75.AssemblyAngularVelocity=Vector3.zero

if _0x73 then _0x90()end
end

-- ============================================================
-- FIX 2: Removed the forced F-tap from Z, X, and C keybinds.
-- ============================================================
local function _0x45()
_0x12=_0x6.InputBegan:Connect(function(_0x46,_0x47)
if _0x47 then return end

local _0x48=_0x17:FindFirstChild(_0x7.Name)
local _0x49=false
if _0x48 then
local _0x50=_0x48:FindFirstChild("Blocking")
if _0x50 and _0x50.Value==true then _0x49=true end
end

if _0x46.KeyCode==Enum.KeyCode.Z then
-- (removed F tap: if _0x49 then _0x20(Enum.KeyCode.F) end)
_0x20(Enum.KeyCode.Two)task.wait(0.02)_0x20(Enum.KeyCode.One)
task.delay(1.2,function()
_0x71("KyokaInvisingggg",false,-1)
end)
end

if _0x46.KeyCode==Enum.KeyCode.X then
-- (removed F tap: if _0x49 then _0x20(Enum.KeyCode.F) end)
_0x20(Enum.KeyCode.Two)task.wait(0.02)_0x20(Enum.KeyCode.Three)
_0x94()
task.delay(1.2,function()
_0x71("KyokaInvis",true,2)
end)
end

if _0x46.KeyCode==Enum.KeyCode.C then
-- (removed F tap: if _0x49 then _0x20(Enum.KeyCode.F) end)
_0x20(Enum.KeyCode.Two)task.wait(0.02)_0x20(Enum.KeyCode.Two)
end
end)
end

local function _0x51(_0x52)
if _0x9 then _0x9:Disconnect()end
_0x14=_0x52:WaitForChild("Humanoid")

_0x9=_0x14.AnimationPlayed:Connect(function(_0x53)
if not _0x53.Animation then return end
local _0x54=_0x53.Animation.AnimationId

if _0x54=="rbxassetid://1470447472"then if not _0x15 then _0x24()end end
if _0x54=="rbxassetid://3238450309"then if not _0x15 then _0x24()end end

if _0x54=="rbxassetid://1470472673"then
_0x20(Enum.KeyCode.Three)
_0x15=true
task.delay(2,function()_0x15=false end)
end

if _0x54=="rbxassetid://1470532199"then _0x20(Enum.KeyCode.One)end
if _0x54=="rbxassetid://1461157246"then _0x20(Enum.KeyCode.One)end

end)
end

function _0xA.Start(_0x55)
_0x16=_0x55

local _0x56=_0x7:WaitForChild("Stats")
local _0x57=_0x56:WaitForChild("Damage")

_0x13=_0x57.Value
_0x8=_0x57.Changed:Connect(function()_0x13=_0x57.Value end)

if _0x7.Character then _0x51(_0x7.Character)end
_0x10=_0x7.CharacterAdded:Connect(function(_0x58)_0x51(_0x58)end)

_0x37()_0x45()
end

function _0xA.Stop()
if _0x8 then _0x8:Disconnect()_0x8=nil end
if _0x9 then _0x9:Disconnect()_0x9=nil end
if _0x10 then _0x10:Disconnect()_0x10=nil end
if _0x11 then _0x11:Disconnect()_0x11=nil end
if _0x12 then _0x12:Disconnect()_0x12=nil end

_0x98()

_0x14=nil _0x15=false _0x16=nil _0x18=false
end

return _0xA
