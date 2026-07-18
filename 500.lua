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

local running = false
local scanning = false
local clickPending = false
local animator = nil
local active = {}

local function releaseNow()
    mouse1release()
end

local function performClick()
    mouse1click()
end

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

            for _, animId in ipairs(SHORT_ANIMATIONS) do
                if string.find(id, animId) then
                    matched = true
                    duration = 0.3
                    break
                end
            end

            if not matched then
                for _, animId in ipairs(LONG_ANIMATIONS) do
                    if string.find(id, animId) then
                        matched = true
                        duration = 0.4
                        break
                    end
                end
            end

            if matched and not active[id] and not scanning and not clickPending then
                active[id] = true
                task.spawn(scan, duration)
            end
        end
    end

    for id in pairs(active) do
        if not current[id] then
            active[id] = nil
        end
    end
end

local function setup(char)
    local hum = char:WaitForChild("Humanoid")
    animator = hum:WaitForChild("Animator")
    table.clear(active)
end

local function loop()
    task.spawn(function()
        while running do
            task.wait(0.1)
            checkAnimations()
        end
    end)
end

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
