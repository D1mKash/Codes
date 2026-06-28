local module = {}

local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local plr = Players.LocalPlayer

local connections = {}

-- Press a key with a very short hold
local function pressKey(key)
    VIM:SendKeyEvent(true, key, false, game)
    task.wait(0.01)
    VIM:SendKeyEvent(false, key, false, game)
end

-- Check if a tool is in the backpack
local function hasToolInBackpack(toolName)
    local backpack = plr:FindFirstChild("Backpack")
    if not backpack then return false end
    return backpack:FindFirstChild(toolName) ~= nil
end

-- Check if any enemy (or dummy) is within range
local function isEnemyNearby(range)
    local char = plr.Character
    if not char then return false end

    -- Get the player's root part (try HumanoidRootPart, fallback to Torso for R6)
    local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not rootPart then return false end

    -- Wait for Live folder to exist (it may load later)
    local live = Workspace:FindFirstChild("Live")
    if not live then
        live = Workspace:WaitForChild("Live", 2) -- wait up to 2 seconds
        if not live then return false end
    end

    for _, model in pairs(live:GetChildren()) do
        if not model:IsA("Model") then continue end

        -- Skip self
        if model == char then continue end

        -- Skip teammates (if they are actual Players)
        local player = Players:FindFirstChild(model.Name)
        if player and plr.Team and player.Team and player.Team == plr.Team then
            continue
        end

        -- Check if the model has a Humanoid (to ensure it's a character)
        if not model:FindFirstChildOfClass("Humanoid") then continue end

        -- Get the opponent's root part (HumanoidRootPart or Torso)
        local otherRoot = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
        if otherRoot then
            local dist = (otherRoot.Position - rootPart.Position).Magnitude
            if dist <= range then
                return true
            end
        end
    end
    return false
end

-- Called when an animation plays on the character
local function onAnimationPlayed(animTrack)
    if not animTrack or not animTrack.Animation then return end

    local animId = animTrack.Animation.AnimationId
    if not animId then return end

    -- --- PRESS 1 (Socom) ---
    if animId == "rbxassetid://128980851549763" or
       animId == "rbxassetid://122609664088954" or
       animId == "rbxassetid://75267484294449" then

        if hasToolInBackpack("Socom") and isEnemyNearby(15) then
            pressKey(Enum.KeyCode.One)
        end

    -- --- PRESS 1 with 0.5s delay ---
    elseif animId == "rbxassetid://1461145506" then
        if hasToolInBackpack("Socom") and isEnemyNearby(15) then
            task.delay(0.5, function()
                pressKey(Enum.KeyCode.One)
            end)
        end

    -- --- PRESS 2 (Nikita / Stinger) ---
    elseif animId == "rbxassetid://1461252313" then
        if (hasToolInBackpack("Nikita") or hasToolInBackpack("Stinger")) and isEnemyNearby(15) then
            pressKey(Enum.KeyCode.Two)
        end
    end
end

-- Connect to a character's Humanoid
local function connectToCharacter(char)
    if not char then return end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        humanoid = char:WaitForChild("Humanoid", 5)
    end
    if not humanoid then return end

    local conn = humanoid.AnimationPlayed:Connect(onAnimationPlayed)
    table.insert(connections, conn)
end

local function onCharacterAdded(char)
    connectToCharacter(char)
end

-- Public methods
function module.Start()
    module.Stop()

    if plr.Character then
        connectToCharacter(plr.Character)
    end

    local charConn = plr.CharacterAdded:Connect(onCharacterAdded)
    table.insert(connections, charConn)
end

function module.Stop()
    for _, conn in ipairs(connections) do
        if conn then
            pcall(conn.Disconnect, conn)
        end
    end
    connections = {}
end

return module
