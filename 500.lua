local Module = {}

local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
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

-- Animations that should trigger the special Space + Click combo
local SPECIAL_CLICK_ANIMATIONS = {
    "1470447472",
    "1461136875",
}

local running = false
local scanning = false
local clickPending = false
local animator = nil
local active = {}

-- --------------------------------------------------------------------
-- Input helpers (exactly like haha.lua)
-- --------------------------------------------------------------------

local function holdKeyDown(key)
    VIM:SendKeyEvent(true, key, false, game)
end

local function holdKeyUp(key)
    VIM:SendKeyEvent(false, key, false, game)
end

local function holdMouseDown()
    VIM:SendMouseButtonEvent(Enum.UserInputType.MouseButton1, 0, 0, true)
end

local function holdMouseUp()
    VIM:SendMouseButtonEvent(Enum.UserInputType.MouseButton1, 0, 0, false)
end

local function mouseClick()
    -- use the executor's built-in if available, else VIM
    if type(mouse1click) == "function" then
        mouse1click()
    else
        holdMouseDown()
        task.wait(0.05)
        holdMouseUp()
    end
end

-- --------------------------------------------------------------------
-- Hold Space + left click for 0.5 seconds
-- --------------------------------------------------------------------
local function holdSpaceAndClick()
    holdKeyDown(Enum.KeyCode.Space)
    holdMouseDown()
    task.wait(0.5)
    holdMouseUp()
    holdKeyUp(Enum.KeyCode.Space)
end

-- --------------------------------------------------------------------
-- Check backpack for Configuration objects with COOLDOWN condition
-- --------------------------------------------------------------------
local function shouldUseSpaceCombo()
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return false end

    local targetNames = {
        "Sonido Clones",
        "Cero",
        "Kyoka Suigetsu",
        "Grab",
        "Bisecting Slash",
    }

    for _, child in ipairs(backpack:GetChildren()) do
        for _, name in ipairs(targetNames) do
            if child.Name == name then
                local cooldown = child:GetAttribute("COOLDOWN")
                if cooldown == nil or cooldown == 20 then
                    return true
                end
            end
        end
    end
    return false
end

-- --------------------------------------------------------------------
-- Scan function
-- --------------------------------------------------------------------
local function scan(duration, isLong, matchedId)
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

        -- Click delay depends on animation type
        local clickDelay = isLong and 0.5 or 0.22
        task.wait(clickDelay)

        -- Decide what to do: normal click, or Space + click
        local useSpaceCombo = false
        if matchedId then
            for _, id in ipairs(SPECIAL_CLICK_ANIMATIONS) do
                if matchedId == id then
                    if shouldUseSpaceCombo() then
                        useSpaceCombo = true
                    end
                    break
                end
            end
        end

        if useSpaceCombo then
            print("🔥 [DEBUG] Using Space + Click combo (0.5s hold)")
            holdSpaceAndClick()
        else
            mouseClick()
        end

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
                        break
                    end
                end
            end

            if matched and not active[id] and not scanning and not clickPending then
                active[id] = true
                task.spawn(scan, duration, isLong, matchedId)
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
-- Setup and loop
-- --------------------------------------------------------------------
local function setup(char)
    local hum = char:WaitForChild("Humanoid")
    animator = hum:WaitForChild("Animator")
    table.clear(active)
end

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
