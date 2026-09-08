local m = {}

local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

------------------------------------------------
-- SETTINGS
------------------------------------------------
local ANIM_START = "1461136875"    -- start move that decides the follow-up
local ANIM_LAND = "1461137417"     -- landing move that triggers the 3 press
local SKILL_NAME = "Dynamic Entry"
local COOLDOWN_READY = 20          -- COOLDOWN value (or missing) means ready
local DAMAGE_DETECT_WINDOW = 0.5   -- how long after a Damage increase animations matter

------------------------------------------------
-- STATE
------------------------------------------------
local running = false
local waitingForLand = false
local connections = {}

local detectUntil = 0
local damageHooked = false
local prevDamage = nil

------------------------------------------------
-- INPUT HELPERS
------------------------------------------------
local function pressKey(key)
	pcall(function()
		VIM:SendKeyEvent(true, key, false, game)
		task.wait(0.01)
		VIM:SendKeyEvent(false, key, false, game)
	end)
end

------------------------------------------------
-- BACKPACK CHECK
------------------------------------------------
-- Abilities live in the Backpack as Configuration objects, not Tools.
local function getBackpackItem(itemName)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return nil end
	return backpack:FindFirstChild(itemName)
end

------------------------------------------------
-- DAMAGE DETECTION WINDOW
------------------------------------------------
local function isDetectionActive()
	return os.clock() < detectUntil
end

-- Stats folder > Damage NumberValue: any increase re-arms the 0.5s window.
local function tryHookDamage()
	if damageHooked then return true end

	local stats = player:FindFirstChild("Stats")
	local damage = stats and stats:FindFirstChild("Damage")
	if not damage or not damage:IsA("NumberValue") then return false end

	damageHooked = true
	prevDamage = damage.Value

	table.insert(connections, damage.Changed:Connect(function(newValue)
		if not running then return end
		if prevDamage ~= nil and newValue > prevDamage then
			detectUntil = os.clock() + DAMAGE_DETECT_WINDOW
		end
		prevDamage = newValue
	end))

	return true
end

------------------------------------------------
-- ANIMATION HANDLER
------------------------------------------------
local function onAnimationPlayed(track)
	if not running then return end
	if not track or not track.Animation then return end

	local numericId = string.match(track.Animation.AnimationId, "(%d+)$")
	if not numericId then return end

	-- Animations only count while the damage-detection window is armed.
	if not isDetectionActive() then return end

	if numericId == ANIM_START then
		-- A fresh start cancels any previous pending landing press.
		waitingForLand = false

		local skill = getBackpackItem(SKILL_NAME)
		local cooldown = skill and skill:GetAttribute("COOLDOWN")

		-- Missing config, or on cooldown -> press 4. Ready -> wait for landing.
		if not skill or (cooldown ~= nil and cooldown ~= COOLDOWN_READY) then
			pressKey(Enum.KeyCode.Four)
		else
			waitingForLand = true
		end
	elseif numericId == ANIM_LAND then
		if waitingForLand then
			waitingForLand = false
			pressKey(Enum.KeyCode.Three)
		end
	end
end

------------------------------------------------
-- CHARACTER HOOK
------------------------------------------------
local function hookCharacter(char)
	if not char then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = char:WaitForChild("Humanoid", 5)
	end
	if not humanoid then return end

	table.insert(connections, humanoid.AnimationPlayed:Connect(onAnimationPlayed))
end

------------------------------------------------
-- PUBLIC API
------------------------------------------------
function m.Start()
	if running then return end
	running = true
	waitingForLand = false
	detectUntil = 0

	if player.Character then
		hookCharacter(player.Character)
	end

	table.insert(connections, player.CharacterAdded:Connect(function(char)
		task.wait(0.5)
		hookCharacter(char)
	end))

	-- Keep trying to watch Stats > Damage until it's available.
	task.spawn(function()
		while running do
			if tryHookDamage() then return end
			task.wait(0.2)
		end
	end)
end

function m.Stop()
	running = false
	waitingForLand = false
	detectUntil = 0
	damageHooked = false
	prevDamage = nil

	for _, conn in ipairs(connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	connections = {}
end

return m
