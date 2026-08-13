local m = {}

local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

-- Animation IDs and their click delays (in seconds)
local ANIMATION_CONFIG = {
    ["77102803675218"]  = 0.55,
    ["7806604118"]      = 0.55,
    ["86485944206392"]  = 1.1,
    ["137954059657357"] = 0.3,
    ["137127919224043"] = 0.2,
}

-- Build a quick lookup set
local targetSet = {}
for id, _ in pairs(ANIMATION_CONFIG) do
    targetSet[id] = true
end

-- Internal state
local connections = {}
local characterConnection = nil
local pendingThread = nil
local running = false

-- Helper: extract numeric ID from an animation string
local function getNumericId(animId)
    if not animId then return nil end
    return string.match(animId, "(%d+)$")
end

-- Simulate a left mouse click (executor‑specific)
local function doLeftClick()
    -- Most executors provide this function.
    -- If yours doesn't, uncomment the alternative block below.
    mouse1click()
end

--[[
-- Alternative using VirtualInputManager (if mouse1click isn't available):
local VIM = game:GetService("VirtualInputManager")
local function doLeftClick()
    VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end
--]]

-- Callback when an animation is played
local function onAnimationPlayed(track)
    if not running then return end
    if not track or not track.Animation then return end

    local animId = track.Animation.AnimationId
    if not animId then return end

    local numericId = getNumericId(animId)
    if not numericId or not targetSet[numericId] then return end

    local delay = ANIMATION_CONFIG[numericId]

    -- Cancel any previously scheduled click
    if pendingThread then
        task.cancel(pendingThread)
        pendingThread = nil
    end

    -- Schedule the new click
    pendingThread = task.spawn(function()
        task.wait(delay)

        -- Safety: if the thread was cancelled, do nothing
        if pendingThread ~= coroutine.running() then
            return
        end
        pendingThread = nil

        doLeftClick()
    end)
end

-- Connect to all animation sources in a character
local function connectToCharacter(character)
    if not character then return end

    -- Clear previous connections (if any)
    for _, conn in ipairs(connections) do
        pcall(conn.Disconnect, conn)
    end
    connections = {}

    local function hookAnimator(instance)
        if instance:IsA("Humanoid") or instance:IsA("Animator") or instance:IsA("AnimationController") then
            if instance.AnimationPlayed then
                local conn = instance.AnimationPlayed:Connect(onAnimationPlayed)
                table.insert(connections, conn)
            end
        end
    end

    -- Hook the Humanoid directly
    local hum = character:FindFirstChildOfClass("Humanoid")
    if hum then hookAnimator(hum) end

    -- Hook any Animator / AnimationController descendants
    for _, child in ipairs(character:GetDescendants()) do
        hookAnimator(child)
    end
end

-- Handle character spawns
local function onCharacterAdded(character)
    connectToCharacter(character)
end

-- Public API
function m.Start()
    if running then return end
    running = true

    if localPlayer.Character then
        connectToCharacter(localPlayer.Character)
    end

    characterConnection = localPlayer.CharacterAdded:Connect(onCharacterAdded)
end

function m.Stop()
    running = false

    for _, conn in ipairs(connections) do
        pcall(conn.Disconnect, conn)
    end
    connections = {}

    if characterConnection then
        characterConnection:Disconnect()
        characterConnection = nil
    end

    if pendingThread then
        task.cancel(pendingThread)
        pendingThread = nil
    end
end

return m
