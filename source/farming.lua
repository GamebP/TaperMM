-- source/farming.lua (fixed Pull Coins with debug logging)
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

                        -- Collect all coin parts into a list
                        local coinParts = {}
                        for _, v in ipairs(coinContainer:GetChildren()) do
                            if v.Name == "Coin_Server" or v.Name == "Snowflake_Server" or v.Name == "Candy_Server" then
                                local coinPart = v:IsA("BasePart") and v or (v:FindFirstChild("Coin") or v:FindFirstChildOfClass("BasePart"))
                                if coinPart and coinPart:IsDescendantOf(Workspace) and not stateTable.visitedCoins[coinPart] then
                                    table.insert(coinParts, coinPart)
                                end
                            end
                        end

                        -- Sort by distance (closest first)
                        table.sort(coinParts, function(a, b)
                            return (a.Position - hrp.Position).Magnitude < (b.Position - hrp.Position).Magnitude
                        end)

                        local collected = 0
                        local maxCoins = 40
                        local pullRadius = 150

                        for _, coinPart in ipairs(coinParts) do
                            if not configTable.AutoCoin or not stateTable.scriptRunning then break end
                            if collected >= maxCoins then break end
                            local distance = (coinPart.Position - hrp.Position).Magnitude
                            if distance > pullRadius then break end -- sorted, so farther ones are > radius

                            -- === PULL COINS METHOD ===
                            if configTable.CoinMethod == "Pull Coins" then
                                -- Ensure we have a valid BasePart
                                if not coinPart or not coinPart:IsA("BasePart") then
                                    utils.log("Skipping invalid coin part", "warn")
                                    stateTable.visitedCoins[coinPart] = true
                                    goto continue
                                end

                                local success = pcall(function()
                                    utils.log("Pulling coin: " .. coinPart.Name .. " at distance " .. tostring(distance), "info")

                                    -- Unanchor and allow movement
                                    local wasAnchored = coinPart.Anchored
                                    coinPart.Anchored = false
                                    coinPart.CanCollide = false
                                    coinPart.AssemblyLinearVelocity = Vector3.zero
                                    coinPart.AssemblyAngularVelocity = Vector3.zero

                                    -- Target position (slightly above your root)
                                    local targetPos = hrp.Position + Vector3.new(0, 2, 0)

                                    -- Try to tween
                                    local tween = TweenService:Create(coinPart, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {
                                        CFrame = CFrame.new(targetPos)
                                    })
                                    tween:Play()
                                    tween.Completed:Wait()

                                    -- If tween didn't move it (due to some issue), set CFrame directly
                                    if (coinPart.Position - targetPos).Magnitude > 1 then
                                        coinPart.CFrame = CFrame.new(targetPos)
                                    end

                                    -- Fire touch to collect
                                    firetouchinterest(coinPart, hrp, 0)
                                    task.wait(0.02)
                                    firetouchinterest(coinPart, hrp, 1)

                                    -- Restore anchor state if part still exists
                                    if coinPart.Parent then
                                        coinPart.Anchored = wasAnchored
                                        coinPart.CanCollide = true
                                    end

                                    utils.log("Coin pulled successfully", "info")
                                end)

                                if success then
                                    stateTable.visitedCoins[coinPart] = true
                                    collected = collected + 1
                                else
                                    utils.log("Failed to pull coin (error caught)", "error")
                                    -- Mark as visited to avoid retrying
                                    stateTable.visitedCoins[coinPart] = true
                                end
                            else
                                -- Existing methods (FireTouch, Teleport, Smooth Fly) - unchanged
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
                                            local distance2 = (hrp.Position - targetPos).Magnitude
                                            local speed = 30
                                            local duration = distance2 / speed
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
                                        local distance2 = (hrp.Position - coinPart.Position).Magnitude
                                        local speed = 30
                                        local duration = distance2 / speed
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
                            ::continue::
                        end
                    end
                end
            end
        end
        Farming.CoinThread = nil
    end)
end

-- The rest of farming.lua (StartAutoGrabGun, StartXPFarm, etc.) stays identical to the previous version.
-- I'll include them below for completeness.

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

function Farming.StartXPFarm(configTable, stateTable, utils, movement)
    if Farming.XPThread then return end
    Farming.XPThread = task.spawn(function()
        while stateTable.scriptRunning and configTable.XPFarm do
            local root = utils.GetRoot()
            if root then
                movement.SetNoclip(true, configTable)
                local safePos = Vector3.new(0, 250, 0)
                if (root.Position - safePos).Magnitude > 5 then
                    movement.TweenTo(safePos, 1.0, utils.GetRoot)
                end
            end
            task.wait(2)
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