local module = {}

local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local inputConnection
local internalPress = false

local function pressKey(key)
    VirtualInputManager:SendKeyEvent(true, key, false, game)
    VirtualInputManager:SendKeyEvent(false, key, false, game)
end

local function randomDelay()
    return 0.04 + math.random() * (0.1 - 0.04)
end

function module.Start()

    if inputConnection then
        inputConnection:Disconnect()
    end

    inputConnection = UserInputService.InputBegan:Connect(function(input, gpe)

        if gpe then return end
        if internalPress then return end

        if input.KeyCode == Enum.KeyCode.Two then

            internalPress = true
            task.delay(randomDelay(), function()
                pressKey(Enum.KeyCode.Three)
                internalPress = false
            end)

        elseif input.KeyCode == Enum.KeyCode.Three then

            internalPress = true
            task.delay(randomDelay(), function()
                pressKey(Enum.KeyCode.Two)
                internalPress = false
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
