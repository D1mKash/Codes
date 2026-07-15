--[[V6 - Fixed Health Bars]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local module = {}

local MAX_DISTANCE = 20
local MAX_ENEMIES = 3
local UPDATE_INTERVAL = 0.5

local activeBars = {}   -- character -> {billboard, connection, ...}
local running = false

-- Helper: get root part
local function getRoot(char)
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
end

-- Create a single health bar (Enabled = false initially)
local function createBar(char)
    local hum = char:FindFirstChild("Humanoid")
    local head = char:FindFirstChild("Head")
    if not hum or not head then return nil end

    local bill = Instance.new("BillboardGui")
    bill.Size = UDim2.new(0, 20, 0, 60)
    bill.StudsOffset = Vector3.new(2, 0, 0)
    bill.Adornee = head
    bill.AlwaysOnTop = true
    bill.Enabled = false   -- start hidden
    bill.Parent = char

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    bg.BorderSizePixel = 0
    bg.Parent = bill

    local fill = Instance.new("Frame")
    fill.AnchorPoint = Vector2.new(0, 1)
    fill.Position = UDim2.new(0, 0, 1, 0)
    fill.Size = UDim2.new(1, 0, 1, 0)
    fill.BackgroundColor3 = Color3.fromRGB(0, 200, 50)
    fill.BorderSizePixel = 0
    fill.Parent = bg

    local function update()
        local health = hum.Health
        local maxHealth = hum.MaxHealth
        if maxHealth > 0 then
            local ratio = math.clamp(health / maxHealth, 0, 1)
            fill.Size = UDim2.new(1, 0, ratio, 0)
            if ratio > 0.5 then fill.BackgroundColor3 = Color3.fromRGB(0,200,50)
            elseif ratio > 0.25 then fill.BackgroundColor3 = Color3.fromRGB(255,200,0)
            else fill.BackgroundColor3 = Color3.fromRGB(255,50,50) end
        end
    end
    update()
    local conn = hum.HealthChanged:Connect(update)

    return { billboard = bill, connection = conn }
end

-- Add/remove bars as players come and go
local function addBar(char)
    if activeBars[char] then return end
    local data = createBar(char)
    if data then activeBars[char] = data end
end

local function removeBar(char)
    local data = activeBars[char]
    if data then
        data.connection:Disconnect()
        data.billboard:Destroy()
        activeBars[char] = nil
    end
end

-- Refresh visibility every 0.5s and on changes
local function updateVisibility()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end
    local selfChar = localPlayer.Character
    local selfRoot = selfChar and getRoot(selfChar)

    -- If we don't have a valid self, hide all bars and return
    if not selfChar or not selfRoot then
        for char, data in pairs(activeBars) do
            data.billboard.Enabled = false
        end
        return
    end

    -- Ensure self has a bar (always shown)
    addBar(selfChar)

    -- Collect distances for all OTHER characters that have bars
    local candidates = {}   -- char -> distance
    candidates[selfChar] = -1  -- self always visible

    for char, data in pairs(activeBars) do
        if char ~= selfChar then
            local root = getRoot(char)
            if root then
                local dist = (selfRoot.Position - root.Position).Magnitude
                if dist <= MAX_DISTANCE then
                    candidates[char] = dist
                end
            end
        end
    end

    -- Sort enemies by distance, pick closest MAX_ENEMIES
    local sorted = {}
    for char, dist in pairs(candidates) do
        if char ~= selfChar then
            table.insert(sorted, {char = char, dist = dist})
        end
    end
    table.sort(sorted, function(a,b) return a.dist < b.dist end)

    local visible = {}
    visible[selfChar] = true
    for i = 1, math.min(MAX_ENEMIES, #sorted) do
        visible[sorted[i].char] = true
    end

    -- Apply visibility to all bars
    for char, data in pairs(activeBars) do
        data.billboard.Enabled = visible[char] == true
    end
end

-- Player events
local function onPlayerAdded(player)
    -- When a new character appears, remove the old one first
    local function onCharAdded(char)
        -- Remove any existing bar for this player (in case of respawn)
        for existingChar, data in pairs(activeBars) do
            if existingChar ~= char and existingChar.Parent == player.Character then
                -- If the old character is still in activeBars, remove it
                -- (but it should have been destroyed already, just clean up)
                removeBar(existingChar)
            end
        end
        task.wait(0.1)  -- small delay to ensure everything loads
        addBar(char)
        -- Immediately update visibility for this new bar
        updateVisibility()
    end

    if player.Character then
        onCharAdded(player.Character)
    end
    player.CharacterAdded:Connect(onCharAdded)
end

local function onPlayerRemoved(player)
    if player.Character then
        removeBar(player.Character)
    end
end

-- Main loop
local function startLoop()
    -- Run an initial update immediately
    updateVisibility()
    task.spawn(function()
        while running do
            task.wait(UPDATE_INTERVAL)
            if running then updateVisibility() end
        end
    end)
end

-- Public API
function module.Start()
    if running then return end
    running = true

    for _, player in ipairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoved:Connect(onPlayerRemoved)

    startLoop()
end

function module.Stop()
    running = false
    for char, data in pairs(activeBars) do
        data.connection:Disconnect()
        data.billboard:Destroy()
    end
    activeBars = {}
end

return module
