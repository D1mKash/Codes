local _0xA={}local _0x1=nil local _0x2=nil local _0x3=false local _0x4=nil

function _0xA.Start()
_0x1=game:GetService("UserInputService")_0x2=game:GetService("VirtualInputManager")

local function _0x5()
_0x2:SendKeyEvent(true,Enum.KeyCode.Q,false,game)
_0x2:SendKeyEvent(false,Enum.KeyCode.Q,false,game)
end

_0x4=_0x1.InputBegan:Connect(function(_0x6,_0x7)
if _0x7 then return end
if _0x6.KeyCode==Enum.KeyCode.X then
_0x3=not _0x3
if _0x3 then
task.spawn(function()
while _0x3 do
_0x5()
task.wait((math.random(10,20))/100)
end
end)
end
end
end)
end

function _0xA.Stop()
_0x3=false
if _0x4 then _0x4:Disconnect()_0x4=nil end
end

return _0xA
