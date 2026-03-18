local module = {}

-- SERVICES
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local VIM = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local THROWN = Workspace:WaitForChild("Thrown")

local inputConnection
local lockConnection
local lockedPart = nil

------------------------------------------------
-- INPUT HELPERS
------------------------------------------------

local function click()
	VIM:SendMouseButtonEvent(0,0,0,true,game,0)
	VIM:SendMouseButtonEvent(0,0,0,false,game,0)
end

------------------------------------------------
-- TOOL CHECK
------------------------------------------------

local function hasValidTools()

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then return false end

	local rubble = backpack:FindFirstChild("Rubble Smash")
	local boogie = backpack:FindFirstChild("Boogie Woogie")

	if not rubble or not boogie then
		return false
	end

	local rCD = rubble:GetAttribute("COOLDOWN")
	local bCD = boogie:GetAttribute("COOLDOWN")

	if (rCD == nil or rCD == 0) and (bCD == nil or bCD == 0) then
		return true
	end

	return false
end

------------------------------------------------
-- FIND ROCK
------------------------------------------------

local function getRock()

	for _,model in pairs(THROWN:GetChildren()) do
		if model.Name == "BigRock" then

			local main = model:FindFirstChild("Main")

			if main and main:IsA("BasePart") and main.Transparency ~= 1 then
				return main
			end

		end
	end

	return nil
end

------------------------------------------------
-- LOCK SYSTEM
------------------------------------------------

local function startLock(part)

	if lockConnection then
		lockConnection:Disconnect()
	end

	lockedPart = part

	lockConnection = RunService.RenderStepped:Connect(function()

		if lockedPart and lockedPart.Parent then
			Camera.CFrame = CFrame.new(Camera.CFrame.Position, lockedPart.Position)
		end

	end)

end

local function stopLock()

	if lockConnection then
		lockConnection:Disconnect()
		lockConnection = nil
	end

	lockedPart = nil

end

------------------------------------------------
-- DAMAGE CHECK
------------------------------------------------

local function waitForDamage()

	local stats = player:FindFirstChild("Stats")
	if not stats then return false end

	local damage = stats:FindFirstChild("Damage")
	if not damage then return false end

	local startValue = damage.Value
	local startTime = tick()

	repeat
		local diff = damage.Value - startValue

		if diff == 5 or diff == 20 then
			return true
		end

		task.wait()

	until tick() - startTime > 2

	return false
end

------------------------------------------------
-- MAIN LOGIC
------------------------------------------------

local function run()

	if not hasValidTools() then
		return
	end

	local rock = getRock()
	if not rock then return end

	startLock(rock)

	-- wait for damage spike
	if waitForDamage() then
		click()
	end

	stopLock()

end

------------------------------------------------
-- START / STOP
------------------------------------------------

function module.Start()

	if inputConnection then
		inputConnection:Disconnect()
	end

	inputConnection = UIS.InputBegan:Connect(function(input,gpe)

		if gpe then return end

		if input.KeyCode == Enum.KeyCode.Two then
			run()
		end

	end)

end

function module.Stop()

	if inputConnection then
		inputConnection:Disconnect()
		inputConnection = nil
	end

	stopLock()

end

return module
