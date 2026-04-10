local GrabBallModule = {}

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

local thrownFolder = workspace:WaitForChild("Thrown")
local liveFolder = workspace:WaitForChild("Live")

local DETECTION_RADIUS = 10

local enabled = false
local connection

-- Left click
local function leftClick()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    task.wait()
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

-- Check nearby characters
local function checkNearby(grabBall)
    if not grabBall or not grabBall:IsDescendantOf(workspace) then return end

    local ballPos = grabBall:IsA("Model") 
        and grabBall:GetPivot().Position 
        or grabBall.Position

    local character = player.Character

    for _, model in pairs(liveFolder:GetChildren()) do
        if model:IsA("Model") and model ~= character then
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if hrp then
                local distance = (hrp.Position - ballPos).Magnitude
                if distance <= DETECTION_RADIUS then
                    leftClick()
                    return
                end
            end
        end
    end
end

-- Main logic when pressing 3
local function onInput(input, gameProcessed)
    if gameProcessed or not enabled then return end

    if input.KeyCode == Enum.KeyCode.Three then
        local grabBall = thrownFolder:WaitForChild("GrabBall", 1)

        if grabBall then
            local startTime = tick()

            while enabled and grabBall and grabBall.Parent and tick() - startTime < 2 do
                checkNearby(grabBall)
                task.wait(0.01)
            end
        end
    end
end

-- Enable
function GrabBallModule:Enable()
    if enabled then return end
    enabled = true

    connection = UserInputService.InputBegan:Connect(onInput)
end

-- Disable
function GrabBallModule:Disable()
    enabled = false

    if connection then
        connection:Disconnect()
        connection = nil
    end
end

return GrabBallModule
