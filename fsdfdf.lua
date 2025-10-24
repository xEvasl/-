-- LocalScript: On-Equip visual duplicate (world + hotbar) with item ID capture (client-side only)

-- Services
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

-- Config
local WORLD_OFFSET     = Vector3.new(3, 0, 0) -- куда появится призрачная копия
local WORLD_LIFETIME   = 15                   -- сек до авто-удаления копии
local USE_FORCEFIELD   = true                 -- призрачный вид
local TRANSPARENCY_ADD = 0.25                 -- доп. прозрачность призрачных частей
local EQUIP_COOLDOWN   = 0.8                  -- анти-спам от повторных срабатываний

-- ──────────────────────────────────────────────────────────────────────────────
-- Helpers
-- ──────────────────────────────────────────────────────────────────────────────
local function notify(title, text, duration)
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = tostring(title or "Info"),
			Text = tostring(text or ""),
			Duration = duration or 3
		})
	end)
end

local function safePart(p: BasePart)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Massless = true
	p.Transparency = math.clamp(p.Transparency + TRANSPARENCY_ADD, 0, 1)
	if USE_FORCEFIELD then
		p.Material = Enum.Material.ForceField
	end
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

local function firstGeometryDescendant(inst: Instance): BasePart?
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("MeshPart") or d:IsA("UnionOperation") then
			return d
		end
	end
	return nil
end

-- Попытаться прочитать ItemId/AssetId из атрибутов или Value-объектов внутри Tool
local function extractItemId(tool: Tool): string?
	if not tool then return nil end

	-- 1) Атрибуты
	local attrKeys = {"ItemId", "ItemID", "ID", "AssetId", "assetId", "itemId"}
	for _, k in ipairs(attrKeys) do
		local v = tool:GetAttribute(k)
		if v ~= nil then return tostring(v) end
	end

	-- 2) Value-объекты
	local function findVal(nameList: {string})
		for _, n in ipairs(nameList) do
			local obj = tool:FindFirstChild(n)
			if obj then
				if obj:IsA("StringValue") or obj:IsA("IntValue") or obj:IsA("NumberValue") then
                    return tostring(obj.Value)
				end
			end
		end
		return nil
	end
	local v = findVal(attrKeys)
	if v then return v end

	-- 3) Ничего не нашли — используем имя как fallback
	return nil
end

-- Построить призрачную модель из Tool (только геометрия)
local function buildWorldVisualFromTool(tool: Tool): Model?
	if not tool or not tool:IsDescendantOf(game) then return nil end

	local model = Instance.new("Model")
	model.Name = tool.Name .. "_VISUAL"

	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("MeshPart") or d:IsA("UnionOperation") then
			local c = d:Clone()
			c.Parent = model
		elseif d:IsA("Accessory") then
			local acc = d:Clone()
			acc.Parent = model
		end
	end

	-- Fallback: склонировать весь Tool и извлечь части
	if #model:GetChildren() == 0 then
		local tmp = tool:Clone()
		stripScripts(tmp)
		for _, d in ipairs(tmp:GetDescendants()) do
			if d:IsA("BasePart") or d:IsA("MeshPart") or d:IsA("UnionOperation") then
				d.Parent = model
			end
		end
		tmp:Destroy()
	end

	if #model:GetChildren() == 0 then model:Destroy() return nil end

	local primary: BasePart? = nil
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			safePart(d)
			if not primary then primary = d end
		end
	end
	if not primary then model:Destroy() return nil end
	model.PrimaryPart = primary
	return model
end

-- Поставить призрачную модель рядом с персонажем
local function placeModelNearCharacter(model: Model)
	local char = player.Character
	if not char or not char.PrimaryPart then
		model:Destroy()
		return
	end

	local targetCF = char.PrimaryPart.CFrame * CFrame.new(WORLD_OFFSET)
	pcall(function() model:PivotTo(targetCF) end)
	model.Parent = workspace

	-- небольшое “проявление”
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local t0 = d.Transparency
			d.Transparency = math.min(1, t0 + 0.5)
			TweenService:Create(d, TweenInfo.new(0.12), {Transparency = t0}):Play()
		end
	end

	Debris:AddItem(model, WORLD_LIFETIME)
