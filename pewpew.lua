local module = {}

-- Services
local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local plr = Players.LocalPlayer

-- Internal state
local connections = {}
local lastPressTime = 0
local PRESS_COOLDOWN = 0.05 -- Prevents spamming if animations fire rapidly

-- Simulates a key press (1 or 2)
local function pressKey(key)
    local now = tick()
    if now - lastPressTime < PRESS_COOLDOWN then return end
    lastPressTime = now

    VIM:SendKeyEvent(true, key, false, game)
    task.wait(0.05)
    VIM:SendKeyEvent(false, key, false, game)
end

-- Checks if a specific tool is in the player's Backpack
local function hasToolInBackpack(toolName)
    local backpack = plr:FindFirstChild("Backpack")
    if not backpack then return false end
    return backpack:FindFirstChild(toolName) ~= nil
end

-- Handles animation playback
local function onAnimationPlayed(animTrack)
    if not animTrack or not animTrack.Animation then return end

    local animId = animTrack.Animation.AnimationId
    if not animId then return end

    -- Check for Socom animations (press 1)
    if animId == "rbxassetid://128980851549763" or
       animId == "rbxassetid://122609664088954" or
       animId == "rbxassetid://75267484294449" then

        if hasToolInBackpack("Socom") then
            pressKey(Enum.KeyCode.One)
        end

    -- Check for Nikita/Stinger animation (press 2)
    elseif animId == "rbxassetid://1461252313" then

        if hasToolInBackpack("Nikita") or hasToolInBackpack("Stinger") then
            pressKey(Enum.KeyCode.Two)
        end
    end
end

-- Connects to a character's Humanoid
local function connectToCharacter(char)
    if not char then return end

    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local conn = humanoid.AnimationPlayed:Connect(onAnimationPlayed)
    table.insert(connections, conn)
end

-- Called when the player respawns
local function onCharacterAdded(char)
    connectToCharacter(char)
end

------------------------------------------------
-- PUBLIC METHODS (for ABAGui)
------------------------------------------------

function module.Start()
    -- Clear any old connections just in case
    module.Stop()

    -- If the character already exists, connect to it
    if plr.Character then
        connectToCharacter(plr.Character)
    end

    -- Listen for future respawns
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
    lastPressTime = 0
end

return module
