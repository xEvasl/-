-- One-file Hydra-style UI (self-contained)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LP = Players.LocalPlayer

-- util
local function safeParent(gui)
    local ok,parent = pcall(function() return game:GetService("CoreGui") end)
    return ok and parent or LP:WaitForChild("PlayerGui")
end

local function applyShadow(obj, padding)
    local holder = Instance.new("Frame")
    holder.Name = "DropShadowHolder"
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(1,0,1,0)
    holder.ZIndex = obj.ZIndex
    holder.Parent = obj

    local shadow = Instance.new("ImageLabel")
    shadow.Name = "DropShadow"
    shadow.BackgroundTransparency = 1
    shadow.AnchorPoint = Vector2.new(0.5,0.5)
    shadow.Position = UDim2.new(0.5,0,0.5,0)
    shadow.Size = UDim2.new(1, padding or 34, 1, padding or 34)
    shadow.Image = "rbxassetid://6014261993"
    shadow.ImageTransparency = 0.5
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(49,49,450,450)
    shadow.ZIndex = (obj.ZIndex or 1) - 1
    shadow.Parent = holder
end

local function roundCorner(obj, r)
    local u = Instance.new("UICorner")
    u.CornerRadius = UDim.new(0, r or 8)
    u.Parent = obj
    return u
end

local function makeStrokeGradient(frame, transparency)
    local hover = Instance.new("Frame")
    hover.Name = "Hover"
    hover.BackgroundTransparency = 1
    hover.BorderSizePixel = 0
    hover.Size = UDim2.new(1,4,1,4)
    hover.Position = UDim2.new(0,-2,0,-2)
    hover.ZIndex = (frame.ZIndex or 1) + 1
    hover.Parent = frame

    local ui = Instance.new("UIGradient")
    ui.Color = ColorSequence.new(Color3.fromRGB(255,255,255), Color3.fromRGB(163,163,163))
    ui.Rotation = 45
    ui.Parent = hover

    roundCorner(hover, 8)
    hover.BackgroundColor3 = Color3.fromRGB(15,15,15)
    hover.BackgroundTransparency = transparency or 1
    return hover
end

local function dragify(frame, dragHandle)
    dragHandle = dragHandle or frame
    local dragging = false
    local dragStart, startPos
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    dragHandle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end)
end

-- ScreenGui
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "HydraOneFileUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true
ScreenGui.Parent = safeParent(ScreenGui)

-- Palette/Fonts
local BG_DARK = Color3.fromRGB(18,18,18)
local BG_MID  = Color3.fromRGB(25,25,25)
local FG_TEXT = Color3.fromRGB(200,200,200)
local FG_MUTED= Color3.fromRGB(100,100,100)
local ACCENT  = Color3.fromRGB(83,87,158)

-- Main Window
local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, 860, 0, 500)
Main.Position = UDim2.new(0.5, -430, 0.5, -250)
Main.BackgroundColor3 = BG_DARK
Main.BorderSizePixel = 0
Main.ZIndex = 50
Main.Parent = ScreenGui
roundCorner(Main, 12)
applyShadow(Main, 34)

-- Title bar (for drag)
local TitleBar = Instance.new("Frame")
TitleBar.BackgroundTransparency = 1
TitleBar.Size = UDim2.new(1, -16, 0, 32)
TitleBar.Position = UDim2.new(0, 8, 0, 8)
TitleBar.Parent = Main

local Watermark = Instance.new("TextLabel")
Watermark.BackgroundTransparency = 1
Watermark.Text = "Hydra Hub — Demo"
Watermark.Font = Enum.Font.Gotham
Watermark.TextSize = 14
Watermark.TextColor3 = Color3.fromRGB(255,255,255)
Watermark.TextXAlignment = Enum.TextXAlignment.Left
Watermark.Size = UDim2.new(1,0,1,0)
Watermark.Parent = TitleBar

dragify(Main, TitleBar)

-- Sidebar
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 220, 1, -24)
Sidebar.Position = UDim2.new(0, 8, 0, 44)
Sidebar.BackgroundTransparency = 1
Sidebar.Parent = Main

local SidebarList = Instance.new("UIListLayout")
SidebarList.Padding = UDim.new(0,10)
SidebarList.SortOrder = Enum.SortOrder.LayoutOrder
SidebarList.Parent = Sidebar

