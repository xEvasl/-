-- LocalScript — Fake Dupe + UI + визуальные предметы в хотбаре (только клиент)
-- Использовать в своём проекте / для учебных тестов. Ничего не меняет на сервере.

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

-- ====== UI ======
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "FakeDupeUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 260, 0, 190)
frame.Position = UDim2.new(0.5, -130, 0.5, -95)
frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
frame.BorderSizePixel = 0
frame.Visible = true
frame.Parent = ScreenGui
Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, 0, 0, 28)
title.Position = UDim2.new(0, 0, 0, 6)
title.Font = Enum.Font.GothamSemibold
title.TextSize = 16
title.TextColor3 = Color3.new(1,1,1)
title.Text = "🌱 Fake Dupe (client-side)"
title.Parent = frame

local nameBox = Instance.new("TextBox")
nameBox.PlaceholderText = "Pet / Item name"
nameBox.Size = UDim2.new(1, -20, 0, 30)
nameBox.Position = UDim2.new(0, 10, 0, 40)
nameBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
nameBox.TextColor3 = Color3.new(1, 1, 1)
nameBox.ClearTextOnFocus = false
nameBox.Font = Enum.Font.Gotham
nameBox.TextSize = 14
nameBox.Parent = frame
Instance.new("UICorner", nameBox).CornerRadius = UDim.new(0, 6)

local amountBox = Instance.new("TextBox")
amountBox.PlaceholderText = "How many? (e.g. 5)"
amountBox.Size = UDim2.new(1, -20, 0, 30)
amountBox.Position = UDim2.new(0, 10, 0, 80)
amountBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
amountBox.TextColor3 = Color3.new(1, 1, 1)
amountBox.ClearTextOnFocus = false
amountBox.Font = Enum.Font.Gotham
amountBox.TextSize = 14
amountBox.Parent = frame
Instance.new("UICorner", amountBox).CornerRadius = UDim.new(0, 6)

local info = Instance.new("TextLabel")
info.BackgroundTransparency = 1
info.TextWrapped = true
info.Text = "Кнопка ниже создаёт клиентские «питомцы» и визуальные предметы в хотбаре."
info.Font = Enum.Font.Gotham
info.TextSize = 12
info.TextColor3 = Color3.fromRGB(210,210,210)
info.Size = UDim2.new(1, -20, 0, 32)
info.Position = UDim2.new(0, 10, 0, 114)
info.Parent = frame

local dupeBtn = Instance.new("TextButton")
dupeBtn.Size = UDim2.new(0.5, -15, 0, 32)
dupeBtn.Position = UDim2.new(0, 10, 1, -42)
dupeBtn.Text = "Dupe Now!"
dupeBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
dupeBtn.TextColor3 = Color3.new(1, 1, 1)
dupeBtn.Font = Enum.Font.GothamBold
dupeBtn.TextSize = 14
dupeBtn.Parent = frame
Instance.new("UICorner", dupeBtn).CornerRadius = UDim.new(0, 8)

local clearBtn = Instance.new("TextButton")
clearBtn.Size = UDim2.new(0.5, -15, 0, 32)
clearBtn.Position = UDim2.new(0.5, 5, 1, -42)
clearBtn.Text = "Clear"
clearBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
clearBtn.TextColor3 = Color3.new(1, 1, 1)
clearBtn.Font = Enum.Font.GothamBold
clearBtn.TextSize = 14
clearBtn.Parent = frame
Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 8)

-- ====== ЛОГИКА «ПИТОМЦЫ» + ХОТБАР ======
-- По мотивам твоего dupe.lua: создаём клиентскую папку Pets у игрока и заполняем её «питомцами». :contentReference[oaicite:4]{index=4}
local function ensurePetsFolder()
	local pets = player:FindFirstChild("Pets")
	if not pets then
		pets = Instance.new("Folder")
		pets.Name = "Pets"
		pets.Parent = player
	end
	return pets
end

local function createFakePet(petName: string)
	local petsFolder = ensurePetsFolder()
	local pet = Instance.new("Folder")
	pet.Name = ("%s_%04d"):format(petName, math.random(0, 9999))
	pet.Parent = petsFolder
	return pet
end

-- Новый блок: делаем визуальный предмет в хотбаре (локальный Tool в Backpack).
local function createVisualToolInHotbar(itemName: string)
	-- Backpack существует у клиента и его локальные изменения видны только ему.
	local backpack = player:WaitForChild("Backpack")
	-- Сам Tool
	local tool = Instance.new("Tool")
	tool.Name = "[V] "..itemName
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("VisualOnly", true) -- подсказка самому себе

	-- Простой “Handle”, чтобы Roblox показал Tool в хотбаре.
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1,1,1)
	handle.Transparency = 0.25
	handle.Anchored = false
	handle.CanCollide = false
	handle.Massless = true
	handle.Material = Enum.Material.ForceField
	handle.Parent = tool

	tool.Parent = backpack
	return tool
end

-- ====== КНОПКИ ======
dupeBtn.MouseButton1Click:Connect(function()
	local name = nameBox.Text
	local amount = tonumber(amountBox.Text) or 1
	if not name or name == "" or amount < 1 then
		StarterGui:SetCore("SendNotification", {
			Title = "Input required";
			Text = "Укажи имя и положительное количество.";
			Duration = 3;
		})
		return
	end

	for i = 1, amount do
		createFakePet(name)                    -- клиентский «питомец» (папка в player)
		createVisualToolInHotbar(name)         -- визуальный предмет в хотбаре (локальный Tool)
	end

	StarterGui:SetCore("SendNotification", {
		Title = "FAKE DUPE";
		Text = name.." x"..amount.." added (client-side)";
		Duration = 4;
	})
end)

clearBtn.MouseButton1Click:Connect(function()
	local pets = player:FindFirstChild("Pets")
	if pets then pets:Destroy() end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, t in ipairs(backpack:GetChildren()) do
			if t:IsA("Tool") and t:GetAttribute("VisualOnly") then
				t:Destroy()
			end
		end
	end
	StarterGui:SetCore("SendNotification", {
		Title = "Cleared";
		Text = "Client-side pets and visual tools removed.";
		Duration = 3;
	})
end)

-- ====== Дополнительно: сворачивание/разворачивание UI (G) ======
local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.G then
		frame.Visible = not frame.Visible
	end
end)
