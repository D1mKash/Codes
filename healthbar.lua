--[[V3]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local module = {}

-- ===== CONFIGURATION =====
local MAX_DISTANCE = 20
local MAX_ENEMIES_SHOWN = 3
local SELF_REFRESH_INTERVAL = 30   -- seconds

-- Internal state
local activeBars = {}          -- character -> {billboard, connection, ...}
local connections = {}
local selfRefreshThread = nil
local running = false

-- Helper: get local player's root part
local function getRoot(character)
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
end

-- Create a health bar for a character (same as before)
local function createHealthBar(character)
    local humanoid = character:FindFirstChild("Humanoid")
    local head = character:FindFirstChild("Head")
    if not humanoid or not head then return nil end

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 20, 0, 60)
    billboard.StudsOffset = Vector3.new(2, 0, 0)
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    billboard.Parent = character
    billboard.Enabled = true

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    bg.BorderSizePixel = 0
    bg.Parent = billboard

    local fill = Instance.new("Frame")
    fill.AnchorPoint = Vector2.new(0, 1)
    fill.Position = UDim2.new(0, 0, 1, 0)
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 200, 50)
    fill.BorderSizePixel = 0
    fill.Parent = bg

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = bg

    local function updateHealth()
        local health = humanoid.Health
        local maxHealth = humanoid.MaxHealth
        if maxHealth > 0 then
            local ratio = math.clamp(health / maxHealth, 0, 1)
            fill.Size = UDim2.new(1, 0, ratio, 0)
            if ratio > 0.5 then
                fill.BackgroundColor3 = Color3.fromRGB(0, 200, 50)
            elseif ratio > 0.25 then
                fill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
            else
                fill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
            end
        end
    end

    updateHealth()
    local conn = humanoid.HealthChanged:Connect(updateHealth)

    return {
        billboard = billboard,
        connection = conn,
        humanoid = humanoid,
        character = character
    }
end

-- Add bar for a character
local function addBarForCharacter(character)
    if activeBars[character] then return end
    local data = createHealthBar(character)
    if data then
        activeBars[character] = data
    end
end

-- Remove bar for a character
local function removeBarForCharacter(character)
    local data = activeBars[character]
    if data then
        if data.connection then data.connection:Disconnect() end
        if data.billboard then data.billboard:Destroy() end
        activeBars[character] = nil
    end
end

-- Refresh self bar (remove and re-add)
local function refreshSelfBar()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end
    local char = localPlayer.Character
    if not char then return end
    removeBarForCharacter(char)
    addBarForCharacter(char)
end

-- Update visibility based on distance and closest enemies
local function updateVisibility()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end
    local selfChar = localPlayer.Character
    if not selfChar then return end
    local selfRoot = getRoot(selfChar)
    if not selfRoot then return end

    -- Compute distances for all characters that have bars
    local distances = {}
    for character, data in pairs(activeBars) do
        if character == selfChar then
            distances[character] = -1  -- self gets special treatment
        else
            local root = getRoot(character)
            if root then
                local dist = (selfRoot.Position - root.Position).Magnitude
                distances[character] = dist
            else
                distances[character] = math.huge
            end
        end
    end

    -- Sort enemies by distance, take closest up to MAX_ENEMIES_SHOWN
    local enemyList = {}
    for character, dist in pairs(distances) do
        if character ~= selfChar and dist <= MAX_DISTANCE then
            table.insert(enemyList, {char = character, dist = dist})
        end
    end
    table.sort(enemyList, function(a, b) return a.dist < b.dist end)

    local visibleEnemies = {}
    for i = 1, math.min(MAX_ENEMIES_SHOWN, #enemyList) do
        visibleEnemies[enemyList[i].char] = true
    end

    -- Apply visibility: self always visible, enemies only if in the visible set
    for character, data in pairs(activeBars) do
        local visible = (character == selfChar) or (visibleEnemies[character] == true)
        if data.billboard then
            data.billboard.Enabled = visible
        end
    end
end

-- Start the periodic visibility update (runs every 0.5s to avoid spam)
local function startVisibilityLoop()
    task.spawn(function()
        while running do
            task.wait(0.5)
            if running then updateVisibility() end
        end
    end)
end

-- Player added
local function onPlayerAdded(player)
    local function onCharacterAdded(character)
        task.wait(0.1)
        addBarForCharacter(character)
    end

    if player.Character then
        onCharacterAdded(player.Character)
    end

    local conn = player.CharacterAdded:Connect(onCharacterAdded)
    connections[player] = conn
end

-- Player removed
local function onPlayerRemoved(player)
    local conn = connections[player]
    if conn then conn:Disconnect() end
    connections[player] = nil

    if player.Character then
        removeBarForCharacter(player.Character)
    end
end

-- Public API
function module.Start()
    if running then return end
    running = true

    -- Add bars for existing players
    for _, player in ipairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end

    -- Connect future players
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoved:Connect(onPlayerRemoved)

    -- Start visibility loop
    startVisibilityLoop()

    -- Start self‑refresh timer
    selfRefreshThread = task.spawn(function()
        while running do
            task.wait(SELF_REFRESH_INTERVAL)
            if running then
                refreshSelfBar()
            end
        end
    end)
end

function module.Stop()
    running = false

    if selfRefreshThread then
        task.cancel(selfRefreshThread)
        selfRefreshThread = nil
    end

    -- Disconnect player connections
    for player, conn in pairs(connections) do
        conn:Disconnect()
    end
    connections = {}

    -- Remove all bars
    for character, data in pairs(activeBars) do
        if data.connection then data.connection:Disconnect() end
        if data.billboard then data.billboard:Destroy() end
    end
    activeBars = {}
end

return module
