local module = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

local connection

------------------------------------------------
-- INPUT
------------------------------------------------

local function pressKey(key)
    VirtualInputManager:SendKeyEvent(true, key, false, game)
    VirtualInputManager:SendKeyEvent(false, key, false, game)
end

------------------------------------------------
-- GUI CHECK
------------------------------------------------

local function getMoveName()

    local playerGui = player:FindFirstChild("PlayerGui")
    if not playerGui then return nil end

    local guiBox = playerGui:FindFirstChild("GuiBox")
    if not guiBox then return nil end

    local clone = guiBox:FindFirstChild("1Clone")
    if not clone then return nil end

    local label = clone:FindFirstChild("TextLabel")
    if not label then return nil end

    return label.Text
end

------------------------------------------------
-- DISTANCE CHECK
------------------------------------------------

local function enemyInRange()

    local char = player.Character
    if not char then return false end

    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    for _,model in pairs(LIVE:GetChildren()) do
        if model ~= char then
            local enemyRoot = model:FindFirstChild("HumanoidRootPart")
            if enemyRoot then
                local distance = (enemyRoot.Position - root.Position).Magnitude
                if distance <= 7 then
                    return true
                end
            end
        end
    end

    return false
end

------------------------------------------------
-- START
------------------------------------------------

function module.Start()

    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")

    connection = humanoid.AnimationPlayed:Connect(function(track)

        if not track.Animation then return end

        local animId = track.Animation.AnimationId
        local moveName = getMoveName()

        if animId == "rbxassetid://1470532199" then
            if moveName == "True Power" and enemyInRange() then
                pressKey(Enum.KeyCode.One)
            end
        end

        if animId == "rbxassetid://1461157246" then
            if moveName == "Kurohitsugi" then
                pressKey(Enum.KeyCode.One)
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

end

return module
