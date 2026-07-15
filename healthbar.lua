--[[
    Vertical Health Bars Module (Visibility‑based)
    - Bars fill from bottom to top (low health = bottom).
    - Bars are hidden when the character is off‑screen or behind walls.
    - Optimised: visibility updated every 0.2s; raycasts only for on‑screen chars.
    - Works for all players (including local).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local module = {}

-- Config
local VISIBILITY_UPDATE_INTERVAL = 0.2   -- seconds
local RAYCAST_MAX_DISTANCE = 200         -- max distance for raycast (far enough)

-- Internal state
local activeBars = {}          -- key = character, value = {billboard, connection, etc.}
local connections = {}
local visibilityRunning = false
local visibilityThread = nil

-- Helper: get the local player's camera
local function getCamera()
    local camera = Workspace.CurrentCamera
    if not camera then
        camera = Workspace:FindFirstChildOfClass("Camera")
    end
    return camera
end

-- Check if a character is visible (on‑screen and not occluded)
local function isCharacterVisible(character)
    local head = character:FindFirstChild("Head")
    if not head then return false end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end  -- dead = not visible

    local camera = getCamera()
    if not camera then return false end

    local headPos = head.Position
    local cameraPos = camera.CFrame.Position

    -- 1. Check if the head is in front of the camera and on‑screen
    local screenPoint, onScreen = camera:WorldToViewportPoint(headPos)
    if not onScreen then return false end

    -- 2. Raycast from camera to head to check for occlusion
    local direction = (headPos - cameraPos).Unit
    local distance = (headPos - cameraPos).Magnitude
    if distance > RAYCAST_MAX_DISTANCE then return false end

    -- Filter out the character itself (ignore all its parts) to avoid self‑block
    local ignoreList = {}
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            table.insert(ignoreList, part)
        end
    end

    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    raycastParams.FilterDescendantsInstances = ignoreList

    local hit = Workspace:Raycast(cameraPos, direction * distance, raycastParams)
    if hit then
        -- Something blocked the ray before reaching the head → not visible
        return false
    end

    return true
end

-- Update visibility for all active bars
local function updateAllVisibility()
    for character, data in pairs(activeBars) do
        if data.billboard then
            local visible = isCharacterVisible(character)
            data.billboard.Enabled = visible
        end
    end
end

-- Create a health bar for a character
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
    -- Initially visible (will be updated in the next cycle)
    billboard.Enabled = true

    -- Background
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    bg.BorderSizePixel = 0
    bg.Parent = billboard

    -- Health fill (bottom‑anchored)
    local fill = Instance.new("Frame")
    fill.AnchorPoint = Vector2.new(0, 1)
    fill.Position = UDim2.new(0, 0, 1, 0)
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 200, 50)
    fill.BorderSizePixel = 0
    fill.Parent = bg

    -- Border stroke
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(255, 255, 255)
    stroke.Thickness = 1
    stroke.Transparency = 0.5
    stroke.Parent = bg

    -- Update health values
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

-- Player added
local function onPlayerAdded(player)
    local function onCharacterAdded(character)
        task.wait(0.1)  -- wait for character to fully load
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

-- Start the visibility update loop
local function startVisibilityLoop()
    if visibilityRunning then return end
    visibilityRunning = true

    visibilityThread = task.spawn(function()
        while visibilityRunning do
            task.wait(VISIBILITY_UPDATE_INTERVAL)
            if visibilityRunning then
                updateAllVisibility()
            end
        end
    end)
end

-- Stop the visibility loop
local function stopVisibilityLoop()
    visibilityRunning = false
    if visibilityThread then
        task.cancel(visibilityThread)
        visibilityThread = nil
    end
end

-- Public API
function module.Start()
    module.Stop()  -- clean up any previous state

    -- Add bars for existing players
    for _, player in ipairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end

    -- Connect future players
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoved:Connect(onPlayerRemoved)

    -- Start the visibility update loop
    startVisibilityLoop()
end

function module.Stop()
    -- Stop the visibility loop
    stopVisibilityLoop()

    -- Disconnect all player connections
    for player, conn in pairs(connections) do
        conn:Disconnect()
    end
    connections = {}

    -- Destroy all bars
    for character, data in pairs(activeBars) do
        if data.connection then data.connection:Disconnect() end
        if data.billboard then data.billboard:Destroy() end
    end
    activeBars = {}
end

return module
