local module = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local lockedPart = nil
local aimConnection

local function isVisible(part)
    local origin = Camera.CFrame.Position
    local direction = part.Position - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { player.Character }

    local result = Workspace:Raycast(origin, direction, params)
    return result and result.Instance:IsDescendantOf(part.Parent)
end

local function getClosestHead()

    local closestPart = nil
    local shortestDistance = math.huge

    local screenCenter = Vector2.new(
        Camera.ViewportSize.X / 2,
        Camera.ViewportSize.Y / 2
    )

    for _, plr in ipairs(Players:GetPlayers()) do

        if plr == player then continue end
        if player.Team and plr.Team == player.Team then continue end

        local character = plr.Character

        if character and character:FindFirstChild("Head") then

            local head = character.Head

            if not isVisible(head) then continue end

            local screenPos, onScreen = Camera:WorldToScreenPoint(head.Position)

            if onScreen then

                local distance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude

                if distance < shortestDistance then
                    shortestDistance = distance
                    closestPart = head
                end

            end

        end

    end

    return closestPart

end

local function updateLock()

    if lockedPart and lockedPart.Parent then
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, lockedPart.Position)
    else
        lockedPart = nil
    end

end

function module.Start()

    if aimConnection then aimConnection:Disconnect() end

    aimConnection = RunService.RenderStepped:Connect(function()

        if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then

            if not lockedPart then
                lockedPart = getClosestHead()
            end

            if lockedPart then
                updateLock()
            end

        else
            lockedPart = nil
        end

    end)

end

function module.Stop()

    if aimConnection then
        aimConnection:Disconnect()
        aimConnection = nil
    end

    lockedPart = nil

end

return module
