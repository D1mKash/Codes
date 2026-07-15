--[[
    Auto Parry Module (Hardcoded IDs)
    - Holds F for 1 second when an enemy within 20 studs plays any animation from the PARRY_LIST.
    - Resets the 1‑second timer on every new enemy attack.
    - Releases early if the local player plays any animation from PERFECT_BLOCK_LIST.
    - DEBUG = true shows "ATTACKING" labels above enemies.
]]

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")

local module = {}

-- ===== CONFIGURATION =====
local MAX_DISTANCE = 20
local BLOCK_KEY = Enum.KeyCode.F
local BLOCK_DURATION = 1          -- seconds to hold F
local DEBUG = true                -- set false to hide debug labels

-- All animations that trigger a parry (enemy attacks)
local PARRY_LIST = {
    "83491849294956", "89420531853362", "83730275893449", "106980660082799",
    "78888626472394", "76236532060812", "74206130671324", "71919935695307",
    "122861547142657", "92851992709496", "126612786608030", "113719263885794",
    "136305578634960", "89039586375625", "101619248052969", "137837926745158",
    "100981571094705", "130865087635587", "86495068205420", "120393553812903",
    "82904229252991", "103732110215321", "103964436023727", "71676634048602",
    "102407060635393", "96726284968458", "139911027872047", "104515319350296",
    "74960202100098", "137034747040618", "134829666925953", "104867156139010",
    "101347661150789", "114647502301740", "118943955490014", "127909081017342",
    "79563637573277", "118070233153900", "98462236639320", "77710266587706",
    "122451562066756", "114364673509520", "82903450925391", "119685134442395",
    "107464726433388", "91485623489753", "73748315742870"
}

-- Animations that cancel the block immediately (perfect blocks)
local PERFECT_BLOCK_LIST = {
    "96600699015093", "90752347516770", "82979105739696", "96304721384743",
    "138519505081692"
}

-- ===== INTERNAL STATE =====
local running = false
local isBlocking = false
local blockStartTime = 0
local debugLabels = {}

-- Convert list to a lookup table for O(1) checks
local function buildLookup(list)
    local t = {}
    for _, id in ipairs(list) do
        t[id] = true
    end
    return t
end

local parryLookup = buildLookup(PARRY_LIST)
local perfectLookup = buildLookup(PERFECT_BLOCK_LIST)

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

    local shouldBlock = false
    local attackingEnemies = {}

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
                                        if animId and parryLookup[animId] then
                                            shouldBlock = true
                                            attackingEnemies[enemy] = true
                                            addLabel(enemy)
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
        if not attackingEnemies[enemy] then
            removeLabel(enemy)
        end
    end

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
    if shouldBlock then
        -- Reset timer on every detection
        blockStartTime = currentTime
        if not isBlocking then
            setBlock(true)
        end
    end

    if isBlocking then
        if earlyUnblock then
            setBlock(false)
            blockStartTime = 0
        elseif currentTime - blockStartTime >= BLOCK_DURATION then
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
            task.wait(0.1)
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
