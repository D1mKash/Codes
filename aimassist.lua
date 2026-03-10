local module = {}

local connection

function module.Start()

    local Players = game:GetService("Players")
    local RunService = game:GetService("RunService")
    local UIS = game:GetService("UserInputService")
    local Workspace = game:GetService("Workspace")

    local player = Players.LocalPlayer
    local Camera = Workspace.CurrentCamera

    local locked

    local function getClosest()

        local closest
        local dist = math.huge
        local center = Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)

        for _,p in ipairs(Players:GetPlayers()) do
            if p ~= player and p.Character and p.Character:FindFirstChild("Head") then

                local pos,onScreen = Camera:WorldToScreenPoint(p.Character.Head.Position)

                if onScreen then
                    local d = (Vector2.new(pos.X,pos.Y)-center).Magnitude

                    if d < dist then
                        dist = d
                        closest = p.Character.Head
                    end
                end

            end
        end

        return closest

    end

    connection = RunService.RenderStepped:Connect(function()

        if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then

            if not locked then
                locked = getClosest()
            end

            if locked then
                Camera.CFrame = CFrame.new(Camera.CFrame.Position,locked.Position)
            end

        else
            locked = nil
        end

    end)

end

function module.Stop()

    if connection then
        connection:Disconnect()
        connection = nil
    end

end

return module
