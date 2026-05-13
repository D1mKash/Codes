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
local CHROLLO_RANGE = 8
local CHROLLO_HEIGHT = 5
local CHROLLO_LERP_ALPHA = 0.175
local CHROLLO_STOP_AFTER_GONE = 1
local CHROLLO_START_DELAY = 1

-- Move toward this relative offset first
local CHROLLO_LOCK_START_RANGE = 5
local CHROLLO_TARGET_OFFSET = Vector3.new(0, 5, 0)
local CHROLLO_STEP_SIZE = 0.1
local CHROLLO_STEP_INTERVAL = 0.01
local CHROLLO_STOP_AFTER_GONE = 0.5

local BLUE_BACK_DISTANCE = 2
local BLUE_RANGE = 5
local BLUE_BACK_DISTANCE = 1
local BLUE_RANGE = 8

------------------------------------------------
-- BASIC HELPERS
@@ -64,6 +68,25 @@
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
@@ -148,7 +171,7 @@
end

------------------------------------------------
-- LOCK ABOVE TARGET HEAD
-- STEP TO OFFSET, THEN NORMAL LOCK
------------------------------------------------

local function smoothFollowAboveTarget(targetModel)
@@ -161,6 +184,8 @@
	if not myRoot or not targetRoot then return end

	local lastSawChrolloStop = os.clock()
	local lockedOnHead = false
	local lastStepTime = 0

	while running do
		char = getCharacter()
@@ -179,150 +204,162 @@
			end
		end

		-- Match target X/Z, stay above them on Y
		local targetPos = targetRoot.Position
		local goalPosition = Vector3.new(
			targetPos.X,
			targetPos.Y + CHROLLO_HEIGHT,
			targetPos.Z
		)
		local targetPosition = targetRoot.Position
		local desiredPosition = targetPosition + CHROLLO_TARGET_OFFSET

		-- Face same horizontal direction as the target
		local look = targetRoot.CFrame.LookVector
		look = Vector3.new(look.X, 0, look.Z)
		if not lockedOnHead then
			local horizontalDist = horizontalDistance(myRoot.Position, targetPosition)

		if look.Magnitude < 0.05 then
			look = Vector3.new(0, 0, -1)
		else
			look = look.Unit
		end
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

		local goal = CFrame.new(goalPosition, goalPosition + look)
					myRoot.AssemblyLinearVelocity = Vector3.zero
					myRoot.AssemblyAngularVelocity = Vector3.zero
				end
			end

		myRoot.CFrame = myRoot.CFrame:Lerp(goal, CHROLLO_LERP_ALPHA)
			task.wait()
		else
			-- Once reached, stop slow stepping and lock normally every frame
			myRoot.CFrame = safeFacingCFrame(desiredPosition, targetRoot)

		myRoot.AssemblyLinearVelocity = Vector3.zero
		myRoot.AssemblyAngularVelocity = Vector3.zero
			myRoot.AssemblyLinearVelocity = Vector3.zero
			myRoot.AssemblyAngularVelocity = Vector3.zero

		RunService.Heartbeat:Wait()
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
