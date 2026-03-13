local module = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

local healthConnections = {}
local enemyData = {}

------------------------------------------------
-- INPUT
------------------------------------------------

local function pressKey(key)
    VirtualInputManager:SendKeyEvent(true,key,false,game)
    VirtualInputManager:SendKeyEvent(false,key,false,game)
end

local function click()
    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
    task.wait(0.02)
    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
end

local function comboDelay()
    return math.random(20,25)/1000
end

local function smallDelay()
    return math.random(100,200)/1000
end

------------------------------------------------
-- COOLDOWN
------------------------------------------------

local function getCooldown(name)

    local obj = player.Backpack:FindFirstChild(name)
    if not obj then
        return 20
    end

    local cd = obj:GetAttribute("COOLDOWN")

    if cd == nil then
        return 20
    end

    return cd
end

------------------------------------------------
-- GROUND CHECK
------------------------------------------------

local function isGrounded()

    local char = player.Character
    if not char then return false end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end

    return hum.FloorMaterial ~= Enum.Material.Air
end

------------------------------------------------
-- COMBOS
------------------------------------------------

local function run2to1()

    pressKey(Enum.KeyCode.Two)
    click()

    task.delay(smallDelay(),function()

        click()

        task.delay(comboDelay(),function()
            pressKey(Enum.KeyCode.One)
        end)

    end)

end

local function run3to1()

    pressKey(Enum.KeyCode.Three)
    click()

    task.delay(smallDelay(),function()

        click()

        task.delay(comboDelay(),function()
            pressKey(Enum.KeyCode.One)
        end)

    end)

end

------------------------------------------------
-- DECISION LOGIC
------------------------------------------------

local function decideCombo()

    local kyoka = getCooldown("Kyoka Suigetsu")
    local kido = getCooldown("Kido")

    local kyokaReady = kyoka == 20
    local kidoReady = kido == 20

    local grounded = isGrounded()

    if not kyokaReady and not kidoReady then
        return
    end

    if not grounded then
        run3to1()
        return
    end

    if kyokaReady and kidoReady then
        run2to1()
        return
    end

    if not kyokaReady and kidoReady then
        run3to1()
        return
    end

    if kyokaReady and not kidoReady then
        run2to1()
        return
    end

end

------------------------------------------------
-- DAMAGE DETECTION
------------------------------------------------

local function connectHumanoid(humanoid)

    enemyData[humanoid] = {
        hits = 0,
        total = 0,
        lastHit = 0
    }

    local previousHealth = humanoid.Health

    local conn
    conn = humanoid.HealthChanged:Connect(function(current)

        local damage = previousHealth - current
        previousHealth = current

        if damage <= 0 then return end

        damage = math.round(damage * 10) / 10

        if damage ~= 4.2 then return end

        local data = enemyData[humanoid]
        if not data then return end

        local now = tick()

        if now - data.lastHit > 1 then
            data.hits = 0
            data.total = 0
        end

        data.lastHit = now
        data.hits += 1
        data.total += damage

        if data.hits >= 4 then

            if data.total >= 16.3 and data.total <= 16.9 then
                decideCombo()
            end

            data.hits = 0
            data.total = 0

        end

    end)

    table.insert(healthConnections,conn)

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

    for _,model in pairs(LIVE:GetChildren()) do
        setupCharacter(model)
    end

    LIVE.ChildAdded:Connect(function(model)
        task.wait(0.1)
        setupCharacter(model)
    end)

end

function module.Stop()

    for _,conn in pairs(healthConnections) do
        conn:Disconnect()
    end

    healthConnections = {}
    enemyData = {}

end

return module
