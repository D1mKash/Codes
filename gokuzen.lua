local module = {}

local Players = game:GetService("Players")
local VIM = game:GetService("VirtualInputManager")

local animationDelays = {
    ["rbxassetid://77102803675218"]  = 0.7,
    ["rbxassetid://86485944206392"]  = 1.0,
    ["rbxassetid://137127919224043"] = 0.6,
    ["rbxassetid://137954059657357"] = 0.45,
}

local player = Players.LocalPlayer
local character = player.Character
local animator = character and character:FindFirstChildOfClass("Animator")
local connections = {}
local pendingTasks = {}

local function click()
    VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
    VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
end

local function onAnimationPlayed(animationTrack)
    local animId = animationTrack.AnimationId
    local delay = animationDelays[animId]
    if not delay then return end

    local taskId = os.clock()
    pendingTasks[taskId] = task.delay(delay, function()
        pendingTasks[taskId] = nil
        click()
    end)
end

local function setupAnimator(newCharacter)
    if connections.animator then
        connections.animator:Disconnect()
        connections.animator = nil
    end
    if connections.character then
        connections.character:Disconnect()
        connections.character = nil
    end

    if newCharacter then
        character = newCharacter
    else
        character = player.Character
    end

    if not character then return end

    animator = character:FindFirstChildOfClass("Animator")
    if animator then
        connections.animator = animator.AnimationPlayed:Connect(onAnimationPlayed)
    end

    connections.character = character.AncestryChanged:Connect(function()
        if not character.Parent then
            if connections.animator then
                connections.animator:Disconnect()
                connections.animator = nil
            end
        end
    end)
end

function module.Start()
    -- Clear any existing setup
    module.Stop()

    -- Initial setup
    setupAnimator()

    -- Watch for character respawns
    connections.player = player.CharacterAdded:Connect(setupAnimator)
end

function module.Stop()
    for _, taskId in pairs(pendingTasks) do
        if taskId then
            task.cancel(taskId)
        end
    end
    pendingTasks = {}

    for _, conn in pairs(connections) do
        if conn then
            conn:Disconnect()
        end
    end
    connections = {}
end

return module
