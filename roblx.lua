-- === Auto George Toggle (drop-in) ============================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local autoGeorgeEnabled = false
local georgePrompt :: ProximityPrompt? = nil

-- ---------- helpers ----------
local function toast(msg: string)
    if typeof(_G.showToast) == "function" then
        _G.showToast(msg)
        return
    end
    if typeof(showToast) == "function" then
        showToast(msg)
        return
    end
    print("[Toast]", msg)
end

local function setPromptsUiHidden(hidden: boolean)
    -- Скрываем системный UI ProximityPrompt для локального игрока
    pcall(function() StarterGui:SetCore("ProximityPromptEnabled", not hidden) end)
    -- На случай, если игра использует свойство сервиса (не во всех проектах доступно из LocalScript)
    pcall(function() ProximityPromptService.Enabled = not hidden end)
end

local function getCharacterRoot()
    local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    return char:FindFirstChild("HumanoidRootPart")
end

local function distToPrompt(prompt: ProximityPrompt)
    local root = getCharacterRoot()
    if not (root and prompt and prompt.Parent) then return math.huge end
    local adornee = prompt.Adornee
    local pos
    if adornee and adornee:IsA("BasePart") then
        pos = adornee.Position
    else
        local parentPart = prompt.Parent:IsA("BasePart") and prompt.Parent or prompt.Parent:FindFirstChildWhichIsA("BasePart", true)
        if parentPart then
            pos = parentPart.Position
        end
    end
    if not pos then return math.huge end
    return (root.Position - pos).Magnitude
end

-- ---------- George prompt resolver ----------
local function findGeorgePrompt()
    georgePrompt = nil
    for _, inst in ipairs(Workspace:GetDescendants()) do
        if inst:IsA("ProximityPrompt") and inst.Name == "George" then
            georgePrompt = inst
            break
        end
    end
end

findGeorgePrompt()

-- Авто-обновление ссылки при появлении/удалении
Workspace.DescendantAdded:Connect(function(inst)
    if georgePrompt == nil and inst:IsA("ProximityPrompt") and inst.Name == "George" then
        georgePrompt = inst
    end
end)

Workspace.DescendantRemoving:Connect(function(inst)
    if inst == georgePrompt then
        georgePrompt = nil
        -- попробовать найти новый экземпляр, если есть
        task.defer(findGeorgePrompt)
    end
end)

-- ---------- Авто-активация George ----------
task.spawn(function()
    while true do
        if autoGeorgeEnabled and georgePrompt and georgePrompt.Enabled then
            local maxDist = (georgePrompt.MaxActivationDistance or 10)
            local d = distToPrompt(georgePrompt)
            if d <= (maxDist + 0.5) then
                -- Безопасный триггер: Roblox сам обработает HoldDuration и условия
                pcall(function()
                    ProximityPromptService:TriggerPrompt(georgePrompt)
                end)
            end
        end
        task.wait(0.25)
    end
end)

-- ---------- UI: добавить кнопку в существующее меню или создать мини-кнопку ----------
local function findMenuContainer()
    -- Попробуем типичные места: ScreenGui вашего меню, фрейм с ListLayout, и т.п.
    local sg = nil
    for _, gui in ipairs(localPlayer:WaitForChild("PlayerGui"):GetChildren()) do
        if gui:IsA("ScreenGui") and (gui.Name:lower():find("super") or gui.Name:lower():find("menu") or gui.Name:lower():find("ui")) then
            sg = gui
            break
        end
    end
    if not sg then
        -- fallback: создаём неброский ScreenGui
        sg = Instance.new("ScreenGui")
        sg.Name = "SuperMenu_AutoGeorge_Fallback"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.Parent = localPlayer:WaitForChild("PlayerGui")
    end

    -- найдём колонку/контейнер с кнопками
    local container = sg:FindFirstChildWhichIsA("Frame", true)
    if container and container:FindFirstChildWhichIsA("UIListLayout", true) then
        return container
    end

    -- fallback: создадим небольшой уголок
    local holder = Instance.new("Frame")
    holder.Name = "AutoGeorgeHolder"
    holder.Parent = sg
    holder.Size = UDim2.fromOffset(200, 48)
    holder.Position = UDim2.new(0, 20, 0, 120)
    holder.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    holder.BackgroundTransparency = 0.1
    holder.BorderSizePixel = 0
    holder.Active = true
    holder.Draggable = true

    local uiCorner = Instance.new("UICorner", holder)
    uiCorner.CornerRadius = UDim.new(0, 10)
    return holder
end

local function buildToggleButton(parent: Instance)
    local btn = Instance.new("TextButton")
    btn.Name = "AutoGeorgeToggle"
    btn.Parent = parent
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.BackgroundColor3 = Color3.fromRGB(34, 34, 40)
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = true
    btn.TextScaled = true
    btn.RichText = true
    btn.Text = "<b>Auto George (Toggle)</b> : OFF"

    local uic = Instance.new("UICorner", btn)
    uic.CornerRadius = UDim.new(0, 8)

    local uiStroke = Instance.new("UIStroke", btn)
    uiStroke.Thickness = 1
    uiStroke.Color = Color3.fromRGB(70, 70, 80)
    uiStroke.Transparency = 0.2

    -- Поведение
    local function refreshLabel()
        btn.Text = string.format("<b>Auto George (Toggle)</b> : %s", autoGeorgeEnabled and "ON" or "OFF")
    end

    local function setEnabled(state: boolean)
        autoGeorgeEnabled = state
        refreshLabel()
        setPromptsUiHidden(state) -- скрыть/показать UI всех ProximityPrompt
        if autoGeorgeEnabled then
            toast("Auto George: ON")
            -- убедимся, что есть ссылка
            if not georgePrompt then findGeorgePrompt() end
        else
            toast("Auto George: OFF")
        end
    end

    btn.MouseButton1Click:Connect(function()
        setEnabled(not autoGeorgeEnabled)
    end)

    -- инициализация
    refreshLabel()
    return btn
end

local container = findMenuContainer()
buildToggleButton(container)

-- Если у вас в файле уже есть система кнопок и глобальные таблицы/регистры — 
-- при желании можно зарегистрировать фичу:
_G.AutoGeorge = {
    getEnabled = function() return autoGeorgeEnabled end,
    setEnabled = function(v: boolean)
        if v ~= autoGeorgeEnabled then
            autoGeorgeEnabled = not autoGeorgeEnabled
            -- найдём кнопку и дёрнем клик, чтобы синхронно обновить UI/тосты
            local btn = nil
            local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
            if pg then
                btn = pg:FindFirstChild("AutoGeorgeToggle", true)
            end
            if btn and btn:IsA("TextButton") then
                btn:Activate()
            else
                -- прямой fallback
                pcall(function() StarterGui:SetCore("ProximityPromptEnabled", not v) end)
                pcall(function() ProximityPromptService.Enabled = not v end)
                toast("Auto George: " .. (v and "ON" or "OFF"))
            end
        end
    end,
    debugPrompt = function() return georgePrompt end,
}
-- === /Auto George Toggle =====================================================
