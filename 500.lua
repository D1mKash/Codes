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
-- Scan function
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
        task.wait(0.2)   -- <-- changed from 0.3 to 0.2
        performClick()

        clickPending = false
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

            -- Trigger scan if matched and not already active
            if matched and not active[id] and not scanning and not clickPending then
                active[id] = true
                task.spawn(scan, duration)
            end

            -- Jump disable for specific animations
            if matchedId and not active[id] and not jumpDisabled then
                if table.find(JUMP_DISABLE_ANIMATIONS, matchedId) then
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

    -- Restore jump if currently disabled (default to 35)
    if jumpDisabled then
        local char = player.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.JumpPower = 35
            end
        end
        jumpDisabled = false
    end
end

return Module
