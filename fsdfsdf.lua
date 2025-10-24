-- LocalScript: draggable menu + "Clone Equipped Item" (client-side only)
-- Place into StarterPlayer -> StarterPlayerScripts
-- WARNING: use only in your own place / Studio. This does not modify server state.

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

-- Config
local OPEN_KEY = Enum.KeyCode.G                -- открыть меню
local WORLD_OFFSET = Vector3.new(3, 0, 0)      -- где появится призрачная модель
local WORLD_LIFETIME = 20                      -- время жизни призрачной модели (сек)
local VISUAL_TOOL_TTL = 0                      -- 0 = не удалять автоматически; можно >0
local USE_FORCEFIELD = true
local TRANSPARENCY_ADD = 0.25
local COOLDOWN = 0.6                           -- защита от спама кнопки

-- helpers
local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title or "Info"),
            Text = tostring(text or ""),
            Duration = duration or 2
        })
    end)
end

local function safePart(p: BasePart)
    if not p then return end
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

local function firstGeometryDescendant(inst: Instance): BasePart?
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("MeshPart") or d:IsA("UnionOperation") then
            return d
        end
    end
    return nil
end

-- Пытаемся извлечь ID предмета из атрибутов или Value-объектов внутри Tool
local function extractItemId(tool: Tool): string?
    if not tool then return nil end
    local keys = {"ItemId", "ItemID", "ID", "AssetId", "assetId", "itemId"}
    for _, k in ipairs(keys) do
        local v = tool:GetAttribute(k)
        if v ~= nil then return tostring(v) end
    end
    -- value objects
    for _, k in ipairs(keys) do
        local obj = tool:FindFirstChild(k)
        if obj then
            if obj:IsA("StringValue") or obj:IsA("IntValue") or obj:IsA("NumberValue") then
                return tostring(obj.Value)
            end
        end
    end
    return nil
end

-- Построить world-visual (Model) из Tool (копируем только геометрию)
local function buildWorldVisualFromTool(tool: Tool): Model?
    if not tool or not tool:IsDescendantOf(game) then return nil end

    local model = Instance.new("Model")
    model.Name = tool.Name .. "_CLONE_VISUAL"

    -- копируем все BasePart/Mesh/Accessory
    for _, d in ipairs(tool:GetDescendants()) do
        if d:IsA("BasePart") or d:IsA("MeshPart") or d:IsA("UnionOperation") or d:IsA("Accessory") then
            local ok, c = pcall(function() return d:Clone() end)
            if ok and c then
                -- не добавляем скрипты — Accessory может содержать Handle (часть) — это ок
                c.Parent = model
            end
        end
    end

    -- fallback: если ничего не скопировалось — клонируем Tool и извлекаем части
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

    if #model:GetChildren() == 0 then
        model:Destroy()
        return nil
    end

    local primary: BasePart? = nil
    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            safePart(d)
            if not primary then primary = d end
        end
    end

    if not primary then
        model:Destroy()
        return nil
    end

    model.PrimaryPart = primary
    return model
end

-- Разместить призрачную модель рядом с персонажем и сделать fade-in
local function placeModelNearCharacter(model: Model)
    local char = player.Character
    if not char or not char.PrimaryPart then
        model:Destroy()
        return
    end

    local targetCF = char.PrimaryPart.CFrame * CFrame.new(WORLD_OFFSET)
    pcall(function() model:PivotTo(targetCF) end)
    model.Parent = workspace

    for _, d in ipairs(model:GetDescendants()) do
        if d:IsA("BasePart") then
            local t0 = d.Transparency
            d.Transparency = math.min(1, t0 + 0.6)
            local tween = TweenService:Create(d, TweenInfo.new(0.14), {Transparency = t0})
            tween:Play()
        end
    end

    Debris:AddItem(model, WORLD_LIFETIME)
end

-- Создать локальный Tool в Backpack, используя первую найденную геометрию из src Tool
local function createVisualToolInHotbarFromTool(src: Tool): Tool
    local backpack = player:WaitForChild("Backpack")
    local tool = Instance.new("Tool")
    tool.Name = "[CLONE] " .. (src and src.Name or "Item")
    tool.CanBeDropped = false
    tool.RequiresHandle = true
    tool:SetAttribute("VisualOnly", true)
    -- попытка скопировать реалистичный Handle
    local geom = firstGeometryDescendant(src)
    if geom then
        local ok, c = pcall(function() return geom:Clone() end)
        if ok and c and c:IsA("BasePart") then
            c.Name = "Handle"
            c.CanCollide = false
            c.CanQuery = false
            c.Massless = true
            c.Anchored = false
            if USE_FORCEFIELD then c.Material = Enum.Material.ForceField end
            c.Parent = tool
        end
    end
    -- если не получилось — простой куб Handle
    if not tool:FindFirstChild("Handle") then
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

    -- проставим SourceItemId, если есть
    local id = extractItemId(src)
    if id then
        pcall(function() tool:SetAttribute("SourceItemId", id) end)
    end

    tool.Parent = backpack

    -- опционально: удалить через TTL
    if VISUAL_TOOL_TTL > 0 then
        Debris:AddItem(tool, VISUAL_TOOL_TTL)
    end

    return tool
end

-- Clear visuals (tools in backpack with VisualOnly + models with suffix)
local function clearVisuals()
    local backpack = player:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, t in ipairs(backpack:GetChildren()) do
            if t:IsA("Tool") and t:GetAttribute("VisualOnly") then
                t:Destroy()
            end
            if t:IsA("Tool") and t:GetAttribute("SourceItemId") then
                -- если нужно — можно отдельно чистить эти тоже
            end
        end
    end
    for _, inst in ipairs(workspace:GetChildren()) do
        if inst:IsA("Model") and tostring(inst.Name):match("_CLONE_VISUAL$") then
            inst:Destroy()
        end
    end
