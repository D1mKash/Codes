local module = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local LIVE_FOLDER = workspace:WaitForChild("Live")

local connection
local running = false

local teammateModel = nil
local currentTarget = nil
local cooldown = false

------------------------------------------------
-- INPUT
------------------------------------------------

local function pressOne()
	VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.One, false, game)
	VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.One, false, game)
end

------------------------------------------------
-- GET MY BLOCKING
------------------------------------------------

local function isMyBlocking()
	local myModel = LIVE_FOLDER:FindFirstChild(player.Name)
	if not myModel then return false end

	local blocking = myModel:FindFirstChild("Blocking")
	return blocking and blocking.Value == true
end

------------------------------------------------
-- VALID TARGET CHECK
------------------------------------------------

local function isValidTarget(model, myRoot)

	if not model or not model.Parent then return false end
	if model.Name == player.Name then return false end
	if model == player.Character then return false end
	if teammateModel and model == teammateModel then return false end

	local root = model:FindFirstChild("HumanoidRootPart")
	local blocking = model:FindFirstChild("Blocking")

	if not root or not blocking then return false end
	if blocking.Value == true then return false end

	local dist = (root.Position - myRoot.Position).Magnitude
	return dist >= 18 and dist <= 45
end

------------------------------------------------
-- FIND SINGLE TARGET
------------------------------------------------

local function findTarget()

	local char = player.Character
	if not char then return nil end

	local myRoot = char:FindFirstChild("HumanoidRootPart")
	if not myRoot then return nil end

	local closest = nil
	local closestDist = math.huge

	for _, model in ipairs(LIVE_FOLDER:GetChildren()) do

		if model:IsA("Model") and isValidTarget(model, myRoot) then

			local root = model:FindFirstChild("HumanoidRootPart")
			local dist = (root.Position - myRoot.Position).Magnitude

			if dist < closestDist then
				closestDist = dist
				closest = model
			end

		end
	end

	return closest
end

------------------------------------------------
-- MAIN LOOP
------------------------------------------------

local function step()

	local char = player.Character
	if not char then return end

	local myRoot = char:FindFirstChild("HumanoidRootPart")
	if not myRoot then return end

	-- if current target invalid → find new one
	if not currentTarget or not isValidTarget(currentTarget, myRoot) then
		currentTarget = findTarget()
	end

	if not currentTarget then return end

	-- wait if YOU are blocking
	if isMyBlocking() then return end

	-- cooldown control
	if cooldown then return end
	cooldown = true

	pressOne()

	task.delay(1, function()
		cooldown = false
	end)
end

------------------------------------------------
-- START
------------------------------------------------

function module.Start(teammate)

	teammateModel = teammate
	running = true

	if connection then connection:Disconnect() end

	connection = RunService.Heartbeat:Connect(function()
		if running then
			step()
		end
	end)

end

------------------------------------------------
-- STOP
------------------------------------------------

function module.Stop()

	running = false
	currentTarget = nil
	cooldown = false

	if connection then
		connection:Disconnect()
		connection = nil
	end

end

return module
