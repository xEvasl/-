--// LocalScript (Client-side only). Suggested path: StarterGui -> LocalScript
--// UI + перетаскивание + визуальное дублирование экипированного Tool в локальный Backpack

--========================--
--  УТИЛИТЫ И НАСТРОЙКИ   --
--========================--

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local LOCAL_PLAYER = Players.LocalPlayer

-- Максимальное число слотов хотбара (стандартно у CoreGui 10).
-- Это не «жёсткое» правило, но поможем избежать переполнения визуально.
local MAX_HOTBAR_SLOTS = 10

--========================--
--     ПОМОЩНИКИ         --
--========================--

local function notify(title, text, duration)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title or "Info",
			Text = text or "",
			Duration = duration or 3
		})
	end)
end

-- Получить экипированный предмет (Tool), если он в руках персонажа
local function getEquippedTool()
	local char = LOCAL_PLAYER.Character
	if not char then return nil end
	return char:FindFirstChildOfClass("Tool")
end

-- Попробовать «узнать» ID/имя/цвет у Tool.
-- В Roblox нет единого стандарта для «ID предмета», поэтому:
-- 1) сначала ищем атрибуты ItemId/AssetId/ItemID,
-- 2) иначе используем DebugId как fallback (локальный уникальный id),
-- 3) имя (DisplayName/Name),
-- 4) цвет текста (атрибут TextColor3 или белый по умолчанию).
local function extractToolMeta(tool: Tool)
	if not tool then return nil end

	local meta = {}

	meta.ItemId = tool:GetAttribute("ItemId")
		or tool:GetAttribute("ItemID")
		or tool:GetAttribute("AssetId")
		or tostring(tool:GetDebugId())

	meta.DisplayName = tool:GetAttribute("DisplayName") or tool.Name

	local attrColor = tool:GetAttribute("TextColor3")
	if typeof(attrColor) == "Color3" then
		meta.TextColor3 = attrColor
	else
		meta.TextColor3 = Color3.new(1, 1, 1) -- белый
	end

	return meta
end

-- Проверка: есть ли «свободный» слот по простому критерию.
-- На клиенте сам хотбар — это визуализация Tools в Backpack.
-- Если их > MAX_HOTBAR_SLOTS, предупредим игрока.
local function hasFreeHotbarSlot(backpack: Backpack)
	local count = 0
	for _, inst in ipairs(backpack:GetChildren()) do
		if inst:IsA("Tool") then
			count += 1
		end
	end
	return count < MAX_HOTBAR_SLOTS
end

-- Сделать уникальное имя для клона, чтобы не конфликтовать в Backpack
local function uniqueToolName(backpack: Backpack, baseName: string)
	local candidate = baseName
	local n = 2
	while backpack:FindFirstChild(candidate) do
		candidate = string.format("%s (%d)", baseName, n)
		n += 1
	end
	return candidate
end

-- Клонировать Tool локально и поместить в Backpack игрока
local function cloneEquippedToolClientSide()
	local backpack = LOCAL_PLAYER:FindFirstChildOfClass("Backpack")
	if not backpack then
		notify("Ошибка", "Backpack не найден.")
		return
	end

	local equipped = getEquippedTool()
	if not equipped then
		notify("Нет предмета", "У вас ничего не экипировано в руках.")
		return
	end

	-- Чисто визуальная логика слотов
	if not hasFreeHotbarSlot(backpack) then
		notify("Хотбар заполнен", "Освободите слот, чтобы добавить копию.")
		-- продолжим всё равно, просто предупредили
	end

	-- Прочитать метаинформацию
	local meta = extractToolMeta(equipped)

	-- Клонируем целиком модель Tool (включая Handle/части/текстуры/настройки)
	local copy = equipped:Clone()
	copy.Archivable = true

	-- Пометим копию, чтобы было понятно, что она клиентская
	copy:SetAttribute("ClientDuplicated", true)
	if meta then
		copy:SetAttribute("SourceItemId", meta.ItemId)
		copy.ToolTip = (copy.ToolTip ~= "" and copy.ToolTip) or meta.DisplayName
	end

	-- Уникальное имя в Backpack, с пометкой "Copy"
	local baseName = (meta and meta.DisplayName) and (meta.DisplayName .. " (Copy)") or (equipped.Name .. " (Copy)")
	copy.Name = uniqueToolName(backpack, baseName)

	-- Для наглядности можно окрасить текст всплывающей подсказки в UI хотбара
	-- (Core хотбар сам берёт имя Tool; цвета имени не поддерживаются напрямую,
	--  но мы сохраним цвет как атрибут — может использоваться кастомными системами UI игры)
	if meta then
		copy:SetAttribute("TextColor3", meta.TextColor3)
	end

	-- Очень важно: размещаем в локальном Backpack игрока.
	-- Это создаст «видимость» нового предмета только для данного клиента.
	copy.Parent = backpack

	notify("Готово", string.format("Склонирован: %s", copy.Name))
