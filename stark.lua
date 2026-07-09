local m = {}

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VIM = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local LIVE = Workspace:WaitForChild("Live")

-- ==================== CONFIG ====================
local HEIGHT_OFFSET_BASE = -4
local HEIGHT_OFFSET_MAX = 3
local HEIGHT_RAMP_START = 1.0
local HEIGHT_RAMP_RATE = 5
local MAX_DIST = 15

-- ==================== STATE ====================
local running = false

-- Height match
local active = false
local heartbeat = nil
local offTimer = nil
local matchStartTime = 0

-- Damage combo
local waitingForDamage = false
local listeningForCombo = false
local damageTimer = nil

-- Connections
local damageConnection = nil
local damageValue = nil
local lastDamage = 0
local permanentConnections = {}
local characterAddedConn = nil
local characterRemovingConn = nil
local liveChildAddedConn = nil

-- Action monitor
local actionData = {}

-- ==================== HELPER FUNCTIONS ====================
local function getCharacter()
    return player.Character
end

local function pressKey(key)
    pcall(function()
        VIM:SendKeyEvent(true, key, false, game)
        task.wait(0.01)
        VIM:SendKeyEvent(false, key, false, game)
    end)
end

-- ==================== HEIGHT MATCH ====================
local function getNearestValidTarget()
    local char = getCharacter()
    if not char then return nil end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then return nil end

    local lilyName = "Lilynette-" .. player.Name
    local closest = nil
    local closestDist = MAX_DIST + 1

    for _, model in pairs(LIVE:GetChildren()) do
        if model == char then continue end
        if model.Name == lilyName then continue end
        local hum = model:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        local root = model:FindFirstChild("HumanoidRootPart")
        if not root then continue end

        local dist = (root.Position - myRoot.Position).Magnitude
        if dist < closestDist and dist <= MAX_DIST then
            closestDist = dist
            closest = model
        end
    end
    return closest
end

local function stopMatch()
    if not active then
        if offTimer then task.cancel(offTimer); offTimer = nil end
        return
    end
    active = false
    if offTimer then task.cancel(offTimer); offTimer = nil end
    if heartbeat then heartbeat:Disconnect(); heartbeat = nil end
end

local function startMatch()
    if active then return end

    active = true
    matchStartTime = os.clock()
    local char = getCharacter()
    if not char then active = false; return end
    local myRoot = char:FindFirstChild("HumanoidRootPart")
    if not myRoot then active = false; return end

    heartbeat = RunService.Heartbeat:Connect(function()
        if not active then return end

        local currentChar = getCharacter()
        if not currentChar then stopMatch(); return end
        local currentRoot = currentChar:FindFirstChild("HumanoidRootPart")
        if not currentRoot then stopMatch(); return end

        -- Ground check
        local hum = currentChar:FindFirstChildOfClass("Humanoid")
        if hum and hum.FloorMaterial ~= Enum.Material.Air then
            stopMatch()
            return
        end

        local target = getNearestValidTarget()
        if not target then stopMatch(); return end
        local targetRoot = target:FindFirstChild("HumanoidRootPart")
        if not targetRoot then stopMatch(); return end

        local elapsed = os.clock() - matchStartTime
        local offset = HEIGHT_OFFSET_BASE
        if elapsed > HEIGHT_RAMP_START then
            local extra = (elapsed - HEIGHT_RAMP_START) * HEIGHT_RAMP_RATE
            offset = math.min(HEIGHT_OFFSET_MAX, HEIGHT_OFFSET_BASE + extra)
        end

        local currentPos = currentRoot.Position
        local newY = targetRoot.Position.Y + offset
        local newCFrame = CFrame.new(Vector3.new(currentPos.X, newY, currentPos.Z)) * currentRoot.CFrame.Rotation
        currentRoot.CFrame = newCFrame
    end)
end

