-- Presses 2 when your stand plays the chosen animation.
local module = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

------------------------------------------------
-- CONFIG
------------------------------------------------
local TRIGGER_ANIMS = {
	["1461157246"] = true,   -- stand animation -> press 2
}

local KEY = Enum.KeyCode.Two
local STAND_FOLDER = "Stands"
local COOLDOWN = 0.2   -- ignore repeat events from the same attack
local RESCAN = 1       -- re-check for new stand animators this often

------------------------------------------------
-- STATE
------------------------------------------------
local running = false
local hooked = {}
local connections = {}
local lastPress = nil

local function findStand()
	local folder = Workspace:FindFirstChild(STAND_FOLDER)
	if not folder then return nil end

	local stand = folder:FindFirstChild(player.Name)
	if stand then return stand end

	local char = player.Character
	if char then
		return folder:FindFirstChild(char.Name)
	end
	return nil
end

------------------------------------------------
-- PRESS
------------------------------------------------
local function press()
	local timestamp = os.clock()
	if lastPress and (timestamp - lastPress) < COOLDOWN then return end
	lastPress = timestamp

	local ok = pcall(function()
		VirtualInputManager:SendKeyEvent(true, KEY, false, game)
		task.wait(0.01)
		VirtualInputManager:SendKeyEvent(false, KEY, false, game)
	end)

	if ok then
		print("[sh] pressed " .. KEY.Name)
	elseif type(keypress) == "function" then
		pcall(keypress, KEY.Name)
		print("[sh] pressed " .. KEY.Name .. " via keypress")
	else
		print("[sh] press failed")
	end
end

------------------------------------------------
-- ANIMATIONS
------------------------------------------------
local function onAnim(track)
	if not running then return end
	if not track or not track.Animation then return end

	local id = string.match(track.Animation.AnimationId or "", "(%d+)$")
	if not id or not TRIGGER_ANIMS[id] then return end

	press()
end

local function hookAnimator(animator)
	if hooked[animator] then return end

	local ok, conn = pcall(function()
		return animator.AnimationPlayed:Connect(onAnim)
	end)

	if ok and conn then
		hooked[animator] = true
		table.insert(connections, conn)
		print("[sh] hooked " .. animator:GetFullName())
	end
end

local function scan()
	local stand = findStand()
	if not stand then return end

	for _, thing in ipairs(stand:GetDescendants()) do
		if thing:IsA("Animator") then
			hookAnimator(thing)
		elseif thing:IsA("AnimationController") and not thing:FindFirstChildOfClass("Animator") then
			hookAnimator(thing)
		end
	end
end

------------------------------------------------
-- START / STOP
------------------------------------------------
function module.Start()
	if running then return end
	running = true

	scan()

	if not findStand() then
		print("[sh] stand not found yet, waiting...")
	end

	table.insert(connections, player.CharacterAdded:Connect(function()
		task.wait(0.5)
		if running then scan() end
	end))

	task.spawn(function()
		while running do
			task.wait(RESCAN)
			scan()
		end
	end)
end

function module.Stop()
	running = false

	for _, conn in ipairs(connections) do
		pcall(function() conn:Disconnect() end)
	end
	connections = {}
	hooked = {}
	lastPress = nil
end

function module.Press()
	press()
end

module.Start()

return module
