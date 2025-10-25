-- Universal RotUp! Premium (single source for both server & client)
-- Paste this SAME code as:
--   1) Script  -> ServerScriptService (server part auto-activates)
--   2) LocalScript -> StarterPlayerScripts (client UI auto-activates)
-- No external modules. Cloning parity via server; client-only fallback if server remotes missing.

-- =========================
-- ======  SETTINGS  =======
-- =========================
local SETTINGS = {
    USE_SERVER_DUPLICATION = true,   -- полнофункциональная идентичность через сервер
    DELETE_ALL_CLONES       = false, -- true = удалять все клоны за раз
    TOAST_DURATION          = 2.0,
    TOGGLE_KEY              = Enum and Enum.KeyCode and Enum.KeyCode.G or nil, -- защита при серверной загрузке
}

-- =========================
-- ======  SERVICES  =======
-- =========================
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

-- ========= Shared helpers (и сервер, и клиент) =========
local function copyAttributes(fromInstance, toInstance)
    local ok, attrs = pcall(function() return fromInstance:GetAttributes() end)
    if ok and attrs then
        for k, v in pairs(attrs) do pcall(function() toInstance:SetAttribute(k, v) end) end
    end
end

local function tagCopy(fromInstance, toInstance)
    local ok, tags = pcall(function() return CollectionService:GetTags(fromInstance) end)
    if ok and tags then
        for _, tag in ipairs(tags) do pcall(function() CollectionService:AddTag(toInstance, tag) end) end
    end
end

