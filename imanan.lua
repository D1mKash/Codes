local module = {}
local inputConnection = nil
local currentToken = 0

function module.Start()
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local VIM = game:GetService("VirtualInputManager")
    local Workspace = game:GetService("Workspace")
    local Live = Workspace:WaitForChild("Live")
    local plr = Players.LocalPlayer

    local function isAbilityReady(abilityName)
        local backpack = plr:FindFirstChild("Backpack")
        if not backpack then return false end
        local config = backpack:FindFirstChild(abilityName)
        if not config or not config:IsA("Configuration") then return false end
        local cooldown = config:GetAttribute("COOLDOWN")
        if cooldown == nil or cooldown == 20 then
            return true
        end
        return false
    end

    local function clickMouse()
        VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait(0.05)
        VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end

    inputConnection = UIS.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end

        local abilityName = nil
        if input.KeyCode == Enum.KeyCode.One then abilityName = "Bisecting Slash"
        elseif input.KeyCode == Enum.KeyCode.Two then abilityName = "7:3 Combo"
        elseif input.KeyCode == Enum.KeyCode.Three then abilityName = "Hair Grab"
        elseif input.KeyCode == Enum.KeyCode.Four then abilityName = "Retirement Kick"
        end

        if not abilityName then return end
        if not isAbilityReady(abilityName) then return end

        -- Generate a unique token for this execution to cancel old ones
        currentToken = currentToken + 1
        local myToken = currentToken

        task.spawn(function()
            -- Find the Cutter GUI
            local cutter = nil
            local cutGUI = Live:FindFirstChild("NanamiCutGUI")
            if cutGUI then
                local mainBar = cutGUI:FindFirstChild("MainBar")
                if mainBar then
                    cutter = mainBar:FindFirstChild("Cutter")
                end
            end

            -- If not found, wait for it (timeout after 2 seconds)
            local timeout = tick() + 2
            while not cutter and tick() < timeout do
                if myToken ~= currentToken then return end -- Cancelled by a new key press

                cutGUI = Live:FindFirstChild("NanamiCutGUI")
                if cutGUI then
                    local mainBar = cutGUI:FindFirstChild("MainBar")
                    if mainBar then
                        cutter = mainBar:FindFirstChild("Cutter")
                    end
                end
                task.wait(0.05) -- Check every 50ms
            end

            if not cutter then return end

            -- Wait for the cutter to reach the threshold
            while cutter and cutter.Position.X.Scale < 0.7 do
                if myToken ~= currentToken then return end -- Cancelled
                task.wait(0.05) -- Check every 50ms instead of every frame
            end

            if cutter and cutter.Position.X.Scale >= 0.7 then
                clickMouse()
            end
        end)
    end)
end

function module.Stop()
    if inputConnection then
        inputConnection:Disconnect()
        inputConnection = nil
    end
    -- Increment token to cancel any pending spawns
    currentToken = currentToken + 1
end

return module
