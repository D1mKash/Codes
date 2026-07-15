--[[
    Vertical Health Bars Module
    Adds a vertical bar on the right side of every character's head.
    - Works for all players (including local player)
    - Updates automatically when health changes
    - Cleans up when stopped
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local module = {}

-- Track active billboards
local activeBars = {}   -- key = character, value = {gui, connection, etc.}
local connections = {}

-- Create a single health bar GUI for a character
local function createHealthBar(character)
    -- Ensure the character has a Humanoid and Head
    local humanoid = character:FindFirstChild("Humanoid")
    local head = character:FindFirstChild("Head")
    if not humanoid or not head then return nil end

    -- Create BillboardGui
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 20, 0, 60)   -- Width 20, Height 60 (vertical bar)
    billboard.StudsOffset = Vector3.new(2, 0, 0)  -- Offset to the right
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    billboard.Parent = character

    -- Background frame (dark)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    bg.BorderSizePixel = 0
    bg.Parent = billboard

    -- Health fill (vertical)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(1, 0, 1, 0)   -- will be updated
    fill.BackgroundColor3 = Color3.fromRGB(0, 200, 50)  -- green
    fill.BorderSizePixel = 0
    fill.Parent = bg

    -- Optional: add a thin border (UIStroke) for style
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = bg

    -- Update function
    local function updateHealth()
        local health = humanoid.Health
        local maxHealth = humanoid.MaxHealth
        if maxHealth > 0 then
            local ratio = math.clamp(health / maxHealth, 0, 1)
            fill.Size = UDim2.new(1, 0, ratio, 0)
            -- Change colour based on health
            if ratio > 0.5 then
                fill.BackgroundColor3 = Color3.fromRGB(0, 200, 50)   -- green
            elseif ratio > 0.25 then
                fill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)  -- yellow
            else
                fill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)  -- red
            end
        end
    end

    -- Initial update
    updateHealth()

    -- Connect health changed
    local conn = humanoid.HealthChanged:Connect(updateHealth)

    -- Store references for cleanup
    return {
        billboard = billboard,
        connection = conn,
        humanoid = humanoid
    }
end

-- Add a bar for a character (if not already added)
local function addBarForCharacter(character)
    if activeBars[character] then return end   -- already exists
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

-- Handle player added
local function onPlayerAdded(player)
    -- When character spawns, add bar
    local function onCharacterAdded(character)
        -- Wait a tiny bit to ensure Humanoid is fully loaded
        task.wait(0.1)
        addBarForCharacter(character)
    end

    -- If player already has a character, add immediately
    if player.Character then
        onCharacterAdded(player.Character)
    end

    -- Connect future character additions
    local conn = player.CharacterAdded:Connect(onCharacterAdded)
    connections[player] = conn
end

-- Handle player removed
local function onPlayerRemoved(player)
    local conn = connections[player]
    if conn then conn:Disconnect() end
    connections[player] = nil

    -- Remove any bars for this player's characters
    -- (We also need to remove the bar for the character if it exists)
    if player.Character then
        removeBarForCharacter(player.Character)
    end
end

-- Start the module: set up all players and events
function module.Start()
    -- Clear any previous state (just in case)
    module.Stop()

    -- Add bars for existing players
    for _, player in ipairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end

    -- Connect future players
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoved:Connect(onPlayerRemoved)
end

-- Stop the module: remove all bars and disconnect events
function module.Stop()
    -- Disconnect all player-added connections
    for player, conn in pairs(connections) do
        conn:Disconnect()
    end
    connections = {}

    -- Remove all existing bars
    for character, data in pairs(activeBars) do
        if data.connection then data.connection:Disconnect() end
        if data.billboard then data.billboard:Destroy() end
    end
    activeBars = {}
end

return module
