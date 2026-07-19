local module = {}

local Players = game:GetService("Players")
local VirtualInput = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- Animation IDs to watch
local ANIM_CERO = "rbxassetid://1470532199"   -- triggers 3+4 + 
local ANIM_OTHER = "rbxassetid://1461157246"  -- triggers 1

-- Scan window duration (seconds)
local SCAN_WINDOW = 0.7

-- Ceiling parameters
local FALLING_SEARCH_TIME = 3   -- seconds to find a falling model
local CEILING_OFFSET = 2        -- studs above target's Y
local DAMAGE_THRESHOLD = 1.8    -- delta damage that removes ceiling
local DAMAGE_TIMEOUT = 1        -- seconds without damage change to remove ceiling

local running = false
local scanActive = false
local pressedInWindow = false
local scanTimer = nil

local connections = {}
local comboConnection = nil

-- Ceiling state
local ceilingActive = false
local ceilingTarget = nil
local ceilingY = 0
local ceilingHeartbeat = nil
local ceilingTimer = nil
local damageConnection = nil
local lastDamage = 0
local lastDamageChangeTime = 0
local searchTask = nil

-- --------------------------------------------------------------------
-- Helper: press a key
-- --------------------------------------------------------------------
local function pressKey(key)
    pcall(function()
        VirtualInput:SendKeyEvent(true, key, false, game)
        task.wait(0.01)
        VirtualInput:SendKeyEvent(false, key, false, game)
    end)
end

-- --------------------------------------------------------------------
-- Ceiling enforcement – smooth Y clamping
-- --------------------------------------------------------------------
local function enforceCeiling()
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local pos = root.Position
    if pos.Y > ceilingY then
        -- Snap position to ceiling
        root.Position = Vector3.new(pos.X, ceilingY, pos.Z)
        -- Cancel vertical velocity to prevent bouncing
        local vel = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
    end
end

-- --------------------------------------------------------------------
-- Update ceiling Y based on target's current Y
-- --------------------------------------------------------------------
local function updateCeilingY()
    if not ceilingTarget then return end
    local targetRoot = ceilingTarget:FindFirstChild("HumanoidRootPart")
    if targetRoot then
        ceilingY = targetRoot.Position.Y + CEILING_OFFSET
    end
end

-- --------------------------------------------------------------------
-- Remove ceiling (disable, cleanup)
-- --------------------------------------------------------------------
local function removeCeiling()
    if ceilingActive then
        ceilingActive = false
        if ceilingHeartbeat then
            ceilingHeartbeat:Disconnect()
            ceilingHeartbeat = nil
        end
        if damageConnection then
            damageConnection:Disconnect()
            damageConnection = nil
        end
        if ceilingTimer then
            task.cancel(ceilingTimer)
            ceilingTimer = nil
        end
        ceilingTarget = nil
    end
end

-- --------------------------------------------------------------------
-- Called when damage changes (while ceiling is active)
-- --------------------------------------------------------------------
local function onDamageChanged()
    if not ceilingActive then return end

    local stats = player:FindFirstChild("Stats")
    local damage = stats and stats:FindFirstChild("Damage")
    if not damage then return end

    local current = damage.Value
    local delta = current - lastDamage
    lastDamage = current
    lastDamageChangeTime = os.clock()

    if delta > DAMAGE_THRESHOLD then
        removeCeiling()
        return
    end
end

-- --------------------------------------------------------------------
-- Timer to check for damage timeout
-- --------------------------------------------------------------------
local function startDamageTimeoutMonitor()
    if ceilingTimer then task.cancel(ceilingTimer) end
    ceilingTimer = task.spawn(function()
        while ceilingActive do
            task.wait(0.5)
            if ceilingActive and (os.clock() - lastDamageChangeTime) > DAMAGE_TIMEOUT then
                removeCeiling()
                break
            end
        end
    end)
end

