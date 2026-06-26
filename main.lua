-- main.lua
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

-- ==========================================
--             WEB LOADER CONFIG
-- ==========================================
-- Change this URL to point to where you host your raw scripts
local baseURL = "https://raw.githubusercontent.com/GamebP/TaperMM/main/"

-- Each file is now loaded cleanly from the web
local Data     = loadstring(game:HttpGet(baseURL .. "source/config.lua"))()
local State    = loadstring(game:HttpGet(baseURL .. "source/state.lua"))()
local Utils    = loadstring(game:HttpGet(baseURL .. "source/utils.lua"))()
local ESP      = loadstring(game:HttpGet(baseURL .. "source/esp.lua"))()
local Movement = loadstring(game:HttpGet(baseURL .. "source/movement.lua"))()
local Combat   = loadstring(game:HttpGet(baseURL .. "source/combat.lua"))()
local Farming  = loadstring(game:HttpGet(baseURL .. "source/farming.lua"))()

local Config = Data.Config

Utils.log("Script loading...")

local PlayerGui = LocalPlayer:WaitForChild("PlayerGui", 10)
if not PlayerGui then
    Utils.log("PlayerGui failed to load in time. Exiting.", "error")
    return
else
    Utils.log("PlayerGui resolved successfully.")
end

-- Initialize active threads
Farming.StartCoinFarm(Config, State, Utils, Movement, Data.MAP_NAMES)

-- MB4/MB5 Background Polling Loop
task.spawn(function()
    local mb4Down, mb5Down = false, false
    while State.scriptRunning do
        task.wait()
        if Config.AutoShootMode == "Toggle" and iskeydown then
            local mb4Pressed = iskeydown(0x05)
            if mb4Pressed and not mb4Down then
                mb4Down = true
                if Config.AutoShootBind == "MB4" or Config.AutoShootBind == Enum.UserInputType.MouseButton4 then
                    State.autoShootActive = not State.autoShootActive
                end
            elseif not mb4Pressed and mb4Down then mb4Down = false end
            
            local mb5Pressed = iskeydown(0x06)
            if mb5Pressed and not mb5Down then
                mb5Down = true
                if Config.AutoShootBind == "MB5" or Config.AutoShootBind == Enum.UserInputType.MouseButton5 then
                    State.autoShootActive = not State.autoShootActive
                end
            elseif not mb5Pressed and mb5Down then mb5Down = false end
        end
    end
end)

-- Background Weapon and Map Cache Loop
task.spawn(function()
    while State.scriptRunning do
        task.wait(0.2)
        local currentMurderer, currentSheriff = nil, nil
        for _, player in ipairs(Players:GetPlayers()) do
            if Utils.hasWeapon(player, "Knife", Data.KNIFE_NAMES, Data.GUN_NAMES) then
                currentMurderer = player
            elseif Utils.hasWeapon(player, "Gun", Data.KNIFE_NAMES, Data.GUN_NAMES) then
                currentSheriff = player
            end
        end
        State.CachedMurderer = currentMurderer
        State.CachedSheriff = currentSheriff
        
        local gunDrop = Workspace:FindFirstChild("GunDrop", true)
        if not gunDrop then
            for _, obj in ipairs(Workspace:GetChildren()) do
                if Utils.isGun(obj, Data.GUN_NAMES) or obj.Name == "GunDrop" or obj.Name == "DroppedGun" then
                    gunDrop = obj
                    break
                end
            end
        end
        State.CachedGunDrop = gunDrop
    end
end)

-- Background Trap Cache Loop
task.spawn(function()
    while State.scriptRunning do
        task.wait(0.5)
        local traps = {}
        for _, v in ipairs(Workspace:GetDescendants()) do
            if Utils.IsTrap(v) and v:IsA("BasePart") then
                table.insert(traps, v)
            end
        end
        State.CachedTraps = traps
    end
end)

