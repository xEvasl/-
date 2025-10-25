--!strict
-- LocalScript (StarterGui) — строго client-side. Никаких RemoteEvents/RemoteFunctions.

--========================================================
--                     ИМПОРТЫ/ССЫЛКИ
--========================================================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

--========================================================
--               КОНСТАНТЫ / НАСТРОЙКИ
--========================================================
local PLATFORM_TAG = "PlacementPlatform"     -- основной способ пометить платформы
local PLATFORM_NAME = "PlacementPlatform"    -- альтернативно — по имени
local PREVIEW_OFFSET = 0.1                   -- на сколько приподнимать предпросмотр над поверхностью
local UI_SIZE = UDim2.fromOffset(280, 120)
local UI_PADDING = 10
local TITLE_HEIGHT = 28
local CORNER_RADIUS = 10
local BUTTON_HEIGHT = 32
local BUTTON_PAD = 8
local TOAST_TIME = 2.0
local RAY_DISTANCE = 1000
local PLACE_ON_GRID = false                  -- включи true, если нужна привязка к сетке
local GRID_SIZE = 1

--========================================================
--                   ЛОКАЛЬНОЕ СОСТОЯНИЕ
--========================================================
local managedPlacedStack: {Model} = {}       -- стек установленных клонов (LIFO)
local previewModel: Model? = nil             -- текущий предпросмотр
local previewConnHeartbeat: RBXScriptConnection? = nil
local highlightBox: SelectionBox? = nil      -- подсветка платформы
local virtualHotbar: {Instance} = {}         -- виртуальная запись дубликатов (client-only)
local dragState = { dragging = false, offset = Vector2.zero }

--========================================================
--                   ВСПОМОГАТЕЛЬНЫЕ УТИЛИТЫ
--========================================================
local function showToast(msg: string)
    -- Ненавязчивая подсказка
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = "Hint",
            Text = msg,
            Duration = TOAST_TIME
        })
    end)
end

local function isPlatform(inst: Instance?): boolean
    if not inst then return false end
    if CollectionService:HasTag(inst, PLATFORM_TAG) then return true end
    if inst.Name == PLATFORM_NAME then return true end
    local parent = inst.Parent
    if parent and (CollectionService:HasTag(parent, PLATFORM_TAG) or parent.Name == PLATFORM_NAME) then
        return true
    end
    return false
end

local function getPlatformRoot(inst: Instance?): BasePart?
    if not inst then return nil end
    if inst:IsA("BasePart") and isPlatform(inst) then
        return inst
    end
    -- если это часть модели-платформы
    local parent = inst.Parent
    if parent and parent:IsA("Model") and isPlatform(parent) then
        local mdl = parent :: Model
        if mdl.PrimaryPart and mdl.PrimaryPart:IsA("BasePart") then
            return mdl.PrimaryPart
        end
        for _, d in ipairs(mdl:GetDescendants()) do
            if d:IsA("BasePart") then
                return d
            end
        end
    end
    -- если родитель — BasePart c признаками платформы
    if inst.Parent and inst.Parent:IsA("BasePart") and isPlatform(inst.Parent) then
        return inst.Parent
    end
    return nil
end

local function snapToGrid(v: Vector3): Vector3
    if not PLACE_ON_GRID then return v end
    local function s(x: number) return math.floor((x + GRID_SIZE/2)/GRID_SIZE)*GRID_SIZE end
    return Vector3.new(s(v.X), s(v.Y), s(v.Z))
end

local function getEquippedTool(): Instance?
    local char = LocalPlayer.Character
    if not char then return nil end
    for _, inst in ipairs(char:GetChildren()) do
        if inst:IsA("Tool") then
            return inst
        end
    end
    -- иногда Tool может быть активирован через Backpack, но не висеть в Character — опционально можно проверить Backpack
    return nil
end

local function firstBasePart(container: Instance): BasePart?
    for _, d in ipairs(container:GetDescendants()) do
        if d:IsA("BasePart") then
            return d
        end
    end
    return nil
end

local function ensureModelFromTool(toolOrModel: Instance): Model?
    -- Унифицируем к модели. Попутно сохраним метаданные в атрибутах.
    if toolOrModel:IsA("Model") then
        local m = (toolOrModel :: Model):Clone()
        if not m.PrimaryPart then
            local pp = firstBasePart(m)
            if pp then m.PrimaryPart = pp end
        end
        -- метаданные
        m:SetAttribute("SourceName", toolOrModel.Name)
        m:SetAttribute("SourceClass", toolOrModel.ClassName)
        return m
    end

    if toolOrModel:IsA("Tool") then
        -- Клонируем Tool, переносим его содержимое в новую Model, уничтожаем временный Tool-клон (фикс утечки)
        local toolClone = (toolOrModel :: Instance):Clone()
        local model = Instance.new("Model")
        model.Name = toolOrModel.Name .. "_Clone"

        for _, ch in ipairs(toolClone:GetChildren()) do
            ch.Parent = model
        end
        toolClone:Destroy()

        local primary = model:FindFirstChild("Handle", true)
        if primary and primary:IsA("BasePart") then
            (model :: Model).PrimaryPart = primary
        else
            local anyPart = firstBasePart(model)
            if anyPart then (model :: Model).PrimaryPart = anyPart end
        end

        -- метаданные
        model:SetAttribute("SourceName", toolOrModel.Name)
        model:SetAttribute("SourceClass", toolOrModel.ClassName)
        -- для наглядности попробуем вытащить возможный AssetId, если разработчик передавал его атрибутом/значением:
        local function tryCopyAttr(attr: string)
            local ok, val = pcall(function() return (toolOrModel :: any):GetAttribute(attr) end)
            if ok and val ~= nil then model:SetAttribute(attr, val) end
        end
        tryCopyAttr("AssetId")
        tryCopyAttr("ItemId")

        return model
    end

    return nil
