local module = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

------------------------------------------------
-- CONFIGURATION
------------------------------------------------
local TRIGGER_ANIM = "1470532199"            -- stand animation that confirms the hit
local TRIGGER_KEY = Enum.KeyCode.Two         -- pressed together with the follow

local DAMAGE_WINDOW = 0.7                    -- animation only counts this long around a hit
local MIN_DAMAGE = 1                         -- smallest Damage change that counts as a hit
local ARM_ON_DECREASE = true                 -- Damage going down also counts as a hit
local CHECK_BEFORE_DAMAGE = true             -- fire when the anim played just before the hit
local PRESS_DEBOUNCE = 0.2                   -- ignores duplicate events from stand + character
local RESCAN_INTERVAL = 1                    -- re-check for new stand / animators this often

local FOLLOW_DURATION = 1.0                  -- how long we sit on the head
local FOLLOW_OFFSET = Vector3.new(0, 4, 0)   -- head offset (same as akaza)
local FOLLOW_ALPHA = 0.175                   -- lerp strength (same as akaza)
local TARGET_RANGE = 6                       -- max distance to the target we follow

local DEBUG = true                           -- print what the script sees

------------------------------------------------
-- LOGGING
------------------------------------------------
local debugEnabled = DEBUG

local function log(...)
	if not debugEnabled then return end
	local parts = {}
	for i = 1, select("#", ...) do
		parts[i] = tostring((select(i, ...)))
	end
	print("[standhead] " .. table.concat(parts, " "))
end

local function pathOf(instance)
	local parts = {}
	local current = instance
	while current and current ~= workspace do
		table.insert(parts, 1, current.Name)
		current = current.Parent
	end
	return table.concat(parts, ".")
end

------------------------------------------------
-- STATE
------------------------------------------------
local running = false

local scanActive = false
local scanToken = 0
local usedInWindow = false
local lastTriggerAt = nil
local lastPressAt = nil

local followToken = 0

local animConnections = {}
local hookedSources = {}
local unavailableSources = {}
local watchedModels = {}
local listeners = {}
local watchedContainers = {}
local damageConnection = nil
local healthConnection = nil
local previousDamage = nil
local seenAnims = {}

local refreshHooks

------------------------------------------------
-- FOLDERS (never block if the game names them differently)
------------------------------------------------
local function getLive()
	return workspace:FindFirstChild("Live")
end

local function getStands()
	return workspace:FindFirstChild("Stands")
end

------------------------------------------------
-- INPUT
------------------------------------------------
local function pressKey(key)
	pcall(function()
		VirtualInputManager:SendKeyEvent(true, key, false, game)
		task.wait(0.01)
		VirtualInputManager:SendKeyEvent(false, key, false, game)
	end)
	log("pressed", key.Name)
end

------------------------------------------------
-- TARGET / HEAD FOLLOW (akaza style)
------------------------------------------------
local function getRoot(model)
	if not model then return nil end
	return model:FindFirstChild("HumanoidRootPart")
end

local function isAlive(model)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0
end

local function getNearestTarget()
	local char = player.Character
	local myRoot = getRoot(char)
	if not myRoot then return nil end

	local live = getLive()
	if not live then return nil end

	local team = player.Team
	local closest, best = nil, math.huge

	for _, model in ipairs(live:GetChildren()) do
		if model ~= char and isAlive(model) then
			local root = getRoot(model)
			if root then
				local owner = Players:GetPlayerFromCharacter(model)
				local sameTeam = team ~= nil and owner ~= nil and owner.Team == team

				if not sameTeam then
					local dist = (root.Position - myRoot.Position).Magnitude
					if dist <= TARGET_RANGE and dist < best then
						best = dist
						closest = model
					end
				end
			end
		end
	end

	return closest
end

local function smoothFollow(targetModel, duration)
	local char = player.Character
	if not char then return end

	local myRoot = getRoot(char)
	local targetRoot = getRoot(targetModel)
	if not myRoot or not targetRoot then return end

	local token = followToken
	local start = os.clock()

	while running and token == followToken and (os.clock() - start) < duration do
		if not myRoot.Parent or not targetRoot.Parent then return end
		if not isAlive(targetModel) then return end

		local pos = targetRoot.Position + FOLLOW_OFFSET
		local look = targetRoot.Position - myRoot.Position
		look = Vector3.new(look.X, 0, look.Z)
		if look.Magnitude < 0.001 then
			look = Vector3.new(0, 0, 1)
		end

		local goal = CFrame.new(pos, pos + look)
		myRoot.CFrame = myRoot.CFrame:Lerp(goal, FOLLOW_ALPHA)

		RunService.Heartbeat:Wait()
	end

	log("follow ended")
end

local function startFollow()
	followToken = followToken + 1

	task.spawn(function()
		local target = getNearestTarget()
		if target then
			log("following", target.Name, "for", FOLLOW_DURATION .. "s")
			smoothFollow(target, FOLLOW_DURATION)
		else
			log("no target in range, press only")
		end
	end)
