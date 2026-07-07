local m = {}

local P = game:GetService("Players")
local R = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local p = P.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

local h
local connections = {}
local characterConnection
local pendingThread = nil   -- currently waiting coroutine
local running = false

------------------------------------------------
-- CONFIGURATION – adjust delays here
------------------------------------------------
-- Map animation ID (string) → delay in seconds
-- The script will wait this long after the animation starts, then follow.
local ANIM_CONFIG = {
	["109159204999611"] = 0.9,   -- example: wait 1.2 seconds
	["89353560922659"]  = 0.5,
	["87557571922650"]  = 2.35,
	["5711400521"]      = 0.8,   -- adjust to your liking
}
-- If you add a new ID, just add it here with its desired delay.

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

local function smoothFollow(targetModel)
	local char = p.Character
	if not char then return end

	local myRoot = getRoot(char)
	local targetRoot = getRoot(targetModel)
	if not myRoot or not targetRoot then return end

	local start = os.clock()
	local totalDuration = 1.3   -- how long to follow

	while running and os.clock() - start < totalDuration do
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
-- ANIMATION HANDLER (uses manual delays)
------------------------------------------------

local function onAnimationPlayed(track)
	if not running then return end
	if not track or not track.Animation then return end

	local animId = track.Animation.AnimationId
	if not animId then return end

	local numericId = string.match(animId, "(%d+)$")
	if not numericId then return end

	-- Check if this ID is in our config
	local delay = ANIM_CONFIG[numericId]
	if not delay then return end   -- not a trigger animation

	-- Cancel any pending follow from a previous trigger
	if pendingThread then
		task.cancel(pendingThread)
		pendingThread = nil
	end

	-- Start a new thread that waits the specified delay, then follows
	pendingThread = task.spawn(function()
		task.wait(delay)

		-- Only proceed if still running and this thread is still active
		if not running or pendingThread ~= coroutine.running() then
			return
		end
		pendingThread = nil

		local target = getNearestTarget()
		if target then
			smoothFollow(target)
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
