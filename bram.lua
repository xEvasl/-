--!strict
-- LocalScript (StarterGui) — ТОЛЬКО client-side. Без RemoteEvents/RemoteFunctions.

--========================================================
--                     СЕРВИСЫ
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
local Camera = Workspace.CurrentCamera

--========================================================
--               КОНФИГ / ПОВЕДЕНИЕ
--========================================================
local RAY_DISTANCE = 1000
local PREVIEW_OFFSET = 0.1
local PLACE_ON_GRID = false
local GRID_SIZE = 1
local TOAST_TIME = 2.0

-- Платформы по тегам/именам (настраиваемо)
local PLATFORM_TAGS = {"PlacementPlatform"}
local PLATFORM_NAMES = {
    "PlacementPlatform","Platform","Tile","Plot",
    "BrainrotPlatform","PVZPlatform"
}

-- В процессе игры можно «доверять» последнюю наведённую цель:
local LearnedPlatformNames: {[string]: boolean} = {}

--========================================================
--                   ЛОКАЛЬНОЕ СОСТОЯНИЕ
--========================================================
local managedPlacedStack: {Model} = {}
local previewModel: Model? = nil
local previewConnHeartbeat: RBXScriptConnection? = nil
local highlightBox: SelectionBox? = nil
local placingDebounce = false
local dragState = { dragging=false, offset = Vector2.new(0,0) }

--========================================================
--                         UI
--========================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ClientClonerUI"
ScreenGui.IgnoreGuiInset = true
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

local Frame = Instance.new("Frame")
Frame.Size = UDim2.fromOffset(320, 160)
Frame.AnchorPoint = Vector2.new(0.5, 0.5)
Frame.Position = UDim2.fromScale(0.5, 0.5)
Frame.BackgroundColor3 = Color3.fromRGB(25,25,30)
Frame.BorderSizePixel = 0
Frame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = Frame

local UIStroke = Instance.new("UIStroke")
UIStroke.Thickness = 1
UIStroke.Color = Color3.fromRGB(70, 70, 80)
UIStroke.Parent = Frame

local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 28)
TitleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
TitleBar.BorderSizePixel = 0
TitleBar.Parent = Frame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 10)
TitleCorner.Parent = TitleBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -20, 1, 0)
TitleLabel.Position = UDim2.fromOffset(10, 0)
TitleLabel.Text = "Client Clone & Place"
TitleLabel.Font = Enum.Font.GothamSemibold
TitleLabel.TextSize = 16
TitleLabel.TextColor3 = Color3.fromRGB(230,230,240)
TitleLabel.BackgroundTransparency = 1
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -20, 1, -(28 + 10 + 30))
Content.Position = UDim2.fromOffset(10, 28 + 10)
Content.BackgroundTransparency = 1
Content.Parent = Frame

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.FillDirection = Enum.FillDirection.Vertical
UIListLayout.Padding = UDim.new(0, 8)
UIListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListLayout.VerticalAlignment = Enum.VerticalAlignment.Top
UIListLayout.Parent = Content

local function makeButton(text: string): TextButton
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 34)
    b.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    b.Text = text
    b.Font = Enum.Font.Gotham
    b.TextSize = 16
    b.TextColor3 = Color3.fromRGB(245,245,255)
    b.BorderSizePixel = 0

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = b

    local s = Instance.new("UIStroke")
    s.Thickness = 1
    s.Color = Color3.fromRGB(80,80,100)
    s.Parent = b

    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.08), {BackgroundColor3 = Color3.fromRGB(65,65,85)}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(50,50,65)}):Play()
    end)
    return b
end

local DuplicateBtn = makeButton("Duplicate")
DuplicateBtn.Parent = Content
local DeleteBtn = makeButton("Delete")
DeleteBtn.Parent = Content

-- Временная кнопка доверия последней цели (появляется при удержании E)
local TrustBtn = makeButton("Trust Last Hit (learn)")
TrustBtn.Visible = false
TrustBtn.Parent = Content

