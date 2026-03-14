local module = {}

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

local damageConnection
local animationConnection
local characterConnection

local lastDamage = 0
local currentHumanoid

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

        if diff >= 4 and diff <= 5 and not triggered then
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

        if id == "rbxassetid://1470447472" then
            waitForDamageTrigger()
        end

        if id == "rbxassetid://1470472673" then
            waitForDamageTrigger()
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

function module.Start()

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

    currentHumanoid = nil

end

return module