end

------------------------------------------------
-- SCAN WINDOW / TRIGGER
------------------------------------------------
local function armWindow(reason)
	scanActive = true
	usedInWindow = false

	scanToken = scanToken + 1
	local token = scanToken

	log("window open (", reason, ") for", DAMAGE_WINDOW .. "s")

	task.delay(DAMAGE_WINDOW, function()
		if not running then return end
		if token ~= scanToken then return end
		scanActive = false
		usedInWindow = false
		log("window closed")
	end)
end

local function fireTrigger(reason)
	local timestamp = os.clock()

	if lastPressAt and (timestamp - lastPressAt) < PRESS_DEBOUNCE then
		log("duplicate trigger ignored (", reason, ")")
		return
	end
	lastPressAt = timestamp

	log("TRIGGER (", reason, ") -> press", TRIGGER_KEY.Name, "+ follow", FOLLOW_DURATION .. "s")

	startFollow()
	pressKey(TRIGGER_KEY)
end

------------------------------------------------
-- ANIMATION HANDLER
------------------------------------------------
local function onAnimationPlayed(track)
	if not running then return end

	local animation = track and track.Animation
	if not animation then return end

	local animationId = animation.AnimationId or ""
	local numericId = string.match(animationId, "(%d+)$")
	if not numericId then return end

	if debugEnabled and not seenAnims[numericId] then
		seenAnims[numericId] = true
		log("animation seen:", numericId)
	end

	if numericId ~= TRIGGER_ANIM then return end

	lastTriggerAt = os.clock()

	if not scanActive then
		log("trigger animation outside window (waiting for damage)")
		return
	end

	if usedInWindow then
		log("trigger animation already used in this window")
		return
	end

	usedInWindow = true
	fireTrigger("animation in window")
end

------------------------------------------------
-- ANIMATION SOURCES (stand, character, Live copy)
------------------------------------------------
local function attachAnimator(source)
	if not source then return end
	if hookedSources[source] or unavailableSources[source] then return end

	local ok, connection = pcall(function()
		return source.AnimationPlayed:Connect(onAnimationPlayed)
	end)

	if not ok or not connection then
		unavailableSources[source] = true
		log("no AnimationPlayed on", pathOf(source))
		return
	end

	hookedSources[source] = true
	table.insert(animConnections, connection)
	log("hooked", pathOf(source))
end

local function hookModel(model)
	if not model then return end

	local hasAnimator = false

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Animator") then
			hasAnimator = true
			attachAnimator(descendant)
		elseif descendant:IsA("AnimationController") and not descendant:FindFirstChildOfClass("Animator") then
			attachAnimator(descendant)
		end
	end

	-- Humanoid proxies its Animator, only used while no Animator exists yet
	if not hasAnimator then
		attachAnimator(model:FindFirstChildOfClass("Humanoid"))
	end

	-- animators created after us (stand loading in)
	if not watchedModels[model] then
		watchedModels[model] = true

		local ok, connection = pcall(function()
			return model.DescendantAdded:Connect(function(descendant)
				if descendant:IsA("Animator") then
					attachAnimator(descendant)
				elseif descendant:IsA("AnimationController") and not descendant:FindFirstChildOfClass("Animator") then
					attachAnimator(descendant)
				end
			end)
		end)

		if ok and connection then
			table.insert(animConnections, connection)
		end
	end
end

local function getStand(char)
	local stands = getStands()
	if not stands or not char then return nil end
	return stands:FindFirstChild(char.Name) or stands:FindFirstChild(player.Name)
end

local function hasStand()
	return getStand(player.Character) ~= nil
end

local function collectSources(char)
	local sources = {}

	if char then
		table.insert(sources, char)
	end

	local stand = getStand(char)
	if stand then
		table.insert(sources, stand)
	end

	-- some games keep the stand (or a copy of the character) inside Live
	local live = getLive()
	if live and char then
		local extra = live:FindFirstChild(char.Name) or live:FindFirstChild(player.Name)
		if extra and extra ~= char then
			table.insert(sources, extra)
		end
	end

	return sources
end

local function onContainerChanged(child)
	if not running then return end

	local char = player.Character
	if not char then return end
	if child.Name ~= char.Name and child.Name ~= player.Name then return end

	task.wait(0.1)
	if running then
		refreshHooks()
	end
end

local function watchContainer(container)
	if not container or watchedContainers[container] then return end
	watchedContainers[container] = true

	local okAdded, added = pcall(function()
		return container.ChildAdded:Connect(onContainerChanged)
	end)
	if okAdded and added then
		table.insert(listeners, added)
	end

	local okRemoved, removed = pcall(function()
		return container.ChildRemoved:Connect(onContainerChanged)
	end)
	if okRemoved and removed then
		table.insert(listeners, removed)
	end
end

