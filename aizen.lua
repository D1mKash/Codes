local module = {}

local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local inputConnection

local function press3()
    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.Three, false, game)
    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Three, false, game)
end

local function randomDelay()
    return math.random(40,100) / 1000 -- 0.04 - 0.10
end

function module.Start()

    if inputConnection then
        inputConnection:Disconnect()
    end

    inputConnection = UserInputService.InputBegan:Connect(function(input,gpe)

        if gpe then return end

        if input.KeyCode == Enum.KeyCode.Two then

            task.delay(randomDelay(), function()
                press3()
            end)

        end

    end)

end

function module.Stop()

    if inputConnection then
        inputConnection:Disconnect()
        inputConnection = nil
    end

end

return module
