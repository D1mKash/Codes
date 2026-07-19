local Module = {}

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LIVE = Workspace:WaitForChild("Live")
local STANDS = Workspace:WaitForChild("Stands")

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
local animator = nil          -- current Animator object we're listening to
local animatorConnection = nil -- connection to AnimationPlayed (if using that) – but we scan via GetPlayingAnimationTracks, so not needed
local active = {}

-- For tracking stand/character source
local currentAnimModel = nil
local standAddedConnection = nil
local standRemovedConnection = nil
local characterAddedConnection = nil

-- --------------------------------------------------------------------
-- Ping reading (unchanged)
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
-- Adjust delay based on ping (same as before)
-- --------------------------------------------------------------------
local function getAdjustedDelay(baseDelay)
    local ping = getPing()
    if ping > 40 then
        local reduction = math.floor((ping - 40) / 10) * 0.01
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
-- Scan function (unchanged)
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
-- Helper: get the Stand model (if any) for a character
-- --------------------------------------------------------------------
local function getStand(char)
    if not char then return nil end
    return STANDS:FindFirstChild(char.Name) or STANDS:FindFirstChild(player.Name)
end

-- --------------------------------------------------------------------
-- Helper: get the animation source (Humanoid or Animator) from a model
-- (same as in head.lua)
-- --------------------------------------------------------------------
local function getAnimationSource(model)
    if not model then return nil end
    local hum = model:FindFirstChildOfClass("Humanoid")
    if hum then
        return hum
    end
    local animator = model:FindFirstChildWhichIsA("Animator", true)
    if animator then
        return animator
    end
    local controller = model:FindFirstChildWhichIsA("AnimationController", true)
    if controller then
        return controller:FindFirstChildOfClass("Animator") or controller:WaitForChild("Animator", 5)
    end
    return nil
end

-- --------------------------------------------------------------------
-- Update the animator source (stand or character)
-- --------------------------------------------------------------------
local function updateAnimatorSource(char)
    -- Clean previous connections
    if animatorConnection then
        animatorConnection:Disconnect()
        animatorConnection = nil
    end

    local stand = getStand(char)
    local sourceModel = stand or char
    currentAnimModel = sourceModel

    local source = getAnimationSource(sourceModel)
    if source then
        -- If it's a Humanoid, get its Animator
        if source:IsA("Humanoid") then
            animator = source:FindFirstChild("Animator")
        elseif source:IsA("Animator") then
            animator = source
        else
            animator = nil
        end

        -- Optionally, we could listen to AnimationPlayed, but we're polling, so not needed.
        -- However, we could set up a connection if we want to be notified, but we'll just rely on the loop.
    else
        animator = nil
    end
end

-- --------------------------------------------------------------------
-- Character setup: called when character appears or stand changes
-- --------------------------------------------------------------------
local function setup(char)
    if not char then return end
    updateAnimatorSource(char)
    table.clear(active)
end

-- --------------------------------------------------------------------
-- Stand added/removed connections
-- --------------------------------------------------------------------
local function setupStandListeners(char)
    if standAddedConnection then
        standAddedConnection:Disconnect()
        standAddedConnection = nil
    end
    if standRemovedConnection then
        standRemovedConnection:Disconnect()
        standRemovedConnection = nil
    end

    standAddedConnection = STANDS.ChildAdded:Connect(function(child)
        if not running then return end
        if not player.Character or player.Character ~= char then return end
        if child.Name == char.Name or child.Name == player.Name then
            task.wait(0.1) -- allow stand to fully load
            setup(char)
        end
    end)

    standRemovedConnection = STANDS.ChildRemoved:Connect(function(child)
        if not running then return end
        if not player.Character or player.Character ~= char then return end
        if child == currentAnimModel then
            task.wait(0.1)
            setup(char) -- fallback to character
        end
    end)
end

-- --------------------------------------------------------------------
-- Animation detector (polling)
-- --------------------------------------------------------------------
local function checkAnimations()
    if not animator then
        -- try to re-acquire if animator is nil but maybe it exists now
        local char = player.Character
        if char then
            updateAnimatorSource(char)
        end
        if not animator then return end
    end

    local current = {}

    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
        if track and track.Animation then
            local id = track.Animation.AnimationId
            current[id] = true

            local matched = false
            local duration = 0.3
            local baseDelay = 0.215   -- SHORT default

            -- Check SHORT
            for _, animId in ipairs(SHORT_ANIMATIONS) do
                if string.find(id, animId) then
                    matched = true
                    duration = 0.3
                    baseDelay = 0.215
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

            -- Check LAST
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

    local char = player.Character
    if char then
        setup(char)
        setupStandListeners(char)
    end

    characterAddedConnection = player.CharacterAdded:Connect(function(newChar)
        setup(newChar)
        setupStandListeners(newChar)
    end)

    loop()
end

function Module.Stop()
    running = false
    scanning = false
    clickPending = false
    animator = nil
    table.clear(active)

    if animatorConnection then
        animatorConnection:Disconnect()
        animatorConnection = nil
    end
    if standAddedConnection then
        standAddedConnection:Disconnect()
        standAddedConnection = nil
    end
    if standRemovedConnection then
        standRemovedConnection:Disconnect()
        standRemovedConnection = nil
    end
    if characterAddedConnection then
        characterAddedConnection:Disconnect()
        characterAddedConnection = nil
    end

    currentAnimModel = nil
end

return Module
