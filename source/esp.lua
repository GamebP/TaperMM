-- source/esp.lua
local ESP = {}

function ESP.getVisualContainer(targetObj)
    if not targetObj or not targetObj.Parent then return nil end
    local container = targetObj:FindFirstChild("ByteVisuals")
    if not container then
        container = Instance.new("Folder")
        container.Name = "ByteVisuals"
        container.Parent = targetObj
    end
    return container
end

function ESP.updateVisuals(targetObj, adorneePart, labelText, color, isItem)
    local container = ESP.getVisualContainer(targetObj)
    if not container then return end
    
    local highlight = container:FindFirstChild("HL")
    local billboard = container:FindFirstChild("BB")
    
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "HL"
        highlight.Parent = container
    end
    
    if not billboard then
        billboard = Instance.new("BillboardGui")
        billboard.Name = "BB"
        billboard.Size = UDim2.new(0, 150, 0, 50)
        billboard.StudsOffset = Vector3.new(0, isItem and 1.5 or 3, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = container
        
        local textLabel = Instance.new("TextLabel")
        textLabel.Name = "TL"
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.Font = Enum.Font.GothamBold
        textLabel.TextStrokeTransparency = 0
        textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
        textLabel.Parent = billboard
    end
    
    highlight.FillColor = color
    highlight.OutlineColor = color
    highlight.FillTransparency = isItem and 0.4 or 0.7
    highlight.OutlineTransparency = 0.1
    highlight.Adornee = targetObj
    highlight.Enabled = true
    
    billboard.Adornee = adorneePart
    billboard.Enabled = true
    local tl = billboard:FindFirstChild("TL")
    if tl then
        tl.Text = labelText
        tl.TextColor3 = color
        tl.TextSize = isItem and 14 or 18
    end
end

function ESP.clearVisuals(targetObj)
    if not targetObj then return end
    local container = targetObj:FindFirstChild("ByteVisuals")
    if container then
        container:Destroy()
    end
end

return ESP