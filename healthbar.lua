--[[
    Vertical Health Bars Module (Flipped)
    - Bar fills from bottom to top (low health = bottom)
    - Max render distance = 40 studs
    - Works for all players (including local)
]]

local Players = game:GetService("Players")

local module = {}

-- Track active billboards and connections
local activeBars = {}
local connections = {}

-- Create a single health bar GUI for a character
local function createHealthBar(character)
    local humanoid = character:FindFirstChild("Humanoid")
    local head = character:FindFirstChild("Head")
    if not humanoid or not head then return nil end

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 20, 0, 60)      -- width 20, height 60 (vertical)
    billboard.StudsOffset = Vector3.new(2, 0, 0)  -- right side of head
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.MaxDistance = 40                    -- 👈 hide beyond 40 studs
    billboard.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    billboard.Parent = character

    -- Background frame (dark)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    bg.BorderSizePixel = 0
    bg.Parent = billboard

    -- Health fill – anchored to the bottom so it grows upward
    local fill = Instance.new("Frame")
    fill.AnchorPoint = Vector2.new(0, 1)          -- 👈 bottom anchor
    fill.Position = UDim2.new(0, 0, 1, 0)        -- 👈 starts at bottom
    fill.Size = UDim2.new(1, 0, 1, 0)            -- will be updated
    fill.BackgroundColor3 = Color3.fromRGB(0, 200, 50) -- green
    fill.BorderSizePixel = 0
    fill.Parent = bg

    -- Optional thin border
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
            -- Fill from bottom: set height to ratio
            fill.Size = UDim2.new(1, 0, ratio, 0)

            -- Color change based on health
            if ratio > 0.5 then
                fill.BackgroundColor3 = Color3.fromRGB(0, 200, 50)   -- green
            elseif ratio > 0.25 then
                fill.BackgroundColor3 = Color3.fromRGB(255, 200, 0)  -- yellow
            else
                fill.BackgroundColor3 = Color3.fromRGB(255, 50, 50)  -- red
            end
        end
    end

    updateHealth()

    local conn = humanoid.HealthChanged:Connect(updateHealth)

    return {
        billboard = billboard,
        connection = conn,
        humanoid = humanoid
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

-- Start
function module.Start()
    module.Stop() -- cleanup first

    for _, player in ipairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end

    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoved:Connect(onPlayerRemoved)
end

-- Stop
function module.Stop()
    for player, conn in pairs(connections) do
        conn:Disconnect()
    end
    connections = {}

    for character, data in pairs(activeBars) do
        if data.connection then data.connection:Disconnect() end
        if data.billboard then data.billboard:Destroy() end
    end
    activeBars = {}
end

return module
