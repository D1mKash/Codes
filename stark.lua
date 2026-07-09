local m = {}

local P = game:GetService("Players")
local R = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VIM = game:GetService("VirtualInputManager")

local p = P.LocalPlayer

local connections = {}
local characterConnection
local damageConn = nil
local timerThread = nil
local running = false

-- Config
local DAMAGE_MIN = 3
local DAMAGE_MAX = 5
local WAIT_TIME = 0.7   -- seconds after last damage increment before listening

-- Animation IDs and their actions
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

-- State
local damageValue = nil
local lastDamage = 0
local isListening = false

------------------------------------------------
-- HELPERS
------------------------------------------------
local function pressKey(key)
	pcall(function()
		VIM:SendKeyEvent(true, key, false, game)
		task.wait(0.01)
		VIM:SendKeyEvent(false, key, false, game)
	end)
end

local function getCharacter()
	return p.Character
end

local function getHumanoid(char)
	return char and char:FindFirstChildOfClass("Humanoid")
end

------------------------------------------------
-- ANIMATION LISTENER
------------------------------------------------
local function onAnimationPlayed(track)
	if not running or not isListening then return end
	if not track or not track.Animation then return end

	local animId = track.Animation.AnimationId
	if not animId then return end

	local numericId = string.match(animId, "(%d+)$")
	if not numericId then return end

	local action = ANIM_ACTIONS[numericId]
	if action then
		-- Stop listening after the first match
		isListening = false
		task.spawn(action)
	end
end

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

	-- Also connect to Animators / AnimationControllers
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
	isListening = false
	for _, conn in ipairs(connections) do
		pcall(conn.Disconnect, conn)
	end
	connections = {}
end

------------------------------------------------
-- TIMER
------------------------------------------------
local function resetTimer()
	if timerThread then
		task.cancel(timerThread)
		timerThread = nil
	end

	timerThread = task.spawn(function()
		task.wait(WAIT_TIME)
		if running then
			local char = getCharacter()
			if char then
				isListening = true
				connectAnimationSources(char)
			end
		end
		timerThread = nil
	end)
end

------------------------------------------------
-- DAMAGE MONITOR
------------------------------------------------
local function onDamageChanged(newValue)
	if not running then return end
	local increment = newValue - lastDamage
	lastDamage = newValue

	if increment > DAMAGE_MIN and increment < DAMAGE_MAX then
		-- Stop any active listening and reset the timer
		stopListening()
		resetTimer()
	end
end

local function setupDamageWatcher()
	if damageConn then
		damageConn:Disconnect()
		damageConn = nil
	end

	local stats = p:FindFirstChild("Stats")
	if not stats then
		warn("Stats folder not found in player")
		return
	end

	local damage = stats:FindFirstChild("Damage")
	if not damage or not damage:IsA("NumberValue") then
		warn("Damage NumberValue not found in Stats folder")
		return
	end

	damageValue = damage
	lastDamage = damage.Value

	damageConn = damageValue:GetPropertyChangedSignal("Value"):Connect(function()
		onDamageChanged(damageValue.Value)
	end)
end

------------------------------------------------
-- CHARACTER RESPAWN
------------------------------------------------
local function onCharacterAdded(char)
	if isListening then
		connectAnimationSources(char)
	end
end

------------------------------------------------
-- PUBLIC API
------------------------------------------------
function m.Start()
	if running then return end
	running = true

	setupDamageWatcher()
	characterConnection = p.CharacterAdded:Connect(onCharacterAdded)

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

	if damageConn then
		damageConn:Disconnect()
		damageConn = nil
	end

	damageValue = nil
	lastDamage = 0

	print("DamageCombo stopped.")
end

return m