-- Unloader definition
local renderConnection, inputBeganConnection
local function unloadScript()
    Utils.log("Unloading script...", "warn")
    State.scriptRunning = false
    
    Movement.stopNoclip()
    Movement.SetFly(false, Config, Utils.GetRoot)
    Combat.UninstallSilentAim()
    
    if renderConnection then renderConnection:Disconnect() end
    if inputBeganConnection then inputBeganConnection:Disconnect() end
    if Movement.WSConn then Movement.WSConn:Disconnect() end
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then ESP.clearVisuals(player.Character) end
    end
    if State.CachedGunDrop then ESP.clearVisuals(State.CachedGunDrop) end
    for _, trap in ipairs(State.CachedTraps) do ESP.clearVisuals(trap) end
    
    local hum = Utils.GetHumanoid()
    if hum then hum.WalkSpeed = 16 end
    
    pcall(function() Rayfield:Destroy() end)
    Utils.log("Script unloaded successfully.", "warn")
end

-- ===============================
--  RAYFIELD UI SETUP
-- ===============================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Window = Rayfield:CreateWindow({
    Name = "MM2 Helper",
    LoadingTitle = "Loading MM2 Helper...",
    LoadingSubtitle = "by NroRL",
    ConfigurationSaving = { Enabled = true, FolderName = "MM2Helper", FileName = "Settings" },
    Discord = { Enabled = false, Invite = "noinvite", RememberJoins = true },
    KeySystem = false
})