end

local function setModelCollision(model: Model, canCollide: boolean)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            d.CanCollide = canCollide
        end
    end
end

local function setModelAnchored(model: Model, anchored: boolean)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            d.Anchored = anchored
            d.AssemblyLinearVelocity = Vector3.zero
            d.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

local function tagManaged(model: Model)
    model:SetAttribute("ClientManagedClone", true)
end

local function isManaged(inst: Instance?): boolean
    if not inst then return false end
    local m = inst:IsA("Model") and inst or inst:FindFirstAncestorOfClass("Model")
    if m then
        return (m :: Model):GetAttribute("ClientManagedClone") == true
    end
    return false
end

local function modelBounds(model: Model): (CFrame, Vector3)
    local cf, size = model:GetBoundingBox()
    return cf, size
end

local function centerOnPlatform(model: Model, platformPart: BasePart)
    -- Центр модели в центр платформы, ориентация как у платформы
    local _, size = modelBounds(model)
    local halfHeight = size.Y * 0.5
    local platCF = platformPart.CFrame
    local upOffset = Vector3.new(0, (platformPart.Size.Y * 0.5) + halfHeight, 0)
    local finalPos = platCF.Position + upOffset
    finalPos = snapToGrid(finalPos)

    -- CFrame.fromMatrix ожидает backVector, которым в роблоксе является ZVector (это "назад")
    local finalCF = CFrame.fromMatrix(finalPos, platCF.XVector, platCF.YVector, platCF.ZVector)
    model:PivotTo(finalCF)
end

local function gentlyPop(model: Model)
    -- Лёгкая "щёлк"-анимация
    local parts: {BasePart} = {}
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then table.insert(parts, d) end
    end
    if #parts == 0 then return end
    for _, p in ipairs(parts) do
        p.Position += Vector3.new(0, 0.05, 0)
    end
    task.delay(0.02, function()
        for _, p in ipairs(parts) do
            p.Position -= Vector3.new(0, 0.05, 0)
        end
    end)
end

--========================================================
--                         UI
--========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ClientClonerUI"
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

-- Основная панель
local Frame = Instance.new("Frame")
Frame.Size = UI_SIZE
Frame.AnchorPoint = Vector2.new(0.5, 0.5)
Frame.Position = UDim2.fromScale(0.5, 0.5)
Frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, CORNER_RADIUS)
UICorner.Parent = Frame

local UIStroke = Instance.new("UIStroke")
UIStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
UIStroke.Thickness = 1
UIStroke.Color = Color3.fromRGB(70, 70, 80)
UIStroke.Parent = Frame

-- Тайтлбар
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, TITLE_HEIGHT)
TitleBar.BackgroundTransparency = 0.1
TitleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Frame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, CORNER_RADIUS)
TitleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -UI_PADDING*2, 1, 0)
TitleLabel.Position = UDim2.fromOffset(UI_PADDING, 0)
TitleLabel.Text = "Client Clone & Place"
TitleLabel.Font = Enum.Font.GothamSemibold
TitleLabel.TextSize = 16
TitleLabel.TextColor3 = Color3.fromRGB(230, 230, 240)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Контент
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -UI_PADDING*2, 1, -(TITLE_HEIGHT + UI_PADDING*2))
Content.Position = UDim2.fromOffset(UI_PADDING, TITLE_HEIGHT + UI_PADDING)
Content.BackgroundTransparency = 1
Content.Parent = Frame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.FillDirection = Enum.FillDirection.Vertical
UIListLayout.Padding = UDim.new(0, BUTTON_PAD)
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
UIListLayout.Parent = Content

local function makeButton(txt: string): TextButton
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, BUTTON_HEIGHT)
    b.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    b.AutoButtonColor = true
    b.Text = txt
    b.Font = Enum.Font.Gotham
    b.TextSize = 16
    b.TextColor3 = Color3.fromRGB(245, 245, 255)
    b.BorderSizePixel = 0

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, math.floor(CORNER_RADIUS*0.8))
    c.Parent = b

    local s = Instance.new("UIStroke")
    s.Thickness = 1
    s.Color = Color3.fromRGB(80, 80, 100)
    s.Parent = b

    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(65, 65, 85)}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(50, 50, 65)}):Play()
    end)
    b.MouseButton1Down:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.05), {BackgroundColor3 = Color3.fromRGB(80, 80, 110)}):Play()
    end)
    b.MouseButton1Up:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(65, 65, 85)}):Play()
    end)

    return b
end

local DuplicateBtn = makeButton("Duplicate")
DuplicateBtn.Parent = Content

local DeleteBtn = makeButton("Delete")
DeleteBtn.Parent = Content

-- Перетаскивание окна
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragState.dragging = true
        dragState.offset = Vector2.new(Mouse.X - Frame.AbsolutePosition.X, Mouse.Y - Frame.AbsolutePosition.Y)
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragState.dragging = false
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragState.dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local newPos = Vector2.new(Mouse.X - dragState.offset.X, Mouse.Y - dragState.offset.Y)
        Frame.Position = UDim2.fromOffset(newPos.X, newPos.Y)
    end
end)

--========================================================
--                ПОДСВЕТКА ПЛАТФОРМЫ (SelectionBox)
--========================================================
highlightBox = Instance.new("SelectionBox")
highlightBox.Name = "PlatformHighlight"
highlightBox.LineThickness = 0.05
highlightBox.Color3 = Color3.fromRGB(120, 180, 255)
highlightBox.Transparency = 0.2
highlightBox.Visible = false
highlightBox.Parent = Workspace -- ВАЖНО: SelectionBox — 3D адорнмент, дер