-- --------------------------------------------------------------------
-- Start ceiling process: find falling model, then activate
-- --------------------------------------------------------------------
local function startCeilingProcess()
    removeCeiling()

    local searchStart = os.clock()
    local foundTarget = nil

    searchTask = task.spawn(function()
        while os.clock() - searchStart < FALLING_SEARCH_TIME do
            if not running then return end

            local bestTarget = nil
            local highestY = -math.huge
            for _, model in ipairs(Workspace.Live:GetChildren()) do
                if model:IsA("Model") then
                    local hum = model:FindFirstChildOfClass("Humanoid")
                    if hum and hum.Health > 0 then
                        local state = hum:GetState()
                        local root = model:FindFirstChild("HumanoidRootPart")
                        if root then
                            local velY = root.AssemblyLinearVelocity.Y
                            if state == Enum.HumanoidStateType.Freefall or velY < -0.5 then
                                if root.Position.Y > highestY then
                                    highestY = root.Position.Y
                                    bestTarget = model
                                end
                            end
                        end
                    end
                end
            end

            if bestTarget then
                foundTarget = bestTarget
                break
            end

            task.wait(0.1)
        end

        if foundTarget then
            ceilingTarget = foundTarget
            updateCeilingY()
            ceilingActive = true

            -- Damage tracking
            local stats = player:FindFirstChild("Stats")
            local damage = stats and stats:FindFirstChild("Damage")
            if damage then
                lastDamage = damage.Value
                lastDamageChangeTime = os.clock()
                damageConnection = damage.Changed:Connect(onDamageChanged)
                table.insert(connections, damageConnection)
            end

            -- Clamp loop
            ceilingHeartbeat = RunService.Heartbeat:Connect(function()
                if not ceilingActive then return end
                updateCeilingY()
                enforceCeiling()
            end)

            startDamageTimeoutMonitor()

            -- Cleanup if target is removed
            local targetRemovedConn = ceilingTarget.AncestryChanged:Connect(function()
                if not ceilingTarget or ceilingTarget.Parent == nil then
                    removeCeiling()
                end
            end)
            table.insert(connections, targetRemovedConn)
        end

        searchTask = nil
    end)
end

-- --------------------------------------------------------------------
-- Scan window functions (unchanged)
-- --------------------------------------------------------------------
local function resetScanWindow()
    if scanTimer then
        task.cancel(scanTimer)
        scanTimer = nil
    end
    scanActive = false
    pressedInWindow = false
end

local function startScanWindow()
    resetScanWindow()
    scanActive = true
    pressedInWindow = false
    scanTimer = task.spawn(function()
        task.wait(SCAN_WINDOW)
        if running then
            scanActive = false
            pressedInWindow = false
        end
        scanTimer = nil
    end)
end

-- --------------------------------------------------------------------
-- Animation detection
-- --------------------------------------------------------------------
local function onAnimationPlayed(track)
    if not running then return end
    if not scanActive then return end
    if pressedInWindow then return end

    if not track or not track.Animation then return end
    local id = track.Animation.AnimationId
    if not id then return end

    if id == ANIM_CERO then
        pressedInWindow = true
        task.spawn(function()
            pressKey(Enum.KeyCode.Three)
            task.wait(0.02)
            pressKey(Enum.KeyCode.Four)
            startCeilingProcess()
        end)
        return
    end

    if id == ANIM_OTHER then
        pressedInWindow = true
        task.spawn(function()
            pressKey(Enum.KeyCode.One)
        end)
        return
    end
end

-- --------------------------------------------------------------------
-- Combo changed trigger
-- --------------------------------------------------------------------
local function onComboChanged()
    if not running then return end
    startScanWindow()
end

-- --------------------------------------------------------------------
-- Hook animators
-- --------------------------------------------------------------------
local function hookAnimators(model)
    if not model then return end

    local animators = {}
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then
        local anim = hum:FindFirstChild("Animator")
        if anim then table.insert(animators, anim) end
    end
    for _, child in ipairs(model:GetDescendants()) do
        if child:IsA("Animator") or child:IsA("AnimationController") then
            table.insert(animators, child)
        end
    end

    for _, animator in ipairs(animators) do
        local conn = animator.AnimationPlayed:Connect(onAnimationPlayed)
        table.insert(connections, conn)
    end
end

-- --------------------------------------------------------------------
-- Setup character
-- --------------------------------------------------------------------
local function setupCharacter(char)
    for _, conn in ipairs(connections) do
        pcall(conn.Disconnect, conn)
    end
    connections = {}

    if comboConnection then
        comboConnection:Disconnect()
        comboConnection = nil
    end

    resetScanWindow()
    removeCeiling()

    if searchTask then
        task.cancel(searchTask)
        searchTask = nil
    end

    if not char then return end

    hookAnimators(char)

    local stats = player:FindFirstChild("Stats")
    local combo = stats and stats:FindFirstChild("Combo")
    if combo then
        comboConnection = combo.Changed:Connect(onComboChanged)
        table.insert(connections, comboConnection)
    end
end

-- --------------------------------------------------------------------
-- Public API
-- --------------------------------------------------------------------
function module.Start()
    if running then return end
    running = true

    local char = player.Character
    if char then setupCharacter(char) end

    local charAddedConn = player.CharacterAdded:Connect(function(newChar)
        setupCharacter(newChar)
    end)
    table.insert(connections, charAddedConn)
end

function module.Stop()
    if not running then return end
    running = false

    for _, conn in ipairs(connections) do
        pcall(conn.Disconnect, conn)
    end
    connections = {}

    if comboConnection then
        comboConnection:Disconnect()
        comboConnection = nil
    end

    resetScanWindow()
    removeCeiling()

    if searchTask then
        task.cancel(searchTask)
        searchTask = nil
    end
end

return module
