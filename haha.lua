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

-- For BlueBuff hold
local holdActive = false
local holdHumanoid = nil
local holdOldJumpPower = 0
local holdOldUseJumpPower = false

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
local CHROLLO_STOP_AFTER_GONE = 0.4

local BLUE_BACK_DISTANCE = 3
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
-- BLUEBUFF: TELEPORT + HOLD (until you press Space/click)
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

-- Starts holding Space + LMB (single down events, no re-apply)
local function startHold()
	if holdActive then return end
	holdActive = true

	local char = getCharacter()
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		holdActive = false
		return
	end

	holdHumanoid = humanoid
	holdOldJumpPower = humanoid.JumpPower
	holdOldUseJumpPower = humanoid.UseJumpPower

	disableJumping(humanoid)

	holdKeyDown(Enum.KeyCode.Space)
	holdMouseDown()
end

-- Releases keys and restores jumping (called when we detect Space/click up)
local function stopHold()
	if not holdActive then return end
	holdActive = false

	holdMouseUp()
	holdKeyUp(Enum.KeyCode.Space)

	if holdHumanoid and holdHumanoid.Parent then
		restoreJumping(holdHumanoid, holdOldJumpPower, holdOldUseJumpPower)
	end

	holdHumanoid = nil
	holdOldJumpPower = 0
	holdOldUseJumpPower = false
end

-- Main combo: press Z
local function doBlueBuffCombo()
	-- If we are already holding, ignore (or you could restart? But they want to stop with space/click, so we just ignore)
	if holdActive then return end

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
		task.wait(0.25)          -- 0.25s delay before pressing Three
		pressKey(Enum.KeyCode.Three)
		startHold()              -- holds Space + LMB until you manually press them
	end
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
end

-- We also need to detect when Space or LMB are released (to stop hold)
-- We can use InputEnded for that.
local function onInputEnded(input, gameProcessed)
	if not running then return end
	if gameProcessed then return end

	-- If Space or left mouse button is released while we are holding, stop the hold.
	if holdActive then
		if input.KeyCode == Enum.KeyCode.Space or input.UserInputType == Enum.UserInputType.MouseButton1 then
			stopHold()
		end
	end
end

------------------------------------------------
-- PUBLIC API
------------------------------------------------

function m.Start()
	if running then return end
	running = true

	inputConnection = UserInputService.InputBegan:Connect(onInputBegan)
	-- Also connect to InputEnded to detect release of Space/LMB
	UserInputService.InputEnded:Connect(onInputEnded)
end

function m.Stop()
	running = false
	chrolloBusy = false
	chrolloToken += 1

	if holdActive then
		stopHold()
	end

	if inputConnection then
		inputConnection:Disconnect()
		inputConnection = nil
	end
end

return m