local function scheduleActionOff()
    if offTimer then task.cancel(offTimer); offTimer = nil end
    offTimer = task.spawn(function()
        task.wait(1)
        stopMatch()
    end)
end

-- ==================== ACTION MONITOR ====================
local function cleanupActionMonitor(char)
    local data = actionData[char]
    if data then
        if data.descConn then pcall(data.descConn.Disconnect, data.descConn) end
        if data.actionConn then pcall(data.actionConn.Disconnect, data.actionConn) end
        if data.removalConn then pcall(data.removalConn.Disconnect, data.removalConn) end
        actionData[char] = nil
    end
end

local function onActionRemoved(char)
    scheduleActionOff()
    cleanupActionMonitor(char)
end

local function onActionAdded(char, actionObj)
    local data = actionData[char]
    if not data then return end
    local skill = char:FindFirstChild("UsingSkill", true)
    if skill and skill:IsA("StringValue") and skill.Value == "Cero" then
        if offTimer then task.cancel(offTimer); offTimer = nil end
        startMatch()
        if data.actionConn then pcall(data.actionConn.Disconnect, data.actionConn) end
        data.actionConn = actionObj.AncestryChanged:Connect(function(_, parent)
            if parent == nil then
                onActionRemoved(char)
            end
        end)
    end
end

local function activateActionMonitor()
    local char = getCharacter()
    if not char then return end
    cleanupActionMonitor(char)

    local data = {}
    actionData[char] = data

    local action = char:FindFirstChild("Action", true)
    if action then
        onActionAdded(char, action)
    end

    data.descConn = char.DescendantAdded:Connect(function(desc)
        if desc.Name == "Action" then
            onActionAdded(char, desc)
        end
    end)

    data.removalConn = char.AncestryChanged:Connect(function(_, parent)
        if parent == nil then
            cleanupActionMonitor(char)
        end
    end)
end

-- ==================== DAMAGE DETECTION ====================
local function onDamageChanged()
    if not damageValue then return end
    local newDamage = damageValue.Value
    local inc = newDamage - lastDamage
    lastDamage = newDamage

    if waitingForDamage then
        if inc > 3 and inc < 5 then
            waitingForDamage = false
            if damageTimer then task.cancel(damageTimer); damageTimer = nil end
            listeningForCombo = true
        end
    end
end

local function startDamageWait()
    if waitingForDamage or listeningForCombo then return end

    waitingForDamage = true
    if damageTimer then task.cancel(damageTimer); damageTimer = nil end
    damageTimer = task.spawn(function()
        task.wait(0.7)
        if waitingForDamage then
            waitingForDamage = false
            damageTimer = nil
        end
    end)
end

-- ==================== ANIMATION LISTENER ====================
local function onAnimationPlayed(track)
    if not running then return end
    if not track or not track.Animation then return end
    local animId = track.Animation.AnimationId
    if not animId then return end
    local numericId = string.match(animId, "(%d+)$")
    if not numericId then return end

    if numericId == "1470447472" then
        startDamageWait()
    end

    if listeningForCombo then
        if numericId == "1461157246" then
            listeningForCombo = false
            if damageTimer then task.cancel(damageTimer); damageTimer = nil end
            pressKey(Enum.KeyCode.One)
        elseif numericId == "1470532199" then
            listeningForCombo = false
            if damageTimer then task.cancel(damageTimer); damageTimer = nil end
            pressKey(Enum.KeyCode.Three)
            task.wait(0.1)
            pressKey(Enum.KeyCode.Four)
            activateActionMonitor()
        end
    end
end

local function setupPermanentListener(char)
    for _, c in ipairs(permanentConnections) do
        pcall(c.Disconnect, c)
    end
    permanentConnections = {}

    local function connectToAnimator(animator)
        if animator and animator.AnimationPlayed then
            local c = animator.AnimationPlayed:Connect(onAnimationPlayed)
            table.insert(permanentConnections, c)
        end
    end

    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then connectToAnimator(hum) end
    for _, child in ipairs(char:GetDescendants()) do
        if child:IsA("Animator") or child:IsA("AnimationController") then
            connectToAnimator(child)
        end
    end