local function deepCloneWithAttributesAndTags(source)
    local clone = source:Clone()
    local function listWithSelf(root)
        local t = {root}
        for _, d in ipairs(root:GetDescendants()) do table.insert(t, d) end
        return t
    end
    local src = listWithSelf(source)
    local dst = listWithSelf(clone)
    for i = 1, math.min(#src, #dst) do
        local s, d = src[i], dst[i]
        copyAttributes(s, d)
        tagCopy(s, d)
        if s:IsA("BasePart") and d:IsA("BasePart") then
            pcall(function()
                d.Anchored     = s.Anchored
                d.CanCollide   = s.CanCollide
                d.Material     = s.Material
                d.Color        = s.Color
                d.Transparency = s.Transparency
                d.Reflectance  = s.Reflectance
            end)
        end
        if s:IsA("Tool") and d:IsA("Tool") then
            pcall(function()
                d.ToolTip        = s.ToolTip
                d.RequiresHandle = s.RequiresHandle
                d.CanBeDropped   = s.CanBeDropped
                d.Grip           = s.Grip
            end)
        end
    end
    return clone
end

local function wrapModelInTool(modelClone)
    local tool = Instance.new("Tool")
    tool.Name = modelClone.Name
    tool.RequiresHandle = false
    tool.CanBeDropped   = true
    copyAttributes(modelClone, tool)
    tagCopy(modelClone, tool)
    modelClone.Parent = tool
    return tool
end

-- =========================
-- ===== SERVER BRANCH =====
-- =========================
if RunService:IsServer() then
    -- Создаём RemoteEvent'ы один раз
    local folder = ReplicatedStorage:FindFirstChild("RotUp_Remotes")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "RotUp_Remotes"
        folder.Parent = ReplicatedStorage
    end

    local REQ_DUPLICATE = folder:FindFirstChild("RequestDuplicate") or Instance.new("RemoteEvent")
    REQ_DUPLICATE.Name = "RequestDuplicate"
    REQ_DUPLICATE.Parent = folder

    local REQ_DELETE = folder:FindFirstChild("RequestDelete") or Instance.new("RemoteEvent")
    REQ_DELETE.Name = "RequestDelete"
    REQ_DELETE.Parent = folder

    local function getEquippedToolServer(char)
        if not char then return nil end
        for _, inst in ipairs(char:GetChildren()) do
            if inst:IsA("Tool") then return inst end
        end
        return nil
    end

    local function findClonesServer(player)
        local t = {}
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            for _, inst in ipairs(backpack:GetChildren()) do
                if inst:IsA("Tool") and inst:GetAttribute("IsClone") == true then table.insert(t, inst) end
            end
        end
        local char = player.Character
        if char then
            for _, inst in ipairs(char:GetChildren()) do
                if inst:IsA("Tool") and inst:GetAttribute("IsClone") == true then table.insert(t, inst) end
            end
        end
        table.sort(t, function(a, b)
            local ta = tonumber(a:GetAttribute("CloneTimestamp")) or 0
            local tb = tonumber(b:GetAttribute("CloneTimestamp")) or 0
            return ta < tb
        end)
        return t
    end

    -- Серверное дублирование: полная идентичность
    REQ_DUPLICATE.OnServerEvent:Connect(function(player, equippedRef)
        local char = player.Character
        if not char then return end

        local equipped
        if typeof(equippedRef) == "Instance" and equippedRef:IsDescendantOf(char) and equippedRef:IsA("Tool") then
            equipped = equippedRef
        else
            equipped = getEquippedToolServer(char)
        end
        if not equipped then return end

        local cloneRoot
        if equipped:IsA("Tool") then
            cloneRoot = deepCloneWithAttributesAndTags(equipped)
        else
            cloneRoot = wrapModelInTool(deepCloneWithAttributesAndTags(equipped))
        end
        cloneRoot:SetAttribute("IsClone", true)
        cloneRoot:SetAttribute("CloneTimestamp", os.clock())

        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            cloneRoot.Parent = backpack
        else
            cloneRoot:Destroy()
        end
    end)

    -- Серверное удаление
    REQ_DELETE.OnServerEvent:Connect(function(player, deleteAll)
        local clones = findClonesServer(player)
        if #clones == 0 then return end
        if deleteAll then
            for _, tool in ipairs(clones) do pcall(function() tool:Destroy() end) end
        else
            local latest = clones[#clones]
            pcall(function() latest:Destroy() end)
        end
    end)

    return -- серверная часть завершена
end

-- =========================
-- ===== CLIENT BRANCH =====
-- =========================
if RunService:IsClient() then
    local Players = game:GetService("Players")
    local TweenService = game:GetService("TweenService")
    local UserInputService = game:GetService("UserInputService")
    local RunSvc = game:GetService("RunService")

    local LOCAL_PLAYER = Players.LocalPlayer
    local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")

    -- Remotes (если серверный скрипт установлен — будут; иначе fallback)
    local remotesFolder = ReplicatedStorage:FindFirstChild("RotUp_Remotes")
    local REQ_DUPLICATE = remotesFolder and remotesFolder:FindFirstChild("RequestDuplicate")
    local REQ_DELETE    = remotesFolder and remotesFolder:FindFirstChild("RequestDelete")
    local HAS_SERVER    = (REQ_DUPLICATE and REQ_DELETE) ~= nil

    -- -------- UI (минимальный серый стиль, draggable, крестик, toggle G) --------
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CloneMenuUI"
    screenGui.ResetOnSpawn = false
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

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

    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
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
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, -44, 1, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "RotUp! Premium"
    titleLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
    titleLabel.Font = Enum.Font.GothamSemibold
    titleLabel.TextSize = 18
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar

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
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
    local closeStroke = Instance.new("UIStroke", closeBtn)
    closeStroke.Color = Color3.fromRGB(110, 110, 110)
    closeStroke.Thickness = 1
    closeStroke.Transparency = 0.15

    local btnRow = Instance.new("Frame")
    btnRow.Name = "Buttons"
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
    local deleteBtn = makeButton("Delete") -- ← вот тут текст кнопки удаления

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
        task.delay(SETTINGS.TOAST_DURATION, function()
            if toast.Visible then
                local t = TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {TextTransparency = 1, BackgroundTransparency = 1})
                t:Play(); t.Completed:Wait(); toast.Visible = false
            end
        end)
    end

    -- ==== Client helpers ====
    local function getEquippedTool()
        local char = LOCAL_PLAYER.Character
        if not char then return nil end
        for _, inst in ipairs(char:GetChildren()) do
            if inst:IsA("Tool") then return inst end
        end
        return nil
    end

    local function findClonesClient()
        local results = {}
        local backpack = LOCAL_PLAYER:FindFirstChild("Backpack")
        if backpack then
            for _, inst in ipairs(backpack:GetChildren()) do
                if inst:IsA("Tool") and inst:GetAttribute("IsClone") == true then table.insert(results, inst) end
            end
        end
        local char = LOCAL_PLAYER.Character
        if char then
            for _, inst in ipairs(char:GetChildren()) do
                if inst:IsA("Tool") and inst:GetAttribute("IsClone") == true then table.insert(results, inst) end
            end
        end
        table.sort(results, function(a, b)
            local ta = tonumber(a:GetAttribute("CloneTimestamp")) or 0
            local tb = tonumber(b:GetAttribute("CloneTimestamp")) or 0
            return ta < tb
        end)
        return results
    end

    -- ==== Client fallback (если сервера нет) ====
    local function clientDuplicate()
        local equipped = getEquippedTool()
        if not equipped then showToast("Equip an item first."); return end
        local cloneRoot
        if equipped:IsA("Tool") then
            cloneRoot = deepCloneWithAttributesAndTags(equipped)
        else
            cloneRoot = wrapModelInTool(deepCloneWithAttributesAndTags(equipped))
        end
        cloneRoot:SetAttribute("IsClone", true)
        cloneRoot:SetAttribute("CloneTimestamp", os.clock())
        cloneRoot.Parent = LOCAL_PLAYER:WaitForChild("Backpack")
        showToast("Cloned to hotbar (client).")
    end

    local function clientDelete()
        local clones = findClonesClient()
        if #clones == 0 then showToast("No clones to delete."); return end
        if SETTINGS.DELETE_ALL_CLONES then
            for _, t in ipairs(clones) do pcall(function() t:Destroy() end) end
            showToast(("Deleted %d clone(s)."):format(#clones))
        else
            local latest = clones[#clones]
            pcall(function() latest:Destroy() end)
            showToast("Deleted latest clone.")
        end
    end

    -- ==== Actions (server-aware) ====
    local function duplicateAction()
        if SETTINGS.USE_SERVER_DUPLICATION and HAS_SERVER then
            local equipped = getEquippedTool()
            if not equipped then showToast("Equip an item first."); return end
            REQ_DUPLICATE:FireServer(equipped)
            showToast("Requested server clone…")
        else
            clientDuplicate()
        end
    end

    local function deleteAction()
        if SETTINGS.USE_SERVER_DUPLICATION and HAS_SERVER then
            REQ_DELETE:FireServer(SETTINGS.DELETE_ALL_CLONES)
            showToast("Requested server delete…")
        else
            clientDelete()
        end
    end

    -- ==== UI interactions ====
    local menuOpen = true
    local function setMenuVisible(v)
        menuOpen = v
        panel.Visible = v
        shadow.Visible = v
        if not v and toast.Visible then toast.Visible = false end
    end

    local debounce = false
    duplicateBtn.MouseButton1Click:Connect(function()
        if debounce then return end; debounce = true
        duplicateAction()
        task.delay(0.1, function() debounce = false end)
    end)

    deleteBtn.MouseButton1Click:Connect(function()
        if debounce then return end; debounce = true
        deleteAction()
        task.delay(0.1, function() debounce = false end)
    end)

    closeBtn.MouseButton1Click:Connect(function() setMenuVisible(false) end)

    if SETTINGS.TOGGLE_KEY then
        UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == SETTINGS.TOGGLE_KEY then
                if UserInputService:GetFocusedTextBox() then return end
                setMenuVisible(not menuOpen)
            end
        end)
    end

    -- Draggable title bar
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

    RunSvc.RenderStepped:Connect(function()
        shadow.Position = panel.Position + UDim2.new(0, 4, 0, 4)
        shadow.Size = panel.Size
        shadow.Visible = panel.Visible
    end)
end