end

-- Найти экипированный Tool в персонаже (проверяет Character children)
local function getEquippedTool(): Tool?
    local char = player.Character
    if not char then return nil end
    for _, v in ipairs(char:GetChildren()) do
        if v:IsA("Tool") then
            return v
        end
    end
    -- иногда инструмент может быть хранится иначе — можно проверить Humanoid:FindFirstChildOfClass, но обычно above works
    return nil
end

-- Основная операция: полностью клонировать экипированный предмет (модель + хотбар)
local lastAction = 0
local function cloneEquipped()
    local now = tick()
    if now - lastAction < COOLDOWN then return end
    lastAction = now

    local tool = getEquippedTool()
    if not tool then
        notify("Clone", "Инструмент не экипирован. Надень Tool в руку и попробуй снова.", 2.5)
        return
    end

    -- попытка взять ID
    local id = extractItemId(tool)
    if id then
        notify("Clone", "ID найден: " .. tostring(id), 2)
    else
        notify("Clone", "ID не найден — клонируем по геометрии.", 2)
    end

    -- 1) world visual
    local model = buildWorldVisualFromTool(tool)
    if model then
        pcall(function() model:SetAttribute("SourceToolName", tool.Name) end)
        if id then pcall(function() model:SetAttribute("SourceItemId", id) end) end
        placeModelNearCharacter(model)
    end

    -- 2) hotbar visual
    local vtool = createVisualToolInHotbarFromTool(tool)
    if vtool then
        notify("Clone", "Визуальный Tool добавлен в Backpack: " .. vtool.Name, 2.5)
    end
end

-- ──────────────────────────────────────────────────────────────────────────────
-- UI: draggable menu with button "Clone Equipped Item" + Clear
-- ──────────────────────────────────────────────────────────────────────────────
local function createUI()
    local sg = Instance.new("ScreenGui")
    sg.Name = "CloneEquippedUI"
    sg.ResetOnSpawn = false
    sg.Parent = player:WaitForChild("PlayerGui")

    local frame = Instance.new("Frame")
    frame.Name = "Main"
    frame.Size = UDim2.new(0, 300, 0, 140)
    frame.Position = UDim2.new(0.5, -150, 0.6, -70)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    frame.BorderSizePixel = 0
    frame.Parent = sg
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)

    local header = Instance.new("TextLabel")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 36)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Color3.fromRGB(42, 42, 42)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 15
    header.TextColor3 = Color3.fromRGB(230, 230, 230)
    header.Text = "  Clone Equipped Item (client)"
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = frame
    Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

    -- dragging logic
    local dragging = false
    local dragStart, startPos
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
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(1, -20, 0, 48)
    info.Position = UDim2.new(0, 10, 0, 44)
    info.BackgroundTransparency = 1
    info.Font = Enum.Font.Gotham
    info.TextSize = 13
    info.TextColor3 = Color3.fromRGB(200,200,200)
    info.TextWrapped = true
    info.Text = "Нажми кнопку — будет полностью клонирован экипированный Tool (модель + визуальный Tool в хотбар). Всё локально."
    info.Parent = frame

    local btnClone = Instance.new("TextButton")
    btnClone.Size = UDim2.new(1, -20, 0, 36)
    btnClone.Position = UDim2.new(0, 10, 1, -48)
    btnClone.Font = Enum.Font.GothamBold
    btnClone.TextSize = 14
    btnClone.TextColor3 = Color3.fromRGB(255,255,255)
    btnClone.BackgroundColor3 = Color3.fromRGB(0, 150, 90)
    btnClone.Text = "Clone Equipped Item"
    btnClone.Parent = frame
    Instance.new("UICorner", btnClone).CornerRadius = UDim.new(0, 8)

    local btnClear = Instance.new("TextButton")
    btnClear.Size = UDim2.new(0, 120, 0, 28)
    btnClear.Position = UDim2.new(1, -130, 0, 8)
    btnClear.Font = Enum.Font.Gotham
    btnClear.TextSize = 13
    btnClear.TextColor3 = Color3.fromRGB(255,255,255)
    btnClear.BackgroundColor3 = Color3.fromRGB(120, 120, 120)
    btnClear.Text = "Clear Visuals"
    btnClear.Parent = frame
    Instance.new("UICorner", btnClear).CornerRadius = UDim.new(0, 6)

    btnClone.MouseButton1Click:Connect(function()
        btnClone.AutoButtonColor = false
        local old = btnClone.BackgroundColor3
        btnClone.BackgroundColor3 = Color3.fromRGB(0, 200, 120)
        cloneEquipped()
        task.delay(0.16, function()
            btnClone.BackgroundColor3 = old
            btnClone.AutoButtonColor = true
        end)
    end)

    btnClear.MouseButton1Click:Connect(function()
        clearVisuals()
        notify("Clear", "Визуальные копии удалены", 2)
    end)

    -- toggle menu by G
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == OPEN_KEY then
            frame.Visible = not frame.Visible
        end
    end)
end

-- init
createUI()

-- Optional: also clone automatically when you Equip (if you want)
-- Uncomment if you want automatic clone on Equip:
--[[ 
local function onCharacterAdded(char)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            -- short delay: often tool will fire Equipped event; do safe call
            child.Equipped:Connect(function() 
                cloneEquipped()
            end)
        end
    end)
end

if player.Character then onCharacterAdded(player.Character) end
player.CharacterAdded:Connect(onCharacterAdded)
]]

