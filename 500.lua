local Module = {}

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Animation IDs that trigger a 0.3 second scan (short)
local SHORT_ANIMATIONS = {
    "1461128166", -- FIST
    "1461128859",
    "1461136273",
    --
    "1470422387", -- SWORD
    "1470439852",
    "1470449816",
    --
    "92901308072582", -- CLEAVER
    "8320258247",
    "8321532463",
    --
    "1470482438", -- DOWNTILT
    "1461277837",
}

-- Animation IDs that trigger a 0.4 second scan (long)
local LONG_ANIMATIONS = {
    "1461145506",
    "1470472673",
}

-- NEW: Animation IDs with 0.3 scan duration and 0.1 base click delay
local LAST_ANIMATIONS = {
    "1461136875",
    "1470447472",
    "8321564926",
}

local running = false
local scanning = false
local clickPending = false
local animator = nil
local active = {}

-- --------------------------------------------------------------------
-- Get current ping from the GUI label (e.g., "32 ms")
-- --------------------------------------------------------------------
local function getPing()
    local gui = player:FindFirstChild("PlayerGui")
    if gui then
        local pingInfo = gui:FindFirstChild("PingInfo")
        if pingInfo then
            local liveStats = pingInfo:FindFirstChild("LiveStats")
            if liveStats then
                local label = liveStats:FindFirstChild("ping")
                if label and label:IsA("TextLabel") then
                    local text = label.Text
                    local num = tonumber(text:match("%d+"))
                    if num then
                        return num
                    end
                end
            end
        end
    end
    return 0
end

-- --------------------------------------------------------------------
-- Adjust delay based on ping:
-- subtract 0.01 for every 20 ms above 40 ms
-- --------------------------------------------------------------------
local function getAdjustedDelay(baseDelay)
    local ping = getPing()
    if ping > 40 then
        local reduction = math.floor((ping - 40) / 20) * 0.01
        return math.max(0, baseDelay - reduction)
    end
    return baseDelay
end

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
-- Scan function
-- --------------------------------------------------------------------
local function scan(duration, baseClickDelay)
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
        local finalDelay = getAdjustedDelay(baseClickDelay)
        task.wait(finalDelay)
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
            local baseDelay = 0.22   -- SHORT default

            -- Check SHORT
            for _, animId in ipairs(SHORT_ANIMATIONS) do
                if string.find(id, animId) then
                    matched = true
                    duration = 0.3
                    baseDelay = 0.22
                    break
                end
            end

            -- Check LONG
            if not matched then
                for _, animId in ipairs(LONG_ANIMATIONS) do
                    if string.find(id, animId) then
                        matched = true
                        duration = 0.4
                        baseDelay = 0.5
                        break
                    end
                end
            end

            -- Check LAST (new)
            if not matched then
                for _, animId in ipairs(LAST_ANIMATIONS) do
                    if string.find(id, animId) then
                        matched = true
                        duration = 0.3
                        baseDelay = 0.1
                        break
                    end
                end
            end

            if matched and not active[id] and not scanning and not clickPending then
                active[id] = true
                task.spawn(scan, duration, baseDelay)
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
end

-- --------------------------------------------------------------------
-- Main loop (0.05s check interval)
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
end

return Module
