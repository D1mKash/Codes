local Module = {}

local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

local running = false
local connection

-- 🔥 just add animations here
local ANIMATIONS = {
	["1461157246"] = {
		Enum.KeyCode.Three,
		Enum.KeyCode.Q
	},

	-- example:
	-- ["1234567890"] = {
	--     Enum.KeyCode.One,
	--     Enum.KeyCode.E
	-- }
}

------------------------------------------------
-- INPUT
------------------------------------------------

local function press(key)
	VIM:SendKeyEvent(true, key, false, game)
	task.wait(0.01)
	VIM:SendKeyEvent(false, key, false, game)
end

------------------------------------------------
-- HOOK
------------------------------------------------

local function hook(animator)

	connection = animator.AnimationPlayed:Connect(function(track)
		if not running then return end
		if not track or not track.Animation then return end

		local id = track.Animation.AnimationId

		for animId, keys in pairs(ANIMATIONS) do
			if string.find(id, animId) then

				for _, key in ipairs(keys) do
					press(key)
				end

				break
			end
		end
	end)
end

------------------------------------------------
-- CHARACTER
------------------------------------------------

local function setup(char)
	local hum = char:WaitForChild("Humanoid")
	local animator = hum:WaitForChild("Animator")
	hook(animator)
end

------------------------------------------------
-- START / STOP
------------------------------------------------

function Module.Start()
	if running then return end
	running = true

	if player.Character then
		setup(player.Character)
	end

	player.CharacterAdded:Connect(setup)
end

function Module.Stop()
	running = false

	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return Module
