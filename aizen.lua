local module = {}

local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local inputConnection
local ignoreInput = false

local function pressKey(key)
    VirtualInputManager:SendKeyEvent(true, key, false, game)
    VirtualInputManager:SendKeyEvent(false, key, false, game)
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
        if ignoreInput then return end

        if input.KeyCode == Enum.KeyCode.Two then

            ignoreInput = true

            task.delay(randomDelay(),function()
                pressKey(Enum.KeyCode.Three)
                task.wait(0.05)
                ignoreInput = false
            end)

        elseif input.KeyCode == Enum.KeyCode.Three then

            ignoreInput = true

            task.delay(randomDelay(),function()
                pressKey(Enum.KeyCode.Two)
                task.wait(0.05)
                ignoreInput = false
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
