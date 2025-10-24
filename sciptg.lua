--// LocalScript — StarterGui (рекомендуемое место: StarterGui -> LocalScript)
--// Полностью client-side. Без сторонних библиотек.

--==[ БАЗОВЫЕ ССЫЛКИ ]==--
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

--==[ ЭКРАННЫЙ UI ]==--
-- Если вы уже создаёте ScreenGui в другом месте — этот блок можно адаптировать,
-- но для цельности скрипт формирует всё сам.
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ClientToolUtility"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

-- Главное окно
local window = Instance.new("Frame")
window.Name = "Window"
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.Position = UDim2.fromScale(0.5, 0.5)              -- по центру экрана
window.Size = UDim2.fromScale(0.28, 0.26)                 -- адаптивный размер
window.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
window.BorderSizePixel = 0
window.Parent = screenGui

local windowCorner = Instance.new("UICorner")
windowCorner.CornerRadius = UDim.new(0, 12)
windowCorner.Parent = window

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(70, 70, 80)
stroke.Thickness = 1
stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
stroke.Parent = window

local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 8)
padding.PaddingBottom = UDim.new(0, 12)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = window

-- Верхняя панель (за неё перетаскиваем)
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.Size = UDim2.new(1, 0, 0, 36)
topBar.BackgroundTransparency = 1
topBar.Parent = window

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Text = "Client Tool Manager"
title.Font = Enum.Font.GothamSemibold
title.TextSize = 18
title.TextColor3 = Color3.fromRGB(235, 235, 245)
title.BackgroundTransparency = 1
title.TextXAlignment = Enum.TextXAlignment.Left
title.Size = UDim2.new(1, -8, 1, 0)
title.Position = UDim2.new(0, 0, 0, 0)
title.Parent = topBar

-- Разделитель
local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, 0, 0, 1)
divider.Position = UDim2.new(0, 0, 0, 36)
divider.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
divider.BorderSizePixel = 0
divider.Parent = window

-- Область контента
local content = Instance.new("Frame")
content.Name = "Content"
content.BackgroundTransparency = 1
content.Position = UDim2.new(0, 0, 0, 44)
content.Size = UDim2.new(1, 0, 1, -88) -- место для кнопок и уведомлений
content.Parent = window

local list = Instance.new("UIListLayout")
list.FillDirection = Enum.FillDirection.Vertical
list.HorizontalAlignment = Enum.HorizontalAlignment.Center
list.VerticalAlignment = Enum.VerticalAlignment.Top
list.Padding = UDim.new(0, 10)
list.Parent = content

-- Кнопка-стиль (единый вид для Duplicate и Delete)
local function createButton(name, text)
    local btn = Instance.new("TextButton")
    btn.Name = name
    btn.Text = text
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 16
    btn.TextColor3 = Color3.fromRGB(240, 240, 250)
    btn.AutoButtonColor = true
    btn.BackgroundColor3 = Color3.fromRGB(45, 95, 255) -- базовый акцент
    btn.Size = UDim2.new(1, -12, 0, 36)
    btn.Parent = content

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = btn

    local uiStroke = Instance.new("UIStroke")
    uiStroke.Color = Color3.fromRGB(20, 55, 180)
    uiStroke.Thickness = 1
    uiStroke.Parent = btn

    local gradient = Instance.new("UIGradient")
    gradient.Rotation = 90
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(55, 105, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 85, 235)),
    })
    gradient.Parent = btn

    btn.MouseEnter:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(65, 115, 255)
    end)
    btn.MouseLeave:Connect(function()
        btn.BackgroundColor3 = Color3.fromRGB(45, 95, 255)
    end)

    return btn
end

-- Кнопки
local duplicateBtn = createButton("DuplicateButton", "Duplicate")
local deleteBtn    = createButton("DeleteButton",    "Delete") -- кнопка удаления (тот же стиль)

-- Поле уведомлений
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.Text = ""
toast.Font = Enum.Font.Gotham
toast.TextSize = 14
toast.TextColor3 = Color3.fromRGB(220, 220, 230)
toast.BackgroundTransparency = 1
toast.Size = UDim2.new(1, -12, 0, 20)
toast.Parent = window
toast.Position = UDim2.new(0, 12, 1, -28)
toast.TextXAlignment = Enum.TextXAlignment.Left

-- Короткие уведомления
local function showToast(msg, seconds)
    toast.Text = tostring(msg or "")
    task.delay(seconds or 1.6, function()
        if toast then toast.Text = "" end
    end)
end

--==[ ПЕРЕТАСКИВАНИЕ ОКНА МЫШКОЙ ]==--
do
    local dragging = false
    local dragStart
    local startPos

    local function update(input)
        local delta = input.Position - dragStart
        window.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end

    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = window.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)

    topBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or
           input.UserInputType == Enum.UserInputType.Touch then
            if dragging then update(input) end
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                         input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
end

--==[ ВСПОМОГАТЕЛЬНОЕ: Поиск экипированного предмета (Tool) ]==--
local function getEquippedTool()
    local character = player.Character or player.CharacterAdded:Wait()
    -- Экипированный предмет — это Tool в Character
    local tool = character:FindFirstChildOfClass("Tool")
    if tool and tool:IsA("Tool") then
        return tool
    end
    return nil
end

