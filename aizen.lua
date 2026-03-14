local module = {}

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local damageConnection
local animationConnection
local characterConnection
local blockingConnection

local lastDamage = 0
local currentHumanoid

local disable044 = false
local teammate = nil

local LIVE_FOLDER = workspace:WaitForChild("Live")

------------------------------------------------
-- INPUT
------------------------------------------------

local function pressKey(key)
    VirtualInputManager:SendKeyEvent(true,key,false,game)
    VirtualInputManager:SendKeyEvent(false,key,false,game)
end

------------------------------------------------
-- FALL CHECK
------------------------------------------------

local function isFalling()
    if not currentHumanoid then return false end

    local state = currentHumanoid:GetState()
    return state == Enum.HumanoidStateType.Freefall
end

------------------------------------------------
-- DAMAGE WAIT CHECK
------------------------------------------------

local function waitForDamageTrigger()

    local stats = player:FindFirstChild("Stats")
    if not stats then return end

    local damageValue = stats:FindFirstChild("Damage")
    if not damageValue then return end

    local startDamage = damageValue.Value
    local triggered = false

    local tempConnection
    tempConnection = damageValue.Changed:Connect(function()

        local diff = damageValue.Value - startDamage

        if diff >= 4 and diff <= 5.5 and not triggered then
            triggered = true

            if isFalling() then
                pressKey(Enum.KeyCode.Three)
            else
                pressKey(Enum.KeyCode.Two)
            end

            if tempConnection then
                tempConnection:Disconnect()
            end
        end

    end)

    task.delay(0.5,function()
        if tempConnection then
            tempConnection:Disconnect()
        end
    end)

end

------------------------------------------------
-- BLOCK CHECK
------------------------------------------------

local function startBlockingCheck()

    blockingConnection = RunService.RenderStepped:Connect(function()

        local char = player.Character
        if not char then return end

        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        for _,obj in ipairs(LIVE_FOLDER:GetChildren()) do

            if obj ~= char and obj ~= teammate then

                local enemyRoot = obj:FindFirstChild("HumanoidRootPart")
                local blocking = obj:FindFirstChild("Blocking")

                if enemyRoot and blocking and blocking.Value == true then

                    local distance = (enemyRoot.Position - root.Position).Magnitude

                    if distance <= 5 then
                        pressKey(Enum.KeyCode.One)
                        return
                    end

                end
            end
        end

    end)

end

------------------------------------------------
-- ANIMATION LISTENER
------------------------------------------------

local function hookAnimations(character)

    if animationConnection then
        animationConnection:Disconnect()
    end

    currentHumanoid = character:WaitForChild("Humanoid")

    animationConnection = currentHumanoid.AnimationPlayed:Connect(function(track)

        if not track.Animation then return end

        local id = track.Animation.AnimationId

        ------------------------------------------------
        -- DISABLED TRIGGER
        ------------------------------------------------

        if id == "rbxassetid://1470447472" then
            if not disable044 then
                waitForDamageTrigger()
            end
        end

        if id == "rbxassetid://3238450309" then
            if not disable044 then
                waitForDamageTrigger()
            end
        end

        ------------------------------------------------
        -- LOCK TRIGGER
        ------------------------------------------------

        if id == "rbxassetid://1470472673" then

            pressKey(Enum.KeyCode.Three)

            disable044 = true

            task.delay(2,function()
                disable044 = false
            end)

        end
            
        if id == "rbxassetid://1470532199" then
            pressKey(Enum.KeyCode.One)
        end

        if id == "rbxassetid://1461157246" then
            pressKey(Enum.KeyCode.One)
        end

    end)

end

------------------------------------------------
-- START
------------------------------------------------

function module.Start(team)

    teammate = team

    local stats = player:WaitForChild("Stats")
    local damageValue = stats:WaitForChild("Damage")

    lastDamage = damageValue.Value

    damageConnection = damageValue.Changed:Connect(function()
        lastDamage = damageValue.Value
    end)

    if player.Character then
        hookAnimations(player.Character)
    end

    characterConnection = player.CharacterAdded:Connect(function(char)
        hookAnimations(char)
    end)

    startBlockingCheck()

end

------------------------------------------------
-- STOP
------------------------------------------------

function module.Stop()

    if damageConnection then
        damageConnection:Disconnect()
        damageConnection = nil
    end

    if animationConnection then
        animationConnection:Disconnect()
        animationConnection = nil
    end

    if characterConnection then
        characterConnection:Disconnect()
        characterConnection = nil
    end

    if blockingConnection then
        blockingConnection:Disconnect()
        blockingConnection = nil
    end

    currentHumanoid = nil
    disable044 = false
    teammate = nil

end

return module
