local module = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

local healthConnections = {}

local hitCount = 0
local damageTotal = 0
local lastHitTime = 0

local function pressKey(key)
    VirtualInputManager:SendKeyEvent(true,key,false,game)
    VirtualInputManager:SendKeyEvent(false,key,false,game)
end

local function click()
    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
end

local function randomDelay()
    return math.random(500,700)/1000
end

------------------------------------------------
-- COOLDOWN CHECK
------------------------------------------------

local function getCooldown(name)

    local obj = player.Backpack:FindFirstChild(name)
    if not obj then return 0 end

    return obj:GetAttribute("COOLDOWN") or 0

end

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

    task.delay(randomDelay(),function()
        click()
        pressKey(Enum.KeyCode.One)
    end)

end

local function run3to1()

    pressKey(Enum.KeyCode.Three)
    click()

    task.delay(randomDelay(),function()
        click()
        pressKey(Enum.KeyCode.One)
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

local function resetCombo()
    hitCount = 0
    damageTotal = 0
end

local function connectHumanoid(humanoid)

    local previousHealth = humanoid.Health

    local conn
    conn = humanoid.HealthChanged:Connect(function(current)

        local damage = previousHealth - current
        previousHealth = current

        if damage <= 0 then return end

        damage = math.round(damage*10)/10

        if damage == 4.2 then

            local now = tick()

            if now - lastHitTime > 1 then
                resetCombo()
            end

            lastHitTime = now

            hitCount += 1
            damageTotal += damage

            if hitCount >= 4 then

                if damageTotal >= 16.3 and damageTotal <= 16.9 then
                    decideCombo()
                end

                resetCombo()

            end

        end

    end)

    table.insert(healthConnections,conn)

end

------------------------------------------------
-- SETUP
------------------------------------------------

local function setupCharacter(model)

    if model.Name == player.Name then return end
    if not model:IsA("Model") then return end

    local humanoid = model:FindFirstChildOfClass("Humanoid")

    if humanoid then
        connectHumanoid(humanoid)
    end

end

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

end

return module
