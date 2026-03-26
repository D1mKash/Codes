local M={}

local P=game:GetService("Players")
local U=game:GetService("UserInputService")
local W=game:GetService("Workspace")
local R=game:GetService("RunService")

local plr=P.LocalPlayer
local cam=W.CurrentCamera
local L=W:WaitForChild("Live")

local l=nil
local c

local wB=false

local function v(p)
 local o=cam.CFrame.Position
 local d=p.Position-o
 local r=RaycastParams.new()
 r.FilterType=Enum.RaycastFilterType.Exclude
 r.FilterDescendantsInstances={plr.Character}
 local res=W:Raycast(o,d,r)
 return res and res.Instance:IsDescendantOf(p.Parent)
end

local function gC()
 local t=nil
 local s=math.huge
 local sc=Vector2.new(cam.ViewportSize.X/2,cam.ViewportSize.Y/2)
 for _,x in ipairs(P:GetPlayers()) do
  if x==plr then continue end
  if plr.Team and x.Team==plr.Team then continue end
  local char=x.Character
  if char and char:FindFirstChild("Head") then
   local h=char.Head
   if not v(h) then continue end
   local sp,onS=cam:WorldToScreenPoint(h.Position)
   if onS then
    local dist=(Vector2.new(sp.X,sp.Y)-sc).Magnitude
    if dist<s then s=dist t=h end
   end
  end
 end
 return t
end

local function gB()
 local m=L:FindFirstChild(plr.Name)
 if not m then return nil end
 return m:FindFirstChild("Blocking")
end

local function fF()
 if not l or not l.Parent then return end
 local ch=plr.Character
 if not ch then return end
 local r=ch:FindFirstChild("HumanoidRootPart")
 if not r then return end
 local t=l.Position
 local rp=r.Position
 r.CFrame=CFrame.new(rp,Vector3.new(t.X,rp.Y,t.Z))
end

local function wBTF()
 if wB then return end
 wB=true
 task.spawn(function()
  while U:IsKeyDown(Enum.KeyCode.F) do
   local b=gB()
   if b and b.Value then fF() break end
   task.wait()
  end
  wB=false
 end)
end

local function uL()
 if l and l.Parent then
  local cp=cam.CFrame.Position+Vector3.new(0,1,0)
  cam.CFrame=CFrame.new(cp,l.Position)
  if U:IsKeyDown(Enum.KeyCode.F) then
   local b=gB()
   if b and b.Value then fF() else wBTF() end
  end
 else
  l=nil
 end
end

function M.Start()
 if c then c:Disconnect() end
 c=R.RenderStepped:Connect(function()
  if U:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
   if not l then l=gC() end
   if l then uL() end
  else
   l=nil
  end
 end)
end

function M.Stop()
 if c then c:Disconnect() c=nil end
 l=nil
end

return M
