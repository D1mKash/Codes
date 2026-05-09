local m = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

local running = false
local inputConnection

------------------------------------------------
-- CHECKS
------------------------------------------------

local function hasInBackpack(itemName)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return false end

	return backpack:FindFirstChild(itemName) ~= nil
end

local function hasJumpOk()
	local char = player.Character
	if not char then return false end

	return char:FindFirstChild("JumpOk", true) ~= nil
end

local function getRoot(model)
	if not model then return nil end
	return model:FindFirstChild("HumanoidRootPart", true)
end

local function isValidTarget(model)
	if not model or not model:IsA("Model") then
		return false
	end

	local myChar = player.Character

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

------------------------------------------------
-- INPUT
------------------------------------------------

local function leftClick(duration)
	VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
	task.wait(duration or 0.1)
	VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

------------------------------------------------
-- TARGETING
------------------------------------------------

local function getNearestTarget(maxRange)
	local char = player.Character
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

	return nearest
end

local function teleportBehindNearest(maxRange)
	local char = player.Character
	if not char then return false end

	local myRoot = getRoot(char)
	if not myRoot then return false end

	local target = getNearestTarget(maxRange)
	if not target then return false end

	local targetRoot = getRoot(target)
	if not targetRoot then return false end

	local behind = targetRoot.CFrame * CFrame.new(0, 0, 3)
	local goal = CFrame.new(behind.Position, targetRoot.Position)

	myRoot.CFrame = goal
	char:PivotTo(goal)

	myRoot.AssemblyLinearVelocity = Vector3.zero
	myRoot.AssemblyAngularVelocity = Vector3.zero

	return true
end

------------------------------------------------
-- ACTIONS
------------------------------------------------

local function delayedTeleport(delayTime, maxRange, clickAfterTeleport)
	task.delay(delayTime, function()
		if not running then return end
		if not hasJumpOk() then return end

		local teleported = teleportBehindNearest(maxRange)

		if teleported and clickAfterTeleport then
			task.wait(0.753)
			leftClick(0.03)
		end
	end)
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
			if hasInBackpack("Erasure Ω") then
				delayedTeleport(1.963, 100, true)
			end
		end

		if input.KeyCode == Enum.KeyCode.Three then
			if hasInBackpack("Erasure β") then
				delayedTeleport(0.6, 40, false)
			end
		end
	end)
end

function m.Stop()
	running = false

	if inputConnection then
		inputConnection:Disconnect()
		inputConnection = nil
	end
end

return m
