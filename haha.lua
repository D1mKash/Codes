local m = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

local running = false
local inputConnection

local chrolloBusy = false
local chrolloToken = 0

------------------------------------------------
-- SETTINGS
------------------------------------------------

local CHROLLO_RANGE = 8
local CHROLLO_START_DELAY = 2.25

-- Move toward this relative offset first
local CHROLLO_LOCK_START_RANGE = 4
local CHROLLO_TARGET_OFFSET = Vector3.new(0, 5, 0)
local CHROLLO_STEP_SIZE = 0.08
local CHROLLO_STEP_INTERVAL = 0.01
local CHROLLO_STOP_AFTER_GONE = 0.4

local BLUE_BACK_DISTANCE = 1
local BLUE_RANGE = 7

------------------------------------------------
-- BASIC HELPERS
------------------------------------------------

local function getCharacter()
	return player.Character
end

local function getRoot(model)
	if not model then return nil end
	return model:FindFirstChild("HumanoidRootPart", true)
end

local function hasInCharacter(name)
	local char = getCharacter()
	if not char then return false end

	return char:FindFirstChild(name, true) ~= nil
end

local function pressKey(key)
	pcall(function()
		VIM:SendKeyEvent(true, key, false, game)
		task.wait(0.01)
		VIM:SendKeyEvent(false, key, false, game)
	end)
end

local function leftClick(duration)
	pcall(function()
		VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
		task.wait(duration or 0.05)
		VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
	end)
end

local function horizontalDistance(a, b)
	local aa = Vector3.new(a.X, 0, a.Z)
	local bb = Vector3.new(b.X, 0, b.Z)
	return (aa - bb).Magnitude
end

local function safeFacingCFrame(position, targetRoot)
	local look = targetRoot.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)

	if look.Magnitude < 0.05 then
		look = Vector3.new(0, 0, -1)
	else
		look = look.Unit
	end

	return CFrame.new(position, position + look)
end

------------------------------------------------
-- TARGET CHECK
------------------------------------------------

local function isValidTarget(model)
	if not model or not model:IsA("Model") then
		return false
	end

	local myChar = getCharacter()

	if model == myChar or model.Name == player.Name then
		return false
	end

	local targetPlayer = Players:FindFirstChild(model.Name)

	if targetPlayer then
		if targetPlayer == player then
			return false
		end

		if player.Team ~= nil and targetPlayer.Team ~= nil and targetPlayer.Team == player.Team then
			return false
		end
	end

	return true
end

local function getNearestTarget(maxRange)
	local char = getCharacter()
	if not char then return nil end

	local myRoot = getRoot(char)
	if not myRoot then return nil end

	local nearest = nil
	local nearestDistance = math.huge

	for _, model in ipairs(LIVE:GetChildren()) do
		if isValidTarget(model) then
			local root = getRoot(model)

			if root then
				local distance = (root.Position - myRoot.Position).Magnitude

				if (not maxRange or distance <= maxRange) and distance < nearestDistance then
					nearestDistance = distance
					nearest = model
				end
			end
		end
	end

	return nearest, nearestDistance
end

------------------------------------------------
-- LIFT FUNCTION
------------------------------------------------

local function lift()
	local char = getCharacter()
	if not char then return end

	local root = getRoot(char)
	if not root then return end

	root.AssemblyLinearVelocity = Vector3.new(0, 32, 0)

	local startTime = os.clock()

	task.spawn(function()
		while running and os.clock() - startTime < 0.1 do
			if not root or not root.Parent then return end

			root.AssemblyLinearVelocity = Vector3.new(0, 32, 0)
			RunService.Heartbeat:Wait()
		end
	end)
end

------------------------------------------------
-- STEP TO OFFSET, THEN NORMAL LOCK
------------------------------------------------

