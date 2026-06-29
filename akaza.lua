local m = {}

local P = game:GetService("Players")
local R = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local VIM = game:GetService("VirtualInputManager")

local p = P.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

local h
local c
local characterConnection

local running = false

-- animation IDs
local ANIM_WAIT = "rbxassetid://1461136875"
local ANIM_COMBO = "rbxassetid://109159204999611"

-- waiting state
local waitingForCombo = false
local waitTimer = nil

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
end

------------------------------------------------
-- STATE CHECKS
------------------------------------------------

local function isFreefall()
	return h and h:GetState() == Enum.HumanoidStateType.Freefall
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

	if closest and dist <= 7 then
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
	local totalDuration = 1.06

	while running and os.clock() - start < totalDuration do
		if not myRoot or not myRoot.Parent then return end
		if not targetRoot or not targetRoot.Parent then return end

		local pos = targetRoot.Position + Vector3.new(0, 4, 0)

		local look = targetRoot.Position - myRoot.Position
		look = Vector3.new(look.X, 0, look.Z)

		local goal = CFrame.new(pos, pos + look)

		myRoot.CFrame = myRoot.CFrame:Lerp(goal, 0.175)

		R.Heartbeat:Wait()
	end
end

------------------------------------------------
-- ANIMATION HANDLER
------------------------------------------------

local function onAnimationPlayed(track)
	if not running then return end
	if isFreefall() then return end
	if not track.Animation then return end

	local id = track.Animation.AnimationId
	if not id then return end

	-- === Wait for the first animation (1461127258) ===
	if id == ANIM_WAIT then
		-- If we were already waiting, cancel the old timer
		if waitTimer then
			task.cancel(waitTimer)
			waitTimer = nil
		end
		waitingForCombo = true

		-- Set a 2-second timeout
		waitTimer = task.delay(2, function()
			waitingForCombo = false
			waitTimer = nil
		end)
	end

	-- === If we are waiting and the combo animation plays, trigger the follow ===
	if waitingForCombo and id == ANIM_COMBO then
		-- Cancel the timer (we got the combo animation)
		if waitTimer then
			task.cancel(waitTimer)
			waitTimer = nil
		end
		waitingForCombo = false

		-- ============================================================
		-- REMOVED the 0.2-second delay – follow starts immediately
		-- ============================================================
		local target = getNearestInRange()
		if target then
			smoothFollow(target)
		end

		-- Press Q after 0.08 seconds (unchanged)
		task.delay(0.08, function()
			if running then
				comboAction()
			end
		end)
	end
end

------------------------------------------------
-- CHARACTER HOOK
------------------------------------------------

local function hk(char)
	if c then
		c:Disconnect()
		c = nil
	end

	h = char:WaitForChild("Humanoid")

	-- Connect to the Animator on the Humanoid (or fallback to Animator inside)
	local animator = h:FindFirstChildOfClass("Animator")
	if not animator then
		animator = h:WaitForChild("Animator", 5)
	end

	if animator then
		c = animator.AnimationPlayed:Connect(onAnimationPlayed)
	end
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
end

function m.Stop()
	running = false

	if c then
		c:Disconnect()
		c = nil
	end

	if characterConnection then
		characterConnection:Disconnect()
		characterConnection = nil
	end

	-- clean up waiting state
	waitingForCombo = false
	if waitTimer then
		task.cancel(waitTimer)
		waitTimer = nil
	end

	h = nil
end

return m
