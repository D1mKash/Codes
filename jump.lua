local module = {}

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

local currentHumanoid
local animationConnection

local triggered = false
local lastDamage = 0

------------------------------------------------
-- INPUT HELPERS
------------------------------------------------

local function leftClick()
	VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
	VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

local function pressKey(key)
	VirtualInputManager:SendKeyEvent(true, key, false, game)
	VirtualInputManager:SendKeyEvent(false, key, false, game)
end

------------------------------------------------
-- FALL CHECK
------------------------------------------------

local function isFalling()
	if not currentHumanoid then return false end
	local state = currentHumanoid:GetState()
	return state == Enum.HumanoidStateType.Freefall
end

------------------------------------------------
-- DAMAGE CHECK (your logic simplified)
------------------------------------------------

local function setupDamageCheck(callback)
	local stats = player:FindFirstChild("Stats")
	if not stats then return end

	local damageValue = stats:FindFirstChild("Damage")
	if not damageValue then return end

	local startDamage = damageValue.Value
	local fired = false

	local conn
	conn = damageValue.Changed:Connect(function()
		local diff = damageValue.Value - startDamage

		if diff >= 4 and diff <= 5.5 and not fired then
			fired = true
			if conn then conn:Disconnect() end
			callback()
		end
	end)

	task.delay(0.5, function()
		if conn then conn:Disconnect() end
	end)
end

------------------------------------------------
-- ACTION SEQUENCE
------------------------------------------------

local function combo()
	leftClick()
	task.wait(0.05)
	pressKey(Enum.KeyCode.Space)
	leftClick()
end

------------------------------------------------
-- ANIMATION HOOK
------------------------------------------------

local function hookAnimations(character)

	if animationConnection then
		animationConnection:Disconnect()
	end

	currentHumanoid = character:WaitForChild("Humanoid")

	animationConnection = currentHumanoid.AnimationPlayed:Connect(function(track)

		if not track.Animation then return end

		local id = track.Animation.AnimationId

		if id == "rbxassetid://1470472673"
		or id == "rbxassetid://1470447472" then

			if isFalling() then return end

			setupDamageCheck(function()
				combo()
			end)

		end

	end)
end

------------------------------------------------
-- START / STOP
------------------------------------------------

function module.Start()
	if player.Character then
		hookAnimations(player.Character)
	end

	player.CharacterAdded:Connect(function(char)
		hookAnimations(char)
	end)
end

function module.Stop()
	if animationConnection then
		animationConnection:Disconnect()
		animationConnection = nil
	end

	currentHumanoid = nil
end

return module