end

local function setupWatcher()
    if damageConnection then
        damageConnection:Disconnect()
        damageConnection = nil
    end

    local char = getCharacter()
    if not char then return end

    local dmg = char:FindFirstChild("DamageDone")
    if not dmg then
        local childConn
        childConn = char.ChildAdded:Connect(function(child)
            if child.Name == "DamageDone" then
                if childConn then childConn:Disconnect() end
                damageValue = child
                lastDamage = child.Value
                damageConnection = child.Changed:Connect(onDamageChanged)
            end
        end)
        return
    end

    damageValue = dmg
    lastDamage = dmg.Value
    damageConnection = damageValue:GetPropertyChangedSignal("Value"):Connect(onDamageChanged)
end

-- ==================== CHARACTER LIFECYCLE ====================
local function onCharacterAdded(char)
    task.wait(0.2)
    setupWatcher()
    setupPermanentListener(char)

    waitingForDamage = false
    listeningForCombo = false
    if damageTimer then task.cancel(damageTimer); damageTimer = nil end
    if active then stopMatch() end
    cleanupActionMonitor(char)
end

local function onCharacterRemoving(char)
    stopMatch()
    for _, c in ipairs(permanentConnections) do
        pcall(c.Disconnect, c)
    end
    permanentConnections = {}
    cleanupActionMonitor(char)
    waitingForDamage = false
    listeningForCombo = false
    if damageTimer then task.cancel(damageTimer); damageTimer = nil end
    if damageConnection then
        damageConnection:Disconnect()
        damageConnection = nil
    end
end

-- ==================== PUBLIC API ====================
function m.Start()
    if running then return end
    running = true

    -- Hook character events
    characterAddedConn = player.CharacterAdded:Connect(onCharacterAdded)
    characterRemovingConn = player.CharacterRemoving:Connect(onCharacterRemoving)

    -- Also watch Live folder for character (safety)
    liveChildAddedConn = LIVE.ChildAdded:Connect(function(child)
        if child:IsA("Model") and child.Name == player.Name then
            local current = player.Character
            if current and current == child then
                if not child:FindFirstChild("DamageDone") or not child:GetAttribute("_damageSetup") then
                    onCharacterAdded(child)
                    child:SetAttribute("_damageSetup", true)
                end
            end
        end
    end)

    -- Initial character if exists
    local char = player.Character
    if char then
        onCharacterAdded(char)
    end
end

function m.Stop()
    if not running then return end
    running = false

    -- Clean up all connections
    if characterAddedConn then
        characterAddedConn:Disconnect()
        characterAddedConn = nil
    end
    if characterRemovingConn then
        characterRemovingConn:Disconnect()
        characterRemovingConn = nil
    end
    if liveChildAddedConn then
        liveChildAddedConn:Disconnect()
        liveChildAddedConn = nil
    end

    -- Stop height match
    stopMatch()

    -- Clean up permanent animation connections
    for _, c in ipairs(permanentConnections) do
        pcall(c.Disconnect, c)
    end
    permanentConnections = {}

    -- Clean up damage watcher
    if damageConnection then
        damageConnection:Disconnect()
        damageConnection = nil
    end
    damageValue = nil
    lastDamage = 0

    -- Clean up action monitors
    local char = getCharacter()
    if char then
        cleanupActionMonitor(char)
    end

    -- Reset states
    waitingForDamage = false
    listeningForCombo = false
    if damageTimer then task.cancel(damageTimer); damageTimer = nil end
    active = false
    if offTimer then task.cancel(offTimer); offTimer = nil end
    if heartbeat then heartbeat:Disconnect(); heartbeat = nil end
end

return m
