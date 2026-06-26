-- source/combat.lua (Silent Aim removed, Safe Pathfinding Dodge added)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local PathfindingService = game:GetService("PathfindingService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local Combat = {
    KillAuraThread = nil,
    DodgeThread = nil
}

-- Raycast verification helper to ensure we move only onto solid walkable parts (No Void)
local function getSafeGround(candidatePos)
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    if LocalPlayer.Character then
        raycastParams.FilterInstances = {LocalPlayer.Character}
    end
    
    -- Cast downwards 50 studs from above the candidate point
    local origin = candidatePos + Vector3.new(0, 10, 0)
    local direction = Vector3.new(0, -60, 0)
    local result = Workspace:Raycast(origin, direction, raycastParams)
    
    if result and result.Instance then
        local nameLower = result.Instance.Name:lower()
        -- Ensure candidate ground is not named void, kill, or dead
        if not nameLower:find("void") and not nameLower:find("kill") and not nameLower:find("dead") then
            return result.Position
        end
    end
    return nil
end

-- Selects the ground position furthest from the threat within 8 directions
local function findBestSafeDestination(rootPos, threatPos)
    local angles = {0, 45, 90, 135, 180, 225, 270, 315}
    local bestPos = nil
    local maxThreatDistance = -1
    
    -- Attempt distance offsets (first 50 studs, fallback to 35 studs)
    for _, distance in ipairs({50, 35}) do
        for _, angle in ipairs(angles) do
            local rad = math.rad(angle)
            local offset = Vector3.new(math.sin(rad) * distance, 0, math.cos(rad) * distance)
            local candidate = rootPos + offset
            
            local safeGround = getSafeGround(candidate)
            if safeGround then
                local threatDist = (safeGround - threatPos).Magnitude
                if threatDist > maxThreatDistance then
                    maxThreatDistance = threatDist
                    bestPos = safeGround
                end
            end
        end
        if bestPos then break end
    end
    
    return bestPos
end

-- Triggerbot validation status helper
function Combat.isBindActive(configTable, stateTable)
    if configTable.AutoShootMode == "Hold" then
        local bind = configTable.AutoShootBind
        if typeof(bind) == "EnumItem" then
            if tostring(bind):find("UserInputType") then
                return UserInputService:IsMouseButtonPressed(bind)
            else
                return UserInputService:IsKeyDown(bind)
            end
        elseif typeof(bind) == "string" then
            local success, keyCode = pcall(function() return Enum.KeyCode[bind] end)
            if success and keyCode then
                return UserInputService:IsKeyDown(keyCode)
            end
            local successMouse, mouseCode = pcall(function() return Enum.UserInputType[bind] end)
            if successMouse and mouseCode then
                return UserInputService:IsMouseButtonPressed(mouseCode)
            end
        end
    else
        return stateTable.autoShootActive
    end
    return false
end

-- Kill Aura
function Combat.StartKillAura(configTable, stateTable, utils, knifeNames, gunNames)
    if Combat.KillAuraThread then return end
    Combat.KillAuraThread = task.spawn(function()
        while stateTable.scriptRunning and configTable.KillAura do
            if utils.hasWeapon(LocalPlayer, "Knife", knifeNames, gunNames) then
                local root = utils.GetRoot()
                local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if root and tool and utils.isKnife(tool, knifeNames) then
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and p.Character then
                            local pr = p.Character:FindFirstChild("HumanoidRootPart")
                            local ph = p.Character:FindFirstChildOfClass("Humanoid")
                            if pr and ph and ph.Health > 0 then
                                local distance = (pr.Position - root.Position).Magnitude
                                
                                if configTable.KillAuraTeleport then
                                    if distance <= configTable.KillAuraTeleportRange then
                                        local originalCFrame = root.CFrame
                                        pcall(function()
                                            local wasAnchored = root.Anchored
                                            root.Anchored = true
                                            
                                            root.CFrame = pr.CFrame * CFrame.new(0, 0, 1.5)
                                            task.wait(0.02)
                                            
                                            tool:Activate()
                                            if mouse1click then
                                                mouse1click()
                                            else
                                                VirtualUser:CaptureController()
                                                VirtualUser:ClickButton1(Vector2.new(0, 0))
                                            end
                                            
                                            task.wait(0.03)
                                            
                                            root.CFrame = originalCFrame
                                            root.Anchored = wasAnchored
                                        end)
                                        task.wait(0.1)
                                    end
                                else
                                    if distance <= configTable.KillAuraRange then
                                        pcall(function()
                                            tool:Activate()
                                            if mouse1click then
                                                mouse1click()
                                            else
                                                VirtualUser:CaptureController()
                                                VirtualUser:ClickButton1(Vector2.new(0, 0))
                                            end
                                        end)
                                    end
                                end
                            end
                        end
                    end
                end
            end
            task.wait(0.1)
        end
        Combat.KillAuraThread = nil
    end)
