local module = {}

local connection
local holdingF = false

function module.Start()

    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local VIM = game:GetService("VirtualInputManager")
    local Workspace = game:GetService("Workspace")

    local player = Players.LocalPlayer
    local LIVE = Workspace:WaitForChild("Live")

    local previousHealth = 0
    local humanoid

    local function click()
        VIM:SendMouseButtonEvent(0,0,0,true,game,0)
        VIM:SendMouseButtonEvent(0,0,0,false,game,0)
    end

    local function pressF(state)
        VIM:SendKeyEvent(state,Enum.KeyCode.F,false,game)
    end

    local function connect(h)

        humanoid = h
        previousHealth = humanoid.Health

        connection = humanoid.HealthChanged:Connect(function(current)

            local damage = previousHealth - current
            previousHealth = current

            if damage > 0 and holdingF then
                pressF(false)
                click()
            end

        end)

    end

    if player.Character then
        connect(player.Character:WaitForChild("Humanoid"))
    end

    player.CharacterAdded:Connect(function(char)
        connect(char:WaitForChild("Humanoid"))
    end)

    UIS.InputBegan:Connect(function(i,g)
        if g then return end
        if i.KeyCode == Enum.KeyCode.F then
            holdingF = true
            pressF(true)
        end
    end)

    UIS.InputEnded:Connect(function(i)
        if i.KeyCode == Enum.KeyCode.F then
            holdingF = false
            pressF(false)
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
