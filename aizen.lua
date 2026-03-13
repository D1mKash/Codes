local module = {}

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

local damageConnection
local animationConnection
local characterConnection

local damageHits = {}
local buildCooldown = false

local anim047Triggered = false

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

    if buildCooldown then return end
    if anim047Triggered then return end -- prevent stacking

    local now = tick()

    table.insert(damageHits, now)

    for i = #damageHits,1,-1 do
        if now - damageHits[i] > 2 then
            table.remove(damageHits,i)
        end
    end

    if #damageHits >= 4 then

        damageHits = {}

        checkKyoka()

        buildCooldown = true

        task.delay(1,function()
            buildCooldown = false
        end)

    end

end

------------------------------------------------
-- ANIMATION LISTENER
------------------------------------------------

local function hookAnimations(character)

    if animationConnection then
        animationConnection:Disconnect()
    end

    local humanoid = character:WaitForChild("Humanoid")

    animationConnection = humanoid.AnimationPlayed:Connect(function(track)

        if not track.Animation then return end

        local id = track.Animation.AnimationId

        if id == "rbxassetid://1470472673" then

            anim047Triggered = true
            pressKey(Enum.KeyCode.Three)

            task.delay(1.1,function()
                anim047Triggered = false
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

function module.Start()

    local stats = player:WaitForChild("Stats")
    local damageValue = stats:WaitForChild("Damage")

    local lastDamage = damageValue.Value

    damageConnection = damageValue.Changed:Connect(function()

        local diff = damageValue.Value - lastDamage

        if diff > 4 then
            registerDamage()
        end

        lastDamage = damageValue.Value

    end)

    if player.Character then
        hookAnimations(player.Character)
    end

    characterConnection = player.CharacterAdded:Connect(function(char)
        hookAnimations(char)
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

    if characterConnection then
        characterConnection:Disconnect()
        characterConnection = nil
    end

    damageHits = {}
    buildCooldown = false
    anim047Triggered = false

end

return module
