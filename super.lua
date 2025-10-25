--// LocalScript — RotUp! Premium: grey UI, Duplicate/Delete, draggable, collapse (X), toggle (G)
--// Duplicate делает точную копию предмета в хотбар; Delete удаляет только дупы

-- =========================
-- ======  SETTINGS  =======
-- =========================
local DELETE_ALL_DUPES = false     -- false: delete only latest dupe; true: delete all dupes
local TOAST_DURATION = 2.0         -- seconds
local TOGGLE_KEY = Enum.KeyCode.G  -- open/close UI

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
screenGui.Name = "DupeMenuUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Panel
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 380, 0, 110)
panel.Position = UDim2.new(0, 20, 1, -140)
panel.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
panel.BorderSizePixel = 0
panel.Visible = true
panel.Active = true
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
local panelStroke = Instance.new("UIStroke", panel)
panelStroke.Thickness = 1
panelStroke.Color = Color3.fromRGB(90, 90, 90)
panelStroke.Transparency = 0.2

-- Soft shadow
local shadow = Instance.new("Frame")
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
titleBar.Size = UDim2.new(1, -16, 0, 36)
titleBar.Position = UDim2.new(0, 8, 0, 8)
titleBar.BackgroundTransparency = 1
titleBar.Active = true
titleBar.Parent = panel

local titleLayout = Instance.new("UIListLayout", titleBar)
titleLayout.FillDirection = Enum.FillDirection.Horizontal
titleLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
titleLayout.VerticalAlignment = Enum.VerticalAlignment.Center
titleLayout.Padding = UDim.new(0, 8)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -44, 1, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "RotUp! Premium"
titleLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
titleLabel.Font = Enum.Font.GothamSemibold
titleLabel.TextSize = 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 32, 0, 32)
closeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(230, 230, 230)
closeBtn.Font = Enum.Font.GothamSemibold
closeBtn.TextSize = 16
closeBtn.AutoButtonColor = true
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
local closeStroke = Instance.new("UIStroke", closeBtn)
closeStroke.Color = Color3.fromRGB(110, 110, 110)
closeStroke.Thickness = 1
closeStroke.Transparency = 0.15

-- Buttons row
local btnRow = Instance.new("Frame")
btnRow.Size = UDim2.new(1, -16, 0, 56)
btnRow.Position = UDim2.new(0, 8, 0, 46)
btnRow.BackgroundTransparency = 1
btnRow.Parent = panel

local rowLayout = Instance.new("UIListLayout", btnRow)
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
rowLayout.VerticalAlignment = Enum.VerticalAlignment.Center
rowLayout.Padding = UDim.new(0, 10)

local function makeButton(text)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 170, 0, 44)
    btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)
    btn.TextColor3 = Color3.fromRGB(230, 230, 230)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 16
    btn.AutoButtonColor = true
    btn.Text = text
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
    local s = Instance.new("UIStroke", btn)
    s.Color = Color3.fromRGB(110, 110, 110)
    s.Thickness = 1
    s.Transparency = 0.15
    btn.Parent = btnRow
    return btn
end

local duplicateBtn = makeButton("Duplicate")
local deleteBtn = makeButton("Delete") -- ← текст кнопки удаления

-- Toast
local toast = Instance.new("TextLabel")
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
Instance.new("UICorner", toast).CornerRadius = UDim.new(0, 8)
local toastStroke = Instance.new("UIStroke", toast)
toastStroke.Color = Color3.fromRGB(100, 100, 100)
toastStroke.Thickness = 1
toastStroke.Transparency = 0.2

local function showToast(msg)
    toast.Text = msg
    toast.Visible = true
    toast.TextTransparency = 1
    toast.BackgroundTransparency = 1
    TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {TextTransparency = 0, BackgroundTransparency = 0}):Play()
    task.delay(TOAST_DURATION, function()
        if toast.Visible then
            local t = TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {TextTransparency = 1, BackgroundTransparency = 1})
            t:Play(); t.Completed:Wait(); toast.Visible = false
        end
    end)
end

-- =========================
-- =====  HELPERS  =========
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

