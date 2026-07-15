--[[V4]]

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local module = {}

-- ===== CONFIGURATION =====
local MAX_DISTANCE = 10
local BLOCK_KEY = Enum.KeyCode.F
local BLOCK_HOLD_DURATION = 0.4    -- hold F for 0.4 seconds after block starts
local SCAN_INTERVAL = 0.05
local DEBUG = true

-- ===== ANIMATION LISTS (with per‑animation delays) =====
-- Format: { "animationId", delay_in_seconds }

-- All M1 animations (1st,2nd,3rd,4th from every style)
local M1_LIST = {
    -- BaseCombat
    {"113961476814500", 0.14}, {"82165070516177", 0.14}, {"138197524717835", 0.14}, {"81174027972159", 0.18},
    -- Basic
    {"83491849294956", 0.14}, {"89420531853362", 0.12}, {"83730275893449", 0.12}, {"106980660082799", 0.12},
    -- Boxing
    {"137980914350618", 0.14}, {"100408082509740", 0.14}, {"94803478352691", 0.14}, {"78695517680318", 0.14},
    -- Capoeira
    {"125976167173936", 0.06}, {"134945199381140", 0.1}, {"117877243065533", 0.1}, {"106965238908791", 0.1},
    -- Hakari
    {"76236532060812", 0.15}, {"74206130671324", 0.15}, {"71919935695307", 0.15}, {"122861547142657", 0.22},
    -- HakariOther
    {"126612786608030", 0.14}, {"113719263885794", 0.14}, {"136305578634960", 0.14}, {"89039586375625", 0.14},
    -- Karate
    {"137837926745158", 0.12}, {"100981571094705", 0.12}, {"130865087635587", 0.12}, {"86495068205420", 0.12},
    -- Kure
    {"82904229252991", 0.12}, {"103732110215321", 0.135}, {"103964436023727", 0.135}, {"71676634048602", 0.135},
    -- MuayThai
    {"96726284968458", 0.14}, {"139911027872047", 0.14}, {"104515319350296", 0.14}, {"74960202100098", 0.137},
    -- Slugger
    {"134829666925953", 0.14}, {"104867156139010", 0.14}, {"112759168172605", 0.13}, {"77710266587706", 0.055},
    -- Striker
    {"127909081017342", 0.13}, {"79563637573277", 0.137}, {"118070233153900", 0.11}, {"81174027972159", 0.23},
    -- Wrestling
    {"82903450925391", 0.14}, {"119685134442395", 0.11}, {"107464726433388", 0.11}, {"91485623489753", 0.14}
}

-- All M2 animations (from every style)
local M2_LIST = {
    -- BaseCombat
    {"113480104450803", 0.3},
    -- Basic
    {"78888626472394", 0.3},
    -- Boxing
    {"132022052139564", 0.3},
    -- Capoeira
    {"131071815103338", 0.3},
    -- Hakari
    {"92851992709496", 0.3},
    -- HakariOther
    {"101619248052969", 0.3},
    -- Karate
    {"120393553812903", 0.3},
    -- Kure
    {"102407060635393", 0.3},
    -- MuayThai
    {"137034747040618", 0.3},
    -- Slugger
    {"118943955490014", 0.3},
    -- Striker
    {"114364673509520", 0.3},
    -- Wrestling
    {"73748315742870", 0.3}
}

-- Perfect block animations (early release) – no delays needed
local PERFECT_BLOCK_LIST = {
    "96600699015093", "90752347516770", "82979105739696", "96304721384743",
    "138519505081692"
}

-- ===== BUILD LOOKUPS AND DELAY MAP =====
local function buildFromList(list)
    local ids = {}
    local delays = {}
    for _, entry in ipairs(list) do
        local id = entry[1]
        local delay = entry[2]   -- must be provided, no default
        ids[id] = true
        delays[id] = delay
    end
    return ids, delays
end

local m1Lookup, m1Delays = buildFromList(M1_LIST)
local m2Lookup, m2Delays = buildFromList(M2_LIST)

-- Merge delays into one map (M1 and M2)
local ANIMATION_DELAYS = {}
for id, delay in pairs(m1Delays) do ANIMATION_DELAYS[id] = delay end
for id, delay in pairs(m2Delays) do ANIMATION_DELAYS[id] = delay end

-- Perfect block lookup (simple list)
local function buildLookup(list)
    local t = {}
    for _, id in ipairs(list) do
        t[id] = true
    end
    return t
end
local perfectLookup = buildLookup(PERFECT_BLOCK_LIST)

-- ===== INTERNAL STATE =====
local running = false
local isBlocking = false
local blockStartTime = 0
local activeAttacks = {}   -- animationId -> startTime (only for attacks from enemies)
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

    local attackingEnemies = {}
    local now = tick()
    local newActive = {}

    -- 1. Collect all currently playing attack animations from enemies
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
                                        if animId and (m1Lookup[animId] or m2Lookup[animId]) then
                                            if not newActive[animId] then
                                                local startTime = activeAttacks[animId] or now
                                                newActive[animId] = startTime
                                            end
                                            attackingEnemies[enemy] = true
                                            addLabel(enemy)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- Remove labels for enemies no longer attacking
    for enemy, _ in pairs(debugLabels) do
        if not attackingEnemies[enemy] then
            removeLabel(enemy)
        end
    end

    activeAttacks = newActive

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

    -- 3. Decide whether to start blocking – only if a delay is defined
    local shouldBlockNow = false
    for animId, startTime in pairs(activeAttacks) do
        local delay = ANIMATION_DELAYS[animId]   -- no fallback
        if delay and now - startTime >= delay then
            shouldBlockNow = true
            break
        end
    end

    if shouldBlockNow and not isBlocking then
        setBlock(true)
        blockStartTime = now
    end

    -- 4. Handle block duration and early release
    if isBlocking then
        if earlyUnblock then
            setBlock(false)
            blockStartTime = 0
            activeAttacks = {}
        elseif now - blockStartTime >= BLOCK_HOLD_DURATION then
            setBlock(false)
            blockStartTime = 0
            activeAttacks = {}
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
    activeAttacks = {}
    for enemy, _ in pairs(debugLabels) do
        removeLabel(enemy)
    end
end

return module
