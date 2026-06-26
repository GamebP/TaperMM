-- source/movement.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local Movement = {
    noclipConnection = nil,
    NoclipConnMaster = nil,
    FlyBV = nil,
    FlyConn = nil,
    WSConn = nil
}

function Movement.startNoclip()
    if Movement.noclipConnection then return end
    Movement.noclipConnection = RunService.Stepped:Connect(function()
        local character = LocalPlayer.Character
        if character then
            for _, part in ipairs(character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then
                    part.CanCollide = false
                end
            end
        end
    end)
end

function Movement.stopNoclip()
    if Movement.noclipConnection then
        Movement.noclipConnection:Disconnect()
        Movement.noclipConnection = nil
    end
end

function Movement.SetNoclip(state, configTable)
    configTable.Noclip = state
    if state then
        if Movement.NoclipConnMaster then Movement.NoclipConnMaster:Disconnect() end
        Movement.NoclipConnMaster = RunService.Stepped:Connect(function()
            local char = LocalPlayer.Character
            if char then
                for _, p in ipairs(char:GetDescendants()) do
                    if p:IsA("BasePart") and p.CanCollide then
                        p.CanCollide = false
                    end
                end
            end
        end)
    else
        if Movement.NoclipConnMaster then 
            Movement.NoclipConnMaster:Disconnect()
            Movement.NoclipConnMaster = nil 
        end
    end
end

function Movement.SetFly(state, configTable, getRootFunc)
    local root = getRootFunc()
    if not root then return end
    if state then
        if Movement.FlyBV then Movement.FlyBV:Destroy() end
        Movement.FlyBV = Instance.new("BodyVelocity")
        Movement.FlyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        Movement.FlyBV.Velocity = Vector3.zero
        Movement.FlyBV.Parent = root
        
        if Movement.FlyConn then Movement.FlyConn:Disconnect() end
        Movement.FlyConn = RunService.RenderStepped:Connect(function()
            local root2 = getRootFunc()
            if not root2 or not Movement.FlyBV then return end
            local cam = Camera.CFrame
            local move = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then move = move + cam.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then move = move - cam.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then move = move - cam.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then move = move + cam.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then move = move + Vector3.new(0,1,0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then move = move - Vector3.new(0,1,0) end
            Movement.FlyBV.Velocity = move.Unit * (move.Magnitude > 0 and configTable.FlySpeed or 0)
        end)
    else
        if Movement.FlyBV then Movement.FlyBV:Destroy(); Movement.FlyBV = nil end
        if Movement.FlyConn then Movement.FlyConn:Disconnect(); Movement.FlyConn = nil end
    end
end

function Movement.ApplyWalkSpeed(value, configTable, getHumanoidFunc)
    configTable.WalkSpeed = value
    local hum = getHumanoidFunc()
    if hum then hum.WalkSpeed = value end
    
    if Movement.WSConn then Movement.WSConn:Disconnect() end
    Movement.WSConn = LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.5)
        local h = getHumanoidFunc()
        if h then h.WalkSpeed = configTable.WalkSpeed end
    end)
end

function Movement.TweenTo(position, duration, getRootFunc, callback)
    local root = getRootFunc()
    if not root then return end
    local info = TweenInfo.new(duration or 0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
    local tween = TweenService:Create(root, info, { CFrame = CFrame.new(position) })
    tween:Play()
    if callback then
        task.spawn(function()
            tween.Completed:Wait()
            callback()
        end)
    end
    return tween
end

return Movement