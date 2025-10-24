--[[ 
LocalScript: Client-side clone + placement system
Author: ChatGPT
Works like Plants vs Brainrots style placement.
Place in: StarterGui → LocalScript
]]

--// Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

--// Config
local PLATFORM_NAME = "PlacementPlatform" -- имя деталей, на которые можно ставить предмет
local UI_TOGGLE_KEY = Enum.KeyCode.G     -- клавиша для показа/скрытия меню
local CLONE_DISTANCE = 10                -- расстояние спауна клона перед игроком

--// Variables
local cloneModel = nil   -- текущий клон, которым игрок управляет
local canPlace = false   -- можно ли сейчас установить
local isPlacing = false  -- флаг режима установки

----------------------------------------------------------
-- 🧩 UI: простое меню с кнопкой Duplicate
----------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "DuplicateUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 240, 0, 120)
frame.Position = UDim2.new(0.5, -120, 0.6, -60)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
frame.BorderSizePixel = 0
frame.Visible = true
frame.Parent = screenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0, 30)
header.Position = UDim2.new(0, 0, 0, 0)
header.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
header.Font = Enum.Font.GothamBold
header.Text = "  Duplicate Tool"
header.TextColor3 = Color3.fromRGB(255, 255, 255)
header.TextSize = 16
header.TextXAlignment = Enum.TextXAlignment.Left
header.Parent = frame
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

-- Drag logic
local dragging, dragStart, startPos = false, nil, nil
header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
		dragStart = input.Position
		startPos = frame.Position
	end
end)
header.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - dragStart
		frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X,
			startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

local duplicateBtn = Instance.new("TextButton")
duplicateBtn.Size = UDim2.new(1, -20, 0, 40)
duplicateBtn.Position = UDim2.new(0, 10, 0, 40)
duplicateBtn.Text = "Duplicate Equipped"
duplicateBtn.Font = Enum.Font.GothamBold
duplicateBtn.TextSize = 14
duplicateBtn.TextColor3 = Color3.fromRGB(255,255,255)
duplicateBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
duplicateBtn.Parent = frame
Instance.new("UICorner", duplicateBtn).CornerRadius = UDim.new(0, 8)

local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, -20, 0, 40)
infoLabel.Position = UDim2.new(0, 10, 0, 85)
infoLabel.BackgroundTransparency = 1
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 12
infoLabel.TextColor3 = Color3.fromRGB(220,220,220)
infoLabel.Text = "Нажми 'Duplicate' чтобы клонировать предмет."
infoLabel.TextWrapped = true
infoLabel.Parent = frame

----------------------------------------------------------
-- ⚙️ Utility functions
----------------------------------------------------------

-- Получаем экипированный Tool (если есть)
local function getEquippedTool()
	local char = player.Character
	if not char then return nil end
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") then
			return tool
		end
	end
	return nil
end

-- Создаём реальный физический клон предмета
local function cloneEquippedTool()
	local tool = getEquippedTool()
	if not tool then
		infoLabel.Text = "Нет экипированного предмета!"
		return
	end

	-- клонируем весь Tool
	local clone = tool:Clone()
	clone.Name = tool.Name .. "_Clone"

	-- отключаем скрипты
	for _, d in ipairs(clone:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end

	-- получаем основную часть (Handle)
	local handle = clone:FindFirstChild("Handle") or clone:FindFirstChildWhichIsA("BasePart")
	if not handle then
		infoLabel.Text = "У предмета нет основной части!"
		return
	end

	handle.Anchored = false
	handle.CanCollide = true
	handle.Massless = false
	handle.Color = tool:FindFirstChild("Handle") and tool.Handle.Color or handle.Color

	-- спауним перед игроком
	local char = player.Character
	if char and char.PrimaryPart then
		local cframe = char.PrimaryPart.CFrame * CFrame.new(0, 0, -CLONE_DISTANCE)
		clone.Parent = workspace
		clone:MoveTo(cframe.Position)
	else
		clone.Parent = workspace
	end

	cloneModel = clone
	isPlacing = true
	infoLabel.Text = "Перемещай мышкой и кликни на платформу."
end

----------------------------------------------------------
-- 🖱 Управление клоном до установки
----------------------------------------------------------
RunService.RenderStepped:Connect(function()
	if isPlacing and cloneModel and cloneModel.Parent == workspace then
		local target = mouse.Hit
		if target then
			local pos = target.Position
			-- плавно тянем модель к курсору
			local root = cloneModel:FindFirstChild("Handle") or cloneModel:FindFirstChildWhichIsA("BasePart")
			if root then
				root.Anchored = true
				root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 2, 0))
			end
		end
	end
end)

-- Клик мышкой для установки
mouse.Button1Down:Connect(function()
	if isPlacing and cloneModel then
		local target = mouse.Target
		if target and target.Name == PLATFORM_NAME then
			local platform = target
			local root = cloneModel:FindFirstChild("Handle") or cloneModel:FindFirstChildWhichIsA("BasePart")

			if root then
				-- ставим клон на платформу
				root.Anchored = true
				local pos = platform.Position + Vector3.new(0, platform.Size.Y / 2 + root.Size.Y / 2, 0)
				root.CFrame = CFrame.new(pos)

				isPlacing = false
				infoLabel.Text = "Клон установлен!"
				cloneModel = nil
			end
		else
			infoLabel.Text = "Нужно кликнуть по платформе!"
		end
	end
end)

----------------------------------------------------------
-- 🔘 Кнопка Duplicate
----------------------------------------------------------
duplicateBtn.MouseButton1Click:Connect(function()
	cloneEquippedTool()
end)

----------------------------------------------------------
-- 🧭 Переключение меню клавишей G
----------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == UI_TOGGLE_KEY then
		frame.Visible = not frame.Visible
	end
end)