-- строка статуса
local Status = Instance.new("TextLabel")
Status.Size = UDim2.new(1, -20, 0, 30)
Status.Position = UDim2.fromOffset(10, Frame.Size.Y.Offset - 30 - 10)
Status.AnchorPoint = Vector2.new(0,0)
Status.BackgroundTransparency = 1
Status.Text = "Ready."
Status.Font = Enum.Font.Gotham
Status.TextSize = 14
Status.TextColor3 = Color3.fromRGB(210,210,220)
Status.TextXAlignment = Enum.TextXAlignment.Left
Status.Parent = Frame

-- Перетаскивание окна
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragState.dragging = true
        local mouse = Players.LocalPlayer:GetMouse()
        dragState.offset = Vector2.new(mouse.X - Frame.AbsolutePosition.X, mouse.Y - Frame.AbsolutePosition.Y)
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragState.dragging = false
            end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragState.dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local mouse = Players.LocalPlayer:GetMouse()
        local newPos = Vector2.new(mouse.X - dragState.offset.X, mouse.Y - dragState.offset.Y)
        Frame.Position = UDim2.fromOffset(newPos.X, newPos.Y)
    end
end)

--========================================================
--                 ПОДСВЕТКА ПЛАТФОРМЫ
--========================================================
highlightBox = Instance.new("SelectionBox")
highlightBox.Name = "PlatformHighlight"
highlightBox.LineThickness = 0.05
highlightBox.Color3 = Color3.fromRGB(120,180,255)
highlightBox.Transparency = 0.2
highlightBox.Visible = false
highlightBox.Parent = Workspace

local function setHighlight(part: BasePart?)
    if part then
        highlightBox.Adornee = part
        highlightBox.Visible = true
    else
        highlightBox.Adornee = nil
        highlightBox.Visible = false
    end
end

--========================================================
--                   УТИЛИТЫ / ПОИСК
--========================================================
local function toast(msg: string)
    Status.Text = msg
    warn("[ClonePlace] "..msg)
    pcall(function()
        StarterGui:SetCore("SendNotification", {Title="Hint", Text=msg, Duration=TOAST_TIME})
    end)
end

local function inList(list: {string}, name: string): boolean
    for _, v in ipairs(list) do
        if v == name then return true end
    end
    return false
end

local function isWhitelistedName(name: string): boolean
    if LearnedPlatformNames[name] then return true end
    return inList(PLATFORM_NAMES, name)
end

local function isPlatform(inst: Instance?): boolean
    if not inst then return false end
    if CollectionService then
        for _, tag in ipairs(PLATFORM_TAGS) do
            if CollectionService:HasTag(inst, tag) then return true end
        end
        local parent = inst.Parent
        if parent then
            for _, tag in ipairs(PLATFORM_TAGS) do
                if CollectionService:HasTag(parent, tag) then return true end
            end
        end
    end
    if inst.Name and isWhitelistedName(inst.Name) then return true end
    local p = inst.Parent
    if p and p.Name and isWhitelistedName(p.Name) then return true end
    return false
end

local function getPlatformRoot(inst: Instance?): BasePart?
    if not inst then return nil end
    if inst:IsA("BasePart") and isPlatform(inst) then return inst end
    local par = inst.Parent
    if par and par:IsA("Model") and isPlatform(par) then
        local m = par :: Model
        if m.PrimaryPart and m.PrimaryPart:IsA("BasePart") then
            return m.PrimaryPart
        end
        for _, d in ipairs(m:GetDescendants()) do
            if d:IsA("BasePart") then return d end
        end
    end
    if par and par:IsA("BasePart") and isPlatform(par) then return par end
    return nil
end

local function snapToGrid(v: Vector3): Vector3
    if not PLACE_ON_GRID then return v end
    local function s(x: number) return math.floor((x + GRID_SIZE/2)/GRID_SIZE)*GRID_SIZE end
    return Vector3.new(s(v.X), s(v.Y), s(v.Z))
end

local function firstBasePart(container: Instance): BasePart?
    for _, d in ipairs(container:GetDescendants()) do
        if d:IsA("BasePart") then return d end
    end
    return nil
end

