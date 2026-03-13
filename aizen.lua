local module = {}

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

local damageConnection
local animationConnection

local damageEvents = {}

------------------------------------------------
-- INPUT
------------------------------------------------

local function pressKey(key)
    VirtualInputManager:SendKeyEvent(true,key,false,game)
    VirtualInputManager:SendKeyEvent(false,key,false,game)
end

------------------------------------------------
-- COOLDOWN CHECK
------------------------------------------------

local function checkKyoka()

    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return end

    local kyoka = backpack:FindFirstChild("Kyoka Suigetsu")
    if not kyoka then return end

    local cd = kyoka:GetAttribute("COOLDOWN")

    if cd == nil or cd == 20 then
        pressKey(Enum.KeyCode.Two)
    elseif cd < 20 then
        pressKey(Enum.KeyCode.Three)
    end

end

------------------------------------------------
-- DAMAGE WINDOW
------------------------------------------------

local function registerDamage(amount)

    local now = tick()

    table.insert(damageEvents, {
        time = now,
        dmg = amount
    })

    local total = 0

    for i = #damageEvents,1,-1 do
        if now - damageEvents[i].time > 2 then
            table.remove(damageEvents,i)
        else
            total = total + damageEvents[i].dmg
        end
    end

    if total > 16 and total < 20 then
        damageEvents = {}
        checkKyoka()
    end

end

------------------------------------------------
-- START
------------------------------------------------

function module.Start()

    local stats = player:WaitForChild("Stats")
    local damageValue = stats:WaitForChild("Damage")

    local lastDamage = damageValue.Value

    damageConnection = damageValue.Changed:Connect(function()

        local diff = damageValue.Value - lastDamage

        if diff > 0 then
            registerDamage(diff)
        end

        lastDamage = damageValue.Value

    end)

    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")

    animationConnection = humanoid.AnimationPlayed:Connect(function(track)

        if not track.Animation then return end

        local id = track.Animation.AnimationId

        if id == "rbxassetid://1470472673" then
            pressKey(Enum.KeyCode.Three)
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

    damageEvents = {}

end

return module
