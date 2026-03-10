local module = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

local humanoidConnection
local inputBeganConnection
local inputEndedConnection

local previousHealth = 0
local holdingF = false
local blockEnabled = true

local MIN_DAMAGE = 0.6
local MAX_DAMAGE = 1.2
local COUNTER_COOLDOWN = 0.12
local lastCounterTime = 0

local function pressF(state)
    VirtualInputManager:SendKeyEvent(state, Enum.KeyCode.F, false, game)
end

local function click()
    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
end

local function isEnemyNearby(radius)
    local character = player.Character
    if not character then return false end

    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return false end

    for _, model in pairs(LIVE:GetChildren()) do
        if model:IsA("Model") and model ~= character then
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if hrp then
                if (hrp.Position - root.Position).Magnitude <= radius then
                    return true
                end
            end
        end
    end

    return false
end

local function getBlockingValue()
    local world = LIVE:FindFirstChild("World_Platinum")
    if not world then return nil end
    return world:FindFirstChild("Blocking")
end

local function connectBlockSystem(humanoid)

    if humanoidConnection then
        humanoidConnection:Disconnect()
    end

    previousHealth = humanoid.Health

    humanoidConnection = humanoid.HealthChanged:Connect(function(currentHealth)

        local damage = previousHealth - currentHealth
        previousHealth = currentHealth

        if damage <= 0 then return end
        if not blockEnabled then return end
        if not holdingF then return end
        if not isEnemyNearby(15) then return end

        damage = math.round(damage * 1000) / 1000

        if damage < MIN_DAMAGE then return end
        if damage > MAX_DAMAGE then return end
        if tick() - lastCounterTime < COUNTER_COOLDOWN then return end

        local blocking = getBlockingValue()

        if blocking and blocking.Value == true then
            lastCounterTime = tick()
            pressF(false)
            holdingF = false
            click()
        end

    end)

end

function module.Start()

    if player.Character then
        connectBlockSystem(player.Character:WaitForChild("Humanoid"))
    end

    player.CharacterAdded:Connect(function(character)
        connectBlockSystem(character:WaitForChild("Humanoid"))
    end)

    inputBeganConnection = UserInputService.InputBegan:Connect(function(input,gpe)

        if gpe then return end

        if input.KeyCode == Enum.KeyCode.F then
            holdingF = true
            pressF(true)
        end

    end)

    inputEndedConnection = UserInputService.InputEnded:Connect(function(input)

        if input.KeyCode == Enum.KeyCode.F then
            holdingF = false
            pressF(false)
        end

    end)

end

function module.Stop()

    blockEnabled = false
    holdingF = false

    if humanoidConnection then
        humanoidConnection:Disconnect()
        humanoidConnection = nil
    end

    if inputBeganConnection then
        inputBeganConnection:Disconnect()
        inputBeganConnection = nil
    end

    if inputEndedConnection then
        inputEndedConnection:Disconnect()
        inputEndedConnection = nil
    end

end

return module