end

-- Сделать визуальный Tool в хотбаре (локальный), похожий на исходный
local function createVisualToolInHotbarFromTool(src: Tool): Tool
	local backpack = player:WaitForChild("Backpack")
	local tool = Instance.new("Tool")
	tool.Name = "[V] " .. (src and src.Name or "Item")
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("VisualOnly", true)

	-- Попробуем клонировать подходящую “ручку” из исходного Tool
	local clonedHandle: BasePart? = nil
	local geom = firstGeometryDescendant(src)
	if geom then
		local c = geom:Clone()
		c.Name = "Handle"
		c.CanCollide = false
		c.CanQuery = false
		c.Massless = true
		c.Anchored = false
		if USE_FORCEFIELD then c.Material = Enum.Material.ForceField end
		c.Parent = tool
		clonedHandle = c
	end

	-- Если не нашли — сделаем простую ручку
	if not clonedHandle then
		local p = Instance.new("Part")
		p.Name = "Handle"
		p.Size = Vector3.new(1,1,1)
		p.CanCollide = false
		p.CanQuery = false
		p.Massless = true
		p.Anchored = false
		if USE_FORCEFIELD then p.Material = Enum.Material.ForceField end
		p.Parent = tool
	end

	tool.Parent = backpack
	return tool
end

-- Убрать все визуалы (если нужно вручную вызвать)
local function clearVisuals()
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, t in ipairs(backpack:GetChildren()) do
			if t:IsA("Tool") and t:GetAttribute("VisualOnly") then
				t:Destroy()
			end
		end
	end
	for _, inst in ipairs(workspace:GetChildren()) do
		if inst:IsA("Model") and inst.Name:match("_VISUAL$") then
			inst:Destroy()
		end
	end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- Main: реагируем на экип предмета
-- ──────────────────────────────────────────────────────────────────────────────
local lastEquipAt = 0

local function onToolEquipped(tool: Tool)
	-- анти-спам
	local now = os.clock()
	if now - lastEquipAt < EQUIP_COOLDOWN then return end
	lastEquipAt = now

	-- ID предмета (если есть)
	local itemId = extractItemId(tool)
	if itemId then
		notify("Equipped", ("ID: %s  |  %s"):format(itemId, tool.Name), 2.5)
	else
		notify("Equipped", ("ID не найден  |  %s"):format(tool.Name), 2.5)
	end

	-- Призрачная копия в мир
	local worldModel = buildWorldVisualFromTool(tool)
	if worldModel then
		if itemId then pcall(function() worldModel:SetAttribute("SourceItemId", itemId) end) end
		pcall(function() worldModel:SetAttribute("VisualOnly", true) end)
		placeModelNearCharacter(worldModel)
	end

	-- Визуальный предмет в хотбаре
	local visualTool = createVisualToolInHotbarFromTool(tool)
	if itemId then pcall(function() visualTool:SetAttribute("SourceItemId", itemId) end) end
end

local function hookCharacter(char: Model)
	-- Если уже держит Tool при спауне
	for _, c in ipairs(char:GetChildren()) do
		if c:IsA("Tool") then
			-- дождёмся события Equipped, если Tool его шлёт
			c.Equipped:Connect(function() onToolEquipped(c) end)
		end
	end

	-- Подписка на любые Tool, попадающие в персонажа
	char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			-- Некоторые тулзы не вызывают Equipped мгновенно — подстрахуемся:
			child.Equipped:Connect(function()
				onToolEquipped(child)
			end)
			-- Если уже экипнут (редкий случай), просто вызовем через тик
			task.defer(function()
				if child.Parent == char then
					onToolEquipped(child)
				end
			end)
		end
	end)
end

-- Подписка на текущего и последующих персонажей
if player.Character then hookCharacter(player.Character) end
player.CharacterAdded:Connect(hookCharacter)

-- [Необязательно] горячая клавиша для очистки всех визуалов (Shift + C)
local UIS = game:GetService("UserInputService")
UIS.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.C and UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
		clearVisuals()
		notify("Clear", "Визуальные дубликаты удалены", 2)
	end
end)
