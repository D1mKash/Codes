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
local CHROLLO_LOCK_START_RANGE = 4
local CHROLLO_HEIGHT = 5
local CHROLLO_BACK_DISTANCE = 0
local CHROLLO_STEP_SIZE = 0.08
local CHROLLO_STEP_INTERVAL = 0.01
local CHROLLO_STOP_AFTER_GONE = 0.3

local BLUE_BACK_DISTANCE = 3
local BLUE_RANGE = 7

------------------------------------------------
-- Infinity Landed variables
------------------------------------------------

local infinityScanToken = 0
local infinitySequenceRunning = false

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

local function holdKeyDown(key)
	pcall(function()
		VIM:SendKeyEvent(true, key, false, game)
	end)
end

local function holdKeyUp(key)
	pcall(function()
		VIM:SendKeyEvent(false, key, false, game)
	end)
end

local function holdMouseDown()
	pcall(function()
		VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
	end)
end

local function holdMouseUp()
	pcall(function()
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
	if look.Magnitude < 0.05 then look = Vector3.new(0, 0, -1) end
	look = look.Unit
	return CFrame.new(position, position + look)
end

local function getChrolloLockPosition(targetRoot)
	return (targetRoot.CFrame * CFrame.new(0, CHROLLO_HEIGHT, CHROLLO_BACK_DISTANCE)).Position
end

------------------------------------------------
-- TARGET CHECK
------------------------------------------------

local function isValidTarget(model)
	if not model or not model:IsA("Model") then return false end
	local myChar = getCharacter()
	if model == myChar or model.Name == player.Name then return false end
	local targetPlayer = Players:FindFirstChild(model.Name)
	if targetPlayer then
		if targetPlayer == player then return false end
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
		if not char or not myRoot or not targetRoot then return end
		if hasInCharacter("ChrolloStop") then
			lastSawChrolloStop = os.clock()
		else
			if os.clock() - lastSawChrolloStop >= CHROLLO_STOP_AFTER_GONE then return end
		end
		local targetPosition = targetRoot.Position
		local desiredPosition = getChrolloLockPosition(targetRoot)
		if not lockedOnHead then
			local horizontalDist = horizontalDistance(myRoot.Position, targetPosition)
			if horizontalDist <= CHROLLO_LOCK_START_RANGE then
				if os.clock() - lastStepTime >= CHROLLO_STEP_INTERVAL then
					lastStepTime = os.clock()
					local difference = desiredPosition - myRoot.Position
					if difference.Magnitude <= CHROLLO_STEP_SIZE then
						lockedOnHead = true
						myRoot.CFrame = safeFacingCFrame(desiredPosition, targetRoot)
					else
						local newPosition = myRoot.Position + difference.Unit * CHROLLO_STEP_SIZE
						myRoot.CFrame = safeFacingCFrame(newPosition, targetRoot)
					end
					myRoot.AssemblyLinearVelocity = Vector3.zero
					myRoot.AssemblyAngularVelocity = Vector3.zero
				end
			end
			task.wait()
		else
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
		if not running then chrolloBusy = false return end
		if token ~= chrolloToken then chrolloBusy = false return end
		if not hasInCharacter("ChrolloStop") then chrolloBusy = false return end
		local target = getNearestTarget(CHROLLO_RANGE)
		if not target then chrolloBusy = false return end
		lift()
		smoothFollowAboveTarget(target)
		chrolloBusy = false
	end)
end

------------------------------------------------
-- BLUEBUFF – SIMPLE HOLD FOR 0.05 SECONDS
------------------------------------------------

local function teleportBehindNearest()
	local char = getCharacter()
	if not char then return false, nil end
	local myRoot = getRoot(char)
	if not myRoot then return false, nil end
	local target = getNearestTarget(BLUE_RANGE)
	if not target then return false, nil end
	local targetRoot = getRoot(target)
	if not targetRoot then return false, nil end
	local behind = targetRoot.CFrame * CFrame.new(0, 0, BLUE_BACK_DISTANCE)
	local goal = CFrame.new(behind.Position, targetRoot.Position)
	myRoot.CFrame = goal
	char:PivotTo(goal)
	myRoot.AssemblyLinearVelocity = Vector3.zero
	myRoot.AssemblyAngularVelocity = Vector3.zero
	return true, targetRoot
end

local function turnCameraToTargetDirection(targetRoot)
	local cam = workspace.CurrentCamera
	if not cam then return end
	local currentPos = cam.CFrame.Position
	local lookVector = targetRoot.CFrame.LookVector
	if lookVector.Magnitude < 0.001 then lookVector = Vector3.new(0, 0, -1) end
	local targetLookAt = currentPos + lookVector.Unit
	cam.CFrame = CFrame.lookAt(currentPos, targetLookAt)
