-- source/farming.lua
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

local Farming = {
    AutoGunThread = nil,
    XPThread = nil,
    AFKThread = nil,
    ResetThread = nil,
    CoinThread = nil
}

function Farming.StartCoinFarm(configTable, stateTable, utils, movement)
    if Farming.CoinThread then return end
    Farming.CoinThread = task.spawn(function()
        local lastCoinContainer = nil
        while stateTable.scriptRunning do
            task.wait(0.2)
            if configTable.AutoCoin then
                local myChar = LocalPlayer.Character
                local hrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local coinContainer = utils.findCoinContainer(utils.MAP_NAMES or {})
                    if coinContainer then
                        if coinContainer ~= lastCoinContainer then
                            stateTable.visitedCoins = {}
                            lastCoinContainer = coinContainer
                        end

                        for _, v in ipairs(coinContainer:GetChildren()) do
                            if not configTable.AutoCoin or not stateTable.scriptRunning then break end
                            if v.Name == "Coin_Server" or v.Name == "Snowflake_Server" or v.Name == "Candy_Server" then
                                local coinPart = v:IsA("BasePart") and v or (v:FindFirstChild("Coin") or v:FindFirstChildOfClass("BasePart"))
                                
                                if coinPart and coinPart:IsDescendantOf(Workspace) and not stateTable.visitedCoins[coinPart] then
                                    if configTable.CoinMethod == "Teleport" then
                                        hrp.AssemblyLinearVelocity = Vector3.zero
                                        hrp.CFrame = coinPart.CFrame + Vector3.new(0, 1.2, 0)
                                        task.wait(0.18) 
                                        stateTable.visitedCoins[coinPart] = true
                                    elseif configTable.CoinMethod == "Smooth Fly" then
                                        local path = PathfindingService:CreatePath({
                                            AgentRadius = 2,
                                            AgentHeight = 5,
                                            AgentCanJump = true
                                        })
                                        local pathSuccess, _ = pcall(function()
                                            path:ComputeAsync(hrp.Position, coinPart.Position)
                                        end)
                                        
                                        if pathSuccess and path.Status == Enum.PathStatus.Success then
                                            local waypoints = path:GetWaypoints()
                                            movement.startNoclip()
                                            
                                            for _, waypoint in ipairs(waypoints) do
                                                if not configTable.AutoCoin or not stateTable.scriptRunning then break end
                                                local targetPos = waypoint.Position + Vector3.new(0, 1.2, 0)
                                                local distance = (hrp.Position - targetPos).Magnitude
                                                local speed = 30
                                                local duration = distance / speed
                                                
                                                hrp.AssemblyLinearVelocity = Vector3.zero
                                                local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(targetPos)})
                                                tween:Play()
                                                
                                                local completed = false
                                                local conn; conn = tween.Completed:Connect(function()
                                                    completed = true
                                                    conn:Disconnect()
                                                end)
                                                
                                                while not completed and configTable.AutoCoin and stateTable.scriptRunning do
                                                    task.wait()
                                                end
                                                if not configTable.AutoCoin or not stateTable.scriptRunning then
                                                    tween:Cancel()
                                                    break
                                                end
                                            end
                                            movement.stopNoclip()
                                            stateTable.visitedCoins[coinPart] = true
                                        else
                                            movement.startNoclip()
                                            local distance = (hrp.Position - coinPart.Position).Magnitude
                                            local speed = 30
                                            local duration = distance / speed
                                            
                                            hrp.AssemblyLinearVelocity = Vector3.zero
                                            local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = coinPart.CFrame + Vector3.new(0, 1.2, 0)})
                                            tween:Play()
                                            
                                            local completed = false
                                            local conn; conn = tween.Completed:Connect(function()
                                                completed = true
                                                conn:Disconnect()
                                            end)
                                            
                                            while not completed and configTable.AutoCoin and stateTable.scriptRunning do
                                                task.wait()
                                            end
                                            if not configTable.AutoCoin or not stateTable.scriptRunning then
                                                tween:Cancel()
                                            end
                                            movement.stopNoclip()
                                            stateTable.visitedCoins[coinPart] = true
                                        end
                                        task.wait(0.1)
                                    else
                                        if firetouchinterest then
                                            firetouchinterest(coinPart, hrp, 0)
                                            task.wait(0.01)
                                            firetouchinterest(coinPart, hrp, 1)
                                            task.wait(0.05)
                                            stateTable.visitedCoins[coinPart] = true
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        Farming.CoinThread = nil
    end)