end

--========================--
--          UI            --
--========================--

-- Создаём ScreenGui в PlayerGui, чтобы UI был только у локального игрока
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ClientDuplicateUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = LOCAL_PLAYER:WaitForChild("PlayerGui")

-- Контейнер окна
local mainFrame = Instance.new("Frame")
mainFrame.Name = "Window"
mainFrame.Size = UDim2.fromScale(0.26, 0.20)           -- адаптивный размер
mainFrame.Position = UDim2.fromScale(0.5, 0.5)         -- по центру экрана
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.BackgroundColor3 = Color3.fromRGB(34, 34, 40) -- мягкий тёмный
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

-- Скруглённые углы и обводка
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = mainFrame

local stroke = Instance.new("UIStroke")
stroke.Thickness = 1
stroke.Transparency = 0.2
stroke.Color = Color3.fromRGB(255, 255, 255)
stroke.Parent = mainFrame

-- Внутренние отступы
local padding = Instance.new("UIPadding")
padding.PaddingTop = UDim.new(0, 10)
padding.PaddingBottom = UDim.new(0, 10)
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.Parent = mainFrame

-- Заголовочная панель (за неё перетаскиваем)
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 32)
titleBar.BackgroundTransparency = 1
titleBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -24, 1, 0)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextScaled = true
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Text = "Client Duplicate"
titleLabel.TextColor3 = Color3.fromRGB(230, 230, 235)
titleLabel.Parent = titleBar

-- Тело окна
local body = Instance.new("Frame")
body.Name = "Body"
body.Size = UDim2.new(1, 0, 1, -titleBar.Size.Y.Offset - 10)
body.Position = UDim2.new(0, 0, 0, titleBar.Size.Y.Offset + 6)
body.BackgroundTransparency = 1
body.Parent = mainFrame

-- Кнопка Duplicate
local duplicateBtn = Instance.new("TextButton")
duplicateBtn.Name = "DuplicateButton"
duplicateBtn.Size = UDim2.new(1, 0, 0, 40)
duplicateBtn.Position = UDim2.new(0, 0, 0, 0)
duplicateBtn.Text = "Duplicate"
duplicateBtn.Font = Enum.Font.GothamMedium
duplicateBtn.TextScaled = true
duplicateBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
duplicateBtn.AutoButtonColor = true
duplicateBtn.BackgroundColor3 = Color3.fromRGB(65, 105, 225) -- плавный синий
duplicateBtn.Parent = body

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 10)
btnCorner.Parent = duplicateBtn

local btnStroke = Instance.new("UIStroke")
btnStroke.Thickness = 1
btnStroke.Transparency = 0.2
btnStroke.Color = Color3.fromRGB(255, 255, 255)
btnStroke.Parent = duplicateBtn

-- Подпись-подсказка
local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Size = UDim2.new(1, 0, 0, 40)
hint.Position = UDim2.new(0, 0, 0, 48)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextScaled = true
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.TextYAlignment = Enum.TextYAlignment.Top
hint.TextWrapped = true
hint.Text = "Нажмите, чтобы создать визуальную копию экипированного предмета. (Только клиент)"
hint.TextColor3 = Color3.fromRGB(200, 200, 205)
hint.Parent = body

-- Адаптация к размеру экрана: ограничим минимальные/макс. размеры
local sizeConstraint = Instance.new("UISizeConstraint")
sizeConstraint.MinSize = Vector2.new(280, 170)
sizeConstraint.MaxSize = Vector2.new(520, 360)
sizeConstraint.Parent = mainFrame

-- Дополнительно — UIScale, чтобы UI выглядело ровно на разных DPI
local uiScale = Instance.new("UIScale")
uiScale.Scale = 1
uiScale.Parent = mainFrame

--========================--
--     ПЕРЕТАСКИВАНИЕ     --
--========================--

do
	-- Реализуем «dragging» вручную (Frame.Draggable устарел)
	local dragging = false
	local dragStart
	local startPos

	local function updateDrag(input)
		local delta = input.Position - dragStart
		local absSize = mainFrame.Parent.AbsoluteSize
		-- Переводим пиксельный delta в относительные доли экрана (Scale)
		local newPos = UDim2.new(
			startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y
		)
		mainFrame.Position = newPos
	end

	titleBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or
		   input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = mainFrame.Position

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	UIS.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
			input.UserInputType == Enum.UserInputType.Touch) then
			updateDrag(input)
		end
	end)
end

--========================--
--   КНОПКА DUPLICATE     --
--========================--

duplicateBtn.Activated:Connect(function()
	cloneEquippedToolClientSide()
end)

-- Приветствие при первом запуске
task.defer(function()
	notify("Client Duplicate UI", "Окно открыто. Перетащите за верхнюю панель. Нажмите Duplicate для копии предмета.", 5)
end)
