--[[
    Auto Parry Module (Grouped, Fast Scan)
    - Scans enemies every 0.05 seconds (fast enough for all animations).
    - M1 animations → block immediately (hold F for 0.3s, reset on new attacks).
    - M2 animations → block after a 0.3s delay (only if the M2 is still playing).
    - Early release on perfect block animations (local player).
    - DEBUG = true shows "ATTACKING" labels above enemies.
]]

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local module = {}

-- ===== CONFIGURATION =====
local MAX_DISTANCE = 20
local BLOCK_KEY = Enum.KeyCode.F
local BLOCK_DURATION = 0.3          -- hold F for 0.3 seconds
local M2_DELAY = 0.3                -- delay before blocking on M2
local SCAN_INTERVAL = 0.05          -- scan every 50ms
local DEBUG = true                  -- show debug labels

-- ===== ANIMATION LISTS =====

-- All M1 animations (1st,2nd,3rd,4th from every style)
local M1_LIST = {
    -- BaseCombat
    "113961476814500", "82165070516177", "138197524717835", "81174027972159",
    -- Basic
    "83491849294956", "89420531853362", "83730275893449", "106980660082799",
    -- Boxing
    "137980914350618", "100408082509740", "94803478352691", "78695517680318",
    -- Capoeira
    "125976167173936", "134945199381140", "117877243065533", "106965238908791",
    -- Hakari
    "76236532060812", "74206130671324", "71919935695307", "122861547142657",
    -- HakariOther
    "126612786608030", "113719263885794", "136305578634960", "89039586375625",
    -- Karate
    "137837926745158", "100981571094705", "130865087635587", "86495068205420",
    -- Kure
    "82904229252991", "103732110215321", "103964436023727", "71676634048602",
    -- MuayThai
    "96726284968458", "139911027872047", "104515319350296", "74960202100098",
    -- Slugger
    "134829666925953", "104867156139010", "112759168172605", "77710266587706",
    -- Striker
    "127909081017342", "79563637573277", "118070233153900", "81174027972159",
    -- Wrestling
    "82903450925391", "119685134442395", "107464726433388", "91485623489753"
}

-- All M2 animations (from every style)
local M2_LIST = {
    -- BaseCombat
    "113480104450803",
    -- Basic
    "78888626472394",
    -- Boxing
    "132022052139564",
    -- Capoeira
    "131071815103338",
    -- Hakari
    "92851992709496",
    -- HakariOther
    "101619248052969",
    -- Karate (fixed full ID)
    "120393553812903",
    -- Kure
    "102407060635393",
    -- MuayThai
    "137034747040618",
    -- Slugger
    "118943955490014",
    -- Striker
    "114364673509520",
    -- Wrestling
    "73748315742870"
}

-- Perfect block animations (early release)
local PERFECT_BLOCK_LIST = {
    "96600699015093", "90752347516770", "82979105739696", "96304721384743",
    "138519505081692"
}

-- ===== LOOKUP TABLES =====
local function buildLookup(list)
    local t = {}
    for _, id in ipairs(list) do
        t[id] = true
    end
    return t
end

local m1Lookup = buildLookup(M1_LIST)
local m2Lookup = buildLookup(M2_LIST)
local perfectLookup = buildLookup(PERFECT_BLOCK_LIST)

-- ===== INTERNAL STATE =====
local running = false
local isBlocking = false
local blockStartTime = 0          -- when block was started (for duration)
local m2StartTime = 0             -- when M2 was first detected (for delay)
local m2Active = false            -- true if any enemy is playing M2
local debugLabels = {}

-- ===== KEY SIMULATION =====
local function setBlock(hold)
    if isBlocking == hold then return end
    isBlocking = hold
    if VirtualInputManager then
        VirtualInputManager:SendKeyEvent(hold, BLOCK_KEY, false, game)
    else
        _G.AutoBlock = hold
    end
end

-- ===== DEBUG LABELS =====
local function addLabel(character)
    if not DEBUG then return end
    if debugLabels[character] then return end
    local head = character:FindFirstChild("Head")
    if not head then return end
    local bill = Instance.new("BillboardGui")
    bill.Size = UDim2.new(0, 80, 0, 30)
    bill.StudsOffset = Vector3.new(0, 3, 0)
    bill.Adornee = head
    bill.AlwaysOnTop = true
    bill.Parent = character
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    label.BackgroundTransparency = 0.3
    label.Text = "ATTACKING"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.SourceSansBold
    label.TextScaled = true
    label.Parent = bill
    debugLabels[character] = bill
