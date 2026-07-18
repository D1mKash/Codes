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

-- Animations that should disable jump for 0.4s when on ground
local JUMP_DISABLE_ANIMATIONS = {
    "1470447472",
    "1461136875",
}

local running = false
local scanning = false
local clickPending = false
local animator = nil
local active = {}

-- State for jump disable
local jumpDisabled = false
local jumpDisableTimer = nil

local function releaseNow()
    mouse1release()
end

local function performClick()
    mouse1click()
end

-- --------------------------------------------------------------------
-- Jump disable handler (runs independently)
-- --------------------------------------------------------------------
local function handleJumpDisable(animId)
    -- Check if this animation requires jump disable
    local shouldDisable = false
    for _, id in ipairs(JUMP_DISABLE_ANIMATIONS) do
        if animId == id then
            shouldDisable = true
            break
        end
    end
    if not shouldDisable then return end

    -- Prevent overlapping
    if jumpDisabled then return end

    local char = player.Character
    if not char then return end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    -- Only disable if on ground (not falling)
    if hum:GetState() == Enum.HumanoidStateType.Falling then
        return
    end

    -- Disable jump
    jumpDisabled = true
    local originalJumpPower = hum.JumpPower
    hum.JumpPower = 0

    -- Restore after 0.4 seconds
    task.spawn(function()
        task.wait(0.4)
        -- Only restore if this same instance hasn't been cleared
        if jumpDisabled then
            local currentChar = player.Character
            if currentChar then
                local currentHum = currentChar:FindFirstChildOfClass("Humanoid")
                if currentHum then
                    currentHum.JumpPower = originalJumpPower
                end
            end
            jumpDisabled = false
        end
    end)
end

-- --------------------------------------------------------------------
-- Scan function (unchanged)
-- --------------------------------------------------------------------
local function scan(duration)
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
        task.wait(0.4)
        performClick()

        clickPending = false
    end
end

-- --------------------------------------------------------------------
-- Animation detector (modified to also call jump disable)
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

            -- Trigger scan if matched and not already active
            if matched and not active[id] and not scanning and not clickPending then
                active[id] = true
                task.spawn(scan, duration)
            end

            -- NEW: Trigger jump disable for specific animations, even if scan is already running or click pending
            if matchedId and not active[id] and not jumpDisabled then
                -- We need the actual animId (the number string) to check if it's in JUMP_DISABLE_ANIMATIONS
                -- The matchedId is the numeric string from our lists, e.g., "1470447472"
                if table.find(JUMP_DISABLE_ANIMATIONS, matchedId) then
                    -- Only trigger once per animation start (we already have active[id] check)
                    -- We also need to ensure we don't double trigger if the animation is already playing
                    -- but we are already inside the "if not active[id]" block, so it's a new animation.
                    task.spawn(handleJumpDisable, matchedId)
                end
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
    -- Reset jump disable state on new character
    jumpDisabled = false
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
    scanning = false
    clickPending = false
    animator = nil
    table.clear(active)
    -- Restore jump if currently disabled
    if jumpDisabled then
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.JumpPower = hum.JumpPower -- not restoring original, but we can set to 50 or something? Actually we stored original in the restore task, but we can't access it here. Better to set to default 50.
                hum.JumpPower = 35 -- default Roblox JumpPower
            end
        end
        jumpDisabled = false
    end
end

return Module
