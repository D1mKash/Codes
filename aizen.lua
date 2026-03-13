local module = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

local healthConnections = {}

------------------------------------------------
-- INPUT
------------------------------------------------

local function pressKey(key)
    VirtualInputManager:SendKeyEvent(true, key, false, game)
    VirtualInputManager:SendKeyEvent(false, key, false, game)
end

local function click()
    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
    task.wait(0.01)
    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
end

------------------------------------------------
-- COMBOS
------------------------------------------------

local function run2to1()
    pressKey(Enum.KeyCode.Two)
    click()
    pressKey(Enum.KeyCode.One)
end

local function run3to1()
    pressKey(Enum.KeyCode.Three)
    click()
    pressKey(Enum.KeyCode.One)
end

------------------------------------------------
-- DAMAGE DETECTION
------------------------------------------------

local function connectHumanoid(humanoid)
    local previousHealth = humanoid.Health

    local conn
    conn = humanoid.HealthChanged:Connect(function(current)
        local damage = previousHealth - current
        previousHealth = current

        if damage <= 0 then return end
        damage = math.round(damage * 10) / 10

        local char = player.Character
        if not char then return end
        local noAttack = char:FindFirstChild("NoAttack")
        if not noAttack then return end

        if damage == 5.4 then
            click()
            run2to1()
        elseif damage == 7.2 then
            click()
            run3to1()
        end
    end)

    table.insert(healthConnections, conn)
end

------------------------------------------------
-- CHARACTER SETUP
------------------------------------------------

local function setupCharacter(model)
    if model.Name == player.Name then return end
    if not model:IsA("Model") then return end

    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if humanoid then
        connectHumanoid(humanoid)
    end
end

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
    for _, conn in pairs(healthConnections) do
        conn:Disconnect()
    end

    healthConnections = {}
end

return module
