local module = {}

local connection

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
            task.wait(0.6)
            click()
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
