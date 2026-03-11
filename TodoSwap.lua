local module = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local LIVE = Workspace:WaitForChild("Live")

local lockedPart = nil
local lockConnection
local inputConnection

local function press4()
    VirtualInputManager:SendKeyEvent(true,Enum.KeyCode.Four,false,game)
    VirtualInputManager:SendKeyEvent(false,Enum.KeyCode.Four,false,game)
end

local function isVisible(part)

    local origin = Camera.CFrame.Position
    local direction = part.Position - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { player.Character }

    local result = Workspace:Raycast(origin,direction,params)

    return result and result.Instance:IsDescendantOf(part.Parent)

end

local function getClosestHead()

    local closestPart = nil
    local shortestDistance = math.huge

    local screenCenter = Vector2.new(
        Camera.ViewportSize.X/2,
        Camera.ViewportSize.Y/2
    )

    for _,model in pairs(LIVE:GetChildren()) do

        if model:IsA("Model") and model ~= player.Character then

            local plr = Players:FindFirstChild(model.Name)

            if plr and player.Team and plr.Team == player.Team then
                continue
            end

            local head = model:FindFirstChild("Head")
            local blocking = model:FindFirstChild("Blocking")

            if head and blocking and blocking.Value == false then

                local screenPos,onScreen = Camera:WorldToScreenPoint(head.Position)

                if onScreen and isVisible(head) then

                    local distance = (Vector2.new(screenPos.X,screenPos.Y) - screenCenter).Magnitude

                    if distance < shortestDistance then
                        shortestDistance = distance
                        closestPart = head
                    end

                end

            end

        end

    end

    return closestPart

end

local function startLock()

    if lockConnection then
        lockConnection:Disconnect()
    end

    lockConnection = RunService.RenderStepped:Connect(function()

        if lockedPart and lockedPart.Parent then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position,lockedPart.Position)
        end

    end)

end

local function stopLock()

    if lockConnection then
        lockConnection:Disconnect()
        lockConnection = nil
    end

    lockedPart = nil

end

local function runCombo()

    lockedPart = getClosestHead()

    if not lockedPart then
        return
    end

    startLock()

    press4()

    local myCharacter = LIVE:FindFirstChild(player.Name)

    if not myCharacter then
        stopLock()
        return
    end

    local startTime = tick()
    local todoAppeared = false

    repeat

        if myCharacter:FindFirstChild("MyTodo") then
            todoAppeared = true
            break
        end

        task.wait()

    until tick() - startTime >= 3

    if not todoAppeared then
        stopLock()
        return
    end

    local enemyModel = lockedPart.Parent
    local blocking = enemyModel and enemyModel:FindFirstChild("Blocking")

    if blocking and blocking.Value == false then
        press4()
        task.wait(1)
    end

    stopLock()

end

function module.Start()

    if inputConnection then
        inputConnection:Disconnect()
    end

    inputConnection = UserInputService.InputBegan:Connect(function(input,gpe)

        if gpe then return end

        if input.KeyCode == Enum.KeyCode.Z then
            runCombo()
        end

    end)

end

function module.Stop()

    if inputConnection then
        inputConnection:Disconnect()
        inputConnection = nil
    end

    stopLock()

end

return module
