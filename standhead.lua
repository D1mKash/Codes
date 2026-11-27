local module = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

------------------------------------------------
-- CONFIGURATION
------------------------------------------------
local TRIGGER_ANIM = "1470532199"            -- stand animation that presses the key
local TRIGGER_KEY = Enum.KeyCode.Two         -- key to press

local FOLLOW = true                          -- also sit on the target's head
local FOLLOW_DURATION = 1.0                  -- how long the head follow runs
local FOLLOW_OFFSET = Vector3.new(0, 4, 0)   -- head offset (same as akaza)
local FOLLOW_ALPHA = 0.175                   -- lerp strength (same as akaza)
local TARGET_RANGE = 6                       -- max distance to the target we follow

local PRESS_COOLDOWN = 0.15                  -- ignores duplicate events from the same attack
local RESCAN_INTERVAL = 1                    -- re-check for new stand / animators this often

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

local animConnections = {}
local hookedSources = {}
local unavailableSources = {}
local watchedModels = {}
local listeners = {}

local followToken = 0
local lastPressAt = nil
local seenAnims = {}

------------------------------------------------
-- INPUT
------------------------------------------------
local function pressKey(key)
	local ok = pcall(function()
		VirtualInputManager:SendKeyEvent(true, key, false, game)
		task.wait(0.01)
		VirtualInputManager:SendKeyEvent(false, key, false, game)
	end)

	log(ok and ("pressed " .. key.Name) or ("press failed for " .. key.Name))
	return ok
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

	local live = workspace:FindFirstChild("Live")
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

		myRoot.CFrame = myRoot.CFrame:Lerp(CFrame.new(pos, pos + look), FOLLOW_ALPHA)

		RunService.Heartbeat:Wait()
	end
end

local function startFollow()
	followToken = followToken + 1

	task.spawn(function()
		local target = getNearestTarget()
		if not target then
			log("no target in range, pressed only")
			return
		end

		log("following", target.Name, "for", FOLLOW_DURATION .. "s")
		smoothFollow(target, FOLLOW_DURATION)
	end)
end

------------------------------------------------
-- TRIGGER
------------------------------------------------
local function trigger(reason)
	local timestamp = os.clock()

	if lastPressAt and (timestamp - lastPressAt) < PRESS_COOLDOWN then
		log("duplicate ignored (", reason, ")")
		return
	end
	lastPressAt = timestamp

	log("TRIGGER (", reason, ")")
	pressKey(TRIGGER_KEY)

	if FOLLOW then
		startFollow()
	end
end

------------------------------------------------
-- ANIMATION HANDLER
------------------------------------------------
local function onAnimationPlayed(track)
	if not running then return end

	local animation = track and track.Animation
	if not animation then return end

	local numericId = string.match(animation.AnimationId or "", "(%d+)$")
	if not numericId then return end

	if debugEnabled and not seenAnims[numericId] then
		seenAnims[numericId] = true
		log("animation seen:", numericId)
	end

	if numericId ~= TRIGGER_ANIM then return end

	trigger("animation " .. numericId)
end

------------------------------------------------
-- ANIMATION SOURCES
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

	-- catch animators that load in later
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
	local stands = workspace:FindFirstChild("Stands")
	if not stands or not char then return nil end
	return stands:FindFirstChild(char.Name) or stands:FindFirstChild(player.Name)
end

-- hook stands (or Live copies) the moment they appear
local watchedFolders = {}

local function watchFolder(folder)
	if not folder or watchedFolders[folder] then return end
	watchedFolders[folder] = true

	local ok, connection = pcall(function()
		return folder.ChildAdded:Connect(function(child)
			if running then
				hookModel(child)
			end
		end)
	end)

	if ok and connection then
		table.insert(listeners, connection)
	end
end

local function hookAll()
	if not running then return end

	local char = player.Character
	if char then
		hookModel(char)
	end

	local stands = workspace:FindFirstChild("Stands")
	local live = workspace:FindFirstChild("Live")

	if stands then
		watchFolder(stands)
	end
	if live then
		watchFolder(live)
	end

	local stand = getStand(char)
	if stand then
		hookModel(stand)
	end

	-- some games keep the stand (or a copy of the character) inside Live
	if live and char then
		local extra = live:FindFirstChild(char.Name) or live:FindFirstChild(player.Name)
		if extra and extra ~= char then
			hookModel(extra)
		end
	end
end

------------------------------------------------
-- PUBLIC API
------------------------------------------------
function module.Start()
	if running then return end
	running = true

	log("started | animation:", TRIGGER_ANIM, "| key:", TRIGGER_KEY.Name)
	log("Stands folder:", workspace:FindFirstChild("Stands") ~= nil, "| Live folder:", workspace:FindFirstChild("Live") ~= nil)

	hookAll()

	-- the Stands/Live folders can appear after us; hook them the moment they do
	table.insert(listeners, workspace.ChildAdded:Connect(function(child)
		if not running then return end
		if child.Name == "Stands" or child.Name == "Live" then
			watchFolder(child)
			hookAll()
		end
	end))

	table.insert(listeners, player.CharacterAdded:Connect(function()
		task.wait(0.5)
		if running then
			hookAll()
		end
	end))

	task.spawn(function()
		while running do
			task.wait(RESCAN_INTERVAL)
			if running then
				hookAll()
			end
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

	for _, connection in ipairs(animConnections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	animConnections = {}
	hookedSources = {}
	unavailableSources = {}
	watchedModels = {}
	watchedFolders = {}

	followToken = followToken + 1
	lastPressAt = nil
	seenAnims = {}

	log("stopped")
end

-- presses the key without the animation, to confirm input works
function module.TestPress()
	pressKey(TRIGGER_KEY)
end

module.HasStand = function()
	return getStand(player.Character) ~= nil
end

module.SetDebug = function(enabled)
	debugEnabled = enabled and true or false
end

return module
