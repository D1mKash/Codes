local module = {}

local connection

------------------------------------------------
-- CHECK CONFIG
------------------------------------------------

local function canUseTwo()

    local player = game:GetService("Players").LocalPlayer
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return false end

    local config = backpack:FindFirstChild("Black Flash") 
        or backpack:FindFirstChild("Taijutsu Combo")

    if not config or not config:IsA("Configuration") then
        return false
    end

    local cd = config:GetAttribute("COOLDOWN")

    if cd == nil or cd == 20 then
        return true
    end

    return false
end

------------------------------------------------
-- START
------------------------------------------------

function module.Start()

    local UIS = game:GetService("UserInputService")
    local VIM = game:GetService("VirtualInputManager")

    local function click()
        VIM:SendMouseButtonEvent(0,0,0,true,game,0)
        VIM:SendMouseButtonEvent(0,0,0,false,game,0)
    end

    connection = UIS.InputBegan:Connect(function(input,gpe)

        if gpe then return end

        if input.KeyCode == Enum.KeyCode.Two then

            if not canUseTwo() then
                return
            end

            task.wait(0.6)
            click()

        end

    end)

end

------------------------------------------------
-- STOP
------------------------------------------------

function module.Stop()

    if connection then
        connection:Disconnect()
        connection = nil
    end

end

return module
