--[[
    Auto Parry Module
    - Scans nearby characters (≤20 studs) for specific animations.
    - When a matching animation plays, simulates holding the block key.
    - Releases block when all matching animations stop.
    - Ignores the local player's own animations.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")  -- may be nil in some executors

local module = {}

-- CONFIGURATION (change these as needed)
local MAX_DISTANCE = 20
local ANIMATION_IDS = {
    "83491849294956", -- 1st
    "89420531853362",
    "83730275893449", -- 3rd
    "106980660082799",
    "78888626472394", -- BASIC
    "76236532060812", -- 1st
    "74206130671324",
    "71919935695307", -- 3rd
    "122861547142657",
    "92851992709496", -- HAKARI
    "126612786608030", -- 1st
    "113719263885794",
    "136305578634960", -- 3rd
    "89039586375625",
    "101619248052969", -- ALT HAKARI
    "137837926745158", -- 1st
    "100981571094705",
    "130865087635587", -- 3rd
    "86495068205420",
    "120393553812903", -- KARATE
    "82904229252991", -- 1st
    "103732110215321",
    "103964436023727", -- 3rd
    "71676634048602",
    "102407060635393", -- KURE
    "96726284968458", -- 1st
    "139911027872047",
    "104515319350296", -- 3rd
    "74960202100098",
    "137034747040618", -- MUAY THAI
    "134829666925953", -- 1st
    "104867156139010",
    "101347661150789", -- 3rd
    "114647502301740",
    "118943955490014", -- SLUGGER
    "127909081017342", -- 1st
    "79563637573277",
    "118070233153900", -- 3rd
    "98462236639320", -- 3rd 2
    "77710266587706",
    "122451562066756",
    "114364673509520", -- STRIKER
    "82903450925391", -- 1st
    "119685134442395",
    "107464726433388", -- 3rd
    "91485623489753",
    "73748315742870", -- WRESTLING
}
local BLOCK_KEY = Enum.KeyCode.F   -- change to your block key

-- Internal state
local running = false
local loopConnection = nil
local isBlocking = false

-- Helper: simulate key press/release
local function setBlock(hold)
    if isBlocking == hold then return end
    isBlocking = hold

    if VirtualInputManager then
        -- Use VirtualInputManager for key simulation (works in most executors)
        VirtualInputManager:SendKeyEvent(hold, BLOCK_KEY, false, game)
        -- SendKeyEvent(bool down, KeyCode, bool ignore, Instance)
        -- For release, we send false
    else
        -- Fallback: set a global variable that your own script can listen to
        _G.AutoBlock = hold
        warn("VirtualInputManager not available. Using _G.AutoBlock = " .. tostring(hold))
    end
end

-- Check if an animation ID matches our list
local function isMatchingAnimation(animationId)
    if type(animationId) ~= "string" then return false end
    -- Extract numeric ID from the full path if needed (e.g., "rbxassetid://123")
    local id = animationId:match("%d+")
    if id then
        for _, target in ipairs(ANIMATION_IDS) do
            if id == target then return true end
        end
    end
    return false
end

-- Main scan function
local function scan()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then return end

    local character = localPlayer.Character
    if not character then return end

    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end

    local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
    if not rootPart then return end

    local shouldBlock = false

    -- Scan all players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer then  -- ignore self
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
                                -- Check all currently playing animation tracks
                                for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                                    local anim = track.Animation
                                    if anim then
                                        local animId = anim.AnimationId
                                        if animId and isMatchingAnimation(animId) then
                                            shouldBlock = true
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        if shouldBlock then break end
    end

    -- Apply block state
    setBlock(shouldBlock)
end

-- Start the module
function module.Start()
    if running then return end
    running = true

    -- Immediately scan once
    scan()

    -- Start loop (0.15 second interval for good responsiveness)
    loopConnection = RunService.Heartbeat:Connect(function(delta)
        if not running then return end
        -- Scan every ~0.15 seconds
        scan()
    end)
    -- Alternative: use a timer loop if Heartbeat is too frequent
    -- We'll use task.wait in a separate thread
    task.spawn(function()
        while running do
            task.wait(0.01)
            if running then scan() end
        end
    end)
end

-- Stop the module
function module.Stop()
    running = false
    if loopConnection then
        loopConnection:Disconnect()
        loopConnection = nil
    end
    -- Release block
    setBlock(false)
end

return module