local function deepDupeWithAttributesAndTags(source)
    local dupe = source:Clone()
    local function withSelfList(root)
        local list = {root}
        for _, d in ipairs(root:GetDescendants()) do table.insert(list, d) end
        return list
    end
    local srcList = withSelfList(source)
    local dupeList = withSelfList(dupe)

    for i = 1, math.min(#srcList, #dupeList) do
        local src = srcList[i]
        local dst = dupeList[i]
        copyAttributes(src, dst)
        tagCopy(src, dst)

        if src:IsA("BasePart") and dst:IsA("BasePart") then
            pcall(function()
                dst.Anchored     = src.Anchored
                dst.CanCollide   = src.CanCollide
                dst.Material     = src.Material
                dst.Color        = src.Color
                dst.Transparency = src.Transparency
                dst.Reflectance  = src.Reflectance
            end)
        end

        if src:IsA("Tool") and dst:IsA("Tool") then
            pcall(function()
                dst.ToolTip        = src.ToolTip
                dst.RequiresHandle = src.RequiresHandle
                dst.CanBeDropped   = src.CanBeDropped
                dst.Grip           = src.Grip
            end)
        end
    end
    return dupe
end

local function wrapModelInTool(modelDupe)
    local tool = Instance.new("Tool")
    tool.Name = modelDupe.Name
    tool.RequiresHandle = false
    tool.CanBeDropped = true
    copyAttributes(modelDupe, tool)
    tagCopy(modelDupe, tool)
    modelDupe.Parent = tool
    return tool
end

local function findDupes()
    local results = {}
    local backpack = LOCAL_PLAYER:FindFirstChild("Backpack")
    if backpack then
        for _, inst in ipairs(backpack:GetChildren()) do
            if inst:IsA("Tool") and inst:GetAttribute("IsDupe") == true then
                table.insert(results, inst)
            end
        end
    end
    local char = LOCAL_PLAYER.Character
    if char then
        for _, inst in ipairs(char:GetChildren()) do
            if inst:IsA("Tool") and inst:GetAttribute("IsDupe") == true then
                table.insert(results, inst)
            end
        end
    end
    table.sort(results, function(a, b)
        local ta = tonumber(a:GetAttribute("DupeTimestamp")) or 0
        local tb = tonumber(b:GetAttribute("DupeTimestamp")) or 0
        return ta < tb
    end)
    return results
end

-- =========================
-- =====  ACTIONS  =========
-- =========================
local function duplicateEquipped()
    local equipped = getEquippedTool()
    if not equipped then
        showToast("Equip an item first.")
        return
    end

    local dupeRoot
    if equipped:IsA("Tool") then
        dupeRoot = deepDupeWithAttributesAndTags(equipped)
    else
        dupeRoot = wrapModelInTool(deepDupeWithAttributesAndTags(equipped))
    end

    -- mark dupe so Delete targets only dupes
    dupeRoot:SetAttribute("IsDupe", true)
    dupeRoot:SetAttribute("DupeTimestamp", os.clock())

    -- add to Backpack so it appears in hotbar
    local backpack = LOCAL_PLAYER:WaitForChild("Backpack")
    dupeRoot.Parent = backpack

    -- try to equip locally
    local char = LOCAL_PLAYER.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum:EquipTool(dupeRoot) end)
    end

    showToast("Duped to hotbar.")
end

local function deleteLatestDupe()
    local dupes = findDupes()
    if #dupes == 0 then
        showToast("No dupes to delete.")
        return
    end

    if DELETE_ALL_DUPES then
        for _, tool in ipairs(dupes) do pcall(function() tool:Destroy() end) end
        showToast(("Deleted %d dupe(s)."):format(#dupes))
    else
        local latest = dupes[#dupes]
        pcall(function() latest:Destroy() end)
        showToast("Deleted latest dupe.")
    end
end

-- =========================
-- ===  UI INTERACTIONS ====
-- =========================
local menuOpen = true
local function setMenuVisible(v)
    menuOpen = v
    panel.Visible = v
    shadow.Visible = v
    if not v and toast.Visible then toast.Visible = false end
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
    deleteLatestDupe()
    task.delay(0.1, function() debounce = false end)
end)

-- Collapse via X
closeBtn.MouseButton1Click:Connect(function() setMenuVisible(false) end)

-- Toggle via G (ignore when typing)
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == TOGGLE_KEY then
        if UserInputService:GetFocusedTextBox() then return end
        setMenuVisible(not menuOpen)
    end
end)

-- Draggable by titleBar
local dragging, dragInput, dragStart = false, nil, Vector2.new()
local startPos = panel.Position
local function clampToScreen(pos)
    local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1920,1080)
    local x = math.clamp(pos.X.Offset, -panel.AbsoluteSize.X + 20, vp.X - 20)
    local y = math.clamp(pos.Y.Offset, 20, vp.Y - 20)
    return UDim2.fromOffset(x, y)
end
local function updateDrag(input)
    local delta = input.Position - dragStart
    panel.Position = clampToScreen(UDim2.fromOffset(startPos.X.Offset + delta.X, startPos.Y.Offset + delta.Y))
end
titleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = panel.Position; dragInput = input
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then dragging = false; dragInput = nil end
        end)
    end
end)
titleBar.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then updateDrag(input) end
end)

-- Keep shadow aligned
RunService.RenderStepped:Connect(function()
    shadow.Position = panel.Position + UDim2.new(0, 4, 0, 4)
    shadow.Size = panel.Size
    shadow.Visible = panel.Visible
end)