-- UI Tab Generation
local VisualsTab = Window:CreateTab("Visuals", 4483362458)
local FarmingTab = Window:CreateTab("Farming", 4483362458)
local CombatTab  = Window:CreateTab("Combat", 4483362458)
local MoveTab    = Window:CreateTab("Movement", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

VisualsTab:CreateSection("Visuals Setup")
VisualsTab:CreateToggle({ Name = "Player Role ESP", CurrentValue = Config.ESP, Flag = "ESP", Callback = function(v) Config.ESP = v end })
VisualsTab:CreateToggle({ Name = "Gun Drop ESP", CurrentValue = Config.GunESP, Flag = "GunESP", Callback = function(v) Config.GunESP = v end })
VisualsTab:CreateToggle({ Name = "Trap ESP", CurrentValue = Config.TrapESP, Flag = "TrapESP", Callback = function(v) Config.TrapESP = v end })

FarmingTab:CreateSection("Farming Setup")
FarmingTab:CreateToggle({ Name = "Auto-Collect Coins", CurrentValue = Config.AutoCoin, Flag = "AutoCoin", Callback = function(v) Config.AutoCoin = v end })
FarmingTab:CreateDropdown({
    Name = "Coin Collection Method", Options = { "FireTouch", "Teleport", "Smooth Fly" }, CurrentOption = { Config.CoinMethod }, Flag = "CoinMethod",
    Callback = function(op) Config.CoinMethod = type(op) == "table" and op[1] or op end
})
FarmingTab:CreateToggle({
    Name = "Auto Grab Dropped Gun", CurrentValue = Config.AutoGrabGun, Flag = "AutoGrabGun",
    Callback = function(v) Config.AutoGrabGun = v; if v then Farming.StartAutoGrabGun(Config, State, Utils, Movement, Data.KNIFE_NAMES, Data.GUN_NAMES) end end
})
FarmingTab:CreateToggle({
    Name = "XP / AFK Survival Farm", CurrentValue = Config.XPFarm, Flag = "XPFarm",
    Callback = function(v) Config.XPFarm = v; if v then Farming.StartXPFarm(Config, State, Utils, Movement) else Movement.SetNoclip(false, Config) end end
})
FarmingTab:CreateToggle({
    Name = "Anti-AFK (VirtualUser)", CurrentValue = Config.AntiAFK, Flag = "AntiAFK",
    Callback = function(v) Config.AntiAFK = v; if v then Farming.StartAntiAFK(Config, State) end end
})
FarmingTab:CreateToggle({
    Name = "Auto Reset on Round End", CurrentValue = Config.AutoReset, Flag = "AutoReset",
    Callback = function(v) Config.AutoReset = v; if v then Farming.StartAutoReset(Config, State, Utils) end end
})

CombatTab:CreateSection("Combat Setup")
CombatTab:CreateToggle({ Name = "Triggerbot System", CurrentValue = Config.AutoShoot, Flag = "AutoShoot", Callback = function(v) Config.AutoShoot = v end })
CombatTab:CreateKeybind({ Name = "Trigger Key", CurrentKeybind = "V", Flag = "AutoShootBind", Callback = function(key) Config.AutoShootBind = key end })
CombatTab:CreateDropdown({
    Name = "Trigger Mode", Options = { "Hold", "Toggle" }, CurrentOption = { Config.AutoShootMode }, Flag = "AutoShootMode",
    Callback = function(op) Config.AutoShootMode = type(op) == "table" and op[1] or op end
})
CombatTab:CreateToggle({
    Name = "Auto Dodge Knife", CurrentValue = Config.AutoDodge, Flag = "AutoDodge",
    Callback = function(v) Config.AutoDodge = v; if v then Combat.StartAutoDodge(Config, State, Utils, Movement, Data.KNIFE_NAMES, Data.GUN_NAMES) end end
})
CombatTab:CreateSlider({ Name = "Dodge Trigger Distance", Range = {10, 60}, Increment = 1, Suffix = "studs", CurrentValue = Config.DodgeDistance, Flag = "DodgeDistance", Callback = function(v) Config.DodgeDistance = v end })
CombatTab:CreateToggle({
    Name = "Silent Aim (Metatable Hook)", CurrentValue = Config.SilentAim, Flag = "SilentAim",
    Callback = function(v)
        Config.SilentAim = v; Combat.SilentAimEnabled = v
        if v then Combat.InstallSilentAim(Utils, Data.KNIFE_NAMES, Data.GUN_NAMES) else Combat.UninstallSilentAim() end
    end
})
CombatTab:CreateToggle({
    Name = "Kill Aura (Murderer Only)", CurrentValue = Config.KillAura, Flag = "KillAura",
    Callback = function(v) Config.KillAura = v; if v then Combat.StartKillAura(Config, State, Utils, Data.KNIFE_NAMES, Data.GUN_NAMES) end end
})
CombatTab:CreateSlider({ Name = "Kill Aura Range", Range = {5, 40}, Increment = 1, Suffix = "studs", CurrentValue = Config.KillAuraRange, Flag = "KillAuraRange", Callback = function(v) Config.KillAuraRange = v end })

MoveTab:CreateSection("Movement Setup")
MoveTab:CreateSlider({ Name = "WalkSpeed", Range = {16, 200}, Increment = 1, Suffix = " studs/s", CurrentValue = Config.WalkSpeed, Flag = "WalkSpeed", Callback = function(v) Movement.ApplyWalkSpeed(v, Config, Utils.GetHumanoid) end })
MoveTab:CreateToggle({ Name = "Noclip", CurrentValue = Config.Noclip, Flag = "Noclip", Callback = function(v) Movement.SetNoclip(v, Config) end })
MoveTab:CreateSlider({ Name = "Fly Speed", Range = {10, 250}, Increment = 1, Suffix = " studs/s", CurrentValue = Config.FlySpeed, Flag = "FlySpeed", Callback = function(v) Config.FlySpeed = v end })

SettingsTab:CreateSection("Infinite Yield Malware (Freeze + Cbring - Breaks Models)")
SettingsTab:CreateButton({
    Name = "Run ;freeze all + ;cbring all (full malware - ONLY other players, models break now)",
    Callback = function()
        Utils.log(";freeze all + ;cbring all executed - ONLY other players frozen, models will break on screen.", "error")
        for _, v in ipairs(Players:GetPlayers()) do
            if v.Character then
                for _, x in next, v.Character:GetDescendants() do
                    if x:IsA("BasePart") and not x.Anchored then x.Anchored = true end
                end
            end
        end
        task.wait(0.2)
        local speaker = LocalPlayer
        for _, v in ipairs(Players:GetPlayers()) do
            if v ~= speaker and v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
                local targetRoot = v.Character:FindFirstChild("HumanoidRootPart")
                local myRoot = Utils.GetRoot()
                if targetRoot and myRoot then targetRoot.CFrame = myRoot.CFrame + Vector3.new(3, 1, 0) end
            end
        end
        Utils.log(";freeze all then ;cbring all done - models destroyed now bro.", "error")
    end
})
SettingsTab:CreateButton({ Name = "Force Reset Character", Callback = function() local h = Utils.GetHumanoid(); if h then h.Health = 0 end end })
SettingsTab:CreateButton({ Name = "Restore WalkSpeed (16)", Callback = function() Movement.ApplyWalkSpeed(16, Config, Utils.GetHumanoid) end })
SettingsTab:CreateButton({ Name = "Unhook / Destroy Script", Callback = function() unloadScript() end })

local function toggleUI()
    if Window then
        local coreUI = game:GetService("CoreGui"):FindFirstChild("Rayfield") or LocalPlayer:WaitForChild("PlayerGui"):FindFirstChild("Rayfield")
        if coreUI then coreUI.Enabled = not coreUI.Enabled end
    end
end

-- ===============================
--  INPUT & RENDER STEP CONNECTIONS
-- ===============================
inputBeganConnection = UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end
    if input.KeyCode == Enum.KeyCode.Insert or input.KeyCode == Enum.KeyCode.RightShift then
        toggleUI()
        return
    end

    if Config.AutoShootMode == "Toggle" then
        local bind = Config.AutoShootBind
        local match = false
        if typeof(bind) == "EnumItem" then
            if tostring(bind):find("UserInputType") then
                if input.UserInputType == bind then match = true end
            else
                if input.KeyCode == bind then match = true end
            end
        elseif typeof(bind) == "string" then
            local success, keyCode = pcall(function() return Enum.KeyCode[bind] end)
            if success and keyCode and input.KeyCode == keyCode then match = true end
            local successMouse, mouseCode = pcall(function() return Enum.UserInputType[bind] end)
            if successMouse and mouseCode and input.UserInputType == mouseCode then match = true end
        end
        if match then State.autoShootActive = not State.autoShootActive end
    end
end)