-- Sidebar Card
local function sidebarCard(titleText, iconId)
    local card = Instance.new("ImageLabel")
    card.BackgroundTransparency = 1
    card.Image = "rbxassetid://7881709447"
    card.ImageColor3 = BG_MID
    card.ScaleType = Enum.ScaleType.Slice
    card.SliceCenter = Rect.new(512,512,512,512)
    card.SliceScale = 0.005
    card.Size = UDim2.new(1, -0, 0, 70)
    card.ZIndex = 60
    card.Parent = Sidebar

    applyShadow(card, 18)

    local inner = Instance.new("Frame")
    inner.BackgroundTransparency = 1
    inner.Size = UDim2.new(1,-16,1,-16)
    inner.Position = UDim2.new(0,8,0,8)
    inner.Parent = card

    local hlist = Instance.new("UIListLayout")
    hlist.FillDirection = Enum.FillDirection.Horizontal
    hlist.HorizontalAlignment = Enum.HorizontalAlignment.Left
    hlist.VerticalAlignment = Enum.VerticalAlignment.Center
    hlist.Padding = UDim.new(0,10)
    hlist.Parent = inner

    local icon = Instance.new("ImageLabel")
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(0,36,0,36)
    icon.Image = ("http://www.roblox.com/asset/?id=%d"):format(iconId)
    icon.ImageColor3 = FG_MUTED
    icon.Parent = inner

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Gotham
    label.Text = titleText
    label.TextColor3 = FG_MUTED
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextSize = 18
    label.Size = UDim2.new(1,-46,1,0)
    label.Parent = inner

    local hover = makeStrokeGradient(card, 1)
    roundCorner(card, 12)

    local selected = false
    local function setSelected(on)
        selected = on
        TweenService:Create(label, TweenInfo.new(0.15), {TextColor3 = on and FG_TEXT or FG_MUTED}):Play()
        TweenService:Create(icon, TweenInfo.new(0.15), {ImageColor3 = on and FG_TEXT or FG_MUTED}):Play()
        TweenService:Create(hover, TweenInfo.new(0.2), {BackgroundTransparency = on and 0.6 or 1}):Play()
    end
    card.MouseEnter:Connect(function()
        if not selected then TweenService:Create(hover, TweenInfo.new(0.2), {BackgroundTransparency = 0.8}):Play() end
    end)
    card.MouseLeave:Connect(function()
        if not selected then TweenService:Create(hover, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play() end
    end)

    return card, setSelected, label
end

-- Subtab button list
local SubtabHolder = Instance.new("Frame")
SubtabHolder.Size = UDim2.new(1,0,0,56)
SubtabHolder.BackgroundTransparency = 1
SubtabHolder.Parent = Sidebar

local SubtabList = Instance.new("UIListLayout")
SubtabList.Padding = UDim.new(0,8)
SubtabList.Parent = SubtabHolder

local function subButton(text, iconId)
    local b = Instance.new("ImageButton")
    b.BackgroundTransparency = 1
    b.AutoButtonColor = false
    b.Image = "rbxassetid://7890831727"
    b.ImageColor3 = BG_MID
    b.ScaleType = Enum.ScaleType.Slice
    b.SliceCenter = Rect.new(512,512,512,512)
    b.SliceScale = 0.003
    b.Size = UDim2.new(1,0,0,40)
    b.Parent = SubtabHolder

    applyShadow(b, 14)
    roundCorner(b, 10)

    local icon = Instance.new("ImageLabel")
    icon.BackgroundTransparency = 1
    icon.Image = ("http://www.roblox.com/asset/?id=%d"):format(iconId)
    icon.ImageColor3 = FG_MUTED
    icon.Size = UDim2.new(0,20,0,20)
    icon.Position = UDim2.new(0,10,0.5,-10)
    icon.Parent = b

    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.Gotham
    t.Text = text
    t.TextColor3 = FG_MUTED
    t.TextSize = 16
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Size = UDim2.new(1,-40,1,0)
    t.Position = UDim2.new(0,40,0,0)
    t.Parent = b

    local hover = makeStrokeGradient(b, 1)

    local selected = false
    local function setSel(on)
        selected = on
        TweenService:Create(t, TweenInfo.new(0.15), {TextColor3 = on and FG_TEXT or FG_MUTED}):Play()
        TweenService:Create(icon, TweenInfo.new(0.15), {ImageColor3 = on and FG_TEXT or FG_MUTED}):Play()
        TweenService:Create(hover, TweenInfo.new(0.2), {BackgroundTransparency = on and 0.6 or 1}):Play()
    end

    b.MouseEnter:Connect(function()
        if not selected then TweenService:Create(hover, TweenInfo.new(0.2), {BackgroundTransparency = 0.85}):Play() end
    end)
    b.MouseLeave:Connect(function()
        if not selected then TweenService:Create(hover, TweenInfo.new(0.2), {BackgroundTransparency = 1}):Play() end
    end)

    return b, setSel
end

local MainCard, setMainSelected = sidebarCard("Main", 8395621517)
SubtabHolder.LayoutOrder = 2
local CombatBtn, setCombatSelected = subButton("Combat", 8395747586)

-- Content Area
local Content = Instance.new("Frame")
Content.Name = "Content"
Content.Size = UDim2.new(1, -244, 1, -24)
Content.Position = UDim2.new(0, 236, 0, 12)
Content.BackgroundTransparency = 1
Content.Parent = Main

-- Section Panel
local Section = Instance.new("ImageLabel")
Section.Name = "SectionCard"
Section.BackgroundTransparency = 1
Section.Image = "rbxassetid://7890925834"
Section.ImageColor3 = BG_MID
Section.ScaleType = Enum.ScaleType.Slice
Section.SliceCenter = Rect.new(512,512,512,512)
Section.SliceScale = 0.003
Section.Size = UDim2.new(1, -16, 1, -16)
Section.Position = UDim2.new(0, 8, 0, 8)
Section.Parent = Content
roundCorner(Section, 12)
applyShadow(Section, 24)
local sectionHover = makeStrokeGradient(Section, 1)

local SectionTitle = Instance.new("TextLabel")
SectionTitle.BackgroundTransparency = 1
SectionTitle.Font = Enum.Font.Gotham
SectionTitle.Text = "Section"
SectionTitle.TextSize = 18
SectionTitle.TextColor3 = FG_TEXT
SectionTitle.TextXAlignment = Enum.TextXAlignment.Left
SectionTitle.Size = UDim2.new(1,-20,0,30)
SectionTitle.Position = UDim2.new(0,10,0,10)
SectionTitle.Parent = Section

local SectionInner = Instance.new("Frame")
SectionInner.BackgroundTransparency = 1
SectionInner.Size = UDim2.new(1,-20,1,-50)
SectionInner.Position = UDim2.new(0,10,0,40)
SectionInner.Parent = Section

local SectionList = Instance.new("UIListLayout")
SectionList.Padding = UDim.new(0,10)
SectionList.SortOrder = Enum.SortOrder.LayoutOrder
SectionList.Parent = SectionInner

-- Mini UI constructors -------------------------------------------------
local UI = {}

function UI.LabelWithDesc(parent, title, desc)
    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(1,0,0,40)
    holder.Parent = parent

    local titleLbl = Instance.new("TextLabel")
    titleLbl.BackgroundTransparency = 1
    titleLbl.Font = Enum.Font.GothamSemibold
    titleLbl.Text = title or "Title"
    titleLbl.TextSize = 16
    titleLbl.TextColor3 = FG_TEXT
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Size = UDim2.new(0.5,0,0,20)
    titleLbl.Parent = holder

    local descLbl = Instance.new("TextLabel")
    descLbl.BackgroundTransparency = 1
    descLbl.Font = Enum.Font.Gotham
    descLbl.Text = desc or ""
    descLbl.TextSize = 12
    descLbl.TextColor3 = FG_MUTED
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.Position = UDim2.new(0,0,0,20)
    descLbl.Size = UDim2.new(0.6,0,0,18)
    descLbl.Parent = holder

    return holder, titleLbl, descLbl
end

function UI.BigButton(parent, text, callback)
    local btn = Instance.new("ImageButton")
    btn.BackgroundTransparency = 1
    btn.AutoButtonColor = false
    btn.Image = "rbxassetid://7890831727"
    btn.ImageColor3 = Color3.fromRGB(30,30,30)
    btn.ScaleType = Enum.ScaleType.Slice
    btn.SliceCenter = Rect.new(512,512,512,512)
    btn.SliceScale = 0.003
    btn.Size = UDim2.new(0,220,0,34)
    btn.Position = UDim2.new(0,0,0,3)
    btn.Parent = parent

    roundCorner(btn, 10)
    applyShadow(btn, 16)
    local hover = makeStrokeGradient(btn, 1)

    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamSemibold
    t.Text = text or "BUTTON"
    t.TextSize = 14
    t.TextColor3 = FG_MUTED
    t.Size = UDim2.new(1,0,1,0)
    t.Parent = btn

    btn.MouseEnter:Connect(function() TweenService:Create(hover, TweenInfo.new(0.15), {BackgroundTransparency = 0.8}):Play() end)
    btn.MouseLeave:Connect(function() TweenService:Create(hover, TweenInfo.new(0.15), {BackgroundTransparency = 1}):Play() end)
    btn.MouseButton1Click:Connect(function() if callback then callback(true) end end)
    return btn
end

function UI.Toggle(parent, default, callback)
    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(0,50,0,26)
    holder.Position = UDim2.new(0,0,0,6)
    holder.Parent = parent

    local bg = Instance.new("Frame")
    bg.BackgroundColor3 = Color3.fromRGB(30,30,30)
    bg.BorderSizePixel = 0
    bg.Size = UDim2.new(1,0,1,0)
    bg.Parent = holder
    roundCorner(bg, 12)
    applyShadow(bg, 14)

    local knob = Instance.new("Frame")
    knob.BackgroundColor3 = Color3.fromRGB(255,255,255)
    knob.Size = UDim2.new(0.5, -4, 1, -4)
    knob.Position = UDim2.new(0,2,0,2)
    knob.Parent = bg
    roundCorner(knob, 12)

    local state = default and true or false
    local function render()
        TweenService:Create(knob, TweenInfo.new(0.15), {Position = state and UDim2.new(0.5,2,0,2) or UDim2.new(0,2,0,2), BackgroundColor3 = state and ACCENT or Color3.fromRGB(200,200,200)}):Play()
        TweenService:Create(bg, TweenInfo.new(0.15), {BackgroundColor3 = state and Color3.fromRGB(35,35,35) or Color3.fromRGB(30,30,30)}):Play()
    end
    render()

    bg.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            state = not state
            render()
            if callback then callback(state) end
        end
    end)

    return {
        Set = function(v) state = v; render() end,
        Get = function() return state end
    }
