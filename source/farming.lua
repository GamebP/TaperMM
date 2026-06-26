-- source/farming.lua (no Pull Coins, fixed XP Farm with waypoints)
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

function Farming.StartCoinFarm(configTable, stateTable, utils, movement, mapNames)
    if Farming.CoinThread then return end
    Farming.CoinThread = task.spawn(function()
        local lastCoinContainer = nil
        while stateTable.scriptRunning do
            task.wait(0.2)
            if configTable.AutoCoin then
                local myChar = LocalPlayer.Character
                local hrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local coinContainer = nil
                    if utils and utils.findCoinContainer then
                        coinContainer = utils.findCoinContainer(mapNames or {})
                    else
                        for _, obj in ipairs(Workspace:GetChildren()) do
                            if obj:IsA("Model") then
                                local c = obj:FindFirstChild("CoinContainer")
                                if c then coinContainer = c; break end
                            end
                        end
                    end

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
                                        -- FireTouch
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
--  FIXED XP FARM: smooth walk along the four waypoints
-- ============================================================
function Farming.StartXPFarm(configTable, stateTable, utils, movement)
    if Farming.XPThread then return end
    Farming.XPThread = task.spawn(function()
        while stateTable.scriptRunning and configTable.XPFarm do
            local root = utils.GetRoot()
            if root then
                movement.SetNoclip(true, configTable)
                local safePos = Vector3.new(0, 250, 0)
                
                if (root.Position - safePos).Magnitude > 5 then
                    -- Temporarily unanchor so the tween can move the character
                    root.Anchored = false
                    
                    local tween = movement.TweenTo(safePos, 1.0, utils.GetRoot)
                    if tween then
                        tween.Completed:Wait() -- Wait until the character arrives
                    end
                    
                    -- Anchor the character at the safe spot to resist gravity
                    if configTable.XPFarm and stateTable.scriptRunning then
                        root.Anchored = true
                    end
                else
                    -- Keep the character anchored if they are already in position
                    root.Anchored = true
                end
            end
            task.wait(1)
        end
        
        -- Cleanup: Make sure to unanchor the character when the farm is turned off
        local root = utils.GetRoot()
        if root then
            root.Anchored = false
        end
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