local m = {}

local P = game:GetService("Players")
local R = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VIM = game:GetService("VirtualInputManager")

local p = P.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

local h
local connections = {}  -- store all event connections
local characterConnection

local running = false

-- Trigger animation IDs (numeric only)
local TRIGGER_ANIMS = {
	"109159204999611",
	"89353560922659",      -- newly added
	"5711400521",
}

------------------------------------------------
-- INPUT COMBO
------------------------------------------------

local function pressKey(key)
	pcall(function()
		VIM:SendKeyEvent(true, key, false, game)
		task.wait(0.01)
		VIM:SendKeyEvent(false, key, false, game)
	end)
end

local function comboAction()
	pressKey(Enum.KeyCode.Q)
end

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

	local localTeam = p.Team  -- may be nil if not on a team

	local closest, dist = nil, math.huge
	local maxDist = 6

	for _, model in pairs(LIVE:GetChildren()) do
		if model == char then continue end  -- skip self

		-- Must have a Humanoid and a HumanoidRootPart
		local hum = model:FindFirstChildOfClass("Humanoid")
		if not hum then continue end
		local root = getRoot(model)
		if not root then continue end

		-- Check if it's a player character
		local player = P:GetPlayerFromCharacter(model)
		if player then
			-- If we are on a team, skip allies
			if localTeam and player.Team == localTeam then
				continue
			end
			-- Also skip if it's the local player (redundant but safe)
			if player == p then
				continue
			end
		end

		-- Distance check
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
-- ANIMATION HANDLER
------------------------------------------------

local function onAnimationPlayed(track)
	if not running then return end
	if not track or not track.Animation then return end

	local animId = track.Animation.AnimationId
	if not animId then return end

	local numericId = string.match(animId, "(%d+)$")
	if not numericId then return end

	-- Check if this animation ID is in our trigger list
	local isTrigger = false
	for _, id in ipairs(TRIGGER_ANIMS) do
		if numericId == id then
			isTrigger = true
			break
		end
	end

	if isTrigger then
		local target = getNearestTarget()
		if target then
			smoothFollow(target)
		end

		-- Press Q after 0.08 seconds
		task.delay(0.08, function()
			if running then
				comboAction()
			end
		end)
	end
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

	-- 1) Connect to Humanoid.AnimationPlayed
	local conn1 = hum.AnimationPlayed:Connect(onAnimationPlayed)
	table.insert(connections, conn1)

	-- 2) Find ALL Animators and AnimationControllers in the character (recursively)
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

	h = nil
end

return m
