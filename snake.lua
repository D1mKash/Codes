local module = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local LIVE_FOLDER = workspace:WaitForChild("Live")

local blockingConnection
local running = false

local blockCooldown = false
local scanTimer = 0

local teammateModel = nil

------------------------------------------------
-- PRESS KEY
------------------------------------------------
local function pressKey(key)
    VirtualInputManager:SendKeyEvent(true, key, false, game)
    VirtualInputManager:SendKeyEvent(false, key, false, game)
end

------------------------------------------------
-- SET TEAMMATE
------------------------------------------------
function module.SetTeammate(input)
    if typeof(input) == "Instance" then
        if input:IsA("Player") then
            teammateModel = input.Character
        else
            teammateModel = input
        end
    else
        teammateModel = nil
    end
end

------------------------------------------------
-- MAIN LOGIC
------------------------------------------------
local function startBlockingCheck()

    blockingConnection = RunService.Heartbeat:Connect(function(dt)

        if not running then return end

        scanTimer += dt
        if scanTimer < 0.1 then return end
        scanTimer = 0

        if blockCooldown then return end

        local char = player.Character
        if not char then return end

        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        ------------------------------------------------
        -- CHECK IF YOU ARE BLOCKING
        ------------------------------------------------

        local myChar = LIVE_FOLDER:FindFirstChild(player.Name)
        local myBlocking = myChar and myChar:FindFirstChild("Blocking", true)

        if myBlocking and myBlocking.Value == true then
            return
        end

        ------------------------------------------------
        -- ENEMY SCAN (FIXED)
        ------------------------------------------------

        for _,obj in ipairs(LIVE_FOLDER:GetChildren()) do

            if not obj:IsA("Model") then continue end

            -- ❌ skip yourself
            if obj.Name == player.Name then continue end

            -- ❌ skip teammate
            if teammateModel and obj == teammateModel then continue end

            local enemyRoot = obj:FindFirstChild("HumanoidRootPart")
            local blocking = obj:FindFirstChild("Blocking", true) -- 🔥 deep search

            if enemyRoot and blocking then

                local distance = (enemyRoot.Position - root.Position).Magnitude

                if distance >= 18 and distance <= 40 then

                    if blocking.Value == false then

                        blockCooldown = true

                        pressKey(Enum.KeyCode.One)

                        task.spawn(function()

                            repeat task.wait()
                            until blocking.Value == true or not obj.Parent

                            task.wait(1)

                            blockCooldown = false

                        end)

                        return
                    end

                end

            end
        end

    end)

end

------------------------------------------------
-- START
------------------------------------------------
function module.Start(teammateInput)

    if running then return end
    running = true

    if teammateInput then
        module.SetTeammate(teammateInput)
    end

    startBlockingCheck()

end

------------------------------------------------
-- STOP
------------------------------------------------
function module.Stop()

    running = false

    if blockingConnection then
        blockingConnection:Disconnect()
        blockingConnection = nil
    end

    blockCooldown = false
    scanTimer = 0
    teammateModel = nil

end

return module
