--[[
One-file LocalScript: Draggable menu + Grow a Garden pets catalog + hotbar visual tools + world ghosts + Duplicate Slot 3
Client-side only. Place in StarterPlayer/StarterPlayerScripts.

HOW TO ADD REAL ICONS/TEXTURES:
1) Скачай изображения питомцев -> загрузи в Roblox как Decal -> получи assetId.
2) Внизу в PET_CATALOG замени imageId=nil на "rbxassetid://YOUR_ASSET_ID" для каждого питомца.
3) При желании поправь mesh/color для более точной формы.
]]

--// Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

--// Config
local OPEN_KEY         = Enum.KeyCode.G
local SLOT_INDEX       = 3
local WORLD_LIFETIME   = 15
local WORLD_OFFSET     = Vector3.new(3, 0, 0)
local USE_FORCEFIELD   = true
local TRANSPARENCY_ADD = 0.25

--// Helpers (parts/tools/world visuals)
local function safePart(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	p.Transparency = math.clamp(p.Transparency + TRANSPARENCY_ADD, 0, 1)
	if USE_FORCEFIELD then p.Material = Enum.Material.ForceField end
end

local function stripScripts(inst: Instance)
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("Script") or d:IsA("LocalScript") or d:IsA("ModuleScript") then
			d:Destroy()
		elseif d:IsA("ParticleEmitter") or d:IsA("Beam") then
			d.Enabled = false
		end
	end
end

local function listAllTools(): {Tool}
	local out = {}
	local char = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if char then for _, c in ipairs(char:GetChildren()) do if c:IsA("Tool") then table.insert(out, c) end end end
	if backpack then for _, c in ipairs(backpack:GetChildren()) do if c:IsA("Tool") then table.insert(out, c) end end end
	return out
end

local function getToolInSlot(slotIdx: number): Tool?
	local tools = listAllTools()
	if #tools == 0 then return nil end
	for _, t in ipairs(tools) do
		local s = tonumber(t:GetAttribute("Slot"))
		if s == slotIdx then return t end
	end
	table.sort(tools, function(a: Tool, b: Tool) return a.Name:lower() < b.Name:lower() end)
	return tools[slotIdx]
end

--// PET CATALOG
-- mesh: "Block"|"Sphere"|"Cylinder"|"Wedge"|"Head"
-- color: Color3.fromRGB(...)
-- imageId: "rbxassetid://12345" (или nil, если пока нет)
local PET_CATALOG = {
	-- насекомые/мелкие
	{key="Ladybug",           display="Ladybug",           mesh="Sphere",   color=Color3.fromRGB(220,20,20),   imageId=nil},
	{key="Bee",               display="Bee",               mesh="Sphere",   color=Color3.fromRGB(255,240,0),   imageId=nil},
	{key="Butterfly",         display="Butterfly",         mesh="Wedge",    color=Color3.fromRGB(150,120,220), imageId=nil},
	{key="Dragonfly",         display="Dragonfly",         mesh="Cylinder", color=Color3.fromRGB(110,190,220), imageId=nil},
	{key="Hummingbird",       display="Hummingbird",       mesh="Head",     color=Color3.fromRGB(70,160,120),  imageId=nil},

	-- птицы/животные
	{key="Crow",              display="Crow",              mesh="Head",     color=Color3.fromRGB(15,15,20),    imageId=nil},
	{key="Cardinal",          display="Cardinal",          mesh="Sphere",   color=Color3.fromRGB(200,50,50),   imageId=nil},
	{key="Owl",               display="Owl",               mesh="Head",     color=Color3.fromRGB(180,150,110), imageId=nil},
	{key="Chicken",           display="Chicken",           mesh="Head",     color=Color3.fromRGB(250,240,220), imageId=nil},

	{key="Capybara",          display="Capybara",          mesh="Head",     color=Color3.fromRGB(150,110,80),  imageId=nil},
	{key="Raccoon",           display="Raccoon",           mesh="Head",     color=Color3.fromRGB(120,120,120), imageId=nil},
	{key="Panda",             display="Panda",             mesh="Head",     color=Color3.fromRGB(230,230,230), imageId=nil},
	{key="Grizzly Bear",      display="Grizzly Bear",      mesh="Head",     color=Color3.fromRGB(120,80,50),   imageId=nil},
	{key="Deer",              display="Deer",              mesh="Head",     color=Color3.fromRGB(180,130,90),  imageId=nil},

	-- фантазийные/особые
	{key="Goblin",            display="Goblin",            mesh="Head",     color=Color3.fromRGB(60,170,70),   imageId=nil},
	{key="Hex Serpent",       display="Hex Serpent",       mesh="Cylinder", color=Color3.fromRGB(80,120,180),  imageId=nil},
	{key="Headless Horseman", display="Headless Horseman", mesh="Wedge",    color=Color3.fromRGB(70,70,70),    imageId=nil},
	{key="Bone Dog",          display="Bone Dog",          mesh="Head",     color=Color3.fromRGB(240,240,230), imageId=nil},

	-- “водные/экзотика”
	{key="Koi",               display="Koi",               mesh="Sphere",   color=Color3.fromRGB(230,110,90),  imageId=nil},
	{key="Axolotl",           display="Axolotl",           mesh="Head",     color=Color3.fromRGB(255,170,200), imageId=nil},
	{key="Flamingo",          display="Flamingo",          mesh="Cylinder", color=Color3.fromRGB(255,135,155), imageId=nil},

	-- растения/базовые
	{key="Sunflower",         display="Sunflower",         mesh="Head",     color=Color3.fromRGB(255,230,0),   imageId=nil},
	{key="Cactus",            display="Cactus",            mesh="Cylinder", color=Color3.fromRGB(55,160,80),   imageId=nil},
	{key="Peashooter",        display="Peashooter",        mesh="Sphere",   color=Color3.fromRGB(120,200,120), imageId=nil},
	{key="Pumpkin",           display="Pumpkin",           mesh="Sphere",   color=Color3.fromRGB(255,150,40),  imageId=nil},
	{key="Mushroom",          display="Mushroom",          mesh="Wedge",    color=Color3.fromRGB(200,170,200), imageId=nil},

	-- прочее
	{key="Goat",              display="Goat",              mesh="Head",     color=Color3.fromRGB(200,200,200), imageId=nil},
	{key="Hedgehog",          display="Hedgehog",          mesh="Sphere",   color=Color3.fromRGB(120,90,60),   imageId=nil},
	{key="Kiwi",              display="Kiwi",              mesh="Head",     color=Color3.fromRGB(110,80,60),   imageId=nil},
	{key="Capybara Alt",      display="Capybara (Alt)",    mesh="Head",     color=Color3.fromRGB(140,100,70),  imageId=nil},
	{key="Ankylosaurus",      display="Ankylosaurus",      mesh="Block",    color=Color3.fromRGB(90,120,120),  imageId=nil},
	{key="Fennec Fox",        display="Fennec Fox",        mesh="Head",     color=Color3.fromRGB(230,200,160), imageId=nil},
}

-- Build a “Handle” part from desc (mesh/color/image)
local function makeHandleFromDesc(desc): BasePart
	local function applyDecal(target)
		if desc.imageId then
			local d = Instance.new("Decal")
			d.Texture = tostring(desc.imageId) -- "rbxassetid://12345"
			d.Face = Enum.NormalId.Front
			d.Parent = target
		end
	end

	local color = desc.color or Color3.fromRGB(200,200,200)

	if desc.mesh == "Wedge" then
		local wedge = Instance.new("WedgePart")
		wedge.Name = "Handle"
		wedge.Size = Vector3.new(1.2,1,1.2)
		wedge.Color = color
		wedge.CanCollide=false; wedge.Massless=true; wedge.Anchored=false
		applyDecal(wedge)
		return wedge
	else
		local p = Instance.new("Part")
		p.Name = "Handle"
		p.Size = Vector3.new(1,1,1)
		p.Color = color
		p.CanCollide=false; p.Massless=true; p.Anchored=false
		local sm
		if desc.mesh == "Sphere" then
			sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Sphere
		elseif desc.mesh == "Cylinder" then
			sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Cylinder
		elseif desc.mesh == "Head" then
			sm = Instance.new("SpecialMesh"); sm.MeshType = Enum.MeshType.Head
		end
		if sm then sm.Parent = p end
		applyDecal(p)
		return p
	end
end

-- Visual-only Tool in hotbar
local function createVisualToolFromDesc(desc): Tool
	local backpack = player:WaitForChild("Backpack")
	local tool = Instance.new("Tool")
	tool.Name = "[V] " .. (desc.display or "Item")
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("VisualOnly", true)
	local handle = makeHandleFromDesc(desc)
	if USE_FORCEFIELD then handle.Material = Enum.Material.ForceField end
	handle.Parent = tool
	tool.Parent = backpack
	return tool
end

-- World model from desc
local function buildWorldModelFromDesc(desc): Model
	local m = Instance.new("Model")
	m.Name = (desc.display or "Item") .. "_VISUAL"
	local core = Instance.new("Part")
	core.Size = Vector3.new(1.5,1.5,1.5)
	core.Color = desc.color or Color3.fromRGB(200,200,200)
	local sm = Instance.new("SpecialMesh")
	if desc.mesh == "Sphere" then sm.MeshType = Enum.MeshType.Sphere
	elseif desc.mesh == "Cylinder" then sm.MeshType = Enum.MeshType.Cylinder
	elseif desc.mesh == "Head" then sm.MeshType = Enum.MeshType.Head
	else sm.MeshType = Enum.MeshType.Brick end
	sm.Parent = core
	core.Parent = m
	for _, d in ipairs(m:GetDescendants()) do if d:IsA("BasePart") then safePart(d) end end
	m.PrimaryPart = core
	return m
end

-- Place near character & fade
local function placeModelNearCharacter(model: Model)
	local char = player.Character
	if not char or not char.PrimaryPart then model:Destroy(); return end
	local targetCF = char.PrimaryPart.CFrame * CFrame.new(WORLD_OFFSET)
	local ok = pcall(function() model:PivotTo(targetCF) end)
	if not ok then
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then p.Position = char.PrimaryPart.Position + WORLD_OFFSET end
		end
	end
	model.Parent = workspace
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local t0 = d.Transparency
			d.Transparency = math.min(1, t0 + 0.5)
			TweenService:Create(d, TweenInfo.new(0.12), {Transparency = t0}):Play()
		end
	end
	Debris:AddItem(model, WORLD_LIFETIME)
end

-- Duplicate from existing Tool (slot 3)
local function buildVisualFromTool(tool: Tool): Model?
	if not tool or not tool:IsDescendantOf(game) then return nil end
	local model = Instance.new("Model")
	model.Name = tool.Name .. "_VISUAL"
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("MeshPart") or d:IsA("UnionOperation") then
			local c = d:Clone(); c.Parent = model
		elseif d:IsA("Accessory") then
			local c = d:Clone(); c.Parent = model
		end
	end
	if #model:GetChildren() == 0 then
		local tmp = tool:Clone(); stripScripts(tmp)
		for _, d in ipairs(tmp:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("MeshPart") or d:IsA("UnionOperation") then d.Parent = model end
		end
		tmp:Destroy()
	end
	if #model:GetChildren() == 0 then model:Destroy(); return nil end
	local primary: BasePart? = nil
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then safePart(d); if not primary then primary = d end end
	end
	if not primary then model:Destroy(); return nil end
	model.PrimaryPart = primary
	return model
end

local function createVisualToolInHotbarFromTool(src: Tool)
	local backpack = player:WaitForChild("Backpack")
	local tool = Instance.new("Tool")
	tool.Name = "[V] "..(src and src.Name or "Item")
	tool.CanBeDropped=false; tool.RequiresHandle=true; tool:SetAttribute("VisualOnly", true)
	local cloned: BasePart? = nil
	for _, d in ipairs(src:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("MeshPart") then
			local c = d:Clone(); c.Name="Handle"; c.CanCollide=false; c.Massless=true; c.Anchored=false; c.Parent=tool; cloned=c; break
		end
	end
	if not cloned then
		local p=Instance.new("Part"); p.Name="Handle"; p.Size=Vector3.new(1,1,1); p.CanCollide=false; p.Massless=true; p.Parent=tool
	end
	tool.Parent = backpack
	return tool
end

local function clearVisuals()
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, t in ipairs(backpack:GetChildren()) do
			if t:IsA("Tool") and t:GetAttribute("VisualOnly") then t:Destroy() end
		end
	end
	for _, inst in ipairs(workspace:GetChildren()) do
		if inst:IsA("Model") and inst.Name:match("_VISUAL$") then inst:Destroy() end
	end
end

-- High-level action: duplicate slot 3 visually (world + hotbar)
local function duplicateSlot3()
	local tool = getToolInSlot(SLOT_INDEX)
	if not tool then
		StarterGui:SetCore("SendNotification", {Title="Slot 3", Text="Tool not found in slot 3.", Duration=2})
		return
	end
	local model = buildVisualFromTool(tool)
	if model then placeModelNearCharacter(model) end
	createVisualToolInHotbarFromTool(tool)
	StarterGui:SetCore("SendNotification", {Title="Visual Duplicate", Text=tool.Name.." (world + hotbar)", Duration=3})
end

--// UI: draggable menu + list + actions (+ preview)
local function createUI()
	local sg = Instance.new("ScreenGui")
	sg.Name = "VisualPetsUI"
	sg.ResetOnSpawn = false
	sg.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.new(0, 560, 0, 300)
	panel.Position = UDim2.new(0.5, -280, 0.6, -150)
	panel.BackgroundColor3 = Color3.fromRGB(24,24,24)
	panel.BorderSizePixel = 0
	panel.Visible = false
	panel.Parent = sg
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.BackgroundColor3 = Color3.fromRGB(34,34,34)
	header.Size = UDim2.new(1, 0, 0, 36)
	header.Position = UDim2.new(0,0,0,0)
	header.Font = Enum.Font.GothamBold
	header.TextSize = 16
	header.TextColor3 = Color3.fromRGB(255,255,255)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Text = "  Visual Pets (client-side)"
	header.Parent = panel
	Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)

	-- Dragging
	local dragging = false
	local dragStart, startPos
	header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true; dragStart = input.Position; startPos = panel.Position
		end
	end)
	header.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = input.Position - dragStart
			panel.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)

	-- Left: list
	local list = Instance.new("ScrollingFrame")
	list.Name = "PetList"
	list.BackgroundColor3 = Color3.fromRGB(28,28,28)
	list.Position = UDim2.new(0, 12, 0, 48)
	list.Size = UDim2.new(0, 240, 1, -60)
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.Parent = panel
	Instance.new("UICorner", list).CornerRadius = UDim.new(0, 8)
	local uiList = Instance.new("UIListLayout"); uiList.Padding = UDim.new(0,6); uiList.Parent = list

	-- Right: actions + preview
	local box = Instance.new("Frame")
	box.Name = "Actions"
	box.BackgroundTransparency = 1
	box.Position = UDim2.new(0, 264, 0, 48)
	box.Size = UDim2.new(1, -276, 1, -60)
	box.Parent = panel

	local preview = Instance.new("ImageLabel")
	preview.Name = "Preview"
	preview.BackgroundColor3 = Color3.fromRGB(40,40,40)
	preview.Size = UDim2.new(0, 64, 0, 64)
	preview.Position = UDim2.new(0, 0, 0, 0)
	preview.ScaleType = Enum.ScaleType.Fit
	preview.Image = ""
	preview.Parent = box
	Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 8)

	local info = Instance.new("TextLabel")
	info.BackgroundTransparency = 1
	info.TextWrapped = true
	info.TextXAlignment = Enum.TextXAlignment.Left
	info.Text = "Выбери питомца слева. Кнопки:\n• Добавить в хотбар — визуальный Tool.\n• Спаун в мир — призрачная модель.\n• Duplicate Slot 3 — клон предмета из 3-го слота.\n• Очистить — убрать визуалы."
	info.Font = Enum.Font.Gotham
	info.TextSize = 13
	info.TextColor3 = Color3.fromRGB(210,210,210)
	info.Size = UDim2.new(1, -74, 0, 64)
	info.Position = UDim2.new(0, 74, 0, 0)
	info.Parent = box

	local addBtn = Instance.new("TextButton")
	addBtn.Text = "Добавить в хотбар"
	addBtn.Font = Enum.Font.GothamBold
	addBtn.TextSize = 14
	addBtn.TextColor3 = Color3.fromRGB(255,255,255)
	addBtn.BackgroundColor3 = Color3.fromRGB(0,160,90)
	addBtn.Size = UDim2.new(1, 0, 0, 36)
	addBtn.Position = UDim2.new(0, 0, 0, 78)
	addBtn.Parent = box
	Instance.new("UICorner", addBtn).CornerRadius = UDim.new(0, 8)

	local spawnBtn = Instance.new("TextButton")
	spawnBtn.Text = "Спаун в мир"
	spawnBtn.Font = Enum.Font.GothamBold
	spawnBtn.TextSize = 14
	spawnBtn.TextColor3 = Color3.fromRGB(255,255,255)
	spawnBtn.BackgroundColor3 = Color3.fromRGB(70,130,180)
	spawnBtn.Size = UDim2.new(1, 0, 0, 36)
	spawnBtn.Position = UDim2.new(0, 0, 0, 124)
	spawnBtn.Parent = box
	Instance.new("UICorner", spawnBtn).CornerRadius = UDim.new(0, 8)

	local dup3Btn = Instance.new("TextButton")
	dup3Btn.Text = "Duplicate Slot 3"
	dup3Btn.Font = Enum.Font.GothamBold
	dup3Btn.TextSize = 14
	dup3Btn.TextColor3 = Color3.fromRGB(255,255,255)
	dup3Btn.BackgroundColor3 = Color3.fromRGB(120,120,120)
	dup3Btn.Size = UDim2.new(1, 0, 0, 36)
	dup3Btn.Position = UDim2.new(0, 0, 0, 170)
	dup3Btn.Parent = box
	Instance.new("UICorner", dup3Btn).CornerRadius = UDim.new(0, 8)

	local clearBtn = Instance.new("TextButton")
	clearBtn.Text = "Очистить"
	clearBtn.Font = Enum.Font.Gotham
	clearBtn.TextSize = 13
	clearBtn.TextColor3 = Color3.fromRGB(255,255,255)
	clearBtn.BackgroundColor3 = Color3.fromRGB(90,90,90)
	clearBtn.Size = UDim2.new(0, 120, 0, 28)
	clearBtn.Position = UDim2.new(1, -120, 1, -28)
	clearBtn.Parent = panel
	Instance.new("UICorner", clearBtn).CornerRadius = UDim.new(0, 6)

	-- Populate list
	local selectedDesc = nil
	for _, desc in ipairs(PET_CATALOG) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, -12, 0, 30)
		btn.BackgroundColor3 = Color3.fromRGB(40,40,40)
		btn.TextColor3 = Color3.fromRGB(255,255,255)
		btn.TextSize = 14
		btn.Font = Enum.Font.Gotham
		btn.Text = desc.display or desc.key
		btn.Parent = list
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

		btn.MouseButton1Click:Connect(function()
			selectedDesc = desc
			for _, b in ipairs(list:GetChildren()) do
				if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(40,40,40) end
			end
			btn.BackgroundColor3 = Color3.fromRGB(0,120,255)
			preview.Image = desc.imageId or ""
		end)
	end

	-- Actions
	addBtn.MouseButton1Click:Connect(function()
		if not selectedDesc then
			StarterGui:SetCore("SendNotification", {Title="Выбор", Text="Сначала выбери питомца слева.", Duration=2})
			return
		end
		createVisualToolFromDesc(selectedDesc)
	end)

	spawnBtn.MouseButton1Click:Connect(function()
		if not selectedDesc then
			StarterGui:SetCore("SendNotification", {Title="Выбор", Text="Сначала выбери питомца слева.", Duration=2})
			return
		end
		local m = buildWorldModelFromDesc(selectedDesc)
		placeModelNearCharacter(m)
	end)

	dup3Btn.MouseButton1Click:Connect(function()
		local t = getToolInSlot(SLOT_INDEX)
		if not t then
			StarterGui:SetCore("SendNotification", {Title="Slot 3", Text="В слоте 3 нет Tool.", Duration=2})
			return
		end
		local model = buildVisualFromTool(t); if model then placeModelNearCharacter(model) end
		createVisualToolInHotbarFromTool(t)
	end)

	clearBtn.MouseButton1Click:Connect(function()
		clearVisuals()
	end)

	-- Toggle G
	UserInputService.InputBegan:Connect(function(input, gp)
		if gp then return end
		if input.KeyCode == OPEN_KEY then
			panel.Visible = not panel.Visible
		end
	end)
end

-- Init UI
createUI()
