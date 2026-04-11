local GrabBallModule = {}

local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

local thrownFolder = workspace:WaitForChild("Thrown")
local liveFolder = workspace:WaitForChild("Live")

local enabled = false
local connection

-- Click spam (reliable)
local function leftClick()
    for i = 1, 3 do
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end
end

local function pressG()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.G, false, game)
    task.wait()
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.G, false, game)
end

-- Get player from character
local function getPlayerFromCharacter(model)
    return Players:GetPlayerFromCharacter(model)
end

-- Handle GrabBall touches
local function trackGrabBall(grabBall)
    if not grabBall then return end

    local myCharacter = player.Character

    local touchConnection
    touchConnection = grabBall.Touched:Connect(function(hit)
        if not enabled then return end

        local model = hit:FindFirstAncestorOfClass("Model")
        if not model then return end

        -- must be inside Live folder
        if model.Parent ~= liveFolder then return end

        -- skip yourself
        if model == myCharacter then return end

        local targetPlayer = getPlayerFromCharacter(model)

        -- skip teammates
        if targetPlayer and targetPlayer.Team == player.Team then return end

        -- VALID TARGET → CLICK
        leftClick()
    end)

    -- auto cleanup after short time
    task.delay(2, function()
        if touchConnection then
            touchConnection:Disconnect()
        end
    end)
end

-- Key detection
local function onInput(input, gameProcessed)
    if gameProcessed or not enabled then return end

    -- Press 3 → track GrabBall
    if input.KeyCode == Enum.KeyCode.Three then
        local grabBall = thrownFolder:WaitForChild("GrabBall", 1)

        if grabBall then
            trackGrabBall(grabBall)
        end
    end

    -- Press 2 → press G after 0.01s
    if input.KeyCode == Enum.KeyCode.Two then
        task.delay(0.05, function()
            if enabled then
                pressG()
            end
        end)
    end
end

-- Enable / Disable
function GrabBallModule:Enable()
    if enabled then return end
    enabled = true
    connection = UserInputService.InputBegan:Connect(onInput)
end

function GrabBallModule:Disable()
    enabled = false

    if connection then
        connection:Disconnect()
        connection = nil
    end
end

-- For your toggle
function GrabBallModule.Start()
    GrabBallModule:Enable()
end

function GrabBallModule.Stop()
    GrabBallModule:Disable()
end

return GrabBallModule
