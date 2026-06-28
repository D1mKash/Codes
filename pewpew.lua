local module = {}

-- Services
local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")
local plr = Players.LocalPlayer

-- Internal state
local connections = {}

-- Simulates a key press (1 or 2) with 0.01s hold
local function pressKey(key)
    VIM:SendKeyEvent(true, key, false, game)
    task.wait(0.01)
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

    -- === PRESS 1 (Immediate) ===
    if animId == "rbxassetid://128980851549763" or
       animId == "rbxassetid://122609664088954" or
       animId == "rbxassetid://75267484294449" then

        if hasToolInBackpack("Socom") then
            pressKey(Enum.KeyCode.One)
        end

    -- === PRESS 1 (with 0.2s delay) ===
    elseif animId == "rbxassetid://1461145506" then

        if hasToolInBackpack("Socom") then
            task.delay(0.2, function()
                pressKey(Enum.KeyCode.One)
            end)
        end

    -- === PRESS 2 (Immediate) ===
    elseif animId == "rbxassetid://1461252313" then

        if hasToolInBackpack("Nikita") or hasToolInBackpack("Stinger") then
            pressKey(Enum.KeyCode.Two)
        end
    end
end

-- Connects to a character's Humanoid (waits for it to exist)
local function connectToCharacter(char)
    if not char then return end

    -- Wait for the Humanoid to load (fixes respawn issue)
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid then
        humanoid = char:WaitForChild("Humanoid", 5) -- Wait up to 5 seconds
    end
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
end

return module