-- attaches anything that is not hooked yet, cheap and safe to call often
local function rescanSources()
	if not running then return end

	for _, model in ipairs(collectSources(player.Character)) do
		hookModel(model)
	end

	watchContainer(getStands())
	watchContainer(getLive())
end

refreshHooks = function()
	for _, connection in ipairs(animConnections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	animConnections = {}
	hookedSources = {}
	unavailableSources = {}
	watchedModels = {}
	seenAnims = {}

	rescanSources()

	log("hooked:", #animConnections, "| stand:", hasStand() and "yes" or "no")
end

------------------------------------------------
-- DAMAGE DETECTION
------------------------------------------------
local function handleHit(description)
	if CHECK_BEFORE_DAMAGE and lastTriggerAt and (os.clock() - lastTriggerAt) <= DAMAGE_WINDOW then
		log(description, "-> trigger animation played just before the hit")
		fireTrigger("animation before damage")
		return
	end

	armWindow(description)
end

local function findDamageValue()
	local stats = player:FindFirstChild("Stats")
	if stats then
		local value = stats:FindFirstChild("Damage")
		if value and value:IsA("NumberValue") then return value end
	end

	local direct = player:FindFirstChild("Damage")
	if direct and direct:IsA("NumberValue") then return direct end

	return nil
end

local function hookDamage()
	if damageConnection then return true end

	local value = findDamageValue()
	if not value then return false end

	previousDamage = value.Value

	damageConnection = value.Changed:Connect(function(newValue)
		if not running then return end

		local delta = newValue - previousDamage
		previousDamage = newValue

		if delta == 0 or math.abs(delta) < MIN_DAMAGE then return end
		if delta < 0 and not ARM_ON_DECREASE then return end

		if delta > 0 then
			handleHit("damage +" .. delta)
		else
			handleHit("damage " .. delta)
		end
	end)

	log("damage source:", pathOf(value))
	return true
end

-- fallback when Stats.Damage is not the thing the game updates
local function hookHealth()
	if healthConnection then return true end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return false end

	local lastHealth = hum.Health

	healthConnection = hum.HealthChanged:Connect(function(newHealth)
		if not running then return end

		local delta = lastHealth - newHealth
		lastHealth = newHealth

		if delta <= 0 then return end
		handleHit("health -" .. delta)
	end)

	log("damage source: Humanoid.Health (fallback)")
	return true
end

------------------------------------------------
-- CHARACTER HOOK
------------------------------------------------
local function setupCharacter(char)
	if not char then return end

	scanActive = false
	usedInWindow = false

	if healthConnection then
		pcall(function()
			healthConnection:Disconnect()
		end)
		healthConnection = nil
	end

	refreshHooks()

	if not damageConnection then
		hookHealth()
	end
end

------------------------------------------------
-- PUBLIC API
------------------------------------------------
function module.Start()
	if running then return end
	running = true

	log("started | Live:", getLive() ~= nil, "| Stands:", getStands() ~= nil)
	log("config | animation:", TRIGGER_ANIM, "| key:", TRIGGER_KEY.Name, "| window:", DAMAGE_WINDOW .. "s")

	local char = player.Character
	if char then
		setupCharacter(char)
	end

	table.insert(listeners, player.CharacterAdded:Connect(function(newChar)
		task.wait(0.5)
		if running then
			setupCharacter(newChar)
		end
	end))

	-- pick up folders that get created after us
	table.insert(listeners, workspace.ChildAdded:Connect(function(child)
		if not running then return end
		if child.Name == "Stands" or child.Name == "Live" then
			task.wait(0.1)
			if running then refreshHooks() end
		end
	end))

	refreshHooks()

	-- keeps hooking animators that replicate/load in late
	task.spawn(function()
		while running do
			task.wait(RESCAN_INTERVAL)
			if running then
				rescanSources()
			end
		end
	end)

	task.spawn(function()
		while running do
			if not damageConnection then
				if not hookDamage() then
					hookHealth()
				end
			end
			task.wait(0.3)
		end
	end)
end

function module.Stop()
	running = false

	for _, connection in ipairs(listeners) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	listeners = {}
	watchedContainers = {}

	for _, connection in ipairs(animConnections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	animConnections = {}
	hookedSources = {}
	unavailableSources = {}
	watchedModels = {}

	if damageConnection then
		pcall(function()
			damageConnection:Disconnect()
		end)
		damageConnection = nil
	end

	if healthConnection then
		pcall(function()
			healthConnection:Disconnect()
		end)
		healthConnection = nil
	end

	scanActive = false
	usedInWindow = false
	scanToken = scanToken + 1
	followToken = followToken + 1

	previousDamage = nil
	lastTriggerAt = nil
	lastPressAt = nil
	seenAnims = {}

	log("stopped")
end

module.HasStand = hasStand
module.IsScanning = function()
	return scanActive
end
module.Refresh = function()
	if running then
		refreshHooks()
	end
end
module.SetDebug = function(enabled)
	debugEnabled = enabled and true or false
end

return module