end

local function removeLabel(character)
    local bill = debugLabels[character]
    if bill then bill:Destroy() end
    debugLabels[character] = nil
end

-- ===== MAIN SCAN =====
local function scan()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end
    local char = localPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then return end

    local shouldBlockM1 = false     -- true if any M1 is detected
    local m2Detected = false        -- true if any M2 is detected
    local attackingEnemies = {}     -- for debug labels

    -- 1. Check all enemies
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local enemy = player.Character
            if enemy then
                local enemyRoot = enemy:FindFirstChild("HumanoidRootPart") or enemy:FindFirstChild("Torso")
                if enemyRoot and root then
                    local dist = (root.Position - enemyRoot.Position).Magnitude
                    if dist <= MAX_DISTANCE then
                        local hum = enemy:FindFirstChild("Humanoid")
                        if hum then
                            local animator = hum:FindFirstChild("Animator")
                            if animator then
                                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                                    local anim = track.Animation
                                    if anim then
                                        local animId = anim.AnimationId:match("%d+")
                                        if animId then
                                            if m1Lookup[animId] then
                                                shouldBlockM1 = true
                                                attackingEnemies[enemy] = true
                                                addLabel(enemy)
                                            elseif m2Lookup[animId] then
                                                m2Detected = true
                                                attackingEnemies[enemy] = true
                                                addLabel(enemy)
                                            end
                                            -- if we already found M1, we can break early
                                            if shouldBlockM1 then break end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        if shouldBlockM1 then break end
    end

    -- Remove labels for enemies not attacking
    for enemy, _ in pairs(debugLabels) do
        if not attackingEnemies[enemy] then
            removeLabel(enemy)
        end
    end

    -- Update m2Active based on detection
    m2Active = m2Detected

    -- 2. Check local player for perfect block (early release)
    local earlyUnblock = false
    if isBlocking then
        local localHum = char:FindFirstChild("Humanoid")
        if localHum then
            local animator = localHum:FindFirstChild("Animator")
            if animator then
                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                    local anim = track.Animation
                    if anim then
                        local animId = anim.AnimationId:match("%d+")
                        if animId and perfectLookup[animId] then
                            earlyUnblock = true
                            break
                        end
                    end
                end
            end
        end
    end

    -- 3. Block logic
    local currentTime = tick()

    -- Handle M1 (immediate block)
    if shouldBlockM1 then
        -- Reset M2 delay timer
        m2StartTime = 0
        -- Reset block timer (renew duration)
        blockStartTime = currentTime
        if not isBlocking then
            setBlock(true)
        end
    else
        -- No M1 detected, check M2
        if m2Active then
            -- M2 is playing, start delay if not already started
            if m2StartTime == 0 then
                m2StartTime = currentTime
            end
            -- If delay has passed and we are not blocking, block now
            if (currentTime - m2StartTime) >= M2_DELAY then
                if not isBlocking then
                    setBlock(true)
                    blockStartTime = currentTime   -- start the block duration timer
                end
            end
        else
            -- No M2, reset delay timer
            m2StartTime = 0
        end
    end

    -- Handle block duration and perfect block early release
    if isBlocking then
        if earlyUnblock then
            setBlock(false)
            blockStartTime = 0
            m2StartTime = 0
        elseif currentTime - blockStartTime >= BLOCK_DURATION then
            setBlock(false)
            blockStartTime = 0
            m2StartTime = 0
        end
    end
end

-- ===== PUBLIC API =====
function module.Start()
    if running then return end
    running = true
    scan()
    task.spawn(function()
        while running do
            task.wait(SCAN_INTERVAL)
            if running then scan() end
        end
    end)
end

function module.Stop()
    running = false
    setBlock(false)
    blockStartTime = 0
    m2StartTime = 0
    m2Active = false
    for enemy, _ in pairs(debugLabels) do
        removeLabel(enemy)
    end
end

return module