end

-- Auto Dodge (Updated with safe pathfinding and void prevention)
function Combat.StartAutoDodge(configTable, stateTable, utils, movement, knifeNames, gunNames)
    if Combat.DodgeThread then return end
    Combat.DodgeThread = task.spawn(function()
        while stateTable.scriptRunning and configTable.AutoDodge do
            local root = utils.GetRoot()
            local hum = utils.GetHumanoid()
            
            if root and hum and not utils.hasWeapon(LocalPlayer, "Knife", knifeNames, gunNames) then
                local activeThreat = nil
                
                -- Check for projectiles or thrown knives
                for _, v in ipairs(Workspace:GetChildren()) do
                    if v:IsA("BasePart") and (v.Name:lower():match("knife") or v.Name:lower():match("projectile")) then
                        if (v.Position - root.Position).Magnitude < configTable.DodgeDistance then
                            activeThreat = v.Position
                            break
                        end
                    end
                end
                
                -- Check for nearby Murderer holding a knife
                if not activeThreat then
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= LocalPlayer and utils.hasWeapon(p, "Knife", knifeNames, gunNames) and p.Character then
                            local mroot = p.Character:FindFirstChild("HumanoidRootPart")
                            if mroot and (mroot.Position - root.Position).Magnitude < configTable.DodgeDistance then
                                activeThreat = mroot.Position
                                break
                            end
                        end
                    end
                end
                
                -- Perform dodge behavior if threat is active
                if activeThreat then
                    stateTable.isDodging = true
                    
                    local destination = findBestSafeDestination(root.Position, activeThreat)
                    if destination then
                        local path = PathfindingService:CreatePath({
                            AgentRadius = 3,
                            AgentHeight = 6,
                            AgentCanJump = true,
                            AgentJumpHeight = 50,
                        })
                        
                        local success, _ = pcall(function()
                            path:ComputeAsync(root.Position, destination)
                        end)
                        
                        if success and path.Status == Enum.PathStatus.Success then
                            local waypoints = path:GetWaypoints()
                            -- Walk waypoints
                            for i = 1, math.min(#waypoints, 10) do
                                if not stateTable.scriptRunning or not configTable.AutoDodge then break end
                                local wp = waypoints[i]
                                if wp.Type == Enum.PathWaypointAction.Jump then
                                    hum.Jump = true
                                end
                                hum:MoveTo(wp.Position)
                                
                                -- Connection fallback timeout to avoid freezing if waypoints are blocked
                                local reached = false
                                local conn
                                conn = hum.MoveToFinished:Connect(function()
                                    reached = true
                                end)
                                
                                local start = os.clock()
                                while not reached and (os.clock() - start) < 0.25 do
                                    task.wait()
                                end
                                if conn then conn:Disconnect() end
                            end
                        end
                    end
                else
                    stateTable.isDodging = false
                end
            else
                stateTable.isDodging = false
            end
            task.wait(0.1)
        end
        stateTable.isDodging = false
        Combat.DodgeThread = nil
    end)
end

-- Triggerbot
function Combat.handleTriggerbot(murderer, configTable, stateTable, utils, gunNames)
    if not configTable.AutoShoot or not murderer or not Combat.isBindActive(configTable, stateTable) then return end
    local myChar = LocalPlayer.Character
    local tool = myChar and myChar:FindFirstChildOfClass("Tool")
    if tool and utils.isGun(tool, gunNames) then
        local now = os.clock()
        if now - stateTable.lastShotTime >= stateTable.SHOT_DEBOUNCE then
            local root = utils.GetRoot()
            local mRoot = murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart")
            if root and mRoot then
                pcall(function()
                    tool:Activate()
                    stateTable.lastShotTime = now
                end)
            end
        end
    end
end

return Combat