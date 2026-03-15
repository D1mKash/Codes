local module = {}

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local damageConnection
local animationConnection
local characterConnection
local blockingConnection
local zConnection

local lastDamage = 0
local currentHumanoid

local disable044 = false
local teammate = nil

local LIVE_FOLDER = workspace:WaitForChild("Live")

local blockCooldown = false
local scanTimer = 0

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
-- BLOCK ACTION
------------------------------------------------

local function doBlockAction()

    if blockCooldown then return end
    blockCooldown = true

    local myChar = LIVE_FOLDER:FindFirstChild(player.Name)

    if myChar then
        local myBlocking = myChar:FindFirstChild("Blocking")

        if myBlocking and myBlocking.Value == true then
            pressKey(Enum.KeyCode.F)
        end
    end

    pressKey(Enum.KeyCode.LeftShift)
    pressKey(Enum.KeyCode.One)
    pressKey(Enum.KeyCode.LeftShift)

    task.delay(1,function()
        blockCooldown = false
    end)

end

------------------------------------------------
-- BLOCK CHECK
------------------------------------------------

local function startBlockingCheck()

    blockingConnection = RunService.Heartbeat:Connect(function(dt)

        scanTimer += dt
        if scanTimer < 0.1 then return end
        scanTimer = 0

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
                        doBlockAction()
                        return
                    end

                end
            end
        end

    end)

end

------------------------------------------------
-- INPUT HANDLER (Z, X, C)
------------------------------------------------

local function startZHandler()

    zConnection = UserInputService.InputBegan:Connect(function(input,gpe)

        if gpe then return end

        if input.KeyCode == Enum.KeyCode.Z then
            pressKey(Enum.KeyCode.Two)
            task.wait(0.2)
            pressKey(Enum.KeyCode.Four)
        end

        if input.KeyCode == Enum.KeyCode.X then
            pressKey(Enum.KeyCode.Two)
            task.wait(0.2)
            pressKey(Enum.KeyCode.Three)
        end

        if input.KeyCode == Enum.KeyCode.C then
            pressKey(Enum.KeyCode.Two)
            task.wait(0.2)
            pressKey(Enum.KeyCode.Two)
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
            if not disable044 then
                waitForDamageTrigger()
            end
        end

        if id == "rbxassetid://3238450309" then
            if not disable044 then
                waitForDamageTrigger()
            end
        end

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
    startZHandler()

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

    if zConnection then
        zConnection:Disconnect()
        zConnection = nil
    end

    currentHumanoid = nil
    disable044 = false
    teammate = nil
    blockCooldown = false

end

return module
