local module = {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

-- Helper to press a key
local function pressKey(key)
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode[key], false, game)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode[key], false, game)
end

-- Helper to simulate click
local function clickMouse()
    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
end

-- Random delay helper
local function randDelay(min, max)
    task.wait(math.random(min*1000, max*1000)/1000)
end

-- State
local damageAccumulator = 0
local hitCounter = 0
local lastDamageTime = tick()

-- Call this whenever you deal damage
function module.RegisterDamage(amount)
    local char = player.Character
    if not char then return end

    local isAir = not char:FindFirstChild("HumanoidRootPart") -- Example check for air
    local TruePower = char:FindFirstChild("True Power")
    local Kido = char:FindFirstChild("Kido")
    local Kyoka = char:FindFirstChild("Kyoka Suigetsu")

    local moveReady = function(move)
        return move and move:FindFirstChild("COOLDOWN") and move.COOLDOWN.Value >= 20
    end

    -- Reset if 1 second passes without new damage
    if tick() - lastDamageTime > 1 then
        damageAccumulator = 0
        hitCounter = 0
    end

    hitCounter += 1
    damageAccumulator += amount
    lastDamageTime = tick()

    -- Ground combos
    if not isAir then
        if moveReady(Kido) and moveReady(Kyoka) then
            if hitCounter >= 4 and damageAccumulator >= 16.3 and damageAccumulator <= 16.9 then
                clickMouse()
                randDelay(0.1, 0.2)
                pressKey("One")
                -- Reset counters
                damageAccumulator = 0
                hitCounter = 0
            end
        elseif moveReady(Kido) and not moveReady(Kyoka) then
            if hitCounter >= 4 and damageAccumulator >= 16.3 and damageAccumulator <= 16.9 then
                clickMouse()
                randDelay(0.1, 0.2)
                pressKey("One")
                damageAccumulator = 0
                hitCounter = 0
            end
        elseif moveReady(Kyoka) and not moveReady(Kido) then
            if hitCounter >= 4 and damageAccumulator >= 16.3 and damageAccumulator <= 16.9 then
                clickMouse()
                randDelay(0.1, 0.2)
                pressKey("One")
                damageAccumulator = 0
                hitCounter = 0
            end
        end
    else -- Air combos
        if moveReady(TruePower) and (not moveReady(Kido) and not moveReady(Kyoka)) then
            if hitCounter >= 5 and damageAccumulator >= 22.3 and damageAccumulator <= 22.9 then
                local noDodgeFolder = char:FindFirstChild("NoDodge")
                if noDodgeFolder then
                    clickMouse()
                    randDelay(0.1, 0.2)
                    pressKey("One")
                    damageAccumulator = 0
                    hitCounter = 0
                end
            end
        end
    end
end

return module
