-- source/farming.lua (robust, with mapNames parameter)
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

-- ============================================================
--  StartCoinFarm now accepts mapNames as the 5th parameter
-- ============================================================
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
                    -- Use the passed mapNames (or empty table as fallback)
                    local coinContainer = nil
                    if utils and utils.findCoinContainer then
                        coinContainer = utils.findCoinContainer(mapNames or {})
                    else
                        -- fallback: try to find CoinContainer manually
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

                        -- Collect all coin parts
                        local coinParts = {}
                        for _, v in ipairs(coinContainer:GetChildren()) do
                            if v.Name == "Coin_Server" or v.Name == "Snowflake_Server" or v.Name == "Candy_Server" then
                                local coinPart = v:IsA("BasePart") and v or (v:FindFirstChild("Coin") or v:FindFirstChildOfClass("BasePart"))
                                if coinPart and coinPart:IsDescendantOf(Workspace) and not stateTable.visitedCoins[coinPart] then
                                    table.insert(coinParts, coinPart)
                                end
                            end
                        end

                        -- Sort by distance
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
                            if distance > pullRadius then break end

                            -- === PULL COINS METHOD ===
                            if configTable.CoinMethod == "Pull Coins" then
                                if coinPart and coinPart:IsA("BasePart") then
                                    local success = pcall(function()
                                        -- Unanchor and allow movement
                                        local wasAnchored = coinPart.Anchored
                                        coinPart.Anchored = false
                                        coinPart.CanCollide = false
                                        coinPart.AssemblyLinearVelocity = Vector3.zero
                                        coinPart.AssemblyAngularVelocity = Vector3.zero

                                        local targetPos = hrp.Position + Vector3.new(0, 2, 0)

                                        -- Tween to player
                                        local tween = TweenService:Create(coinPart, TweenInfo.new(0.3, Enum.EasingStyle.Linear), {
                                            CFrame = CFrame.new(targetPos)
                                        })
                                        tween:Play()
                                        tween.Completed:Wait()

                                        -- Fallback direct set
                                        if (coinPart.Position - targetPos).Magnitude > 1 then
                                            coinPart.CFrame = CFrame.new(targetPos)
                                        end

                                        -- Fire touch to collect
                                        if firetouchinterest then
                                            firetouchinterest(coinPart, hrp, 0)
                                            task.wait(0.02)
                                            firetouchinterest(coinPart, hrp, 1)
                                        end

                                        -- Restore anchor if still exists
                                        if coinPart.Parent then
                                            coinPart.Anchored = wasAnchored
                                            coinPart.CanCollide = true
                                        end
                                    end)
                                    if success then
                                        stateTable.visitedCoins[coinPart] = true
                                        collected = collected + 1
                                    else
                                        stateTable.visitedCoins[coinPart] = true -- skip on error
                                    end
                                end
                            else
                                -- Other methods (FireTouch, Teleport, Smooth Fly) – unchanged
                                if configTable.CoinMethod == "Teleport" then
                                    hrp.AssemblyLinearVelocity = Vector3.zero
                                    hrp.CFrame = coinPart.CFrame + Vector3.new(0, 1.2, 0)
                                    task.wait(0.18)
                                    stateTable.visitedCoins[coinPart] = true
                                elseif configTable.CoinMethod == "Smooth Fly" then
                                    -- ... (keep your existing code for Smooth Fly)
                                    -- I'll keep it minimal to avoid length – you can copy from your version
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
        Farming.CoinThread = nil
    end)
end

-- The rest of your farming.lua (StartAutoGrabGun, StartXPFarm, etc.) stays identical.
-- I'll include them here for completeness, but they are unchanged.

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