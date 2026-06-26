-- source/utils.lua
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

local Utils = {}

function Utils.log(message, level)
    level = level or "info"
    local prefix = "[MM2 Debug] [" .. os.date("%X") .. "] "
    if level == "warn" then
        warn(prefix .. "[WARN] " .. message)
    elseif level == "error" then
        warn(prefix .. "[ERROR] " .. message)
    else
        print(prefix .. "[INFO] " .. message)
    end
end

function Utils.GetCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

function Utils.GetRoot()
    local c = Utils.GetCharacter()
    return c and c:FindFirstChild("HumanoidRootPart")
end

function Utils.GetHumanoid()
    local c = Utils.GetCharacter()
    return c and c:FindFirstChildOfClass("Humanoid")
end

function Utils.getAdorneePart(object)
    if not object or not object.Parent then return nil end
    if object:IsA("BasePart") then return object end
    if object:IsA("Model") then return object.PrimaryPart or object:FindFirstChildOfClass("BasePart") end
    if object:IsA("Tool") then return object:FindFirstChild("Handle") or object:FindFirstChildOfClass("BasePart") end
    return nil
end

function Utils.isKnife(tool, knifeNames)
    if not tool or not tool:IsA("Tool") then return false end
    if table.find(knifeNames, tool.Name) then return true end
    for _, child in ipairs(tool:GetChildren()) do
        if child:IsA("LocalScript") or child:IsA("Script") then
            local name = child.Name:lower()
            if name:find("knife") or name:find("stab") then
                return true
            end
        end
    end
    return false
end

function Utils.isGun(tool, gunNames)
    if not tool or not tool:IsA("Tool") then return false end
    if table.find(gunNames, tool.Name) then return true end
    for _, child in ipairs(tool:GetChildren()) do
        if child:IsA("LocalScript") or child:IsA("Script") then
            local name = child.Name:lower()
            if name:find("gun") or name:find("shoot") or name:find("fire") then
                return true
            end
        end
    end
    return false
end

function Utils.hasWeapon(player, weaponType, knifeNames, gunNames)
    if not player then return false end
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if weaponType == "Knife" and Utils.isKnife(tool, knifeNames) then return true end
            if weaponType == "Gun" and Utils.isGun(tool, gunNames) then return true end
        end
    end
    local character = player.Character
    if character then
        for _, tool in ipairs(character:GetChildren()) do
            if weaponType == "Knife" and Utils.isKnife(tool, knifeNames) then return true end
            if weaponType == "Gun" and Utils.isGun(tool, gunNames) then return true end
        end
    end
    return false
end

function Utils.IsTrap(model)
    return model and (model.Name:lower():match("trap") or model:GetAttribute("IsTrap") == true)
end

function Utils.findCoinContainer(mapNames)
    for _, mapName in ipairs(mapNames) do
        local map = Workspace:FindFirstChild(mapName)
        if map then
            local container = map:FindFirstChild("CoinContainer")
            if container then return container end
        end
    end
    
    for _, obj in ipairs(Workspace:GetChildren()) do
        if obj:IsA("Model") and obj.Name ~= "Terrain" then
            local container = obj:FindFirstChild("CoinContainer")
            if container then return container end
        end
    end
    
    local success, result = pcall(function()
        return Workspace:FindFirstChild("CoinContainer", true)
    end)
    if success and result then return result end
    return nil
end

return Utils