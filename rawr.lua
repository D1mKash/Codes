local M={}

local P=game:GetService("Players")
local V=game:GetService("VirtualInputManager")

local p=P.LocalPlayer

local A={
	["1461136875"]=Enum.KeyCode.Three,
	["1461157246"]=Enum.KeyCode.Four
}

local C={}
local R=false

local function k(K)
	V:SendKeyEvent(true,K,false,game)
	task.wait(0.01)
	V:SendKeyEvent(false,K,false,game)
end

local function h(a)
	if not a then return end
	
	local c=a.AnimationPlayed:Connect(function(t)
		if not R then return end
		if not t or not t.Animation then return end
		
		local i=t.Animation.AnimationId
		if not i or i=="" then return end
		
		for id,key in pairs(A) do
			if string.find(i,id) then
				k(key)
				break
			end
		end
	end)
	
	table.insert(C,c)
end

local function o(c)
	local h=c:WaitForChild("Humanoid",5)
	if not h then return end
	
	local a=h:FindFirstChildOfClass("Animator") or h:WaitForChild("Animator",5)
	h(a)
end

function M.Start()
	if R then return end
	R=true
	
	if p.Character then
		o(p.Character)
	end
	
	table.insert(C,p.CharacterAdded:Connect(o))
end

function M.Stop()
	R=false
	
	for _,c in ipairs(C) do
		if c then
			c:Disconnect()
		end
	end
	
	table.clear(C)
end

return M
