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

function Farming.StartCoinFarm(configTable, stateTable, utils, movement, mapNames)
    if Farming.CoinThread then return end
    Farming.CoinThread = task.spawn(function()
        local lastCoinContainer = nil
        while stateTable.scriptRunning do
            task.wait(0.2)
            
            -- PRIORITY OVERRIDE FOR AUTODODGE
            -- Yield coin farming tasks if active dodging sequence is running
            if stateTable.isDodging then
                task.wait(0.5)
                continue
            end
            
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

                        local collected = 0
                        local maxCoins = 40
                        local maxRange = 250 -- Maximum search range for coins

                        -- Smart Dynamic Nearest-Neighbor Target Selection Loop
                        while collected < maxCoins and stateTable.scriptRunning and configTable.AutoCoin and not stateTable.isDodging do
                            local currentHrp = utils.GetRoot()
                            if not currentHrp then break end
                            
                            -- 1. Gather all unvisited coin parts still present on the map
                            local coinParts = {}
                            for _, v in ipairs(coinContainer:GetChildren()) do
                                if v.Name == "Coin_Server" or v.Name == "Snowflake_Server" or v.Name == "Candy_Server" then
                                    local coinPart = v:IsA("BasePart") and v or (v:FindFirstChild("Coin") or v:FindFirstChildOfClass("BasePart"))
                                    if coinPart and coinPart:IsDescendantOf(Workspace) and not stateTable.visitedCoins[coinPart] then
                                        table.insert(coinParts, coinPart)
                                    end
                                end
                            end
                            
                            if #coinParts == 0 then break end -- No unvisited coins left in container
                            
                            -- 2. Identify the single closest coin part from the current position
                            local closestCoin = nil
                            local closestDistance = math.huge
                            for _, coinPart in ipairs(coinParts) do
                                local dist = (coinPart.Position - currentHrp.Position).Magnitude
                                if dist < closestDistance then
                                    closestDistance = dist
                                    closestCoin = coinPart
                                end
                            end
                            
                            -- Stop targeting loop if closest coin is beyond active range limits
                            if not closestCoin or closestDistance > maxRange then break end
                            
                            -- 3. Move and Collect targeted coin
                            local coinPart = closestCoin
                            
                            if configTable.CoinMethod == "Teleport" then
                                pcall(function()
                                    currentHrp.AssemblyLinearVelocity = Vector3.zero
                                    currentHrp.CFrame = coinPart.CFrame + Vector3.new(0, 1.2, 0)
                                    task.wait(0.18)
                                    stateTable.visitedCoins[coinPart] = true
                                    collected = collected + 1
                                end)
                            else
                                -- Default/Fallback option is now "Smooth Fly"
                                local success = pcall(function()
                                    currentHrp.AssemblyLinearVelocity = Vector3.zero
                                    local speed = configTable.FlySpeed or 50
                                    local dist = (coinPart.Position - currentHrp.Position).Magnitude
                                    local duration = dist / speed
                                    
                                    movement.SetNoclip(true, configTable)
                                    
                                    local tween = TweenService:Create(currentHrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
                                        CFrame = coinPart.CFrame + Vector3.new(0, 1.2, 0)
                                    })
                                    tween:Play()
                                    
                                    -- Actively polling for interrupts during flight transition
                                    while tween.PlaybackState == Enum.PlaybackState.Playing do
                                        if stateTable.isDodging or not configTable.AutoCoin or not stateTable.scriptRunning then
                                            tween:Cancel()
                                            break
                                        end
                                        task.wait(0.05)
                                    end
                                    
                                    if not stateTable.isDodging and configTable.AutoCoin and stateTable.scriptRunning then
                                        if firetouchinterest then
                                            firetouchinterest(coinPart, currentHrp, 0)
                                            task.wait(0.01)
                                            firetouchinterest(coinPart, currentHrp, 1)
                                        end
                                        stateTable.visitedCoins[coinPart] = true
                                        collected = collected + 1
                                    end
                                    
                                    movement.SetNoclip(false, configTable)
                                end)
                                if not success then
                                    stateTable.visitedCoins[coinPart] = true
                                end
                            end
                            task.wait(0.05) -- Adaptive delay step between targets
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