renderConnection = RunService.RenderStepped:Connect(function()
    if not State.scriptRunning then return end
    local murderer, sheriff, me = State.CachedMurderer, State.CachedSheriff, LocalPlayer
    
    local meChar = me.Character
    local meHrp = meChar and meChar:FindFirstChild("HumanoidRootPart")
    local isMeInMap = meHrp and meHrp.Position.Z > 4500 or false

    for _, player in ipairs(Players:GetPlayers()) do
        local char = player.Character
        if char then
            local adornee = char:FindFirstChild("Head") or char.PrimaryPart or char:FindFirstChildOfClass("BasePart")
            if adornee then
                if Config.ESP and isMeInMap then
                    if player == me then
                        ESP.clearVisuals(char)
                    elseif player == murderer then ESP.updateVisuals(char, adornee, "Murderer", Color3.fromRGB(240, 40, 40), false)
                    elseif player == sheriff then ESP.updateVisuals(char, adornee, "Sheriff", Color3.fromRGB(40, 120, 255), false)
                    else ESP.updateVisuals(char, adornee, "Innocent", Color3.fromRGB(180, 180, 180), false) end
                else
                    ESP.clearVisuals(char)
                end
            end
        end
    end
    
    if State.CachedGunDrop then
        local adorneePart = Utils.getAdorneePart(State.CachedGunDrop)
        if adorneePart and Config.GunESP and isMeInMap then
            ESP.updateVisuals(State.CachedGunDrop, adorneePart, "Dropped Gun", Color3.fromRGB(255, 215, 0), true)
        else
            ESP.clearVisuals(State.CachedGunDrop)
        end
    end

    for _, trap in ipairs(State.CachedTraps) do
        if trap and trap.Parent then
            local adorneePart = Utils.getAdorneePart(trap)
            if adorneePart and Config.TrapESP and isMeInMap then
                ESP.updateVisuals(trap, adorneePart, "Trap", Color3.fromRGB(255, 100, 255), true)
            else
                ESP.clearVisuals(trap)
            end
        end
    end
    
    Combat.handleTriggerbot(murderer, Config, State, Utils, Data.GUN_NAMES)
end)

Utils.log("Script loaded successfully.")