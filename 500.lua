local Module = {}

local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

local running = false
local scanning = false
local animator = nil
local active = {}

-- Animations that trigger a 0.5 second scan
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

-- Animations that trigger a 0.6 second scan
local LONG_ANIMATIONS = {
    "1461145506",
    "1470472673",
}

-- Simulate a left mouse click
local function pressLeftClick()
    VIM:SendMouseButtonEvent(Enum.UserInputType.MouseButton1, 0, 0, true)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(Enum.UserInputType.MouseButton1, 0, 0, false)
end

-- The actual scan that watches the Combo value
local function scan(duration)
    if scanning then
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

    -- Check repeatedly within the scan duration
    while os.clock() - startTime < duration and scanning do
        task.wait(0.05) -- check every 50ms
        if combo.Value == initial + 1 then
            success = true
            break -- stop the scan immediately
        end
    end

    scanning = false

    -- If combo increased by exactly 1, wait 0.5s then left-click
    if success then
        task.wait(0.5)
        pressLeftClick()
    end
end

-- Check which animations are currently playing
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
            local duration = 0.5

            -- Check if it matches a short-scan animation
            for _, animId in ipairs(SHORT_ANIMATIONS) do
                if string.find(id, animId) then
                    matched = true
                    duration = 0.5
                    break
                end
            end

            -- If not, check if it matches a long-scan animation
            if not matched then
                for _, animId in ipairs(LONG_ANIMATIONS) do
                    if string.find(id, animId) then
                        matched = true
                        duration = 0.6
                        break
                    end
                end
            end

            -- Trigger a scan only once per animation play, and only if one isn't already running
            if matched and not active[id] and not scanning then
                active[id] = true
                task.spawn(scan, duration)
            end
        end
    end

    -- Clean up animations that have stopped playing
    for id in pairs(active) do
        if not current[id] then
            active[id] = nil
        end
    end
end

-- Setup a new character
local function setup(char)
    local hum = char:WaitForChild("Humanoid")
    animator = hum:WaitForChild("Animator")
    table.clear(active)
end

-- Main loop that runs while the module is active
local function startLoop()
    task.spawn(function()
        while running do
            task.wait(0.1)
            checkAnimations()
        end
    end)
end

-- Public API: Start monitoring
function Module.Start()
    if running then return end
    running = true

    if player.Character then
        setup(player.Character)
    end

    player.CharacterAdded:Connect(setup)
    startLoop()
end

-- Public API: Stop monitoring
function Module.Stop()
    running = false
    scanning = false -- interrupts any ongoing scan
    animator = nil
    table.clear(active)
end

return Module
