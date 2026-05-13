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
local mouseHeld = false

------------------------------------------------
-- SETTINGS
------------------------------------------------

local CHROLLO_RANGE = 8
local CHROLLO_HEIGHT = 4
local CHROLLO_MOVE_SPEED = 1 -- studs per second
local CHROLLO_START_DELAY = 1
local CHROLLO_STOP_AFTER_GONE = 1

local BLUE_BACK_DISTANCE = 2
local BLUE_RANGE = 20 -- set to nil for unlimited range

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

local function holdLeftClick()
	if mouseHeld then return end
	mouseHeld = true

	pcall(function()
		VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
	end)
end

local function releaseLeftClick()
	if not mouseHeld then return end
	mouseHeld = false

	pcall(function()
		VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
	end)
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
-- CHROLLOSTOP SLOW HEAD POSITION
------------------------------------------------

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
		if not char then
			chrolloBusy = false
			return
		end

		local myRoot = getRoot(char)
		if not myRoot then
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

			-- if target gets out of range, stop immediately
			local currentDistance = (targetRoot.Position - myRoot.Position).Magnitude
			if currentDistance > CHROLLO_RANGE then
				break
			end

			if hasInCharacter("ChrolloStop") then
				lastSawChrolloStop = os.clock()
			else
				if os.clock() - lastSawChrolloStop >= CHROLLO_STOP_AFTER_GONE then
					break
				end
			end

			local goalPosition = targetRoot.Position + Vector3.new(0, CHROLLO_HEIGHT, 0)
			local currentPosition = myRoot.Position
			local direction = goalPosition - currentPosition
			local distanceToGoal = direction.Magnitude

			local newPosition

			if distanceToGoal <= 0.05 then
				newPosition = goalPosition
			else
				local step = math.min(CHROLLO_MOVE_SPEED * dt, distanceToGoal)
				newPosition = currentPosition + direction.Unit * step
			end

			local goalCFrame = CFrame.new(newPosition, targetRoot.Position)

			myRoot.CFrame = goalCFrame
			char:PivotTo(goalCFrame)

			myRoot.AssemblyLinearVelocity = Vector3.zero
			myRoot.AssemblyAngularVelocity = Vector3.zero
		end

		following = false
		chrolloBusy = false
	end)
end

------------------------------------------------
-- BLUEBUFF Q + TELEPORT BEHIND + HOLD CLICK
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
		holdLeftClick()
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

	releaseLeftClick()

	if inputConnection then
		inputConnection:Disconnect()
		inputConnection = nil
	end
end

return m
