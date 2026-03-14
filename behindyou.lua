-- Module: AutoBackHit
local module = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer

local trackedWalls = {}
local connection

-- Config
local LIVE_FOLDER = workspace:WaitForChild("Live")
local WALL_WIDTH = 15
local WALL_HEIGHT = 8
local WALL_THICK = 1
local WALL_OFFSET = 3
local MAX_DISTANCE = 10

------------------------------------------------
-- HELPER: click left mouse
------------------------------------------------
local function clickLeft()
    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,0)
    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,0)
end

------------------------------------------------
-- CREATE WALL FOR AN OBJECT
------------------------------------------------
local function createWall(objRoot)
    local wall = Instance.new("Part")
    wall.Size = Vector3.new(WALL_WIDTH, WALL_HEIGHT, WALL_THICK)
    wall.Anchored = true
    wall.CanCollide = false
    wall.Transparency = 1 -- invisible
    wall.Parent = workspace

    local inside = false

    -- remove wall if object dies (Humanoid)
    local humanoid = objRoot.Parent:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.Died:Connect(function()
            wall:Destroy()
        end)
    end

    return {
        Wall = wall,
        ObjRoot = objRoot,
        Inside = inside
    }
end

------------------------------------------------
-- START MODULE
------------------------------------------------
function module.Start(teammate)
    trackedWalls = {}

    for _, obj in ipairs(LIVE_FOLDER:GetChildren()) do
        local hrp = obj:FindFirstChild("HumanoidRootPart")
        if hrp and obj ~= player.Character and obj ~= teammate then
            table.insert(trackedWalls, createWall(hrp))
        end
    end

    connection = RunService.RenderStepped:Connect(function()
        local char = player.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        for _, data in ipairs(trackedWalls) do
            local wall = data.Wall
            local objRoot = data.ObjRoot
            if not objRoot or not objRoot.Parent then
                if wall then wall:Destroy() end
                continue
            end

            local wallCF = objRoot.CFrame * CFrame.new(0,0,WALL_OFFSET)
            wall.CFrame = wallCF

            local relative = wallCF:PointToObjectSpace(root.Position)
            local distance = relative.Magnitude

            local inZone = (relative.Z > 0 and distance <= MAX_DISTANCE)

            if inZone and not data.Inside then
                clickLeft()
                data.Inside = true
            elseif not inZone then
                data.Inside = false
            end
        end
    end)
end

------------------------------------------------
-- STOP MODULE
------------------------------------------------
function module.Stop()
    if connection then
        connection:Disconnect()
        connection = nil
    end

    for _, data in ipairs(trackedWalls) do
        if data.Wall then
            data.Wall:Destroy()
        end
    end

    trackedWalls = {}
end

return module