local function getEquippedTool(): Instance?
    local char = LocalPlayer.Character
    if char then
        local t = char:FindFirstChildOfClass("Tool")
        if t then return t end
    end
    -- fallback: возьмём первый Tool из Backpack как источник визуала
    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        local t = backpack:FindFirstChildOfClass("Tool")
        if t then return t end
    end
    return nil
end

local function ensureModelFromTool(toolOrModel: Instance): Model?
    if toolOrModel:IsA("Model") then
        local m = (toolOrModel :: Model):Clone()
        if not m.PrimaryPart then
            local pp = firstBasePart(m)
            if pp then m.PrimaryPart = pp end
        end
        m:SetAttribute("SourceName", toolOrModel.Name)
        m:SetAttribute("SourceClass", toolOrModel.ClassName)
        return m
    end

    if toolOrModel:IsA("Tool") then
        local toolClone = toolOrModel:Clone()
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
        model:SetAttribute("SourceName", toolOrModel.Name)
        model:SetAttribute("SourceClass", toolOrModel.ClassName)
        return model
    end
    return nil
end

local function setModelCollision(model: Model, canCollide: boolean)
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then d.CanCollide = canCollide end
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
    if m then return (m :: Model):GetAttribute("ClientManagedClone") == true end
    return false
end

local function modelBounds(model: Model): (CFrame, Vector3)
    return model:GetBoundingBox()
end

local function centerOnPlatform(model: Model, platformPart: BasePart)
    local _, size = modelBounds(model)
    local halfH = size.Y * 0.5
    local platCF = platformPart.CFrame
    local upOffset = Vector3.new(0, (platformPart.Size.Y * 0.5) + halfH, 0)
    local pos = snapToGrid(platCF.Position + upOffset)
    local finalCF = CFrame.fromMatrix(pos, platCF.XVector, platCF.YVector, platCF.ZVector)
    model:PivotTo(finalCF)
end

local function gentlyPop(model: Model)
    local parts: {BasePart} = {}
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then table.insert(parts, d) end
    end
    if #parts == 0 then return end
    for _, p in ipairs(parts) do p.Position += Vector3.new(0, 0.05, 0) end
    task.delay(0.02, function()
        for _, p in ipairs(parts) do p.Position -= Vector3.new(0, 0.05, 0) end
    end)
end

--========================================================
--                ПРЕДПРОСМОТР / СЛЕЖЕНИЕ
--========================================================
local lastHitInstance: Instance? = nil

local function destroyPreview()
    if previewConnHeartbeat then previewConnHeartbeat:Disconnect() previewConnHeartbeat = nil end
    if previewModel and previewModel.Parent then previewModel:Destroy() end
    previewModel = nil
    setHighlight(nil)
end

local function placePreviewIfPossible()
    if not previewModel or placingDebounce then return end

    local mouse = LocalPlayer:GetMouse()
    local unitRay = Camera:ScreenPointToRay(mouse.X, mouse.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    local blacklist: {Instance} = {previewModel}
    if LocalPlayer.Character then table.insert(blacklist, LocalPlayer.Character) end
    params.FilterDescendantsInstances = blacklist

    local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * RAY_DISTANCE, params)
    if not result or not result.Instance then return end
    if not isPlatform(result.Instance) then return end

    local root = getPlatformRoot(result.Instance)
    if not root then return end

    placingDebounce = true
    centerOnPlatform(previewModel, root)
    setModelCollision(previewModel, true)
    setModelAnchored(previewModel, true)
    gentlyPop(previewModel)

    table.insert(managedPlacedStack, previewModel)
    previewModel = nil
    if previewConnHeartbeat then previewConnHeartbeat:Disconnect() previewConnHeartbeat = nil end
    setHighlight(nil)
    toast("Объект установлен.")
    task.delay(0.1, function() placingDebounce = false end)
end

