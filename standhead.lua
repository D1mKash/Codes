local module = {}

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

------------------------------------------------
-- CONFIG
------------------------------------------------
local TRIGGER_ANIMS = {
	["1470532199"] = true,
}

local KEY = Enum.KeyCode.Two
local RESCAN = 0.5
local COOLDOWN = 0.2   -- ignore repeat events from the same attack

------------------------------------------------
-- STATE
------------------------------------------------
local running = false
local hooked = {}       -- animator -> true
local connections = {}
local seen = {}         -- animation id -> true
local lastPress = nil
local log = print

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
		log("[sh] pressed " .. KEY.Name)
	elseif type(keypress) == "function" then
		pcall(keypress, KEY.Name)
		log("[sh] pressed " .. KEY.Name .. " via keypress")
	else
		log("[sh] PRESS FAILED")
	end
end

------------------------------------------------
-- ANIMATIONS
------------------------------------------------
local function onAnim(track)
	if not running then return end
	if not track or not track.Animation then return end

	local id = string.match(track.Animation.AnimationId or "", "(%d+)$")
	if not id then return end

	if not seen[id] then
		seen[id] = true
		log("[sh] ANIM " .. id .. (TRIGGER_ANIMS[id] and "  <-- MATCH" or ""))
	end

	if TRIGGER_ANIMS[id] then
		press()
	end
end

local function hookAnimator(animator)
	if hooked[animator] then return end
	hooked[animator] = true

	local ok, conn = pcall(function()
		return animator.AnimationPlayed:Connect(onAnim)
	end)

	if ok and conn then
		table.insert(connections, conn)
		log("[sh] hooked " .. animator:GetFullName())
	end
end

local function hookModel(model)
	if not model then return end

	for _, thing in ipairs(model:GetDescendants()) do
		if thing:IsA("Animator") then
			hookAnimator(thing)
		elseif thing:IsA("AnimationController") and not thing:FindFirstChildOfClass("Animator") then
			hookAnimator(thing)
		end
	end

	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum and not model:FindFirstChildWhichIsA("Animator", true) then
		hookAnimator(hum)
	end
end

------------------------------------------------
-- SOURCES: character, every stand, our Live copy
------------------------------------------------
local function hookEverything()
	if not running then return end

	hookModel(player.Character)

	local stands = workspace:FindFirstChild("Stands")
	if stands then
		hookModel(stands)
	end

	local live = workspace:FindFirstChild("Live")
	local char = player.Character
	if live and char then
		local copy = live:FindFirstChild(char.Name) or live:FindFirstChild(player.Name)
		if copy and copy ~= char then
			hookModel(copy)
		end
	end
end

------------------------------------------------
-- START / STOP
------------------------------------------------
function module.Start()
	if running then return end
	running = true

	log("[sh] started | key " .. KEY.Name .. " | animation 1470532199")

	hookEverything()

	table.insert(connections, player.CharacterAdded:Connect(function()
		task.wait(0.5)
		if running then hookEverything() end
	end))

	task.spawn(function()
		while running do
			task.wait(RESCAN)
			if running then hookEverything() end
		end
	end)
end

function module.Stop()
	running = false

	for _, c in ipairs(connections) do
		pcall(function() c:Disconnect() end)
	end
	connections = {}
	hooked = {}

	log("[sh] stopped")
end

function module.Press()
	press()
end

module.Start()

return module