end

-- Auto‑Grab Gun – brings gun to you
function Farming.StartAutoGrabGun(configTable, stateTable, utils, movement, knifeNames, gunNames)
    if Farming.AutoGunThread then return end
    Farming.AutoGunThread = task.spawn(function()
        while stateTable.scriptRunning and configTable.AutoGrabGun do
            local gun = stateTable.CachedGunDrop
            local root = utils.GetRoot()
            if gun and root and not utils.hasWeapon(LocalPlayer, "Gun", knifeNames, gunNames) then
                local gunPart = utils.getAdorneePart(gun)
                if gunPart and gunPart:IsA("BasePart") then
                    local targetPos = root.Position + Vector3.new(0, 2, 0)
                    local tween = TweenService:Create(gunPart, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {
                        CFrame = CFrame.new(targetPos)
                    })
                    tween:Play()
                    tween.Completed:Wait()
                    pcall(function()
                        firetouchinterest(gunPart, root, 0)
                        task.wait(0.01)
                        firetouchinterest(gunPart, root, 1)
                    end)
                end
            end
            task.wait(0.2)
        end
        Farming.AutoGunThread = nil
    end)
end

-- ============================================================
--  UPDATED XP FARM: smooth walk between the given waypoints
-- ============================================================
function Farming.StartXPFarm(configTable, stateTable, utils, movement)
    if Farming.XPThread then return end
    Farming.XPThread = task.spawn(function()
        -- Define the path waypoints (X, Y, Z)
        local waypoints = {
            Vector3.new(-49.50, 247.16, 9010.89),
            Vector3.new(32.31, 254.66, 9007.49),
            Vector3.new(34.09, 259.34, 9052.07),
            Vector3.new(-24.01, 260.87, 9057.17)
        }

        while stateTable.scriptRunning and configTable.XPFarm do
            for _, wp in ipairs(waypoints) do
                if not stateTable.scriptRunning or not configTable.XPFarm then break end

                local root = utils.GetRoot()
                if root then
                    -- Enable noclip to avoid collisions
                    movement.SetNoclip(true, configTable)

                    -- Smoothly tween to the next waypoint (1.5 seconds)
                    movement.TweenTo(wp, 1.5, utils.GetRoot)

                    -- Wait a bit longer than the tween to ensure arrival
                    task.wait(1.8)

                    -- Optional: short pause at each waypoint
                    task.wait(1)
                end
            end
        end

        -- Disable noclip when the farm stops
        movement.SetNoclip(false, configTable)
        Farming.XPThread = nil
    end)
end

function Farming.StartAntiAFK(configTable, stateTable)
    if Farming.AFKThread then return end
    Farming.AFKThread = task.spawn(function()
        while stateTable.scriptRunning and configTable.AntiAFK do
            VirtualUser:CaptureController()
            VirtualUser:ClickButton1(Vector2.new())
            task.wait(math.random(120, 240))
        end
        Farming.AFKThread = nil
    end)
end

function Farming.StartAutoReset(configTable, stateTable, utils)
    if Farming.ResetThread then return end
    Farming.ResetThread = task.spawn(function()
        while stateTable.scriptRunning and configTable.AutoReset do
            local hum = utils.GetHumanoid()
            if hum and hum.Health <= 0 then
                task.wait(1)
                local char = utils.GetCharacter()
                if char and char:FindFirstChild("Humanoid") and char.Humanoid.Health <= 0 then
                    pcall(function()
                        ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ResetCharacter"):FireServer()
                    end)
                end
            end
            task.wait(1)
        end
        Farming.ResetThread = nil
    end)
end

return Farming