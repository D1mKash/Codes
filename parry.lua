--[[
    Auto Parry Module (with debug label)
    - Scans nearby characters (≤20 studs) for specific animations.
    - When a matching animation plays:
        * Holds block key.
        * Shows a "Attacking" text above the enemy's head (debug).
    - Releases block and removes text when animation stops.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")  -- may be nil

local module = {}

-- CONFIG
local MAX_DISTANCE = 20
local ANIMATION_IDS = {
    "83491849294956", "89420531853362", "83730275893449", "106980660082799",
    "78888626472394", "76236532060812", "74206130671324", "71919935695307",
    "122861547142657", "92851992709496", "126612786608030", "113719263885794",
    "136305578634960", "89039586375625", "101619248052969", "137837926745158",
    "100981571094705", "130865087635587", "86495068205420", "120393553812903",
    "82904229252991", "103732110215321", "103964436023727", "71676634048602",
    "102407060635393", "96726284968458", "139911027872047", "104515319350296",
    "74960202100098", "137034747040618", "134829666925953", "104867156139010",
    "101347661150789", "114647502301740", "118943955490014", "127909081017342",
    "79563637573277", "118070233153900", "98462236639320", "77710266587706",
    "122451562066756", "114364673509520", "82903450925391", "119685134442395",
    "107464726433388", "91485623489753", "73748315742870"
}
local BLOCK_KEY = Enum.KeyCode.F

-- State
local running = false
local isBlocking = false
local debugLabels = {}  -- key = character, value = BillboardGui

-- Helper: set block key
local function setBlock(hold)
    if isBlocking == hold then return end
    isBlocking = hold
    if VirtualInputManager then
        VirtualInputManager:SendKeyEvent(hold, BLOCK_KEY, false, game)
    else
        _G.AutoBlock = hold
        warn("VirtualInputManager not available. Using _G.AutoBlock = " .. tostring(hold))
    end
end

-- Helper: check animation match
local function isMatchingAnimation(animationId)
    if type(animationId) ~= "string" then return false end
    local id = animationId:match("%d+")
    if id then
        for _, target in ipairs(ANIMATION_IDS) do
            if id == target then return true end
        end
    end
    return false
end

-- Debug: add "Attacking" label above a character
local function addDebugLabel(character)
    if debugLabels[character] then return end  -- already exists

    local head = character:FindFirstChild("Head")
    if not head then return end

    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.new(0, 80, 0, 30)
    billboard.StudsOffset = Vector3.new(0, 3, 0)  -- above head
    billboard.Adornee = head
    billboard.AlwaysOnTop = true
    billboard.Parent = character

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    label.BackgroundTransparency = 0.3
    label.Text = "ATTACKING"
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 18
    label.TextScaled = true
    label.Parent = billboard

    debugLabels[character] = billboard
end

-- Remove debug label
local function removeDebugLabel(character)
    local billboard = debugLabels[character]
    if billboard then
        billboard:Destroy()
        debugLabels[character] = nil
    end
end

-- Main scan
local function scan()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end

    local character = localPlayer.Character
    if not character then return end

    local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
    if not rootPart then return end

    local shouldBlock = false
    local attackingCharacters = {}  -- to update labels

    -- Scan all players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then
            local targetChar = player.Character
            if targetChar then
                local targetRoot = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Torso")
                if targetRoot and rootPart then
                    local distance = (rootPart.Position - targetRoot.Position).Magnitude
                    if distance <= MAX_DISTANCE then
                        local targetHumanoid = targetChar:FindFirstChild("Humanoid")
                        if targetHumanoid then
                            local animator = targetHumanoid:FindFirstChild("Animator")
                            if animator then
                                -- Check animations
                                local found = false
                                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                                    local anim = track.Animation
                                    if anim then
                                        local animId = anim.AnimationId
                                        if animId and isMatchingAnimation(animId) then
                                            found = true
                                            shouldBlock = true
                                            break
                                        end
                                    end
                                end
                                if found then
                                    attackingCharacters[targetChar] = true
                                    -- Add debug label
                                    addDebugLabel(targetChar)
                                else
                                    -- No matching animation, remove label if present
                                    removeDebugLabel(targetChar)
                                end
                            end
                        end
                    else
                        -- Out of range, remove label if present
                        removeDebugLabel(targetChar)
                    end
                end
            end
        end
    end

    -- Remove labels for characters no longer attacking or out of range
    for char, _ in pairs(debugLabels) do
        if not attackingCharacters[char] then
            removeDebugLabel(char)
        end
    end

    -- Apply block state
    setBlock(shouldBlock)
end

-- Start
function module.Start()
    if running then return end
    running = true
    scan()
    task.spawn(function()
        while running do
            task.wait(0.01)  -- scan every 100ms
            if running then scan() end
        end
    end)
end

-- Stop
function module.Stop()
    running = false
    setBlock(false)
    -- Remove all debug labels
    for char, _ in pairs(debugLabels) do
        removeDebugLabel(char)
    end
end

return module
