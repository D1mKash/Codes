local Module = {}

local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local running = false
local animator

-- animations to detect
local ANIMATIONS = {
	"1470495207",
	"1461127258",
}

-- dropdown-controlled key
local selectedKey = Enum.KeyCode.Three

-- prevent duplicate spam
local active = {}

------------------------------------------------
-- SET KEY
------------------------------------------------

function Module.SetKey(key)
	selectedKey = key
end

------------------------------------------------
-- PRESS
------------------------------------------------

local function press(key)
	VIM:SendKeyEvent(true, key, false, game)
	task.wait(0.01)
	VIM:SendKeyEvent(false, key, false, game)
end

------------------------------------------------
-- SCAN (with ground distance check)
------------------------------------------------

local function scan()
	local char = player.Character
	if not char then return end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum then return end

	local rootPart = char:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- ============================================================
	-- NEW: Measure distance to the ground
	-- If we're higher than 15 studs, skip activation.
	-- ============================================================
	local origin = rootPart.Position
	local direction = Vector3.new(0, -1, 0)

	local raycastParams = RaycastParams.new()
	raycastParams.FilterDescendantsInstances = {char}
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

	local result = Workspace:Raycast(origin, direction * 30, raycastParams)
	local groundDistance = result and result.Distance or 30

	-- If the ground is more than 15 studs away, we are too high → skip
	if groundDistance > 10 then
		return
	end

	if not animator then return end

	local current = {}

	for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
		if track and track.Animation then
			local id = track.Animation.AnimationId
			current[id] = true

			for _, animId in ipairs(ANIMATIONS) do
				if string.find(id, animId) then
					if not active[id] then
						active[id] = true
						press(selectedKey)
					end
					break
				end
			end
		end
	end

	-- cleanup ended animations
	for id in pairs(active) do
		if not current[id] then
			active[id] = nil
		end
	end
end

------------------------------------------------
-- LOOP
------------------------------------------------

local function startLoop()
	task.spawn(function()
		while running do
			task.wait(0.05)
			scan()
		end
	end)
end

------------------------------------------------
-- CHARACTER
------------------------------------------------

local function setup(char)
	local hum = char:WaitForChild("Humanoid")
	animator = hum:WaitForChild("Animator")
	table.clear(active)
end

------------------------------------------------
-- START / STOP
------------------------------------------------

function Module.Start()
	if running then return end
	running = true

	if player.Character then
		setup(player.Character)
	end

	player.CharacterAdded:Connect(setup)

	startLoop()
end

function Module.Stop()
	running = false
	animator = nil
	table.clear(active)
end

return Module
