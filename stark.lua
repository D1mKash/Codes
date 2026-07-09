local m = {}

local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- ===========================
-- CONFIGURATION
-- ===========================
local DAMAGE_MIN = 3
local DAMAGE_MAX = 5
local WAIT_TIME = 0.7   -- seconds after last damage increment before listening

-- Animation IDs and actions
local ANIM_ACTIONS = {
	["1461157246"] = function()
		pressKey(Enum.KeyCode.One)
	end,
	["1470532199"] = function()
		pressKey(Enum.KeyCode.Three)
		task.wait(0.1)
		pressKey(Enum.KeyCode.Four)
	end,
}

-- ===========================
-- STATE
-- ===========================
local running = false
local connections = {}         -- all event connections
local characterConnection = nil
local damageConnection = nil
local timerThread = nil        -- the 0.7s timer
local listening = false       -- are we currently waiting for an animation?
local damageValue = nil
local lastDamage = 0

-- ===========================
-- HELPERS
-- ===========================
local function pressKey(key)
	pcall(function()
		VIM:SendKeyEvent(true, key, false, game)
		task.wait(0.01)
		VIM:SendKeyEvent(false, key, false, game)
	end)
end

local function getCharacter()
	return player.Character
end

local function getHumanoid(char)
	return char and char:FindFirstChildOfClass("Humanoid")
end

-- ===========================
-- ANIMATION LISTENER
-- ===========================
local function onAnimationPlayed(track)
	if not running or not listening then return end
	if not track or not track.Animation then return end

	local animId = track.Animation.AnimationId
	if not animId then return end

	-- Extract numeric ID
	local numericId = string.match(animId, "(%d+)$")
	if not numericId then return end

	local action = ANIM_ACTIONS[numericId]
	if action then
		listening = false   -- consume the trigger, stop listening
		task.spawn(action)  -- press keys without blocking the event
	end
end

-- Connect animation listeners to a character
local function connectAnimationSources(char)
	-- Clean old connections
	for _, conn in ipairs(connections) do
		pcall(conn.Disconnect, conn)
	end
	connections = {}

	local hum = getHumanoid(char)
	if not hum then return end

	-- Humanoid.AnimationPlayed
	local conn1 = hum.AnimationPlayed:Connect(onAnimationPlayed)
	table.insert(connections, conn1)

	-- Also connect to any Animators / AnimationControllers
	local function findAnimators(model)
		for _, child in ipairs(model:GetDescendants()) do
			if child:IsA("Animator") or child:IsA("AnimationController") then
				if child.AnimationPlayed then
					local conn = child.AnimationPlayed:Connect(onAnimationPlayed)
					table.insert(connections, conn)
				end
			end
		end
	end
	findAnimators(char)
end

local function stopListening()
	listening = false
	for _, conn in ipairs(connections) do
		pcall(conn.Disconnect, conn)
	end
	connections = {}
end

-- ===========================
-- TIMER
-- ===========================
local function resetTimer()
	if timerThread then
		task.cancel(timerThread)
		timerThread = nil
	end

	-- Stop any active listening (new damage cancels the window)
	stopListening()

	timerThread = task.spawn(function()
		task.wait(WAIT_TIME)
		if not running then return end
		-- After waiting, enable listening
		listening = true
		local char = getCharacter()
		if char then
			connectAnimationSources(char)
		end
		timerThread = nil
	end)
end

-- ===========================
-- DAMAGE MONITOR
-- ===========================
local function onDamageChanged()
	if not running then return end
	if not damageValue then return end

	local newDamage = damageValue.Value
	local increment = newDamage - lastDamage
	lastDamage = newDamage

	if increment > DAMAGE_MIN and increment < DAMAGE_MAX then
		-- Reset the timer (this also stops listening)
		resetTimer()
	end
end

local function setupDamageWatcher()
	if damageConnection then
		damageConnection:Disconnect()
		damageConnection = nil
	end

	local stats = player:FindFirstChild("Stats")
	if not stats then
		warn("Stats folder not found")
		return
	end

	local dmg = stats:FindFirstChild("Damage")
	if not dmg or not dmg:IsA("NumberValue") then
		warn("Damage NumberValue not found")
		return
	end

	damageValue = dmg
	lastDamage = damageValue.Value

	damageConnection = damageValue:GetPropertyChangedSignal("Value"):Connect(onDamageChanged)
end

-- ===========================
-- CHARACTER RESPAWN
-- ===========================
local function onCharacterAdded(char)
	-- If we are listening, reconnect the animation sources
	if listening then
		connectAnimationSources(char)
	end
end

-- ===========================
-- PUBLIC API
-- ===========================
function m.Start()
	if running then return end
	running = true

	setupDamageWatcher()
	characterConnection = player.CharacterAdded:Connect(onCharacterAdded)

	-- If character already exists, we don't start listening until damage triggers, so nothing else needed.
	print("DamageCombo started.")
end

function m.Stop()
	running = false

	if timerThread then
		task.cancel(timerThread)
		timerThread = nil
	end

	stopListening()

	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end

	if damageConnection then
		damageConnection:Disconnect()
		damageConnection = nil
	end

	damageValue = nil
	lastDamage = 0

	print("DamageCombo stopped.")
end

return m
