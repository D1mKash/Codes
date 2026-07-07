local m = {}

local P = game:GetService("Players")
local R = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local p = P.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

local h
local connections = {}         -- event connections for animation sources
local characterConnection
local pendingEndConn = nil     -- connection for the current animation's Ended event

local running = false

-- All trigger animation IDs (numeric)
local TRIGGER_ANIMS = {
	"109159204999611",
	"89353560922659",
	"87557571922650",
	"5711400521",
}

------------------------------------------------
-- FOLLOW / LOCK SYSTEM
------------------------------------------------

local function getRoot(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end

-- Returns the nearest valid target within 6 studs, respecting team rules
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
	local totalDuration = 1.3

	while running and os.clock() - start < totalDuration do
		if not myRoot or not myRoot.Parent then return end
		if not targetRoot or not targetRoot.Parent then return end

		local pos = targetRoot.Position + Vector3.new(0, 4, 0)
		local look = targetRoot.Position - myRoot.Position
		look = Vector3.new(look.X, 0, look.Z)
		local goal = CFrame.new(pos, pos + look)

		myRoot.CFrame = myRoot.CFrame:Lerp(goal, 0.175)
		R.Heartbeat:Wait()
	end
end

------------------------------------------------
-- ANIMATION HANDLER (triggers after animation ends)
------------------------------------------------

local function onAnimationPlayed(track)
	if not running then return end
	if not track or not track.Animation then return end

	local animId = track.Animation.AnimationId
	if not animId then return end

	local numericId = string.match(animId, "(%d+)$")
	if not numericId then return end

	-- Check if it's a trigger
	local isTrigger = false
	for _, id in ipairs(TRIGGER_ANIMS) do
		if numericId == id then
			isTrigger = true
			break
		end
	end

	if not isTrigger then return end

	-- Cancel any pending animation‑end listener
	if pendingEndConn then
		pendingEndConn:Disconnect()
		pendingEndConn = nil
	end

	-- Wait until this animation finishes, then run the follow
	pendingEndConn = track.Ended:Connect(function()
		pendingEndConn = nil
		if not running then return end

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
	-- Clear previous connections
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

	if pendingEndConn then
		pendingEndConn:Disconnect()
		pendingEndConn = nil
	end

	h = nil
end

return m
