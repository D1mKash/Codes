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

local CHROLLO_START_DELAY = 1
local CHROLLO_TARGET_RANGE = 8
local CHROLLO_HEIGHT_START_RADIUS = 3
local CHROLLO_HEIGHT = 5

local CHROLLO_Y_STEP = 0.1
local CHROLLO_Y_INTERVAL = 0.1
local CHROLLO_STOP_AFTER_GONE = 1

local BLUE_BACK_DISTANCE = 2
local BLUE_RANGE = 5

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
	local aFlat = Vector3.new(a.X, 0, a.Z)
	local bFlat = Vector3.new(b.X, 0, b.Z)

	return (aFlat - bFlat).Magnitude
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
-- CHROLLOSTOP HEAD LOCK SYSTEM
------------------------------------------------

local function getAboveHeadPosition(targetModel)
	local targetRoot = getRoot(targetModel)
	if not targetRoot then return nil end

	return targetRoot.Position + Vector3.new(0, CHROLLO_HEIGHT, 0)
end

local function setRootYOnly(root, newY, lookAtPosition)
	local currentPosition = root.Position
	local newPosition = Vector3.new(currentPosition.X, newY, currentPosition.Z)

	local look = Vector3.new(
		lookAtPosition.X,
		newPosition.Y,
		lookAtPosition.Z
	)

	root.CFrame = CFrame.new(newPosition, look)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

local function lockOnTopOfTarget(root, targetRoot)
	local goalPosition = targetRoot.Position + Vector3.new(0, CHROLLO_HEIGHT, 0)

	local look = Vector3.new(
		targetRoot.Position.X,
		goalPosition.Y,
		targetRoot.Position.Z
	)

	root.CFrame = CFrame.new(goalPosition, look)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
end

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

		local char = getCharacter()
		local myRoot = getRoot(char)

		if not char or not myRoot then
			chrolloBusy = false
			return
		end

		local target = getNearestTarget(CHROLLO_TARGET_RANGE)

		if not target then
			chrolloBusy = false
			return
		end

		local targetRoot = getRoot(target)

		if not targetRoot then
			chrolloBusy = false
			return
		end

		local heightReady = false
		local lastSawChrolloStop = os.clock()
		local lastYStep = 0

		while running and token == chrolloToken do
			RunService.Heartbeat:Wait()

			char = getCharacter()
			myRoot = getRoot(char)
			targetRoot = getRoot(target)

			if not char or not myRoot or not targetRoot then
				break
			end

			local distToTarget = (targetRoot.Position - myRoot.Position).Magnitude

			if distToTarget > CHROLLO_TARGET_RANGE + CHROLLO_HEIGHT then
				break
			end

			if hasInCharacter("ChrolloStop") then
				lastSawChrolloStop = os.clock()
			else
				if os.clock() - lastSawChrolloStop >= CHROLLO_STOP_AFTER_GONE then
					break
				end
			end

			local goalPosition = getAboveHeadPosition(target)
			if not goalPosition then
				break
			end

			local horizontalDist = horizontalDistance(myRoot.Position, targetRoot.Position)

			if not heightReady then
				-- Do not touch X/Z until you are close enough horizontally.
				if horizontalDist <= CHROLLO_HEIGHT_START_RADIUS then
					if os.clock() - lastYStep >= CHROLLO_Y_INTERVAL then
						lastYStep = os.clock()

						local currentY = myRoot.Position.Y
						local targetY = goalPosition.Y
						local difference = targetY - currentY

						if math.abs(difference) <= CHROLLO_Y_STEP then
							setRootYOnly(myRoot, targetY, targetRoot.Position)
							heightReady = true
						else
							local direction = difference > 0 and 1 or -1
							local newY = currentY + (CHROLLO_Y_STEP * direction)

							setRootYOnly(myRoot, newY, targetRoot.Position)
						end
					end
				end
			else
				-- Only after Y height is correct, lock X/Z above their head.
				lockOnTopOfTarget(myRoot, targetRoot)
			end
		end

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
