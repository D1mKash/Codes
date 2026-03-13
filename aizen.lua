local module = {}

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

local damageConnection
local animationConnection

local damageHits = {}

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
-- DAMAGE TRACKING
------------------------------------------------

local function registerDamage()

    local now = tick()

    table.insert(damageHits, now)

    -- remove hits older than 2 seconds
    for i = #damageHits,1,-1 do
        if now - damageHits[i] > 2 then
            table.remove(damageHits,i)
        end
    end

    if #damageHits >= 3 then
        damageHits = {}
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

        if damageValue.Value > lastDamage then
            registerDamage()
        end

        lastDamage = damageValue.Value

    end)

    local character = player.Character or player.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")

    animationConnection = humanoid.AnimationPlayed:Connect(function(track)

        if not track.Animation then return end

        if track.Animation.AnimationId == "rbxassetid://1470472673" then
            pressKey(Enum.KeyCode.Three)
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

    damageHits = {}

end

return module
