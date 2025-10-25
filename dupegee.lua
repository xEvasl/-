--// LocalScript — Client-side only
--// Minimal grey UI + Duplicate/Delete + collapse (X) + toggle by G + draggable title bar
--// No server calls. No DataStores. No E-key handling (compatibility only).

-- =========================
-- ======  SETTINGS  =======
-- =========================
local DELETE_ALL_CLONES = false   -- false = delete most recent clone only; true = delete all clones made by this script
local TOAST_DURATION = 2.0        -- seconds the toast stays visible
local TOGGLE_KEY = Enum.KeyCode.G -- open/close menu

-- =========================
-- ======  SERVICES  =======
-- =========================
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LOCAL_PLAYER = Players.LocalPlayer

-- =========================
-- =======  UI  ============
-- =========================
local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CloneMenuUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Container panel (expanded a bit)
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 380, 0, 110)         -- wider & taller
panel.Position = UDim2.new(0, 20, 1, -140)     -- bottom-left-ish
panel.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
panel.BorderSizePixel = 0
panel.Visible = true
panel.Active = true  -- allow input capture
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness = 1
panelStroke.Color = Color3.fromRGB(90, 90, 90)
panelStroke.Transparency = 0.2
panelStroke.Parent = panel

-- Soft shadow
local shadow = Instance.new("Frame")
shadow.Name = "Shadow"
shadow.Size = panel.Size
shadow.Position = panel.Position + UDim2.new(0, 4, 0, 4)
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.75
shadow.BorderSizePixel = 0
shadow.ZIndex = panel.ZIndex - 1
shadow.Visible = panel.Visible
shadow.Parent = screenGui

-- Title bar
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, -16, 0, 36)
titleBar.Position = UDim2.new(0, 8, 0, 8)
titleBar.BackgroundTransparency = 1
titleBar.Active = true     -- for dragging
titleBar.Parent = panel

local titleLayout = Instance.new("UIListLayout")
titleLayout.FillDirection = Enum.FillDirection.Horizontal
titleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
titleLayout.Padding = UDim.new(0, 8)
titleLayout.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -44, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "RotUp! Premium"
titleLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
titleLabel.Font = Enum.Font.GothamSemibold
titleLabel.TextSize = 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

-- Close (collapse) button "X"
local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
closeBtn.Font = Enum.Font.GothamSemibold
closeBtn.TextSize = 16
closeBtn.AutoButtonColor = true
closeBtn.Parent = titleBar
local closeCorner = Instance.new("UICorner", closeBtn)
closeCorner.CornerRadius = UDim.new(0, 8)
local closeStroke = Instance.new("UIStroke", closeBtn)
closeStroke.Color = Color3.fromRGB(110, 110, 110)
closeStroke.Thickness = 1
closeStroke.Transparency = 0.15

-- Buttons container
local btnRow = Instance.new("Frame")
btnRow.Name = "Buttons"
btnRow.Size = UDim2.new(1, -16, 0, 56)
btnRow.Position = UDim2.new(0, 8, 0, 46)
btnRow.BackgroundTransparency = 1
btnRow.Parent = panel

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 10)
layout.Parent = btnRow

local function makeButton(text)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 170, 0, 44)
    btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    btn.TextColor3 = Color3.fromRGB(230, 230, 230)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 16
    btn.AutoButtonColor = true
    btn.Text = text

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 10)
    c.Parent = btn

    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(110, 110, 110)
    s.Thickness = 1
    s.Transparency = 0.15
    s.Parent = btn

    btn.Parent = btnRow
    return btn
end

local duplicateBtn = makeButton("Duplicate")
local deleteBtn = makeButton("Delete")

-- Toast
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.Size = UDim2.new(0, 320, 0, 26)
toast.Position = UDim2.new(0, 20, 1, -175)
toast.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
toast.TextColor3 = Color3.fromRGB(235, 235, 235)
toast.Font = Enum.Font.Gotham
toast.TextSize = 14
toast.TextWrapped = true
toast.Visible = false
toast.BorderSizePixel = 0
toast.Parent = screenGui
local toastCorner = Instance.new("UICorner", toast)
toastCorner.CornerRadius = UDim.new(0, 8)
local toastStroke = Instance.new("UIStroke", toast)
toastStroke.Color = Color3.fromRGB(100, 100, 100)
toastStroke.Thickness = 1
toastStroke.Transparency = 0.2

local function showToast(msg)
    toast.Text = msg
    toast.Visible = true
    toast.TextTransparency = 1
    toast.BackgroundTransparency = 1
    local tweenIn = TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {TextTransparency = 0, BackgroundTransparency = 0})
    tweenIn:Play()
    tweenIn.Completed:Wait()
    task.delay(TOAST_DURATION, function()
        if toast.Visible then
            local tweenOut = TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {TextTransparency = 1, BackgroundTransparency = 1})
            tweenOut:Play()
            tweenOut.Completed:Wait()
            toast.Visible = false
        end
    end)
end

-- =========================
-- ===  HELPER UTILS   =====
-- =========================

local function getEquippedTool()
    local char = LOCAL_PLAYER.Character
    if not char then return nil end
    for _, inst in ipairs(char:GetChildren()) do
        if inst:IsA("Tool") then
            return inst
        end
    end
    return nil
end