end

function UI.Slider(parent, min, max, default, onChange)
    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(1,0,0,30)
    holder.Parent = parent

    local bar = Instance.new("Frame")
    bar.BackgroundColor3 = Color3.fromRGB(30,30,30)
    bar.BorderSizePixel = 0
    bar.Size = UDim2.new(0.7,0,0,8)
    bar.Position = UDim2.new(0,0,0.5,-4)
    bar.Parent = holder
    roundCorner(bar, 8)

    local fill = Instance.new("Frame")
    fill.BackgroundColor3 = Color3.fromRGB(255,255,255)
    fill.BorderSizePixel = 0
    fill.Size = UDim2.new(0,0,1,0)
    fill.Parent = bar
    roundCorner(fill, 8)

    local valueBox = Instance.new("TextLabel")
    valueBox.BackgroundTransparency = 1
    valueBox.Font = Enum.Font.GothamSemibold
    valueBox.TextSize = 14
    valueBox.TextColor3 = FG_MUTED
    valueBox.Size = UDim2.new(0.25,0,1,0)
    valueBox.Position = UDim2.new(0.72,10,0,0)
    valueBox.Parent = holder

    min, max = min or 0, max or 100
    local val = math.clamp(default or min, min, max)

    local function set(v)
        val = math.clamp(v, min, max)
        local alpha = (val - min)/(max-min)
        fill.Size = UDim2.new(alpha,0,1,0)
        valueBox.Text = tostring(math.floor(val))
        if onChange then onChange(val) end
    end
    set(val)

    local dragging = false
    bar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            local x = (input.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X
            set(min + (max-min)*x)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local x = math.clamp((input.Position.X - bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
            set(min + (max-min)*x)
        end
    end)

    return {Set=set, Get=function() return val end}
end

function UI.ColorPickerMini(parent, default, onChange)
    local holder = Instance.new("Frame")
    holder.BackgroundTransparency = 1
    holder.Size = UDim2.new(1,0,0,26)
    holder.Parent = parent

    local swatch = Instance.new("ImageButton")
    swatch.BackgroundTransparency = 1
    swatch.Image = "rbxassetid://7881709447"
    swatch.ScaleType = Enum.ScaleType.Slice
    swatch.SliceCenter = Rect.new(512,512,512,512)
    swatch.SliceScale = 0.005
    swatch.ImageColor3 = BG_MID
    swatch.Size = UDim2.new(0,32,0,20)
    swatch.Position = UDim2.new(0,0,0,3)
    swatch.ZIndex = 100
    swatch.Parent = holder
    roundCorner(swatch, 8)
    applyShadow(swatch, 14)

    local preview = Instance.new("Frame")
    preview.Size = UDim2.new(1,-6,1,-6)
    preview.Position = UDim2.new(0,3,0,3)
    preview.BorderSizePixel = 0
    preview.Parent = swatch
    roundCorner(preview, 6)

    local clr = default or Color3.fromRGB(255,0,0)
    preview.BackgroundColor3 = clr

    -- simple tri-slider popup
    local popup = Instance.new("Frame")
    popup.Visible = false
    popup.BackgroundColor3 = BG_MID
    popup.Size = UDim2.new(0,180,0,110)
    popup.Position = UDim2.new(0,40,0,-40)
    popup.BorderSizePixel = 0
    popup.Parent = holder
    popup.ZIndex = 500
    roundCorner(popup, 10)
    applyShadow(popup, 20)

    local vlist = Instance.new("UIListLayout")
    vlist.Padding = UDim.new(0,6)
    vlist.Parent = popup

    local function makeChan(name, init)
        local row = Instance.new("Frame")
        row.BackgroundTransparency = 1
        row.Size = UDim2.new(1,-10,0,26)
        row.Parent = popup

        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.Font = Enum.Font.Gotham
        label.Text = name
        label.TextSize = 12
        label.TextColor3 = FG_TEXT
        label.Position = UDim2.new(0,6,0,0)
        label.Size = UDim2.new(0,24,1,0)
        label.Parent = row

        local slider = UI.Slider(row, 0, 255, init, nil)
        slider.Set(init)
        return slider
    end

    local r = math.floor(clr.R*255)
    local g = math.floor(clr.G*255)
    local b = math.floor(clr.B*255)

    local sr = makeChan("R", r)
    local sg = makeChan("G", g)
    local sb = makeChan("B", b)

    local function apply()
        local c = Color3.fromRGB(sr.Get(), sg.Get(), sb.Get())
        preview.BackgroundColor3 = c
        if onChange then onChange(c) end
    end

    swatch.MouseButton1Click:Connect(function()
        popup.Visible = not popup.Visible
    end)

    -- watch sliders
    local last = tick()
    RunService.Heartbeat:Connect(function()
        if popup.Visible then
            if tick() - last > 0.05 then
                last = tick()
                apply()
            end
        end
    end)

    return {
        Set=function(c) clr=c; preview.BackgroundColor3=c; end,
        Get=function() return preview.BackgroundColor3 end
    }
end

function UI.TextBox(parent, placeholder, onCommit)
    local bg = Instance.new("ImageLabel")
    bg.BackgroundTransparency = 1
    bg.Image = "rbxassetid://7881709447"
    bg.ImageColor3 = BG_MID
    bg.ScaleType = Enum.ScaleType.Slice
    bg.SliceCenter = Rect.new(512,512,512,512)
    bg.SliceScale = 0.005
    bg.Size = UDim2.new(0,160,0,26)
    bg.Parent = parent
    roundCorner(bg, 8)
    applyShadow(bg, 14)

    local tb = Instance.new("TextBox")
    tb.BackgroundTransparency = 1
    tb.ClearTextOnFocus = false
    tb.Font = Enum.Font.GothamSemibold
    tb.Text = ""
    tb.PlaceholderText = placeholder or ""
    tb.TextSize = 14
    tb.TextColor3 = FG_MUTED
    tb.Size = UDim2.new(1,-12,1,0)
    tb.Position = UDim2.new(0,6,0,0)
    tb.Parent = bg

    tb.FocusLost:Connect(function(enter)
        if onCommit then onCommit(tb.Text) end
    end)
    return tb
end

function UI.KeybindBox(parent, defaultKeyCode, onBind)
    local bg = Instance.new("ImageLabel")
    bg.BackgroundTransparency = 1
    bg.Image = "rbxassetid://7890925834"
    bg.ImageColor3 = BG_MID
    bg.ScaleType = Enum.ScaleType.Slice
    bg.SliceCenter = Rect.new(512,512,512,512)
    bg.SliceScale = 0.003
    bg.Size = UDim2.new(0,40,0,26)
    bg.Parent = parent
    roundCorner(bg, 8)
    applyShadow(bg, 14)

    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamSemibold
    t.TextSize = 14
    t.TextColor3 = FG_MUTED
    t.Size = UDim2.new(1,0,1,0)
    t.Parent = bg

    local binding = false
    local keycode = defaultKeyCode or Enum.KeyCode.Q
    t.Text = keycode.Name:sub(1,1)

    bg.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1 then
            binding = true
            t.Text = "…"
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if binding and input.UserInputType == Enum.UserInputType.Keyboard then
            binding = false
            keycode = input.KeyCode
            t.Text = keycode.Name:sub(1,1)
            if onBind then onBind(keycode) end
        end
    end)

    return {
        Get=function() return keycode end,
        Set=function(kc) keycode = kc; t.Text = kc.Name:sub(1,1) end
    }
end

-- BUILD CONTROLS IN ORDER (exact names)
-- 1) Kill All title + big KILL!! button + desc
do
    local row, _, _ = UI.LabelWithDesc(SectionInner, "Kill All", "kills everyone")
    local btn = UI.BigButton(row, "KILL!!", function(v) print("[Button:Kill All]", v) end)
    btn.Position = UDim2.new(0,0,0,3)
