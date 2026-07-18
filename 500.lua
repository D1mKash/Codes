local Module = {}

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Animation IDs that trigger a 0.3 second scan (short)
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

-- Animation IDs that trigger a 0.4 second scan (long)
local LONG_ANIMATIONS = {
    "1461145506",
    "1470472673",
}

-- Animations that should disable jump for 0.7 seconds
local JUMP_DISABLE_ANIMATIONS = {
    "1470447472",
    "1461136875",
    "1470449816",
    "1461136273",   -- added
}

local running = false
local scanning = false
local clickPending = false
local animator = nil
local active = {}   -- tracks animations that have already been processed

-- Jump disable state
local jumpData = {
    disabled = false,
    originalJumpPower = 0,
    cancelRestore = false,
}

-- --------------------------------------------------------------------
-- Mouse functions
-- --------------------------------------------------------------------
local function releaseNow()
    mouse1release()
end

local function performClick()
    mouse1click()
end

-- --------------------------------------------------------------------
-- Restore jump immediately (used when LONG animation plays)
-- --------------------------------------------------------------------
local function restoreJumpNow()
    if not jumpData.disabled then return end

    jumpData.cancelRestore = true   -- cancel the scheduled restore
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.JumpPower = jumpData.originalJumpPower
        end
    end
    jumpData.disabled = false
    jumpData.originalJumpPower = 0
end

-- --------------------------------------------------------------------
-- Jump disable handler (disables for 0.7s, with cancel support)
-- --------------------------------------------------------------------
local function handleJumpDisable(animId)
    -- Check if this animation is in the disable list
    local shouldDisable = false
    for _, id in ipairs(JUMP_DISABLE_ANIMATIONS) do
        if animId == id then
            shouldDisable = true
            break
        end
    end
    if not shouldDisable then return end

    -- Prevent overlapping disables
    if jumpData.disabled then return end

    local char = player.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    -- Disable jump
    jumpData.disabled = true
    jumpData.originalJumpPower = hum.JumpPower
    jumpData.cancelRestore = false
    hum.JumpPower = 0

    -- Schedule restore after 0.7 seconds
    task.spawn(function()
        task.wait(0.7)
        -- Only restore if not cancelled and still disabled
        if not jumpData.cancelRestore and jumpData.disabled then
            local currentChar = player.Character
            if currentChar then
                local currentHum = currentChar:FindFirstChildOfClass("Humanoid")
                if currentHum then
                    currentHum.JumpPower = jumpData.originalJumpPower
                end
            end
            jumpData.disabled = false
            jumpData.originalJumpPower = 0
        end
    end)
end

-- --------------------------------------------------------------------
-- Scan function (with click delay based on animation type)
-- --------------------------------------------------------------------
local function scan(duration, isLong)
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

    while os.clock() - startTime < duration and scanning do
        task.wait(0.05)
        if combo.Value ~= initial then
            success = true
            break
        end
    end

    scanning = false

    if success then
        clickPending = true

        releaseNow()
        -- Click delay depends on animation type
        local clickDelay = isLong and 0.5 or 0.3
        task.wait(clickDelay)
        performClick()

        clickPending = false
    end
end

-- --------------------------------------------------------------------
-- Animation detector (FIXED: jump disable now triggers)
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
            local isLong = false

            -- Check short animations
            for _, animId in ipairs(SHORT_ANIMATIONS) do
                if string.find(id, animId) then
                    matched = true
                    duration = 0.3
                    matchedId = animId
                    isLong = false
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
                        isLong = true

                        -- LONG animation detected: restore JumpPower immediately
                        restoreJumpNow()

                        break
                    end
                end
            end

            -- If matched and not already processed
            if matched and not active[id] and not scanning and not clickPending then
                -- Spawn the scan task
                task.spawn(scan, duration, isLong)

                -- Spawn jump disable if this animation is in the disable list
                if matchedId and not jumpData.disabled then
                    for _, jid in ipairs(JUMP_DISABLE_ANIMATIONS) do
                        if matchedId == jid then
                            task.spawn(handleJumpDisable, matchedId)
                            break
                        end
                    end
                end

                -- Mark as processed so we don't retrigger
                active[id] = true
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

    -- Reset jump state on new character
    if jumpData.disabled then
        restoreJumpNow()
    end
    jumpData.disabled = false
    jumpData.originalJumpPower = 0
    jumpData.cancelRestore = false
end

-- --------------------------------------------------------------------
-- Main loop (faster: 0.05)
-- --------------------------------------------------------------------
local function loop()
    task.spawn(function()
        while running do
            task.wait(0.05)
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
    scanning = false
    clickPending = false
    animator = nil
    table.clear(active)

    -- Restore jump if currently disabled (default to 35)
    if jumpData.disabled then
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.JumpPower = 35
            end
        end
        jumpData.disabled = false
        jumpData.originalJumpPower = 0
        jumpData.cancelRestore = false
    end
end

return Module
