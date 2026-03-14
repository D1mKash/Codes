-- Module: AutoBackHit
local module = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

local connection
local addedConnection

local targets = {}

-- Config
local LIVE_FOLDER = workspace:WaitForChild("Live")
local MIN_DISTANCE = 2
local MAX_DISTANCE = 10
local COOLDOWN = 3

local lastClick = 0

------------------------------------------------
-- CLICK
------------------------------------------------

local function clickLeft()
    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
end

------------------------------------------------
-- ADD TARGET
------------------------------------------------

local function addTarget(obj, teammate)

    local root = obj:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if obj == player.Character then return end
    if teammate and obj == teammate then return end

    table.insert(targets, root)
end

------------------------------------------------
-- START
------------------------------------------------

function module.Start(teammate)

    targets = {}

    for _,obj in ipairs(LIVE_FOLDER:GetChildren()) do
        addTarget(obj, teammate)
    end

    addedConnection = LIVE_FOLDER.ChildAdded:Connect(function(obj)
        task.wait()
        addTarget(obj, teammate)
    end)

    connection = RunService.RenderStepped:Connect(function()

        local char = player.Character
        if not char then return end

        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        if tick() - lastClick < COOLDOWN then
            return
        end

        for _,enemyRoot in ipairs(targets) do

            if enemyRoot and enemyRoot.Parent then

                local relative = enemyRoot.CFrame:PointToObjectSpace(root.Position)
                local distance = (enemyRoot.Position - root.Position).Magnitude

                local behind = relative.Z > 2

                if behind and distance >= MIN_DISTANCE and distance <= MAX_DISTANCE then
                    clickLeft()
                    lastClick = tick()
                    break
                end

            end
        end

    end)

end

------------------------------------------------
-- STOP
------------------------------------------------

function module.Stop()

    if connection then
        connection:Disconnect()
        connection = nil
    end

    if addedConnection then
        addedConnection:Disconnect()
        addedConnection = nil
    end

    targets = {}

end

return module
