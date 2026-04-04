local m={}local p=game:GetService("Players")local v=game:GetService("VirtualInputManager")local pl=p.LocalPlayer
local a={["1461136875"]=Enum.KeyCode.Three,["1461157246"]=Enum.KeyCode.Four}
local c={}local r=false
local function k(kc)pcall(function()v:SendKeyEvent(true,kc,false,game)task.wait(0.01)v:SendKeyEvent(false,kc,false,game)end)end
local function h(hum)if not hum then return end local s,e=pcall(function()return hum.AnimationPlayed:Connect(function(t)if not r or not t or not t.Animation then return end local i=t.Animation.AnimationId if not i or i=="" then return end for id,key in pairs(a)do if string.find(i,id)then k(key)break end end end)end)if s and e then table.insert(c,e)end end
local function o(ch)if not ch then return end local hum=ch:WaitForChild("Humanoid",5)if not hum then return end local anim=hum:FindFirstChildOfClass("Animator")or hum:WaitForChild("Animator",5)h(anim)end
function m.Start()if r then return end r=true if pl.Character then o(pl.Character)end table.insert(c,pl.CharacterAdded:Connect(o))end
function m.Stop()r=false for _,v in ipairs(c)do if v then v:Disconnect()end end table.clear(c)end
return m
