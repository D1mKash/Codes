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

-- animation IDs (numeric only)
local ANIM_WAIT = "1461136875"
local ANIM_COMBO = "109159204999611"

-- waiting state
local waitingForCombo = false
local waitTimer = nil

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

local function getNearestInRange()
	local char = p.Character
	if not char then return end

	local myRoot = getRoot(char)
	if not myRoot then return end

	local closest, dist = nil, math.huge

	for _, model in pairs(LIVE:GetChildren()) do
		if model ~= char then
			local root = getRoot(model)
			if root then
				local d = (root.Position - myRoot.Position).Magnitude
				if d < dist then
					dist = d
					closest = model
				end
			end
		end
	end

	if closest and dist <= 7 then
		return closest
	end
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

	-- Extract numeric ID from the string (e.g., "rbxassetid://123456" -> "123456")
	local numericId = string.match(animId, "(%d+)$")
	if not numericId then return end

	-- === Wait for the first animation ===
	if numericId == ANIM_WAIT then
		-- Cancel any previous timer
		if waitTimer then
			task.cancel(waitTimer)
			waitTimer = nil
		end
		waitingForCombo = true

		-- Set a 2-second timeout
		waitTimer = task.delay(2, function()
			waitingForCombo = false
			waitTimer = nil
		end)
	end

	-- === If waiting and combo animation plays, trigger follow ===
	if waitingForCombo and numericId == ANIM_COMBO then
		-- Cancel timer
		if waitTimer then
			task.cancel(waitTimer)
			waitTimer = nil
		end
		waitingForCombo = false

		-- Immediately start follow if enemy within 7 studs
		local target = getNearestInRange()
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
				-- Connect to their AnimationPlayed if it exists
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

	if waitTimer then
		task.cancel(waitTimer)
		waitTimer = nil
	end
	waitingForCombo = false

	h = nil
end

return m
