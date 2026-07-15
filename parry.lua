--[[V4]]

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local module = {}

-- ===== CONFIGURATION =====
local MAX_DISTANCE = 10
local BLOCK_KEY = Enum.KeyCode.F
local BLOCK_HOLD_DURATION = 0.2
local SCAN_INTERVAL = 0.05
local DEBUG = true

-- ===== ONE TABLE – ALL ANIMATIONS WITH THEIR DELAYS =====
-- Change any value below to adjust that animation's delay (in seconds).
-- The keys are the animation IDs – just change the number to adjust timing.
local ANIMATION_DELAYS = {
    -- BaseCombat
    ["113961476814500"] = 0.1, -- 1stM1
    ["82165070516177"] = 0.1,  -- 2ndM1
    ["138197524717835"] = 0.1, -- 3rdM1
    ["81174027972159"] = 0.1,  -- 4thM1
    ["113480104450803"] = 0.1, -- M2

    -- Basic
    ["83491849294956"] = 0.1,  -- 1stM1
    ["89420531853362"] = 0.1,  -- 2ndM1
    ["83730275893449"] = 0.1,  -- 3rdM1
    ["106980660082799"] = 0.1, -- 4thM1
    ["78888626472394"] = 0.1,  -- M2

    -- Boxing
    ["137980914350618"] = 0.1, -- 1stM1
    ["100408082509740"] = 0.1, -- 2ndM1
    ["94803478352691"] = 0.1,  -- 3rdM1
    ["78695517680318"] = 0.1,  -- 4thM1
    ["132022052139564"] = 0.1, -- M2

    -- Capoeira
    ["125976167173936"] = 0.1, -- 1stM1
    ["134945199381140"] = 0.1, -- 2ndM1
    ["117877243065533"] = 0.1, -- 3rdM1
    ["106965238908791"] = 0.1, -- 4thM1
    ["131071815103338"] = 0.1, -- M2

    -- Hakari
    ["76236532060812"] = 0.1,  -- 1stM1
    ["74206130671324"] = 0.1,  -- 2ndM1
    ["71919935695307"] = 0.1,  -- 3rdM1
    ["122861547142657"] = 0.1, -- 4thM1
    ["92851992709496"] = 0.1,  -- M2

    -- HakariOther
    ["126612786608030"] = 0.1, -- 1stM1
    ["113719263885794"] = 0.1, -- 2ndM1
    ["136305578634960"] = 0.1, -- 3rdM1
    ["89039586375625"] = 0.1,  -- 4thM1
    ["101619248052969"] = 0.1, -- M2

    -- Karate
    ["137837926745158"] = 0.1, -- 1stM1
    ["100981571094705"] = 0.1, -- 2ndM1
    ["130865087635587"] = 0.1, -- 3rdM1
    ["86495068205420"] = 0.1,  -- 4thM1
    ["120393553812903"] = 0.1, -- M2

    -- Kure
    ["82904229252991"] = 0.1,  -- 1stM1
    ["103732110215321"] = 0.1, -- 2ndM1
    ["103964436023727"] = 0.1, -- 3rdM1
    ["71676634048602"] = 0.1,  -- 4thM1
    ["102407060635393"] = 0.1, -- M2

    -- MuayThai
    ["96726284968458"] = 0.1,  -- 1stM1
    ["139911027872047"] = 0.1, -- 2ndM1
    ["104515319350296"] = 0.1, -- 3rdM1
    ["74960202100098"] = 0.1,  -- 4thM1
    ["137034747040618"] = 0.1, -- M2

    -- Slugger
    ["134829666925953"] = 0.1, -- 1stM1
    ["104867156139010"] = 0.1, -- 2ndM1
    ["112759168172605"] = 0.1, -- 3rdM1
    ["77710266587706"] = 0.1,  -- 4thM1
    ["118943955490014"] = 0.1, -- M2

    -- Striker
    ["127909081017342"] = 0.1, -- 1stM1
    ["79563637573277"] = 0.1,  -- 2ndM1
    ["118070233153900"] = 0.1, -- 3rdM1
    ["81174027972159"] = 0.1,  -- 4thM1
    ["114364673509520"] = 0.1, -- M2

    -- Wrestling
    ["82903450925391"] = 0.1,  -- 1stM1
    ["119685134442395"] = 0.1, -- 2ndM1
    ["107464726433388"] = 0.1, -- 3rdM1
    ["91485623489753"] = 0.1,  -- 4thM1
    ["73748315742870"] = 0.1,  -- M2
}

-- Perfect block animations (early release)
local PERFECT_BLOCK_LIST = {
    "96600699015093", "90752347516770", "82979105739696", "96304721384743",
    "138519505081692"
}

-- ===== BUILD LOOKUPS =====
-- Build attack lookup directly from ANIMATION_DELAYS keys (no duplicate lists!)
local ATTACK_LOOKUP = {}
for animId, _ in pairs(ANIMATION_DELAYS) do
    ATTACK_LOOKUP[animId] = true
end

local function buildLookup(list)
    local t = {}
    for _, id in ipairs(list) do t[id] = true end
    return t
end

local perfectLookup = buildLookup(PERFECT_BLOCK_LIST)

-- ===== INTERNAL STATE =====
local running = false
local isBlocking = false
local blockStartTime = 0
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

    local currentTime = tick()
    local detectedAnimations = {}   -- enemy -> {startTime, delay}

    -- 1. Check enemies
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
                                        if animId and ATTACK_LOOKUP[animId] then
                                            if not detectedAnimations[enemy] then
                                                local delay = ANIMATION_DELAYS[animId] or 0.1
                                                detectedAnimations[enemy] = {
                                                    startTime = currentTime,
                                                    delay = delay
                                                }
                                                addLabel(enemy)
                                            end
                                            break
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

    -- Remove labels for enemies not attacking
    for enemy, _ in pairs(debugLabels) do
        if not detectedAnimations[enemy] then
            removeLabel(enemy)
        end
    end

    -- 2. Check if any animation's delay has passed
    local shouldBlockNow = false
    for _, data in pairs(detectedAnimations) do
        if (currentTime - data.startTime) >= data.delay then
            shouldBlockNow = true
            break
        end
    end

    -- 3. Perfect block early release
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

    -- 4. Block logic
    if shouldBlockNow and not isBlocking then
        setBlock(true)
        blockStartTime = currentTime
    end

    if isBlocking then
        if earlyUnblock then
            setBlock(false)
            blockStartTime = 0
        elseif currentTime - blockStartTime >= BLOCK_HOLD_DURATION then
            setBlock(false)
            blockStartTime = 0
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
    for enemy, _ in pairs(debugLabels) do
        removeLabel(enemy)
    end
end

return module