end

local function disableJumping(humanoid)
	if not humanoid then return end
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid.JumpPower = 0
		humanoid.UseJumpPower = false
	end)
end

local function restoreJumping(humanoid, oldJumpPower, oldUseJumpPower)
	if not humanoid then return end
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid.JumpPower = oldJumpPower
		humanoid.UseJumpPower = oldUseJumpPower
	end)
end

-- Simple hold: press down, wait 0.05s, release
local function holdSpaceAndClickBriefly()
	holdKeyDown(Enum.KeyCode.Space)
	holdMouseDown()
	task.wait(0.05)          -- hold for 0.05 seconds
	holdMouseUp()
	holdKeyUp(Enum.KeyCode.Space)
end

local function doBlueBuffCombo()
	-- Ensure BlueBuff is active
	if not hasInCharacter("BlueBuff") then
		pressKey(Enum.KeyCode.Three)
		task.wait(0.1)
		if not hasInCharacter("BlueBuff") then return end
	end

	pressKey(Enum.KeyCode.Q)
	task.wait(0.05)

	local teleported, targetRoot = teleportBehindNearest()

	if teleported and targetRoot then
		turnCameraToTargetDirection(targetRoot)

		-- Disable jumping, hold Space+click briefly, restore jumping
		local char = getCharacter()
		local humanoid = char and char:FindFirstChildOfClass("Humanoid")
		local oldJumpPower = humanoid and humanoid.JumpPower or 0
		local oldUseJumpPower = humanoid and humanoid.UseJumpPower or false

		if humanoid then
			disableJumping(humanoid)
		end

		holdSpaceAndClickBriefly()
		task.wait(0.25)
		pressKey(Enum.KeyCode.Three)

		if humanoid then
			restoreJumping(humanoid, oldJumpPower, oldUseJumpPower)
		end
	end
end

------------------------------------------------
-- INFINITY LANDED SCAN AND SEQUENCE (UPDATED)
------------------------------------------------

local function startInfinityScan()
	-- Ignore if a sequence is already running
	if infinitySequenceRunning then return end

	-- Increment token to cancel any previous scan
	infinityScanToken += 1
	local myToken = infinityScanToken

	task.spawn(function()
		local startTime = os.clock()
		-- Scan for up to 2 seconds
		while os.clock() - startTime < 2 do
			-- If token changed, this scan is obsolete
			if infinityScanToken ~= myToken then
				return
			end

			-- Check if "INFINITYLANDED" exists in character
			if hasInCharacter("INFINITYLANDED") then
				-- Found – start the sequence
				infinitySequenceRunning = true

				-- Store original gravity to restore later
				local originalGravity = workspace.Gravity

				-- Use pcall to ensure gravity is restored even if error occurs
				local success, err = pcall(function()
					-- Sequence with updated delays and gravity manipulation
					task.wait(0.15)                   -- initial delay (changed from 0.3)
					pressKey(Enum.KeyCode.Space)     -- first Space
					task.wait(0.07)
					pressKey(Enum.KeyCode.Two)       -- 2
					task.wait(1)
					pressKey(Enum.KeyCode.One)       -- 1
					task.wait(1.7)                   -- changed from 1.0 to 1.7

					-- Lowers gravity
					workspace.Gravity = 40

					-- Apply upward velocity to simulate jump (now gravity is off)
					local char = getCharacter()
					if char then
						local root = getRoot(char)
						if root then
							root.AssemblyLinearVelocity = Vector3.new(0, 20, 0)
						end
					end

					pressKey(Enum.KeyCode.Space)     -- second Space (while gravity is off)
					task.wait(0.2)
					pressKey(Enum.KeyCode.Three)     -- 3
				end)

				-- Restore gravity regardless of success/failure
				workspace.Gravity = originalGravity

				-- If an error occurred, you could optionally print it
				if not success then
					warn("Infinity sequence error: " .. tostring(err))
				end

				-- Mark sequence as finished
				infinitySequenceRunning = false
				return
			end

			task.wait(0.1) -- check every 0.1 seconds
		end
		-- Timeout: do nothing
	end)
end

------------------------------------------------
-- INPUT HANDLER
------------------------------------------------

local function onInputBegan(input, gameProcessed)
	if not running then return end
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Two then
		startChrolloFollow()
	end

	if input.KeyCode == Enum.KeyCode.Z then
		doBlueBuffCombo()
	end

	if input.KeyCode == Enum.KeyCode.Four then
		startInfinityScan()
	end
end

------------------------------------------------
-- PUBLIC API
------------------------------------------------

function m.Start()
	if running then return end
	running = true
	inputConnection = UserInputService.InputBegan:Connect(onInputBegan)
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