local function startPreview(model: Model)
    destroyPreview()
    previewModel = model
    model.Parent = Workspace
    setModelAnchored(model, false)
    setModelCollision(model, true) -- по ТЗ клон не фантомный
    tagManaged(model)

    previewConnHeartbeat = RunService.Heartbeat:Connect(function()
        if not previewModel then return end
        local mouse = LocalPlayer:GetMouse()
        local unitRay = Camera:ScreenPointToRay(mouse.X, mouse.Y)

        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Blacklist
        local blacklist: {Instance} = {previewModel}
        if LocalPlayer.Character then table.insert(blacklist, LocalPlayer.Character) end
        params.FilterDescendantsInstances = blacklist

        local result = Workspace:Raycast(unitRay.Origin, unitRay.Direction * RAY_DISTANCE, params)

        local targetCF = previewModel:GetPivot()
        local hoverPlatform: BasePart? = nil
        lastHitInstance = result and result.Instance or nil

        if result then
            local hitPos = result.Position + result.Normal * PREVIEW_OFFSET
            targetCF = CFrame.new(snapToGrid(hitPos))
            if isPlatform(result.Instance) then
                hoverPlatform = getPlatformRoot(result.Instance)
            end
        end

        previewModel:PivotTo(targetCF)

        -- Подсветка/установка при удержании E
        if UserInputService:IsKeyDown(Enum.KeyCode.E) and hoverPlatform then
            setHighlight(hoverPlatform)
            placePreviewIfPossible()
            TrustBtn.Visible = true
            Status.Text = ("E held: %s"):format(hoverPlatform.Name)
        else
            setHighlight(nil)
            TrustBtn.Visible = false
        end
    end)
end

--========================================================
--                     ДЕЙСТВИЯ КНОПОК
--========================================================
local function duplicateEquipped()
    -- защищаем кнопки явным pcall и статусом
    local ok, err = pcall(function()
        local src = getEquippedTool()
        if not src then
            toast("Нет экипированного предмета (ни в Character, ни в Backpack).")
            return
        end
        local m = ensureModelFromTool(src)
        if not m then
            toast("Не удалось клонировать предмет.")
            return
        end
        startPreview(m)
        toast("Клон создан. Зажмите E и наведите на платформу.")
    end)
    if not ok then
        warn("[Duplicate ERROR] ", err)
        Status.Text = "Ошибка Duplicate (смотри Output)."
    end
end

local function deleteTargetOrLast()
    local ok, err = pcall(function()
        if previewModel then
            destroyPreview()
            toast("Предпросмотр отменён.")
            return
        end

        local mouse = LocalPlayer:GetMouse()
        local target = mouse.Target
        if target and isManaged(target) then
            local m = target:FindFirstAncestorOfClass("Model")
            if m and m:IsDescendantOf(Workspace) then
                m:Destroy()
                for i = #managedPlacedStack, 1, -1 do
                    if managedPlacedStack[i] == m then table.remove(managedPlacedStack, i) break end
                end
                toast("Удалено под курсором.")
                return
            end
        end

        if #managedPlacedStack == 0 then
            toast("Нечего удалить.")
            return
        end
        local last = managedPlacedStack[#managedPlacedStack]
        if last and last:IsDescendantOf(Workspace) then last:Destroy() end
        table.remove(managedPlacedStack, #managedPlacedStack)
        toast("Удалён последний установленный объект.")
    end)
    if not ok then
        warn("[Delete ERROR] ", err)
        Status.Text = "Ошибка Delete (смотри Output)."
    end
end

DuplicateBtn.MouseButton1Click:Connect(duplicateEquipped)
DeleteBtn.MouseButton1Click:Connect(deleteTargetOrLast)

-- «Доверие» последней наведённой цели — добавляет имя части в белый список
TrustBtn.MouseButton1Click:Connect(function()
    if lastHitInstance and lastHitInstance.Name then
        LearnedPlatformNames[lastHitInstance.Name] = true
        toast("Запомнено имя платформы: ".. lastHitInstance.Name)
    else
        toast("Нечего запоминать (нет цели).")
    end
end)

--========================================================
--                  ПОДСКАЗКА ПРИ СТАРТЕ
--========================================================
toast("Готово. Duplicate → наведите на платформу → удерживайте E. Delete — удалить.")
