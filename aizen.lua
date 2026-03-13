local module = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

local healthConnections = {}
local enemyData = {}
local keyPressed = {}

------------------------------------------------
-- INPUT HELPERS
------------------------------------------------

local function pressKey(key)
    VirtualInputManager:SendKeyEvent(true,key,false,game)
    task.wait(0.01)
    VirtualInputManager:SendKeyEvent(false,key,false,game)
end

local function click()
    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
    task.wait(0.01)
    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
end

------------------------------------------------
-- COOLDOWN CHECK
------------------------------------------------

local function getCooldown(name)
    local obj = player.Backpack:FindFirstChild(name)
    if not obj then return 20 end
    local cd = obj:GetAttribute("COOLDOWN")
    if cd == nil then return 20 end
    return cd
end

------------------------------------------------
-- DAMAGE DETECTION
------------------------------------------------

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
            keyPressed[Enum.KeyCode.Two] = nil
            keyPressed[Enum.KeyCode.Three] = nil
        end
        enemyData[humanoid].lastHit = now

        local awakened = false
        if player.Character and player.Character:FindFirstChild("Stats") then
            awakened = player.Character.Stats:FindFirstChild("Damage") ~= nil
        end

        local dmg2 = awakened and 5.4 or 4.5
        local dmg3 = awakened and 7.2 or 6

        for key, waiting in pairs(keyPressed) do
            if waiting and player.Character and player.Character:FindFirstChild("NoAttack") then
                if key == Enum.KeyCode.Two and damage >= dmg2 - 0.1 and damage <= dmg2 + 0.1 then
                    keyPressed[key] = nil
                    click()
                    pressKey(Enum.KeyCode.One)
                elseif key == Enum.KeyCode.Three and damage >= dmg3 - 0.1 and damage <= dmg3 + 0.1 then
                    keyPressed[key] = nil
                    click()
                    pressKey(Enum.KeyCode.One)
                end
            end
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
-- KEY INPUT
------------------------------------------------

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    if input.KeyCode == Enum.KeyCode.Two and getCooldown("Kido") == 20 then
        keyPressed[Enum.KeyCode.Two] = true
    elseif input.KeyCode == Enum.KeyCode.Three and getCooldown("Kyoka Suigetsu") == 20 then
        keyPressed[Enum.KeyCode.Three] = true
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
    for _, conn in pairs(healthConnections) do
        conn:Disconnect()
    end
    healthConnections = {}
    enemyData = {}
    keyPressed = {}
end

return module