end

-- 2) Toggle: Auto Farm
do
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1,0,0,40)
    row.Parent = SectionInner

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamSemibold
    title.Text = "Auto Farm"
    title.TextSize = 16
    title.TextColor3 = FG_TEXT
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Size = UDim2.new(0.5,0,0,20)
    title.Parent = row

    local desc = Instance.new("TextLabel")
    desc.BackgroundTransparency = 1
    desc.Font = Enum.Font.Gotham
    desc.Text = "Optional Description here"
    desc.TextSize = 12
    desc.TextColor3 = FG_MUTED
    desc.TextXAlignment = Enum.TextXAlignment.Left
    desc.Position = UDim2.new(0,0,0,20)
    desc.Size = UDim2.new(0.6,0,0,18)
    desc.Parent = row

    local tog = UI.Toggle(row, false, function(state)
        print("[Toggle:Auto Farm]", state)
    end)
end

-- 3) Slider: Walkspeed 0..120 default 16 with value box
do
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1,0,0,40)
    row.Parent = SectionInner

    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamSemibold
    t.Text = "Walkspeed"
    t.TextColor3 = FG_TEXT
    t.TextSize = 16
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Size = UDim2.new(1,0,0,18)
    t.Parent = row

    UI.Slider(row, 0, 120, 16, function(v)
        print("[Slider:Walkspeed]", v)
    end)
