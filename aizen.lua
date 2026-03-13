local module = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

------------------------------------------------
-- INPUT HELPERS
------------------------------------------------
local function click()
    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
    task.wait(0.01)
    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
end

local function pressKey(key)
    VirtualInputManager:SendKeyEvent(true,key,false,game)
    task.wait(0.01)
    VirtualInputManager:SendKeyEvent(false,key,false,game)
end

------------------------------------------------
-- DAMAGE DETECTION
------------------------------------------------
local enemyData = {}

local function connectHumanoid(humanoid)
    enemyData[humanoid] = { lastHit = 0 }

    local previousHealth = humanoid.Health

    local conn
    conn = humanoid.HealthChanged:Connect(function(current)
        local damage = previousHealth - current
        previousHealth = current

        if damage <= 0 then return end
        damage = math.round(damage * 10) / 10

        local now = tick()
        if now - enemyData[humanoid].lastHit > 1 then
            enemyData[humanoid].lastHit = now
        end

        return damage
    end)

    return conn
end

------------------------------------------------
-- CHARACTER SETUP
------------------------------------------------
local humanoidConnections = {}

local function setupCharacter(model)
    if model.Name == player.Name then return end
    if not model:IsA("Model") then return end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        local conn = connectHumanoid(humanoid)
        table.insert(humanoidConnections, conn)
    end
end

------------------------------------------------
-- COMBO LOGIC
------------------------------------------------
local function startCombo(expectedDamage)
    -- Wait for NoAttack folder
    local char = player.Character
    if not char then return end

    -- Wait until "NoAttack" appears
    repeat task.wait() until char:FindFirstChild("NoAttack")

    -- Click for 0.01 seconds
    click()

    -- Wait until "NoAttack" disappears
    repeat task.wait() until not char:FindFirstChild("NoAttack")

    -- Press 1
    pressKey(Enum.KeyCode.One)
end

local function handleKeyPress(key)
    local gui = player:WaitForChild("PlayerGui"):WaitForChild("GuiBox", 5)
    if not gui then return end

    local clone = gui:FindFirstChild("1Clone")
    if not clone or not clone:FindFirstChild("TextLabel") then return end

    local text = clone.TextLabel.Text
    local damageTarget = nil

    if text == "Kurohitsugi" then
        damageTarget = 6
    elseif text == "True Power" then
        damageTarget = 4.5
    else
        return
    end

    -- Track all enemies
    for _, model in pairs(LIVE:GetChildren()) do
        local humanoid = model:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.HealthChanged:Connect(function(current)
                local damage = math.round((humanoid.Health - current) * -10) / 10
                if damage == damageTarget then
                    startCombo(damageTarget)
                end
            end)
        end
    end
end

------------------------------------------------
-- INPUT LISTENER
------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Two or input.KeyCode == Enum.KeyCode.Three then
        handleKeyPress(input.KeyCode)
    end
end)

------------------------------------------------
-- START / STOP
------------------------------------------------
function module.Start()
    for _, model in pairs(LIVE:GetChildren()) do
        setupCharacter(model)
    end

    LIVE.ChildAdded:Connect(function(model)
        task.wait(0.1)
        setupCharacter(model)
    end)
end

function module.Stop()
    for _, conn in pairs(humanoidConnections) do
        conn:Disconnect()
    end
    humanoidConnections = {}
    enemyData = {}
end

return module
