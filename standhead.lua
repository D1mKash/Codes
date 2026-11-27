-- Damage -> 0.7s animation check -> press 2 + sit on the target's head for 1s.
local module = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

------------------------------------------------
-- CONFIG
------------------------------------------------
local TRIGGER_ANIMS = {
	["1461157246"] = true,
}

local KEY = Enum.KeyCode.Two
local STAND_FOLDER = "Stands"

local REQUIRE_DAMAGE = true    -- false = press on the animation alone
local DAMAGE_WINDOW = 0.7      -- animation counts this long after a hit
local DAMAGE_GRACE = 0.15      -- animation before the hit still counts within this

local FOLLOW = true            -- sit on the target's head
local FOLLOW_DURATION = 1.0
local FOLLOW_OFFSET = Vector3.new(0, 4, 0)
local FOLLOW_ALPHA = 0.175
local TARGET_RANGE = 6

local COOLDOWN = 0.2           -- ignore repeat events from the same attack
local RESCAN = 1               -- re-check for new stand animators this often

------------------------------------------------
-- STATE
------------------------------------------------
local running = false
local hooked = {}
local connections = {}
local lastPress = nil
local followToken = 0

local lastDamageAt = nil
local damageSeen = false

------------------------------------------------
-- STAND
------------------------------------------------
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
-- FOLLOW
------------------------------------------------
local function getRoot(model)
	if not model then return nil end
	return model:FindFirstChild("HumanoidRootPart")
end

local function isAlive(model)
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if not hum then return false end
	return hum.Health > 0
end

local function getNearestTarget()
	local char = player.Character
	local myRoot = getRoot(char)
	if not myRoot then return nil end

	local live = Workspace:FindFirstChild("Live")
	if not live then return nil end

	local team = player.Team
	local closest, best = nil, math.huge

	for _, model in ipairs(live:GetChildren()) do
		if model ~= char and isAlive(model) then
			local root = getRoot(model)
			if root then
				local owner = Players:GetPlayerFromCharacter(model)
				local sameTeam = team ~= nil and owner ~= nil and owner.Team == team

				if not sameTeam then
					local dist = (root.Position - myRoot.Position).Magnitude
					if dist <= TARGET_RANGE and dist < best then
						best = dist
						closest = model
					end
				end
			end
		end
	end

	return closest
end

local function smoothFollow(targetModel, token)
	local char = player.Character
	if not char then return end

	local myRoot = getRoot(char)
	local targetRoot = getRoot(targetModel)
	if not myRoot or not targetRoot then return end

	local start = os.clock()

	while running and token == followToken and (os.clock() - start) < FOLLOW_DURATION do
		if not myRoot.Parent or not targetRoot.Parent then return end
		if not isAlive(targetModel) then return end

		local pos = targetRoot.Position + FOLLOW_OFFSET
		local look = targetRoot.Position - myRoot.Position
		look = Vector3.new(look.X, 0, look.Z)
		if look.Magnitude < 0.001 then
			look = Vector3.new(0, 0, 1)
		end

		myRoot.CFrame = myRoot.CFrame:Lerp(CFrame.new(pos, pos + look), FOLLOW_ALPHA)

		RunService.Heartbeat:Wait()
	end
end

local function startFollow()
	followToken = followToken + 1
	local token = followToken

	task.spawn(function()
		local target = getNearestTarget()
		if not target then
			print("[sh] no target in range, press only")
			return
		end

		print("[sh] following " .. target.Name .. " for " .. FOLLOW_DURATION .. "s")
		smoothFollow(target, token)
	end)
end

------------------------------------------------
-- DAMAGE
------------------------------------------------
local function onDamage(description)
	lastDamageAt = os.clock()

	if not damageSeen then
		damageSeen = true
	end

	print(string.format("[sh] %s -> window open for %.1fs", description, DAMAGE_WINDOW))
end

local function watchValue(value)
	local previous = value.Value

	table.insert(connections, value.Changed:Connect(function(newValue)
		if not running then return end

		local delta = newValue - previous
		previous = newValue

		if math.abs(delta) < 0.5 then return end
		onDamage(string.format("damage %+g", delta))
	end))

	print("[sh] damage source: " .. value:GetFullName())
end

local damageMode = nil   -- "value" or "health"
local healthConnection = nil

local function watchHealth(hum)
	if healthConnection then
		pcall(function() healthConnection:Disconnect() end)
		healthConnection = nil
	end

	local previous = hum.Health

	healthConnection = hum.HealthChanged:Connect(function(newHealth)
		if not running then return end

		local delta = previous - newHealth
		previous = newHealth

		if delta <= 0 then return end
		onDamage(string.format("health -%g", delta))
	end)

	print("[sh] damage source: Humanoid.Health")
end

local function findDamageValue()
	local stats = player:FindFirstChild("Stats")
	if stats then
		local value = stats:FindFirstChild("Damage")
		if value and value:IsA("NumberValue") then return value end
	end

	local direct = player:FindFirstChild("Damage")
	if direct and direct:IsA("NumberValue") then return direct end

	return nil
end

local function setupDamage()
	if damageMode then return true end

	local value = findDamageValue()
	if value then
		damageMode = "value"
		watchValue(value)
		return true
	end

	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		damageMode = "health"
		watchHealth(hum)
		return true
	end

	return false
end

------------------------------------------------
-- ANIMATIONS
------------------------------------------------
local function shouldFire()
	if not REQUIRE_DAMAGE then return true end

	-- no readable damage source: never block the press
	if not damageSeen or not lastDamageAt then return true end

	return (os.clock() - lastDamageAt) <= DAMAGE_WINDOW
end

local function fire(id)
	local timestamp = os.clock()
	if lastPress and (timestamp - lastPress) < COOLDOWN then return end

	print("[sh] " .. id .. " -> press " .. KEY.Name .. " + follow")
	press()

	if FOLLOW then
		startFollow()
	end
end

local function onAnim(track)
	if not running then return end
	if not track or not track.Animation then return end

	local id = string.match(track.Animation.AnimationId or "", "(%d+)$")
	if not id or not TRIGGER_ANIMS[id] then return end

	if shouldFire() then
		fire(id)
		return
	end

	-- the animation often lands a frame before the damage stat updates
	task.delay(DAMAGE_GRACE, function()
		if not running then return end

		if shouldFire() then
			fire(id)
		else
			print("[sh] " .. id .. " ignored (no damage)")
		end
	end)
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
	setupDamage()

	if not findStand() then
		print("[sh] stand not found yet, waiting...")
	end

	table.insert(connections, player.CharacterAdded:Connect(function(newChar)
		task.wait(0.5)
		if not running then return end

		scan()

		if damageMode == "health" then
			local hum = newChar:FindFirstChildOfClass("Humanoid")
			if not hum then
				hum = newChar:WaitForChild("Humanoid", 5)
			end
			if hum then
				watchHealth(hum)
			end
		elseif not damageMode then
			setupDamage()
		end
	end))

	task.spawn(function()
		while running do
			task.wait(RESCAN)
			scan()
			if not damageMode then setupDamage() end
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

	followToken = followToken + 1
	lastPress = nil
	lastDamageAt = nil
	damageSeen = false

	if healthConnection then
		pcall(function() healthConnection:Disconnect() end)
		healthConnection = nil
	end
	damageMode = nil
end

function module.Press()
	press()
end

module.Start()

return module
