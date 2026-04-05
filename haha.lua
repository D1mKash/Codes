local m={}local p=game:GetService("Players")local v=game:GetService("VirtualInputManager")local u=game:GetService("UserInputService")local pl=p.LocalPlayer
local a={
	["1461157246"]={{key=Enum.KeyCode.Three,delay=0.15}},
	["1461252313"]={{key=Enum.KeyCode.Q,delay=1.7}},
    ["1461127258"]={{key=Enum.KeyCode.Three,delay=0.01},{key=Enum.KeyCode.Q,delay=0.01},{key=Enum.KeyCode.Three,delay=0.55}}
}
local c={}local r=false
local function k(kc)pcall(function()v:SendKeyEvent(true,kc,false,game)task.wait(0.01)v:SendKeyEvent(false,kc,false,game)end)end
local function h(anim)if not anim then return end local s,e=pcall(function()return anim.AnimationPlayed:Connect(function(t)if not r or not t or not t.Animation then return end local i=t.Animation.AnimationId if not i or i=="" then return end for id,acts in pairs(a)do if string.find(i,id)then for _,act in ipairs(acts)do if act.delay and act.delay>0 then task.wait(act.delay)end k(act.key)end break end end end)end)if s and e then table.insert(c,e)end end
local function i()local s,e=u.InputBegan:Connect(function(input,gp)if not r or gp then return end if input.KeyCode==Enum.KeyCode.Two then task.spawn(function()task.wait(0.1)k(Enum.KeyCode.One)task.wait(0.01)k(Enum.KeyCode.One)end)end end) table.insert(c,e)end
local function o(ch)if not ch then return end local hum=ch:WaitForChild("Humanoid",5)if not hum then return end local anim=hum:FindFirstChildOfClass("Animator")or hum:WaitForChild("Animator",5)h(anim)end
function m.Start()if r then return end r=true if pl.Character then o(pl.Character)end table.insert(c,pl.CharacterAdded:Connect(o)) i() end
function m.Stop()r=false for _,v in ipairs(c)do if v then v:Disconnect()end end table.clear(c)end
return m
