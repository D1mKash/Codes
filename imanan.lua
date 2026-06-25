local _0xA = {}
local _0x1 = nil        -- Input listener
local _0x21 = nil       -- Active cooldown listener
local _0x20 = 0         -- Cancellation token for GUI scanning threads

function _0xA.Start()
    local Players = game:GetService("Players")
    local UIS = game:GetService("UserInputService")
    local VIM = game:GetService("VirtualInputManager")
    local Workspace = game:GetService("Workspace")
    local Live = Workspace:WaitForChild("Live")
    local plr = Players.LocalPlayer

    local backpack = plr:FindFirstChild("Backpack")
    if not backpack then backpack = plr:WaitForChild("Backpack") end

    -- Mapping keys to ability names (exactly as in Backpack)
    local abilityMap = {
        [Enum.KeyCode.One] = "Bisecting Slash",
        [Enum.KeyCode.Two] = "7:3 Combo",
        [Enum.KeyCode.Three] = "Hair Grab",
        [Enum.KeyCode.Four] = "Retirement Kick",
    }

    -- The core logic: wait for Nanami Cut GUI and click at 0.7
    local function triggerCut()
        -- Cancel any previous scanning thread
        _0x20 = _0x20 + 1
        local myToken = _0x20

        task.spawn(function()
            local cutter = nil
            local cutGUI = Live:FindFirstChild("NanamiCutGUI")

            if cutGUI then
                local mainBar = cutGUI:FindFirstChild("MainBar")
                if mainBar then cutter = mainBar:FindFirstChild("Cutter") end
            end

            -- Wait for the GUI to appear (max 2 seconds)
            local timeout = tick() + 2
            while not cutter and tick() < timeout do
                if myToken ~= _0x20 then return end -- Canceled
                cutGUI = Live:FindFirstChild("NanamiCutGUI")
                if cutGUI then
                    local mainBar = cutGUI:FindFirstChild("MainBar")
                    if mainBar then cutter = mainBar:FindFirstChild("Cutter") end
                end
                task.wait(0.05)
            end

            if not cutter then return end

            -- Wait for the bar to reach 0.7
            while cutter and cutter.Position.X.Scale < 0.7 do
                if myToken ~= _0x20 then return end
                task.wait(0.05)
            end

            -- Click!
            if cutter and cutter.Position.X.Scale >= 0.7 then
                VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0)
                task.wait(0.05)
                VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0)
            end
        end)
    end

    -- Cancels any ongoing "waiting for cooldown" listener
    local function cancelCooldownWatcher()
        if _0x21 then
            pcall(_0x21.Disconnect, _0x21)
            _0x21 = nil
        end
    end

    -- Input listener
    _0x1 = UIS.InputBegan:Connect(function(input, gp)
        if gp then return end

        local abilityName = abilityMap[input.KeyCode]
        if not abilityName then return end

        -- Find the ability config in backpack
        local config = backpack:FindFirstChild(abilityName)
        if not config or not config:IsA("Configuration") then return end

        local currentCooldown = config:GetAttribute("COOLDOWN")

        -- Only proceed if the move is ready (cooldown == 20 or nil)
        if currentCooldown ~= 20 and currentCooldown ~= nil then return end

        -- Cancel any previous cooldown watcher (prevents multiple listeners)
        cancelCooldownWatcher()

        -- Now listen for the cooldown to DROP (confirmation the move fired)
        local listenerToken = _0x20 + 1 -- Unique token for this specific watcher
        _0x21 = config:GetAttributeChangedSignal("COOLDOWN"):Connect(function()
            local newCooldown = config:GetAttribute("COOLDOWN")

            -- If cooldown dropped (from 20 to anything < 20), the move is confirmed!
            if newCooldown ~= nil and newCooldown < 20 then
                -- Disconnect this listener immediately
                cancelCooldownWatcher()
                -- Now start scanning for the Nanami Cut GUI
                triggerCut()
            end
        end)

        -- Safety net: if the cooldown doesn't drop within 3 seconds, kill the listener
        task.delay(3, function()
            -- Only kill if this specific listener is still active
            if _0x21 then
                pcall(_0x21.Disconnect, _0x21)
                _0x21 = nil
            end
        end)
    end)
end

function _0xA.Stop()
    -- Disconnect input listener
    if _0x1 then
        pcall(_0x1.Disconnect, _0x1)
        _0x1 = nil
    end

    -- Disconnect cooldown watcher
    if _0x21 then
        pcall(_0x21.Disconnect, _0x21)
        _0x21 = nil
    end

    -- Increment token to kill any active GUI scanning threads
    _0x20 = _0x20 + 1
end

return _0xA