local function copyAttributes(fromInstance, toInstance)
    local ok, attrs = pcall(function() return fromInstance:GetAttributes() end)
    if ok and attrs then
        for k, v in pairs(attrs) do
            pcall(function() toInstance:SetAttribute(k, v) end)
        end
    end
end

local function tagCopy(fromInstance, toInstance)
    local ok, tags = pcall(function() return CollectionService:GetTags(fromInstance) end)
    if ok and tags then
        for _, tag in ipairs(tags) do
            pcall(function() CollectionService:AddTag(toInstance, tag) end)
        end
    end
end

local function deepCloneWithAttributesAndTags(source)
    local clone = source:Clone()

    local function withSelfList(root)
        local list = {root}
        for _, d in ipairs(root:GetDescendants()) do
            table.insert(list, d)
        end
        return list
    end

    local srcList = withSelfList(source)
    local cloneList = withSelfList(clone)

    for i = 1, math.min(#srcList, #cloneList) do
        local src = srcList[i]
        local dst = cloneList[i]
        copyAttributes(src, dst)
        tagCopy(src, dst)
        if src:IsA("BasePart") and dst:IsA("BasePart") then
            pcall(function()
                dst.Anchored = src.Anchored
                dst.CanCollide = src.CanCollide
                dst.Material = src.Material
                dst.Color = src.Color
                dst.Transparency = src.Transparency
                dst.Reflectance = src.Reflectance
            end)
        end
        if src:IsA("Tool") and dst:IsA("Tool") then
            pcall(function()
                dst.ToolTip = src.ToolTip
                dst.RequiresHandle = src.RequiresHandle
                dst.CanBeDropped = src.CanBeDropped
                dst.Grip = src.Grip
            end)
        end
    end
    return clone
end

local function findClones()
    local results = {}
    local backpack = LOCAL_PLAYER:FindFirstChild("Backpack")
    if backpack then
        for _, inst in ipairs(backpack:GetChildren()) do
            if inst:IsA("Tool") and inst:GetAttribute("IsClone") == true then
                table.insert(results, inst)
            end
        end
    end
    local char = LOCAL_PLAYER.Character
    if char then
        for _, inst in ipairs(char:GetChildren()) do
            if inst:IsA("Tool") and inst:GetAttribute("IsClone") == true then
                table.insert(results, inst)
            end
        end
    end
    table.sort(results, function(a, b)
        local ta = tonumber(a:GetAttribute("CloneTimestamp")) or 0
        local tb = tonumber(b:GetAttribute("CloneTimestamp")) or 0
        return ta < tb
    end)
    return results
end

local function deleteLatestClone()
    local clones = findClones()
    if #clones == 0 then
        showToast("No clones to delete.")
        return
    end

    if DELETE_ALL_CLONES then
        local count = 0
        for _, tool in ipairs(clones) do
            count += 1
            pcall(function() tool:Destroy() end)
        end
        showToast(("Deleted %d clone(s)."):format(count))
    else
        local latest = clones[#clones]
        pcall(function() latest:Destroy() end)
        showToast("Deleted latest clone.")
    end
end

local function wrapModelInTool(modelClone)
    local tool = Instance.new("Tool")
    tool.Name = modelClone.Name
    tool.RequiresHandle = false
    tool.CanBeDropped = true
    copyAttributes(modelClone, tool)
    tagCopy(modelClone, tool)
    modelClone.Parent = tool
    pcall(function()
        if modelClone.PrimaryPart then
            tool.Grip = CFrame.new()
        end
    end)
    return tool
end

local function duplicateEquipped()
    local equipped = getEquippedTool()
    if not equipped then
        showToast("Equip an item first.")
        return
    end

    local cloneRoot
    if equipped:IsA("Tool") then
        local toolClone = deepCloneWithAttributesAndTags(equipped)
        toolClone:SetAttribute("IsClone", true)
        toolClone:SetAttribute("CloneTimestamp", os.clock())
        cloneRoot = toolClone
    else
        local modelClone = deepCloneWithAttributesAndTags(equipped)
        cloneRoot = wrapModelInTool(modelClone)
        cloneRoot:SetAttribute("IsClone", true)
        cloneRoot:SetAttribute("CloneTimestamp", os.clock())
    end

    local backpack = LOCAL_PLAYER:WaitForChild("Backpack")
    cloneRoot.Parent = backpack
    showToast("Cloned to hotbar.")
end

-- =========================
-- ===  UI INTERACTIONS ====
-- =========================
local menuOpen = true
local function setMenuVisible(visible)
    menuOpen = visible
    panel.Visible = visible
    shadow.Visible = visible
    if not visible and toast.Visible then
        toast.Visible = false
    end
end

-- Buttons
local debounce = false
duplicateBtn.MouseButton1Click:Connect(function()
    if debounce then return end; debounce = true
    duplicateEquipped()
    task.delay(0.1, function() debounce = false end)
end)

deleteBtn.MouseButton1Click:Connect(function()
    if debounce then return end; debounce = true
    deleteLatestClone()
    task.delay(0.1, function() debounce = false end)
end)

-- Collapse via X button
closeBtn.MouseButton1Click:Connect(function()
    setMenuVisible(false)
end)

-- Toggle by G (don’t trigger while typing)
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == TOGGLE_KEY then
        if UserInputService:Get