local function smoothFollowAboveTarget(targetModel)
	local char = getCharacter()
	if not char then return end

	local myRoot = getRoot(char)
	local targetRoot = getRoot(targetModel)

	if not myRoot or not targetRoot then return end

	local lastSawChrolloStop = os.clock()
	local lockedOnHead = false
	local lastStepTime = 0

	while running do
		char = getCharacter()
		myRoot = getRoot(char)
		targetRoot = getRoot(targetModel)

		if not char or not myRoot or not targetRoot then
			return
		end

		if hasInCharacter("ChrolloStop") then
			lastSawChrolloStop = os.clock()
		else
			if os.clock() - lastSawChrolloStop >= CHROLLO_STOP_AFTER_GONE then
				return
			end
		end

		local targetPosition = targetRoot.Position
		local desiredPosition = targetPosition + CHROLLO_TARGET_OFFSET

		if not lockedOnHead then
			local horizontalDist = horizontalDistance(myRoot.Position, targetPosition)

			if horizontalDist <= CHROLLO_LOCK_START_RANGE then
				if os.clock() - lastStepTime >= CHROLLO_STEP_INTERVAL then
					lastStepTime = os.clock()

					local currentOffset = myRoot.Position - targetPosition
					local difference = CHROLLO_TARGET_OFFSET - currentOffset

					if difference.Magnitude <= CHROLLO_STEP_SIZE then
						lockedOnHead = true
						myRoot.CFrame = safeFacingCFrame(desiredPosition, targetRoot)
					else
						local newOffset = currentOffset + difference.Unit * CHROLLO_STEP_SIZE
						local newPosition = targetPosition + newOffset

						myRoot.CFrame = safeFacingCFrame(newPosition, targetRoot)
					end

					myRoot.AssemblyLinearVelocity = Vector3.zero
					myRoot.AssemblyAngularVelocity = Vector3.zero
				end
			end

			task.wait()
		else
			-- Once reached, stop slow stepping and lock normally every frame
			myRoot.CFrame = safeFacingCFrame(desiredPosition, targetRoot)

			myRoot.AssemblyLinearVelocity = Vector3.zero
			myRoot.AssemblyAngularVelocity = Vector3.zero

			RunService.Heartbeat:Wait()
		end
	end
end

------------------------------------------------
-- CHROLLOSTOP ACTION
------------------------------------------------

local function startChrolloFollow()
	if chrolloBusy then return end

	chrolloBusy = true
	chrolloToken += 1

	local token = chrolloToken

	task.delay(CHROLLO_START_DELAY, function()
		if not running then
			chrolloBusy = false
			return
		end

		if token ~= chrolloToken then
			chrolloBusy = false
			return
		end

		if not hasInCharacter("ChrolloStop") then
			chrolloBusy = false
			return
		end

		local target = getNearestTarget(CHROLLO_RANGE)

		if not target then
			chrolloBusy = false
			return
		end

		lift()
		smoothFollowAboveTarget(target)

		chrolloBusy = false
	end)
end

------------------------------------------------
-- BLUEBUFF Q + TELEPORT BEHIND + CLICK
------------------------------------------------

local function teleportBehindNearest()
	local char = getCharacter()
	if not char then return false end

	local myRoot = getRoot(char)
	if not myRoot then return false end

	local target = getNearestTarget(BLUE_RANGE)
	if not target then return false end

	local targetRoot = getRoot(target)
	if not targetRoot then return false end

	local behind = targetRoot.CFrame * CFrame.new(0, 0, BLUE_BACK_DISTANCE)
	local goal = CFrame.new(behind.Position, targetRoot.Position)

	myRoot.CFrame = goal
	char:PivotTo(goal)

	myRoot.AssemblyLinearVelocity = Vector3.zero
	myRoot.AssemblyAngularVelocity = Vector3.zero

	return true
end

local function useBlueBuff()
	if not hasInCharacter("BlueBuff") then return end

	pressKey(Enum.KeyCode.Q)
	task.wait(0.05)

	local teleported = teleportBehindNearest()

	if teleported then
		leftClick(0.05)
	end
end

------------------------------------------------
-- PUBLIC API
------------------------------------------------

function m.Start()
	if running then return end
	running = true

	inputConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if not running then return end
		if gameProcessed then return end

		if input.KeyCode == Enum.KeyCode.Two then
			startChrolloFollow()
		end

		if input.KeyCode == Enum.KeyCode.Z then
			useBlueBuff()
		end
	end)
end

function m.Stop()
	running = false
	chrolloBusy = false
	chrolloToken += 1

	if inputConnection then
		inputConnection:Disconnect()
		inputConnection = nil
	end
end

return m
