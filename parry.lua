--[[
    Auto Parry Module (Dynamic Animation Loader)
    - Scans enemies within 20 studs.
    - Holds F for 1 second when an enemy plays any animation from:
        * ReplicatedStorage.Animations.BaseCombat (1stM1, 2ndM1, 3rdM1, 4thM1, M2)
        * ReplicatedStorage.Animations.Combat/<any folder> (same 5 animations)
    - Resets the 1‑second timer on every new enemy attack.
    - Releases early if local player plays an animation from:
        * ReplicatedStorage.Animations.PerfectBlockAnims (any animation)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")

local module = {}

-- Configuration
local MAX_DISTANCE = 20
local BLOCK_KEY = Enum.KeyCode.F
local BLOCK_DURATION = 1        -- seconds to hold F
local DEBUG = true              -- show "ATTACKING" labels
local PERFECT_BLOCK_PATH = "Animations.PerfectBlockAnims"  -- change if needed

-- State variables
local running = false
local isBlocking = false
local blockStartTime = 0
local debugLabels = {}
local allowedAnimIds = {}       -- set of numeric IDs to parry
local perfectBlockIds = {}      -- set of numeric IDs for early release

-- Helper: collect all Animation IDs from a folder (recursive)
local function collectAnimationIds(folder, idSet)
    if not folder then return end
    for _, child in ipairs(folder:GetChildren()) do
        if child:IsA("Animation") then
            local id = child.AnimationId:match("%d+")
            if id then idSet[id] = true end
        elseif child:IsA("Folder") then
            collectAnimationIds(child, idSet)
        end
    end
end

-- Load all parry‑worthy animations from ReplicatedStorage
local function loadAnimationSets()
    allowedAnimIds = {}
    perfectBlockIds = {}

    local anims = ReplicatedStorage:FindFirstChild("Animations")
    if not anims then
        warn("Animations folder not found in ReplicatedStorage")
        return
    end

    -- 1. BaseCombat
    local base = anims:FindFirstChild("BaseCombat")
    if base then collectAnimationIds(base, allowedAnimIds) end

    -- 2. Combat subfolders
    local combat = anims:FindFirstChild("Combat")
    if combat then
        for _, sub in ipairs(combat:GetChildren()) do
            if sub:IsA("Folder") then
                collectAnimationIds(sub, allowedAnimIds)
            end
        end
    end

    -- 3. PerfectBlockAnims (early release)
    local perfect = anims:FindFirstChild("PerfectBlockAnims")
    if perfect then collectAnimationIds(perfect, perfectBlockIds) end

    if DEBUG then
        print(string.format("Loaded %d parry animations, %d perfect block animations",
            tableCount(allowedAnimIds), tableCount(perfectBlockIds)))
    end
end

-- Helper to count table size
local function tableCount(t)
    local c = 0
    for _ in pairs(t) do c = c + 1 end
    return c
end

-- Key simulation
local function setBlock(hold)
    if isBlocking == hold then return end
    isBlocking = hold
    if VirtualInputManager then
        VirtualInputManager:SendKeyEvent(hold, BLOCK_KEY, false, game)
    else
        _G.AutoBlock = hold
    end
end

-- Debug label management
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

-- Main scan function
local function scan()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end
    local char = localPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not root then return end

    local shouldBlock = false
    local attackingEnemies = {}   -- for debug label cleanup

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
                                        if animId and allowedAnimIds[animId] then
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
                        if animId and perfectBlockIds[animId] then
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
        -- Reset timer on every detection (keep blocking)
        blockStartTime = currentTime
        if not isBlocking then
            setBlock(true)   -- hold F
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

-- Start the module
function module.Start()
    if running then return end
    running = true

    -- Load animation IDs from ReplicatedStorage
    loadAnimationSets()

    -- Run scan immediately and then every 0.1 sec
    scan()
    task.spawn(function()
        while running do
            task.wait(0.01)
            if running then scan() end
        end
    end)
end

-- Stop the module
function module.Stop()
    running = false
    setBlock(false)
    blockStartTime = 0
    for enemy, _ in pairs(debugLabels) do
        removeLabel(enemy)
    end
end

return module
