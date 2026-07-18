local Module = {}

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local Stats = game:GetService("Stats")   -- for ping

-- --------------------------------------------------------------------
-- Animation groups: each defines scan duration and base click delay
-- --------------------------------------------------------------------
local GROUPS = {
    SHORT = {
        ids = {
            "1461128166", "1461128859", "1461136273",
            "1470422387", "1470439852", "1470449816",
            "92901308072582", "8320258247", "8321532463",
            "1470482438", "1461277837",
        },
        scanDuration = 0.3,
        baseClickDelay = 0.21,
    },
    LONG = {
        ids = { "1461145506", "1470472673" },
        scanDuration = 0.4,
        baseClickDelay = 0.5,
    },
    LAST = {
        ids = { "1461136875", "1470447472", "8321564926" },
        scanDuration = 0.3,
        baseClickDelay = 0.1,
    },
}

-- Build a reverse map: animationId → group info
local animationMap = {}
for _, group in pairs(GROUPS) do
    for _, id in ipairs(group.ids) do
        animationMap[id] = group
    end
end

local running = false
local scanning = false
local clickPending = false
local animator = nil
local active = {}

-- --------------------------------------------------------------------
-- Ping adjustment: subtract 0.01 for every 20ms above 40ms
-- --------------------------------------------------------------------
local function getAdjustedDelay(baseDelay)
    local ping = Stats.Ping or 0
    if ping > 40 then
        local adjustment = math.floor((ping - 40) / 20) * 0.01
        return math.max(0, baseDelay - adjustment)   -- never negative
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
-- Scan function – now receives base click delay (adjusted later)
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
        -- Compute final delay with current ping
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

            -- Look up the animation ID in the map
            local group = nil
            for animId, info in pairs(animationMap) do
                if string.find(id, animId) then
                    group = info
                    break
                end
            end

            -- If matched and not already processed
            if group and not active[id] and not scanning and not clickPending then
                active[id] = true
                task.spawn(scan, group.scanDuration, group.baseClickDelay)
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
