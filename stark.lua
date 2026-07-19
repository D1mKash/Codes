local module = {}

local Players = game:GetService("Players")
local VirtualInput = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

-- Animation IDs to watch
local ANIM_CERO = "rbxassetid://1470532199"   -- triggers 3+4
local ANIM_OTHER = "rbxassetid://1461157246"  -- triggers 1

-- Scan durations (seconds)
local SCAN_CERO = 0.4
local SCAN_OTHER = 0.5

local running = false
local scanning = false          -- prevent overlapping scans
local connections = {}          -- store all event connections for cleanup
local character = nil
local animatorConnections = {}  -- for each animator, store its connection

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
-- Scan for combo change within a time limit
-- --------------------------------------------------------------------
local function scanForComboChange(duration, keys)
    if scanning then return end
    scanning = true

    -- Get combo value
    local stats = player:FindFirstChild("Stats")
    local combo = stats and stats:FindFirstChild("Combo")
    if not combo or type(combo.Value) ~= "number" then
        scanning = false
        return
    end

    local initial = combo.Value
    local startTime = os.clock()
    local success = false

    -- Wait for combo to change
    while os.clock() - startTime < duration and scanning do
        task.wait(0.05)
        if combo.Value ~= initial then
            success = true
            break
        end
    end

    scanning = false

    if success then
        -- Press each key in order
        for _, key in ipairs(keys) do
            pressKey(key)
            task.wait(0.02) -- small gap between key presses
        end
    end
end

-- --------------------------------------------------------------------
-- Called when any animation track starts playing
-- --------------------------------------------------------------------
local function onAnimationPlayed(track)
    if not running then return end
    if not track or not track.Animation then return end

    local id = track.Animation.AnimationId
    if not id then return end

    -- Check for Cero animation (triggers 3+4)
    if id == ANIM_CERO then
        task.spawn(scanForComboChange, SCAN_CERO, {Enum.KeyCode.Three, Enum.KeyCode.Four})
        return
    end

    -- Check for other animation (triggers 1)
    if id == ANIM_OTHER then
        task.spawn(scanForComboChange, SCAN_OTHER, {Enum.KeyCode.One})
        return
    end
end

-- --------------------------------------------------------------------
-- Hook into all Animator/AnimationController instances on a model
-- --------------------------------------------------------------------
local function hookAnimators(model)
    -- Find all animators
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
        if not animatorConnections[animator] then
            local conn = animator.AnimationPlayed:Connect(onAnimationPlayed)
            animatorConnections[animator] = conn
            table.insert(connections, conn)
        end
    end
end

-- --------------------------------------------------------------------
-- Setup for the current character
-- --------------------------------------------------------------------
local function setupCharacter(char)
    -- Clear old connections
    for _, conn in ipairs(connections) do
        pcall(conn.Disconnect, conn)
    end
    connections = {}
    animatorConnections = {}
    scanning = false

    if char then
        hookAnimators(char)
    end
end

-- --------------------------------------------------------------------
-- Public API
-- --------------------------------------------------------------------
function module.Start()
    if running then return end
    running = true

    character = player.Character
    if character then
        setupCharacter(character)
    end

    -- Listen for character respawn
    local charAddedConn = player.CharacterAdded:Connect(function(newChar)
        character = newChar
        setupCharacter(newChar)
    end)
    table.insert(connections, charAddedConn)

    -- Also listen for character removal to clean up (optional)
    local charRemovingConn = player.CharacterRemoving:Connect(function()
        -- no need to do much; setup on next character will clean
    end)
    table.insert(connections, charRemovingConn)
end

function module.Stop()
    if not running then return end
    running = false

    for _, conn in ipairs(connections) do
        pcall(conn.Disconnect, conn)
    end
    connections = {}
    animatorConnections = {}
    scanning = false
    character = nil
end

return module
