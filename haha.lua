local Module = {}

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

-- animation mappings
local ANIM_ACTIONS = {
	["1461157246"] = {
		{key = Enum.KeyCode.Three, delay = 0},
		{key = Enum.KeyCode.Q, delay = 0.01},
	}
}

local connections = {}
local running = false

local function pressKey(key)
	VirtualInputManager:SendKeyEvent(true, key, false, game)
	task.wait(0.01)
	VirtualInputManager:SendKeyEvent(false, key, false, game)
end

local function hookAnimator(animator)
	if not animator then return end
	
	local conn = animator.AnimationPlayed:Connect(function(track)
		if not running then return end
		if not track or not track.Animation then return end
		
		local animId = track.Animation.AnimationId
		if not animId or animId == "" then return end
		
		for id, actions in pairs(ANIM_ACTIONS) do
			if string.find(animId, id) then
				for _, action in ipairs(actions) do
					if action.delay and action.delay > 0 then
						task.wait(action.delay)
					end
					pressKey(action.key)
				end
				break
			end
		end
	end)
	
	table.insert(connections, conn)
end

-- key listener
local function hookInput()
	local conn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not running or gameProcessed then return end
		
		if input.KeyCode == Enum.KeyCode.Two then
			task.spawn(function()
				task.wait(0.1)
				pressKey(Enum.KeyCode.One)
       			pressKey(Enum.KeyCode.One)
			end)
		end
	end)
	
	table.insert(connections, conn)
end

local function onCharacter(char)
	local humanoid = char:WaitForChild("Humanoid", 5)
	if not humanoid then return end
	
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 5)
	hookAnimator(animator)
end

function Module.Start()
	if running then return end
	running = true
	
	if player.Character then
		onCharacter(player.Character)
	end
	
	table.insert(connections, player.CharacterAdded:Connect(onCharacter))
	
	-- start input listener
	hookInput()
end

function Module.Stop()
	running = false
	
	for _, conn in ipairs(connections) do
		if conn then
			conn:Disconnect()
		end
	end
	
	table.clear(connections)
end

return Module
