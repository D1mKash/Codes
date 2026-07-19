local module = {}

local Players = game:GetService("Players")
local VirtualInput = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local player = Players.LocalPlayer

-- Animation IDs to watch
local ANIM_CERO = "rbxassetid://1470532199"   -- triggers 3+4 + gravity boost
local ANIM_OTHER = "rbxassetid://1461157246"  -- triggers 1

-- Scan window duration (seconds)
local SCAN_WINDOW = 0.7

-- Gravity multiplier and duration
local GRAVITY_MULTIPLIER = 4
local GRAVITY_DURATION = 5  -- seconds

local running = false
local scanActive = false
local pressedInWindow = false
local scanTimer = nil

local connections = {}
local comboConnection = nil

-- Gravity state
local gravityTimer = nil
local originalGravity = Workspace.Gravity

-- --------------------------------------------------------------------
-- Helper: press a key using VirtualInputManager
-- --------------------------------------------------------------------
local function pressKey(key)
    pcall(function()
        VirtualInput:SendKeyEvent(true, key, false, game)
        task.wait(0.01)
        VirtualInput:SendKeyEvent(false, key, false, game)
    end)
end

-- --------------------------------------------------------------------
-- Gravity boost: set to 4× for 5 seconds, then revert
-- --------------------------------------------------------------------
local function setGravityBoost()
    -- Cancel any pending revert
    if gravityTimer then
        task.cancel(gravityTimer)
        gravityTimer = nil
    end

    -- Store current (in case it was already modified)
    originalGravity = Workspace.Gravity

    -- Apply 4×
    Workspace.Gravity = originalGravity * GRAVITY_MULTIPLIER

    -- Schedule revert
    gravityTimer = task.spawn(function()
        task.wait(GRAVITY_DURATION)
        if running then
            Workspace.Gravity = originalGravity
        end
        gravityTimer = nil
    end)
end

-- --------------------------------------------------------------------
-- Reset gravity to original (cleanup)
-- --------------------------------------------------------------------
local function resetGravity()
    if gravityTimer then
        task.cancel(gravityTimer)
        gravityTimer = nil
    end
    Workspace.Gravity = originalGravity
end

-- --------------------------------------------------------------------
-- Reset scan window
-- --------------------------------------------------------------------
local function resetScanWindow()
    if scanTimer then
        task.cancel(scanTimer)
        scanTimer = nil
    end
    scanActive = false
    pressedInWindow = false
end

-- --------------------------------------------------------------------
-- Start a new scan window (called on combo change)
-- --------------------------------------------------------------------
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
-- Called when any animation track starts playing
-- --------------------------------------------------------------------
local function onAnimationPlayed(track)
    if not running then return end
    if not scanActive then return end
    if pressedInWindow then return end

    if not track or not track.Animation then return end
    local id = track.Animation.AnimationId
    if not id then return end

    -- Check for Cero animation (triggers 3+4 + gravity boost)
    if id == ANIM_CERO then
        pressedInWindow = true
        task.spawn(function()
            pressKey(Enum.KeyCode.Three)
            task.wait(0.02)
            pressKey(Enum.KeyCode.Four)
            -- Apply gravity boost
            setGravityBoost()
        end)
        return
    end

    -- Check for other animation (triggers 1)
    if id == ANIM_OTHER then
        pressedInWindow = true
        task.spawn(function()
            pressKey(Enum.KeyCode.One)
        end)
        return
    end
end

-- --------------------------------------------------------------------
-- Combo changed → start scan window
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
        if anim then
            table.insert(animators, anim)
        end
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
    resetGravity()  -- reset gravity to original on character change

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

    originalGravity = Workspace.Gravity  -- capture initial

    local char = player.Character
    if char then
        setupCharacter(char)
    end

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
    resetGravity()  -- revert gravity on stop
end

return module
