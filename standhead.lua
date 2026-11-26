local module = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local LIVE = workspace:WaitForChild("Live")
local STANDS = workspace:WaitForChild("Stands")

------------------------------------------------
-- CONFIGURATION
------------------------------------------------
local TRIGGER_ANIM = "1470532199"            -- stand animation that confirms the hit
local TRIGGER_KEY = Enum.KeyCode.Two         -- pressed together with the follow

local DAMAGE_WINDOW = 0.7                    -- animation only counts this long after damage
local MIN_DAMAGE = 1                         -- smallest Damage increase that opens the window

local FOLLOW_DURATION = 1.0                  -- how long we sit on the head
local FOLLOW_OFFSET = Vector3.new(0, 4, 0)   -- head offset (same as akaza)
local FOLLOW_ALPHA = 0.175                   -- lerp strength (same as akaza)
local TARGET_RANGE = 6                       -- max distance to the target we follow

------------------------------------------------
-- STATE
------------------------------------------------
local running = false

local scanActive = false
local scanToken = 0
local usedInWindow = false

local followToken = 0

local animConnections = {}
local connections = {}
local damageConnection = nil
local damageValue = nil
local previousDamage = nil

------------------------------------------------
-- INPUT
------------------------------------------------
local function pressKey(key)
	pcall(function()
		VirtualInputManager:SendKeyEvent(true, key, false, game)
		task.wait(0.01)
		VirtualInputManager:SendKeyEvent(false, key, false, game)
	end)
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

	local team = player.Team
	local closest, best = nil, math.huge

	for _, model in ipairs(LIVE:GetChildren()) do
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
end

local function startFollow()
	followToken = followToken + 1

	task.spawn(function()
		local target = getNearestTarget()
		if target then
			smoothFollow(target, FOLLOW_DURATION)
		end
	end)
end

------------------------------------------------
-- SCAN WINDOW (opened by damage)
------------------------------------------------
local function openWindow()
	scanActive = true
	usedInWindow = false

	scanToken = scanToken + 1
	local token = scanToken

	task.delay(DAMAGE_WINDOW, function()
		if not running then return end
		if token == scanToken then
			scanActive = false
		end
	end)
end

------------------------------------------------
-- ANIMATION HANDLER
------------------------------------------------
local function onTriggerAnimDetected()
	usedInWindow = true

	startFollow()
	pressKey(TRIGGER_KEY)
end

local function onAnimationPlayed(track)
	if not running then return end
	if not scanActive or usedInWindow then return end

	local animation = track and track.Animation
	if not animation then return end

	local numericId = string.match(animation.AnimationId or "", "(%d+)$")
	if numericId ~= TRIGGER_ANIM then return end

	onTriggerAnimDetected()
end

------------------------------------------------
-- STAND / ANIMATION SOURCES
------------------------------------------------
local function getStand(char)
	if not char then return nil end
	return STANDS:FindFirstChild(char.Name) or STANDS:FindFirstChild(player.Name)
end

-- true while our own stand exists in Workspace.Stands
local function hasStand()
	return getStand(player.Character) ~= nil
end

local function hookAnimations(model, bucket)
	if not model then return end

	local found = false
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("Animator") then
			found = true
			table.insert(bucket, descendant.AnimationPlayed:Connect(onAnimationPlayed))
		end
	end

	-- Humanoid proxies its Animator, only used when no Animator is present yet
	if not found then
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			table.insert(bucket, hum.AnimationPlayed:Connect(onAnimationPlayed))
		end
	end
end

local function clearAnimConnections()
	for _, conn in ipairs(animConnections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	animConnections = {}
end

local function connectAnims(char)
	clearAnimConnections()
	if not char then return end

	-- stand first, character second so the stand takes priority when both move
	local stand = getStand(char)
	if stand then
		hookAnimations(stand, animConnections)
	end
	hookAnimations(char, animConnections)
end

local function onStandChanged(child)
	if not running then return end

	local char = player.Character
	if not char then return end
	if child.Name ~= char.Name and child.Name ~= player.Name then return end

	task.wait(0.1)
	if running and player.Character == char then
		connectAnims(char)
	end
end

------------------------------------------------
-- DAMAGE DETECTION
------------------------------------------------
local function hookDamage()
	local stats = player:FindFirstChild("Stats")
	local damage = stats and stats:FindFirstChild("Damage")
	if not damage or not damage:IsA("NumberValue") then return false end

	damageValue = damage
	previousDamage = damage.Value

	damageConnection = damage.Changed:Connect(function(newValue)
		if not running then return end

		if previousDamage ~= nil and (newValue - previousDamage) >= MIN_DAMAGE then
			openWindow()
		end
		previousDamage = newValue
	end)

	return true
end

local function setupDamage()
	if damageConnection and damageValue and damageValue.Parent then return end

	if damageConnection then
		damageConnection:Disconnect()
		damageConnection = nil
	end

	damageValue = nil
	previousDamage = nil
	hookDamage()
end

------------------------------------------------
-- CHARACTER HOOK
------------------------------------------------
local function setupCharacter(char)
	if not char then return end

	scanActive = false
	usedInWindow = false

	connectAnims(char)
	setupDamage()
end

------------------------------------------------
-- PUBLIC API
------------------------------------------------
function module.Start()
	if running then return end
	running = true

	local char = player.Character
	if char then
		setupCharacter(char)
	end

	table.insert(connections, player.CharacterAdded:Connect(function(newChar)
		task.wait(0.5)
		if running then
			setupCharacter(newChar)
		end
	end))

	table.insert(connections, STANDS.ChildAdded:Connect(onStandChanged))
	table.insert(connections, STANDS.ChildRemoved:Connect(onStandChanged))

	-- keep retrying until Stats > Damage exists
	task.spawn(function()
		while running do
			if damageConnection and damageValue and damageValue.Parent then return end
			setupDamage()
			task.wait(0.2)
		end
	end)
end

function module.Stop()
	running = false

	for _, conn in ipairs(connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	connections = {}

	clearAnimConnections()

	if damageConnection then
		damageConnection:Disconnect()
		damageConnection = nil
	end

	scanActive = false
	usedInWindow = false
	scanToken = scanToken + 1
	followToken = followToken + 1

	damageValue = nil
	previousDamage = nil
end

module.HasStand = hasStand
module.IsScanning = function()
	return scanActive
end

return module
