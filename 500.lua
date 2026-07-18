local Module = {}

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Animation IDs that trigger a 0.3 second scan
local SHORT_ANIMATIONS = {
    "1461128166",
    "1461128859",
    "1461136273",
    "1461136875",
    "1470422387",
    "1470439852",
    "1470449816",
    "1470447472",
}

-- Animation IDs that trigger a 0.4 second scan
local LONG_ANIMATIONS = {
    "1461145506",
    "1470472673",
}

-- Animations that require jump power modification
local JUMP_CHECK_ANIMATIONS = {
    "1461136875",
    "1470447472",
}

local running = false
local scanning = false
local clickPending = false
local animator = nil
local active = {}

-- Stores info for jump power restoration
local jumpData = {
    humanoid = nil,
    originalJumpPower = 0,
    modified = false,
}

-- --------------------------------------------------------------------
-- Click functions
-- --------------------------------------------------------------------
local function releaseNow()
    pcall(mouse1release)
end

local function performClick()
    pcall(mouse1click)
end

-- --------------------------------------------------------------------
-- Safe jump power override (sets to 0 if not falling)
-- Returns true if modified, false otherwise
-- --------------------------------------------------------------------
local function tryOverrideJumpPower()
    if jumpData.modified then
        return true -- already modified, skip
    end

    local char = player.Character
    if not char then return false end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end

    -- Check if currently falling
    if hum:GetState() == Enum.HumanoidStateType.Falling then
        return false
    end

    -- Override
    jumpData.humanoid = hum
    jumpData.originalJumpPower = hum.JumpPower
    hum.JumpPower = 0
    jumpData.modified = true
    return true
end

-- --------------------------------------------------------------------
-- Restore jump power if it was modified
-- --------------------------------------------------------------------
local function restoreJumpPower()
    if not jumpData.modified then return end

    local hum = jumpData.humanoid
    if hum and hum.Parent and hum:IsA("Humanoid") then
        hum.JumpPower = jumpData.originalJumpPower
    end

    jumpData.modified = false
    jumpData.humanoid = nil
    jumpData.originalJumpPower = 0
end

-- --------------------------------------------------------------------
-- Reset all state for a clean start (called on Stop and on errors)
-- --------------------------------------------------------------------
local function resetState()
    scanning = false
    clickPending = false
    restoreJumpPower()
end

-- --------------------------------------------------------------------
-- Main scan function
-- --------------------------------------------------------------------
local function scan(duration, triggerAnimId)
    if scanning or clickPending then
        return
    end

    scanning = true

    local stats = player:FindFirstChild("Stats")
    local combo = stats and stats:FindFirstChild("Combo")

    if not combo or type(combo.Value) ~= "number" then
        scanning = false
        return
    end

    local initial = combo.Value
    local startTime = os.clock()
    local success = false

    -- Scan loop
    while os.clock() - startTime < duration and scanning do
        task.wait(0.05)
        if combo.Value ~= initial then
            success = true
            break
        end
    end

    scanning = false

    if not success then
        return
    end

    -- Lock to prevent new scans during click sequence
    clickPending = true

    -- Handle JumpPower override if needed
    local modifiedJump = false
    if triggerAnimId and table.find(JUMP_CHECK_ANIMATIONS, triggerAnimId) then
        modifiedJump = tryOverrideJumpPower()
    end

    -- Execute click sequence
    local ok, err = pcall(function()
        releaseNow()
        task.wait(0.4)
        performClick()
    end)

    if not ok then
        -- Something went wrong, print error? But we have no prints; we can just reset.
        -- We'll still restore jump if needed.
    end

    -- Restore jump power if we modified it
    if modifiedJump then
        restoreJumpPower()
    end

    -- Release the lock
    clickPending = false

    -- If something went wrong, also ensure locks are cleared
    if not ok then
        resetState() -- fallback to clear everything
    end
end

-- --------------------------------------------------------------------
-- Animation detector
-- --------------------------------------------------------------------
local function checkAnimations()
    local char = player.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    if not animator then
        animator = hum:FindFirstChild("Animator")
        if not animator then return end
    end

    local current = {}

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if track and track.Animation then
            local id = track.Animation.AnimationId
            current[id] = true

            local matched = false
            local duration = 0.3
            local matchedId = nil

            -- Check short animations
            for _, animId in ipairs(SHORT_ANIMATIONS) do
                if string.find(id, animId) then
                    matched = true
                    duration = 0.3
                    matchedId = animId
                    break
                end
            end

            -- Check long animations if not matched yet
            if not matched then
                for _, animId in ipairs(LONG_ANIMATIONS) do
                    if string.find(id, animId) then
                        matched = true
                        duration = 0.4
                        matchedId = animId
                        break
                    end
                end
            end

            -- Trigger scan only if not already active, not scanning, and no click pending
            if matched and not active[id] and not scanning and not clickPending then
                active[id] = true
                task.spawn(scan, duration, matchedId)
            end
        end
    end

    -- Clean up finished animations
    for id in pairs(active) do
        if not current[id] then
            active[id] = nil
        end
    end
end

-- --------------------------------------------------------------------
-- Character setup
-- --------------------------------------------------------------------
local function setup(char)
    local hum = char:WaitForChild("Humanoid")
    animator = hum:WaitForChild("Animator")
    table.clear(active)
    resetState() -- ensure no leftover state from previous character
end

-- --------------------------------------------------------------------
-- Main loop
-- --------------------------------------------------------------------
local function loop()
    task.spawn(function()
        while running do
            task.wait(0.1)
            checkAnimations()
        end
    end)
end

-- --------------------------------------------------------------------
-- Public API
-- --------------------------------------------------------------------
function Module.Start()
    if running then return end
    running = true

    if player.Character then
        setup(player.Character)
    end

    player.CharacterAdded:Connect(setup)
    loop()
end

function Module.Stop()
    running = false
    resetState()  -- clears scanning, clickPending, and restores JumpPower
    animator = nil
    table.clear(active)
end

return Module
