local m = {}

local P = game:GetService("Players")
local R = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local p = P.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

local h
local connections = {}
local characterConnection
local pendingThread = nil
local running = false

------------------------------------------------
-- CONFIGURATION – adjust delays & follow durations
------------------------------------------------
-- Global fallback values (used if not specified per animation)
local DEFAULT_DELAY = 1.0           -- seconds to wait before following
local DEFAULT_FOLLOW_DURATION = 1.0 -- seconds to keep following

-- Map animation ID → { delay = seconds, followDuration = seconds }
-- If a field is omitted, the global default is used.
local ANIM_CONFIG = {
	["109159204999611"] = {
		delay = 0.4,
		followDuration = 1.2,
	},
	["89353560922659"] = {
		delay = 0.5,
		followDuration = 1.3,
	},
	["87557571922650"] = {
		delay = 2.1,
		followDuration = 0.9,
	},
	["5711400521"] = {
		delay = 0.8,
		followDuration = 0.6,
	},
	-- Add new ones here, e.g.:
	-- ["123456789"] = { delay = 1.0, followDuration = 2.0 },
}

------------------------------------------------
-- FOLLOW / LOCK SYSTEM
------------------------------------------------

local function getRoot(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end

local function getNearestTarget()
	local char = p.Character
	if not char then return end

	local myRoot = getRoot(char)
	if not myRoot then return end

	local localTeam = p.Team
	local closest, dist = nil, math.huge
	local maxDist = 6

	for _, model in pairs(LIVE:GetChildren()) do
		if model == char then continue end

		local hum = model:FindFirstChildOfClass("Humanoid")
		if not hum then continue end
		local root = getRoot(model)
		if not root then continue end

		local player = P:GetPlayerFromCharacter(model)
		if player then
			if localTeam and player.Team == localTeam then continue end
			if player == p then continue end
		end

		local d = (root.Position - myRoot.Position).Magnitude
		if d < maxDist and d < dist then
			dist = d
			closest = model
		end
	end

	return closest
end

-- smoothFollow now accepts a duration parameter
local function smoothFollow(targetModel, duration)
	local char = p.Character
	if not char then return end

	local myRoot = getRoot(char)
	local targetRoot = getRoot(targetModel)
	if not myRoot or not targetRoot then return end

	local start = os.clock()
	while running and os.clock() - start < duration do
		if not myRoot.Parent or not targetRoot.Parent then return end

		local pos = targetRoot.Position + Vector3.new(0, 4, 0)
		local look = targetRoot.Position - myRoot.Position
		look = Vector3.new(look.X, 0, look.Z)
		local goal = CFrame.new(pos, pos + look)

		myRoot.CFrame = myRoot.CFrame:Lerp(goal, 0.175)
		R.Heartbeat:Wait()
	end
end

------------------------------------------------
-- ANIMATION HANDLER (uses manual delays & durations)
------------------------------------------------

local function onAnimationPlayed(track)
	if not running then return end
	if not track or not track.Animation then return end

	local animId = track.Animation.AnimationId
	if not animId then return end

	local numericId = string.match(animId, "(%d+)$")
	if not numericId then return end

	local config = ANIM_CONFIG[numericId]
	if not config then return end   -- not a trigger animation

	-- Get delay and follow duration from config, fallback to defaults
	local delay = config.delay or DEFAULT_DELAY
	local followDuration = config.followDuration or DEFAULT_FOLLOW_DURATION

	-- Cancel any pending follow from a previous trigger
	if pendingThread then
		task.cancel(pendingThread)
		pendingThread = nil
	end

	-- Start a new thread that waits the delay, then follows
	pendingThread = task.spawn(function()
		task.wait(delay)

		if not running or pendingThread ~= coroutine.running() then
			return
		end
		pendingThread = nil

		local target = getNearestTarget()
		if target then
			smoothFollow(target, followDuration)
		end
	end)
end

------------------------------------------------
-- CONNECT TO ALL ANIMATION SOURCES
------------------------------------------------

local function connectToAnimationSources(char)
	for _, conn in ipairs(connections) do
		pcall(conn.Disconnect, conn)
	end
	connections = {}

	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	h = hum

	local conn1 = hum.AnimationPlayed:Connect(onAnimationPlayed)
	table.insert(connections, conn1)

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

------------------------------------------------
-- CHARACTER HOOK
------------------------------------------------

local function hk(char)
	if not char then return end
	connectToAnimationSources(char)
end

------------------------------------------------
-- PUBLIC API
------------------------------------------------

function m.Start()
	if running then return end
	running = true

	if p.Character then
		hk(p.Character)
	end

	characterConnection = p.CharacterAdded:Connect(hk)
end

function m.Stop()
	running = false

	for _, conn in ipairs(connections) do
		pcall(conn.Disconnect, conn)
	end
	connections = {}

	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end

	if pendingThread then
		task.cancel(pendingThread)
		pendingThread = nil
	end

	h = nil
end

return m
