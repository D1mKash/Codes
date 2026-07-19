local module = {}

local Players = game:GetService("Players")
local VirtualInput = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

-- Animation IDs to watch
local ANIM_CERO = "rbxassetid://1470495207"   -- triggers 2
local ANIM_OTHER = "rbxassetid://1461157246"  -- triggers 1

-- Scan window duration (seconds)
local SCAN_WINDOW = 0.7

local running = false
local scanActive = false          -- are we inside a scan window?
local pressedInWindow = false     -- did we already press in this window?
local scanTimer = nil             -- thread handle for the window timer

local connections = {}            -- all event connections for cleanup
local comboConnection = nil       -- connection to Combo.Changed

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
-- Reset the scan window (called when combo changes or we stop)
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
    resetScanWindow()  -- cancel any pending window

    scanActive = true
    pressedInWindow = false

    -- Set a timer to close the window after SCAN_WINDOW seconds
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
    if not scanActive then return end          -- ignore animations outside scan window
    if pressedInWindow then return end         -- already pressed in this window

    if not track or not track.Animation then return end
    local id = track.Animation.AnimationId
    if not id then return end

    -- Check for Cero animation (triggers 3+4)
    if id == ANIM_CERO then
        pressedInWindow = true
        task.spawn(function()
            pressKey(Enum.KeyCode.Two)
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
-- Combo value changed – trigger a new scan window
-- --------------------------------------------------------------------
local function onComboChanged()
    if not running then return end
    startScanWindow()
end

-- --------------------------------------------------------------------
-- Hook into all Animator/AnimationController instances on a model
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
    -- Also find any Animator or AnimationController descendants
    for _, child in ipairs(model:GetDescendants()) do
        if child:IsA("Animator") or child:IsA("AnimationController") then
            table.insert(animators, child)
        end
    end

    -- Connect to each animator's AnimationPlayed
    for _, animator in ipairs(animators) do
        local conn = animator.AnimationPlayed:Connect(onAnimationPlayed)
        table.insert(connections, conn)
    end
end

-- --------------------------------------------------------------------
-- Setup for the current character – hook animators and combo
-- --------------------------------------------------------------------
local function setupCharacter(char)
    -- Clear old connections
    for _, conn in ipairs(connections) do
        pcall(conn.Disconnect, conn)
    end
    connections = {}

    if comboConnection then
        comboConnection:Disconnect()
        comboConnection = nil
    end

    resetScanWindow()

    if not char then return end

    -- Hook animators
    hookAnimators(char)

    -- Hook combo change
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
    if char then
        setupCharacter(char)
    end

    -- Listen for character respawn
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
end

return module
