-- source/combat.lua (Silent Aim removed)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local Combat = {
    KillAuraThread = nil,
    DodgeThread = nil
}

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

-- Kill Aura (unchanged)
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
                                if (pr.Position - root.Position).Magnitude <= configTable.KillAuraRange then
                                    pcall(function()
                                        tool:Activate()
                                    end)
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

-- Auto Dodge (unchanged)
function Combat.StartAutoDodge(configTable, stateTable, utils, movement, knifeNames, gunNames)
    if Combat.DodgeThread then return end
    Combat.DodgeThread = task.spawn(function()
        while stateTable.scriptRunning and configTable.AutoDodge do
            local root = utils.GetRoot()
            if root and not utils.hasWeapon(LocalPlayer, "Knife", knifeNames, gunNames) then
                for _, v in ipairs(Workspace:GetChildren()) do
                    if v:IsA("BasePart") and (v.Name:lower():match("knife") or v.Name:lower():match("projectile")) then
                        if (v.Position - root.Position).Magnitude < configTable.DodgeDistance then
                            local dodge = root.CFrame.RightVector * 25 + root.CFrame.UpVector * 10
                            movement.TweenTo(root.Position + dodge, 0.15, utils.GetRoot)
                            break
                        end
                    end
                end
                for _, p in ipairs(Players:GetPlayers()) do
                    if p ~= LocalPlayer and utils.hasWeapon(p, "Knife", knifeNames, gunNames) and p.Character then
                        local mroot = p.Character:FindFirstChild("HumanoidRootPart")
                        if mroot and (mroot.Position - root.Position).Magnitude < configTable.DodgeDistance then
                            local away = (root.Position - mroot.Position).Unit * 35
                            movement.TweenTo(root.Position + away, 0.18, utils.GetRoot)
                            break
                        end
                    end
                end
            end
            task.wait(0.1)
        end
        Combat.DodgeThread = nil
    end)
end

-- Triggerbot (unchanged)
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