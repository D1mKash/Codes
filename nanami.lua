local module = {}

local connection

------------------------------------------------
-- SKILL CHECK
------------------------------------------------

local function canUse(skillName)

    local player = game:GetService("Players").LocalPlayer
    local backpack = player:FindFirstChild("Backpack")
    if not backpack then return false end

    local config = backpack:FindFirstChild(skillName)

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
    local RunService = game:GetService("RunService")
    local VIM = game:GetService("VirtualInputManager")
    local Workspace = game:GetService("Workspace")

    local LIVE = Workspace:WaitForChild("Live")

    local function click()
        VIM:SendMouseButtonEvent(0,0,0,true,game,0)
        VIM:SendMouseButtonEvent(0,0,0,false,game,0)
    end

    connection = UIS.InputBegan:Connect(function(input,gpe)

        if gpe then return end

        local skillName = nil

        if input.KeyCode == Enum.KeyCode.One then
            skillName = "Bisecting Slash"
        elseif input.KeyCode == Enum.KeyCode.Two then
            skillName = "7:3 Combo"
        elseif input.KeyCode == Enum.KeyCode.Three then
            skillName = "Hair Grab"
        elseif input.KeyCode == Enum.KeyCode.Four then
            skillName = "Retirement Kick"
        end

        if not skillName then return end

        -- CHECK COOLDOWN
        if not canUse(skillName) then
            return
        end

        local cutter

        local guiConn
        guiConn = LIVE.DescendantAdded:Connect(function(inst)

            if inst.Name ~= "NanamiCutGUI" then return end

            local bar = inst:FindFirstChild("MainBar")
            local c = bar and bar:FindFirstChild("Cutter")

            if c then
                cutter = c
                guiConn:Disconnect()
            end

        end)

        local hb
        hb = RunService.Heartbeat:Connect(function()

            if not cutter then return end

            if cutter.Position.X.Scale >= 0.7 then
                click()
                hb:Disconnect()
            end

        end)

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
