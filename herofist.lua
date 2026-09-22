local m = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

local running = false
local connections = {}

local finalDestructionBusy = false

------------------------------------------------
-- INPUT HELPERS
------------------------------------------------

local function pressKey(key)
	pcall(function()
		VIM:SendKeyEvent(true, key, false, game)
		task.wait(0.01)
		VIM:SendKeyEvent(false, key, false, game)
	end)
end

local function releaseKey(key)
	pcall(function()
		VIM:SendKeyEvent(false, key, false, game)
	end)
end

local function leftClick()
	-- Prefer executor-native mouse events so the click registers at the cursor.
	if type(mouse1press) == "function" and type(mouse1release) == "function" then
		pcall(mouse1press)
		task.wait(0.01)
		pcall(mouse1release)
		return
	end
	pcall(function()
		VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
		task.wait(0.01)
		VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
	end)
end

------------------------------------------------
-- BACKPACK / COOLDOWN
------------------------------------------------

local function getBackpackItem(itemName)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return nil end
	return backpack:FindFirstChild(itemName)
end

-- COOLDOWN: nil or 20 means ready; anything else means on cooldown.
local function isOnCooldown(item)
	if not item then return true end
	local cooldown = item:GetAttribute("COOLDOWN")
	return cooldown ~= nil and cooldown ~= 20
end

------------------------------------------------
-- TARGET CHECK
------------------------------------------------

local function isValidTarget(model)
	if not model or not model:IsA("Model") then return false end

	local myChar = player.Character
	if model == myChar or model.Name == player.Name then return false end

	local targetPlayer = Players:FindFirstChild(model.Name)
	if targetPlayer then
		if targetPlayer == player then return false end
		-- Exclude teammates (if we are on a team).
		if player.Team ~= nil and targetPlayer.Team ~= nil and targetPlayer.Team == player.Team then
			return false
		end
	end

	return true
end

local function isEnemyWithin(distance)
	local char = player.Character
	if not char then return false end

	local myRoot = char:FindFirstChild("HumanoidRootPart")
	if not myRoot then return false end

	for _, model in ipairs(LIVE:GetChildren()) do
		if isValidTarget(model) then
			local root = model:FindFirstChild("HumanoidRootPart")
			if root and (root.Position - myRoot.Position).Magnitude <= distance then
				return true
			end
		end
	end

	return false
end

------------------------------------------------
-- ANIMATION HANDLER
------------------------------------------------

local function onAnimationPlayed(track)
	if not running then return end
	if not track or not track.Animation then return end

	local numericId = string.match(track.Animation.AnimationId, "(%d+)$")
	if not numericId then return end

	if numericId == "1461157246" then
		-- press 1 (no delay)
		pressKey(Enum.KeyCode.One)

	elseif numericId == "1461137417" then
		-- press 3 (no delay)
		pressKey(Enum.KeyCode.Three)

	elseif numericId == "1461127258" then
		-- leftclick -> 4 -> wait 0.9 -> leftclick again
		if finalDestructionBusy then return end
		finalDestructionBusy = true

		task.spawn(function()
			leftClick()
			pressKey(Enum.KeyCode.Four)

			task.wait(1.1)

			if not running then
				finalDestructionBusy = false
				return
			end

			leftClick()
			finalDestructionBusy = false
		end)
	end
end

------------------------------------------------
-- HERO'S FIST MONITOR
------------------------------------------------

local function heroFistLoop()
	task.spawn(function()
		local handledThisHold = false

		while running do
			task.wait(0.01)
			if not running then return end

			local heroFist = getBackpackItem("Hero's Fist")
			if not heroFist then continue end

			-- On cooldown -> do nothing.
			if isOnCooldown(heroFist) then
				continue
			end

			-- Only act while we are holding F.
			local holdingF = UIS:IsKeyDown(Enum.KeyCode.F)
			if not holdingF then
				handledThisHold = false
				continue
			end

			-- Once per F-hold: release F, then press 2 if an enemy is within 18 studs.
			if not handledThisHold and isEnemyWithin(18) then
				handledThisHold = true
				releaseKey(Enum.KeyCode.F)
				task.wait(0.01)
				pressKey(Enum.KeyCode.Two)
			end
		end
	end)
end

------------------------------------------------
-- CHARACTER HOOK
------------------------------------------------

local function hookCharacter(char)
	if not char then return end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = char:WaitForChild("Humanoid", 5)
	end
	if not humanoid then return end

	table.insert(connections, humanoid.AnimationPlayed:Connect(onAnimationPlayed))
end

------------------------------------------------
-- PUBLIC API
------------------------------------------------

function m.Start()
	if running then return end
	running = true

	if player.Character then
		hookCharacter(player.Character)
	end

	table.insert(connections, player.CharacterAdded:Connect(function(char)
		task.wait(0.5)
		hookCharacter(char)
	end))

	heroFistLoop()
end

function m.Stop()
	running = false
	finalDestructionBusy = false

	for _, conn in ipairs(connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	connections = {}
end

return m
