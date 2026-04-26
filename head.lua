local m = {}

local P = game:GetService("Players")
local R = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local VIM = game:GetService("VirtualInputManager")

local p = P.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")
local STANDS = Workspace:WaitForChild("Stands")

local h
local c
local characterConnection
local standAddedConnection
local standRemovedConnection

local s = "D"
local v0 = 0
local d
local running = false
local currentAnimModel

------------------------------------------------
-- INPUT COMBO
------------------------------------------------

local function pressKey(key)
	pcall(function()
		VIM:SendKeyEvent(true, key, false, game)
		task.wait(0.01)
		VIM:SendKeyEvent(false, key, false, game)
	end)
end

local function comboAction()
	pressKey(Enum.KeyCode.Q)

	task.wait(0.05)

	pressKey(Enum.KeyCode.Space)

	task.wait(0.05)

	pressKey(Enum.KeyCode.Space)
end

------------------------------------------------
-- STATE CHECKS
------------------------------------------------

local function isFreefall()
	return h and h:GetState() == Enum.HumanoidStateType.Freefall
end

------------------------------------------------
-- STAND / ANIMATION SOURCE SYSTEM
------------------------------------------------

local function getStand(char)
	if not char then return nil end

	return STANDS:FindFirstChild(char.Name) or STANDS:FindFirstChild(p.Name)
end

local function getAnimationSource(model)
	if not model then return nil end

	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		return hum
	end

	local animator = model:FindFirstChildWhichIsA("Animator", true)
	if animator then
		return animator
	end

	local controller = model:FindFirstChildWhichIsA("AnimationController", true)
	if controller then
		return controller:FindFirstChildOfClass("Animator") or controller:WaitForChild("Animator", 5)
	end

	return nil
end

------------------------------------------------
-- FOLLOW / LOCK SYSTEM
------------------------------------------------

local function getRoot(model)
	return model and model:FindFirstChild("HumanoidRootPart")
end

local function getNearestInRange()
	local char = p.Character
	if not char then return end

	local myRoot = getRoot(char)
	if not myRoot then return end

	local closest, dist = nil, math.huge

	for _, model in pairs(LIVE:GetChildren()) do
		if model ~= char then
			local root = getRoot(model)
			if root then
				local d = (root.Position - myRoot.Position).Magnitude
				if d < dist then
					dist = d
					closest = model
				end
			end
		end
	end

	if closest and dist <= 5 then
		return closest
	end
end

local function smoothFollow(targetModel)
	local char = p.Character
	if not char then return end

	local myRoot = getRoot(char)
	local targetRoot = getRoot(targetModel)
	if not myRoot or not targetRoot then return end

	local start = os.clock()

	while running and os.clock() - start < 0.76 do
		if not myRoot or not targetRoot then return end

		local pos = targetRoot.Position + Vector3.new(0, 5, 0)

		local look = targetRoot.Position - myRoot.Position
		look = Vector3.new(look.X, 0, look.Z)

		local goal = CFrame.new(pos, pos + look)

		myRoot.CFrame = myRoot.CFrame:Lerp(goal, 0.15)

		R.Heartbeat:Wait()
	end
end

------------------------------------------------
-- ORIGINAL FUNCTIONS
------------------------------------------------

local function l()
	local char = p.Character
	if not char then return end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	root.AssemblyLinearVelocity = Vector3.new(0, 32, 0)

	local t = os.clock()

	task.spawn(function()
		while running and os.clock() - t < 0.1 do
			if not root or not root.Parent then return end
			root.AssemblyLinearVelocity = Vector3.new(0, 32, 0)
			R.Heartbeat:Wait()
		end
	end)
end

local function reset()
	s = "D"
	if d then
		d:Disconnect()
		d = nil
	end
end

------------------------------------------------
-- DAMAGE DETECTION THREAD
------------------------------------------------

local function ds()
	task.spawn(function()
		while running do
			task.wait(0.1)

			if s ~= "D" then
				continue
			end

			local stats = p:FindFirstChild("Stats")
			local dmg = stats and stats:FindFirstChild("Damage")

			if dmg then
				v0 = dmg.Value

				if d then d:Disconnect() end

				d = dmg.Changed:Connect(function()
					if not running then return end

					local delta = dmg.Value - v0

					if delta >= 4 and delta <= 9 and s == "D" then
						s = "A"

						if d then
							d:Disconnect()
							d = nil
						end
					end
				end)
			end
		end
	end)
end

------------------------------------------------
-- ANIMATION HANDLER
------------------------------------------------

local function onAnimationPlayed(track)
	if not running then return end
	if isFreefall() then return end
	if s ~= "A" then return end
	if not track.Animation then return end

	local id = track.Animation.AnimationId

	if id == "rbxassetid://1461137417" or id == "rbxassetid://1470454728" then

		task.delay(0.2, function()
			local target = getNearestInRange()
			if target then
				smoothFollow(target)
			end
		end)

		l()

		task.delay(0.08, function()
			if running then
				comboAction()
			end
		end)

		reset()
	end
end

------------------------------------------------
-- CHARACTER / STAND HOOK
------------------------------------------------

local function hk(char)
	if c then
		c:Disconnect()
		c = nil
	end

	if standAddedConnection then
		standAddedConnection:Disconnect()
		standAddedConnection = nil
	end

	if standRemovedConnection then
		standRemovedConnection:Disconnect()
		standRemovedConnection = nil
	end

	h = char:WaitForChild("Humanoid")

	local stand = getStand(char)
	local animModel = stand or char
	local animSource = getAnimationSource(animModel)

	-- fallback to character if stand exists but has no animation source
	if not animSource and animModel ~= char then
		animModel = char
		animSource = getAnimationSource(char)
	end

	currentAnimModel = animModel

	if animSource then
		c = animSource.AnimationPlayed:Connect(onAnimationPlayed)
	end

	-- if your Stand spawns after the script starts, switch to tracking it
	standAddedConnection = STANDS.ChildAdded:Connect(function(child)
		if not running then return end
		if not p.Character or p.Character ~= char then return end

		if child.Name == char.Name or child.Name == p.Name then
			task.wait(0.1)
			hk(char)
		end
	end)

	-- if your Stand gets removed, fall back to tracking your character
	standRemovedConnection = STANDS.ChildRemoved:Connect(function(child)
		if not running then return end
		if not p.Character or p.Character ~= char then return end

		if child == currentAnimModel then
			task.wait(0.1)
			hk(char)
		end
	end)
end

------------------------------------------------
-- PUBLIC API
------------------------------------------------

function m.Start()
	if running then return end
	running = true

	if p.Character then
		hk(p.Character)
	end

	characterConnection = p.CharacterAdded:Connect(hk)

	ds()
end

function m.Stop()
	running = false
	s = "D"

	if c then
		c:Disconnect()
		c = nil
	end

	if d then
		d:Disconnect()
		d = nil
	end

	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end

	if standAddedConnection then
		standAddedConnection:Disconnect()
		standAddedConnection = nil
	end

	if standRemovedConnection then
		standRemovedConnection:Disconnect()
		standRemovedConnection = nil
	end

	h = nil
	currentAnimModel = nil
end

return m