end

-- 4) ColorPicker: default red with preview small square
do
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1,0,0,40)
    row.Parent = SectionInner

    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamSemibold
    t.Text = "Colorpicker"
    t.TextColor3 = FG_TEXT
    t.TextSize = 16
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Size = UDim2.new(1,0,0,18)
    t.Parent = row

    UI.ColorPickerMini(row, Color3.fromRGB(255,0,0), function(c)
        print("[ColorPicker]", c)
    end)
end

-- 5) Textbox: Damage / Damage Multiplier (empty)
do
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1,0,0,40)
    row.Parent = SectionInner

    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamSemibold
    t.Text = "Damage"
    t.TextColor3 = FG_TEXT
    t.TextSize = 16
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Size = UDim2.new(1,0,0,18)
    t.Parent = row

    UI.TextBox(row, "", function(text)
        print("[Textbox:Damage]", text)
    end)
end

-- 6) Keybind: Kill All default Q, show Q in box
do
    local row = Instance.new("Frame")
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1,0,0,40)
    row.Parent = SectionInner

    local t = Instance.new("TextLabel")
    t.BackgroundTransparency = 1
    t.Font = Enum.Font.GothamSemibold
    t.Text = "Kill All"
    t.TextColor3 = FG_TEXT
    t.TextSize = 16
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Size = UDim2.new(1,0,0,18)
    t.Parent = row

    local kb = UI.KeybindBox(row, Enum.KeyCode.Q, function(kc)
        print("[Keybind:Kill All]", kc.Name)
    end)

    -- Example: listen to bound key (prints only)
    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == (kb.Get()) then
            print("[Keybind Pressed] Kill All")
        end
    end)
end

-- Selection logic for tabs
local function activateMain()
    setMainSelected(true)
    setCombatSelected(true) -- only one subtab exists now
end
MainCard.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then activateMain() end end)
CombatBtn.MouseButton1Click:Connect(function() activateMain() end)
activateMain()

-- Global show/hide toggle (RightShift)
local visible = true
local function setVisible(v)
    visible = v
    Main.Visible = visible
end
UserInputService.InputBegan:Connect(function(inp, gp)
    if gp then return end
    if inp.KeyCode == Enum.KeyCode.RightShift then
        setVisible(not visible)
    end
end)
