local Module = {}

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

-- animation mappings
local ANIM_ACTIONS = {
	["1461136875"] = Enum.KeyCode.Three,
	["1461157246"] = Enum.KeyCode.Four,
}

local function pressKey(key)
	VirtualInputManager:SendKeyEvent(true, key, false, game)
	task.wait(0.01)
	VirtualInputManager:SendKeyEvent(false, key, false, game)
end

local function hookAnimator(animator)
	if not animator then return end
	
	animator.AnimationPlayed:Connect(function(track)
		if not track or not track.Animation then return end
		
		local animId = track.Animation.AnimationId
		if not animId or animId == "" then return end
		
		for id, key in pairs(ANIM_ACTIONS) do
			if string.find(animId, id) then
				pressKey(key)
				break
			end
		end
	end)
end

local function onCharacter(char)
	local humanoid = char:WaitForChild("Humanoid", 5)
	if not humanoid then return end
	
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 5)
	hookAnimator(animator)
end

function Module.Start()
	if player.Character then
		onCharacter(player.Character)
	end
	
	player.CharacterAdded:Connect(onCharacter)
	
end

return Module
