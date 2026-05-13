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

local followToken = 0
local following = false
local chrolloBusy = false

------------------------------------------------
-- SETTINGS
------------------------------------------------

local CHROLLO_RANGE = 8
local CHROLLO_MOVE_SPEED = 1 -- studs per second
local CHROLLO_START_DELAY = 1
local CHROLLO_STOP_AFTER_GONE = 1
local CHROLLO_STAND_OFFSET_ABOVE_HEAD = 3

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

local function getHead(model)
	if not model then return nil end
	return model:FindFirstChild("Head", true)
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
	local av = Vector3.new(a.X, 0, a.Z)
	local bv = Vector3.new(b.X, 0, b.Z)
	return (av - bv).Magnitude
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
-- CHROLLOSTOP SLOW HEAD FOLLOW
------------------------------------------------

local function getStandOnHeadPosition(target)
	local head = getHead(target)
	local root = getRoot(target)

	if head then
		return head.Position + Vector3.new(0, CHROLLO_STAND_OFFSET_ABOVE_HEAD, 0)
	end

	if root then
		return root.Position + Vector3.new(0, 6, 0)
	end

	return nil
end

local function startChrolloFollow()
	if chrolloBusy then return end

	chrolloBusy = true
	followToken += 1

	local token = followToken

	task.delay(CHROLLO_START_DELAY, function()
		if not running then
			chrolloBusy = false
			return
		end

		if token ~= followToken then
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

		local target, distance = getNearestTarget(CHROLLO_RANGE)

		if not target or not distance or distance > CHROLLO_RANGE then
			chrolloBusy = false
			return
		end

		local targetRoot = getRoot(target)

		if not targetRoot then
			chrolloBusy = false
			return
		end

		following = true

		local lastSawChrolloStop = os.clock()

		while running and token == followToken and following do
			local dt = RunService.Heartbeat:Wait()

			char = getCharacter()
			myRoot = getRoot(char)
			targetRoot = getRoot(target)

			if not char or not myRoot or not targetRoot then
				break
			end

			-- Stop immediately if target moves out of horizontal range
			if horizontalDistance(targetRoot.Position, myRoot.Position) > CHROLLO_RANGE then
				break
			end

			if hasInCharacter("ChrolloStop") then
				lastSawChrolloStop = os.clock()
			else
				if os.clock() - lastSawChrolloStop >= CHROLLO_STOP_AFTER_GONE then
					break
				end
			end

			local goalPosition = getStandOnHeadPosition(target)
			if not goalPosition then
				break
			end

			local currentPosition = myRoot.Position
			local offset = goalPosition - currentPosition
			local distanceToGoal = offset.Magnitude

			local newPosition

			if distanceToGoal <= 0.03 then
				newPosition = goalPosition
			else
				local step = math.min(CHROLLO_MOVE_SPEED * dt, distanceToGoal)
				newPosition = currentPosition + offset.Unit * step
			end

			local lookAt = Vector3.new(targetRoot.Position.X, newPosition.Y, targetRoot.Position.Z)
			local goalCFrame = CFrame.new(newPosition, lookAt)

			myRoot.CFrame = goalCFrame
			myRoot.AssemblyLinearVelocity = Vector3.zero
			myRoot.AssemblyAngularVelocity = Vector3.zero
		end

		following = false
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
	following = false
	chrolloBusy = false
	followToken += 1

	if inputConnection then
		inputConnection:Disconnect()
		inputConnection = nil
	end
end

return m
