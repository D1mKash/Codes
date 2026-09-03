local m = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

------------------------------------------------
-- SETTINGS
------------------------------------------------
local TRIGGER_KEY = Enum.KeyCode.Four    -- key that starts the Space + click combo
local CLICK_DELAY = 0.03                  -- delay after pressing 4 before holding Left Click
local CLICK_HOLD_TIME = 0.05             -- how long Left Click is held
local SPACE_HOLD_TIME = 0.09              -- how long Space stays held after the click releases

------------------------------------------------
-- STATE
------------------------------------------------
local running = false
local comboActive = false
local connections = {}

local jumpDisabled = false
local jumpHumanoid = nil
local oldJumpPower = 0
local oldUseJumpPower = false

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

-- Left click: prefer executor-native mouse1press/mouse1release so it
-- registers at the cursor. Fall back to VirtualInputManager (cursor-relative).
local function holdMouseDown()
	if type(mouse1press) == "function" then
		pcall(mouse1press)
		return
	end
	pcall(function()
		VIM:SendMouseButtonEvent(0, 0, 0, true, game, 1)
	end)
end

local function holdMouseUp()
	if type(mouse1release) == "function" then
		pcall(mouse1release)
		return
	end
	pcall(function()
		VIM:SendMouseButtonEvent(0, 0, 0, false, game, 1)
	end)
end

------------------------------------------------
-- BACKPACK CHECK
------------------------------------------------
-- These ability names live in the Backpack as Configuration objects, not Tools.
local function getBackpackItem(itemName)
	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return nil end
	return backpack:FindFirstChild(itemName)
end

local function hasInBackpack(itemName)
	return getBackpackItem(itemName) ~= nil
end

------------------------------------------------
-- JUMP CONTROL
------------------------------------------------
local function disableJumping(humanoid)
	if not humanoid then return end
	if jumpDisabled then return end
	jumpDisabled = true
	jumpHumanoid = humanoid
	oldJumpPower = humanoid.JumpPower
	oldUseJumpPower = humanoid.UseJumpPower
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid.JumpPower = 0
		humanoid.UseJumpPower = false
	end)
end

local function restoreJumping()
	if not jumpDisabled then return end
	jumpDisabled = false
	local humanoid = jumpHumanoid
	jumpHumanoid = nil
	if not humanoid then return end
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		humanoid.JumpPower = oldJumpPower
		humanoid.UseJumpPower = oldUseJumpPower
	end)
end

------------------------------------------------
-- 4 COMBO (Space is already held by the input handler)
------------------------------------------------
local function comboSequence()
	if not running then
		holdKeyUp(Enum.KeyCode.Space)
		restoreJumping()
		comboActive = false
		return
	end

	-- Wait 0.7s (Space is held the whole time), then hold Left Click.
	task.wait(CLICK_DELAY)
	if not running then
		holdKeyUp(Enum.KeyCode.Space)
		restoreJumping()
		comboActive = false
		return
	end
	holdMouseDown()

	task.wait(CLICK_HOLD_TIME)
	holdMouseUp()

	task.wait(SPACE_HOLD_TIME)
	holdKeyUp(Enum.KeyCode.Space)
	restoreJumping()
	comboActive = false
end

------------------------------------------------
-- INPUT HANDLER
------------------------------------------------
local function onInputBegan(input)
	if not running then return end
	if input.KeyCode ~= TRIGGER_KEY then return end
	if comboActive then return end

	comboActive = true

	-- Disable jump, then hold Space as soon as jump is disabled.
	local char = player.Character
	disableJumping(char and char:FindFirstChildOfClass("Humanoid"))
	holdKeyDown(Enum.KeyCode.Space)

	task.spawn(comboSequence)
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
		-- Grab is ready (COOLDOWN missing or 20) -> press 1, never press 2.
		local grab = getBackpackItem("Grab")
		if grab then
			local cooldown = grab:GetAttribute("COOLDOWN")
			if cooldown == nil or cooldown == 20 then
				pressKey(Enum.KeyCode.One)
				return
			end
		end
		-- Grab missing or on cooldown -> Fast Flash Attack -> press 2.
		if hasInBackpack("Fast Flash Attack") then
			pressKey(Enum.KeyCode.Two)
		end
	elseif numericId == "1461127258" then
		if hasInBackpack("Final Destruction") then
			pressKey(Enum.KeyCode.Two)
		elseif hasInBackpack("God Big Bang") then
			-- Wait 0.8s, then press 3.
			task.delay(0.6, function()
				if not running then return end
				pressKey(Enum.KeyCode.Three)
			end)
		end
	end
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

	table.insert(connections, UserInputService.InputBegan:Connect(onInputBegan))
end

function m.Stop()
	running = false
	comboActive = false

	for _, conn in ipairs(connections) do
		pcall(function()
			conn:Disconnect()
		end)
	end
	connections = {}

	holdMouseUp()
	holdKeyUp(Enum.KeyCode.Space)
	restoreJumping()
end

return m