--==[ ВСПОМОГАТЕЛЬНОЕ: Получить «ID»/имя для UI ]==--
local function getReadableId(tool)
    if not tool then return "N/A" end
    -- Популярные атрибуты/свойства, если есть
    local candidates = {
        tool:GetAttribute("ItemID"),
        tool:GetAttribute("ID"),
        tool:GetAttribute("AssetId"),
        tool:FindFirstChild("Configuration") and (tool.Configuration:GetAttribute("ID") or tool.Configuration:GetAttribute("ItemID")),
        tool.ToolTip, -- часто как «отображаемое» имя
        tool.Name
    }
    for _,v in ipairs(candidates) do
        if typeof(v) == "string" and v ~= "" then
            return v
        end
        if typeof(v) == "number" then
            return tostring(v)
        end
    end
    -- fallback — отладочный идентификатор
    return tool:GetDebugId(0)
end

--==[ КЛОНИРОВАНИЕ 1-в-1 ]==--
-- клонирование всех свойств/вложений/атрибутов/скриптов обеспечивается стандартным Instance:Clone()
-- Дополнительно следим, чтобы Archivable=true (на всякий случай)
local function deepCloneTool(tool)
    if not tool or not tool:IsA("Tool") then return nil end
    local prevArchivable = tool.Archivable
    tool.Archivable = true
    local clone = tool:Clone() -- клонирование всех свойств (Mesh/Material/Color/Transparency/TextureID), вложенных объектов, атрибутов и скриптов
    tool.Archivable = prevArchivable
    -- Визуальная идентичность: позаботимся о локальной прозрачности/состоянии потомков
    for _,desc in ipairs(clone:GetDescendants()) do
        if desc:IsA("BasePart") then
            -- Если у оригинала были локальные модификаторы, их у клона нет — оставляем дефолт
            desc.LocalTransparencyModifier = 0
        end
    end
    return clone
end

--==[ ДОБАВЛЕНИЕ КЛОНА В СВОБОДНЫЙ СЛОТ ХОТБАРА (локально) ]==--
-- Для чисто клиентского эффекта родитель — Backpack локального игрока. Такой Tool виден в вашем хотбаре только вам.
local function addCloneToHotbar(cloneTool)
    if not cloneTool then return false end
    local backpack = player:FindFirstChildOfClass("Backpack")
    if not backpack then
        showToast("Backpack не найден", 1.6)
        return false
    end
    -- имя можно слегка варьировать, чтобы не конфликтовало
    local baseName = cloneTool.Name
    local i = 2
    while backpack:FindFirstChild(cloneTool.Name) do
        cloneTool.Name = string.format("%s (%d)", baseName, i)
        i += 1
    end
    -- Помещаем в Backpack — появится локально в хотбаре (без репликации на сервер)
    cloneTool.Parent = backpack
    return true
end

--==[ КНОПКА DUPLICATE — улучшенная ]==--
duplicateBtn.MouseButton1Click:Connect(function()
    local tool = getEquippedTool()
    if not tool then
        showToast("Ничего не экипировано", 1.4)
        return
    end

    -- соберём базовую информацию для уведомления
    local readableId = getReadableId(tool)
    local displayName = tool.ToolTip and tool.ToolTip ~= "" and tool.ToolTip or tool.Name

    -- клонирование всех свойств
    local clone = deepCloneTool(tool)
    if not clone then
        showToast("Не удалось клонировать", 1.6)
        return
    end

    -- Дополнительно синхронизируем «отображаемое имя», если используется
    if tool.ToolTip and tool.ToolTip ~= "" then
        clone.ToolTip = tool.ToolTip
    end

    -- Добавляем в локальный хотбар
    local ok = addCloneToHotbar(clone)
    if ok then
        showToast(("Скопировано: %s (ID: %s)"):format(displayName, readableId), 1.8)
    else
        clone:Destroy()
    end
end)

--==[ КНОПКА DELETE — локальное удаление экипированного предмета ]==--
-- кнопка удаления: удаляет экипированный Tool только у клиента (client-side), без серверного взаимодействия
deleteBtn.MouseButton1Click:Connect(function()
    local tool = getEquippedTool()
    if not tool then
        showToast("Ничего не экипировано", 1.4)
        return
    end

    -- Попытка «мягко» спрятать (на случай, если серверная репликация вернёт объект):
    for _,desc in ipairs(tool:GetDescendants()) do
        if desc:IsA("BasePart") then
            desc.LocalTransparencyModifier = 1 -- делаем невидимым локально
        end
        if desc:IsA("ParticleEmitter") or desc:IsA("Trail") then
            desc.Enabled = false
        end
        if desc:IsA("PointLight") or desc:IsA("SpotLight") or desc:IsA("SurfaceLight") then
            desc.Enabled = false
        end
        if desc:IsA("Sound") then
            desc:Stop()
            desc.Volume = 0
        end
    end

    -- Полное локальное удаление
    local nameForMsg = tool.ToolTip and tool.ToolTip ~= "" and tool.ToolTip or tool.Name
    tool:Destroy() -- удаляет у клиента; на сервер не влияет

    showToast(("Удалено локально: %s"):format(nameForMsg), 1.6)
end)

--==[ ПОДДЕРЖКА РАЗНЫХ РАЗМЕРОВ ОКНА ]==--
-- Окно и так в процентах; добавим ограничители, чтобы не было слишком огромным/узким на разных экранах
local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(320, 200)
sizeConstraint.MaxSize = Vector2.new(700, 420)
sizeConstraint.Parent = window

-- Для аккуратности: сообщим пользователю
task.delay(0.3, function()
    showToast("Client Tool Manager готов", 1.4)
end)

-- Опционально: можно скрыть системный Backpack UI (если делаете свой хотбар)
-- StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, true) -- оставляем включённым по умолчанию
