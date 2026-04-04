local M={}

local P=game:GetService("Players")
local V=game:GetService("VirtualInputManager")
local U=game:GetService("UserInputService")

local p=P.LocalPlayer

-- animation mappings
local A={
	["1461157246"]={
		{key=Enum.KeyCode.Three,delay=0},
		{key=Enum.KeyCode.Q,delay=0.01}
	}
}

local C={} -- connections
local R=false

local function k(K)
	V:SendKeyEvent(true,K,false,game)
	task.wait(0.01)
	V:SendKeyEvent(false,K,false,game)
end

local function h(anim)
	if not anim then return end
	local c=anim.AnimationPlayed:Connect(function(track)
		if not R then return end
		if not track or not track.Animation then return end
		local i=track.Animation.AnimationId
		if not i or i=="" then return end
		for id,actions in pairs(A) do
			if string.find(i,id) then
				for _,act in ipairs(actions) do
					if act.delay and act.delay>0 then task.wait(act.delay) end
					k(act.key)
				end
				break
			end
		end
	end)
	table.insert(C,c)
end

local function j()
	local c=U.InputBegan:Connect(function(input,gp)
		if not R or gp then return end
		if input.KeyCode==Enum.KeyCode.Two then
			task.spawn(function()
				task.wait(0.1)
				k(Enum.KeyCode.One)
				k(Enum.KeyCode.One)
			end)
		end
	end)
	table.insert(C,c)
end

local function o(char)
	local h=char:WaitForChild("Humanoid",5)
	if not h then return end
	local a=h:FindFirstChildOfClass("Animator") or h:WaitForChild("Animator",5)
	hookAnimator(a)
end

function M.Start()
	if R then return end
	R=true
	if p.Character then o(p.Character) end
	table.insert(C,p.CharacterAdded:Connect(o))
	j()
end

function M.Stop()
	R=false
	for _,c in ipairs(C) do
		if c then c:Disconnect() end
	end
	table.clear(C)
end

return M
