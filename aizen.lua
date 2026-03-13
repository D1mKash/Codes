local module = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

local inputConnection
local healthConnections = {}

local function pressKey(key)
    VirtualInputManager:SendKeyEvent(true,key,false,game)
    VirtualInputManager:SendKeyEvent(false,key,false,game)
end

local function randomDelay()
    return math.random(200,300)/1000 -- 0.20 - 0.30
end

--================================================--
-- Z COMBO
--================================================--

local function runZCombo()

    pressKey(Enum.KeyCode.Two)

    task.delay(randomDelay(),function()
        pressKey(Enum.KeyCode.Three)
    end)

end

--================================================--
-- DAMAGE DETECTION
--================================================--

local function connectHumanoid(humanoid)

    local previousHealth = humanoid.Health

    local conn
    conn = humanoid.HealthChanged:Connect(function(current)

        local damage = previousHealth - current
        previousHealth = current

        if damage <= 0 then return end

        damage = math.round(damage*10)/10

        -- 4.5 DAMAGE
        if damage == 4.5 then

            pressKey(Enum.KeyCode.Two)

            task.delay(randomDelay(),function()
                pressKey(Enum.KeyCode.One)
            end)

        end

        -- 6 DAMAGE
        if damage == 6 then

            pressKey(Enum.KeyCode.Three)

            task.delay(randomDelay(),function()
                pressKey(Enum.KeyCode.One)
            end)

        end

    end)

    table.insert(healthConnections,conn)

end

local function setupDamageDetection()

    for _,model in pairs(LIVE:GetChildren()) do

        if model:IsA("Model") and model.Name ~= player.Name then

            local humanoid = model:FindFirstChildOfClass("Humanoid")

            if humanoid then
                connectHumanoid(humanoid)
            end

        end

    end

end

--================================================--
-- START / STOP
--================================================--

function module.Start()

    if inputConnection then
        inputConnection:Disconnect()
    end

    inputConnection = UserInputService.InputBegan:Connect(function(input,gpe)

        if gpe then return end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then return end

        if input.KeyCode == Enum.KeyCode.Z then
            runZCombo()
        end

    end)

    setupDamageDetection()

end

function module.Stop()

    if inputConnection then
        inputConnection:Disconnect()
        inputConnection = nil
    end

    for _,conn in pairs(healthConnections) do
        conn:Disconnect()
    end

    healthConnections = {}

end

return module
