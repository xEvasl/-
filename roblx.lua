-- Roblox UI Mock "Section" Panel (placeholders only)
-- Put this as a LocalScript under StarterGui

local Players = game:GetService("Players")
local player = Players.LocalPlayer

-- Root
local gui = Instance.new("ScreenGui")
gui.Name = "DemoUI"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Helpers
local function round(num, dec) dec = dec or 0 return math.floor(num*10^dec+0.5)/10^dec end
local function mk(inst, props, parent)
    local o = Instance.new(inst)
    for k,v in pairs(props or {}) do o[k]=v end
    if parent then o.Parent = parent end
    return o
end

-- Center container
local container = mk("Frame", {
    Size = UDim2.fromOffset(260, 240),
    Position = UDim2.new(0.5, -130, 0.5, -120),
    BackgroundColor3 = Color3.fromRGB(24,24,24)
}, gui)
mk("UICorner", {CornerRadius = UDim.new(0,10)}, container)
mk("UIStroke", {Thickness = 1, Color = Color3.fromRGB(40,40,40)}, container)
mk("UIPadding", {PaddingTop=UDim.new(0,10),PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12),PaddingBottom=UDim.new(0,10)}, container)

-- Title
local title = mk("TextLabel", {
    Size = UDim2.new(1,0,0,18),
    BackgroundTransparency = 1,
    Text = "Section",
    TextColor3 = Color3.fromRGB(170,170,170),
    Font = Enum.Font.GothamBold,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left
}, container)

-- List layout for rows
local list = mk("UIListLayout", {
    Padding = UDim.new(0,8),
    SortOrder = Enum.SortOrder.LayoutOrder
}, container)
list.Parent = container
title.LayoutOrder = 0

-- Row helper
local function row(height)
    local r = mk("Frame", {
        Size = UDim2.new(1,0,0,height or 26),
        BackgroundTransparency = 1
    }, container)
    r.LayoutOrder = (#container:GetChildren())
    return r
end

local function leftLabel(text, parent)
    return mk("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(0.6,0,1,0),
        Text = text,
        TextColor3 = Color3.fromRGB(230,230,230),
        Font = Enum.Font.Gotham,
        TextSize = 14,
        TextXAlignment = Enum.TextXAlignment.Left
    }, parent)
end

-- 1) Kill All + button KILL!!
do
    local r = row(30)
    leftLabel("Kill All\nkills everyone", r).TextXAlignment = Enum.TextXAlignment.Left
    local btn = mk("TextButton", {
        Size = UDim2.new(0,88,1,0),
        Position = UDim2.new(1,-88,0,0),
        BackgroundColor3 = Color3.fromRGB(45,45,45),
        Text = "KILL!!",
        TextColor3 = Color3.fromRGB(220,220,220),
        Font = Enum.Font.GothamBold,
        TextSize = 14
    }, r)
    mk("UICorner", {CornerRadius = UDim.new(0,6)}, btn)
    btn.MouseButton1Click:Connect(function()
        print("[UI] KILL!! clicked (placeholder)")
    end)
end

-- 2) Auto Farm toggle
local function makeToggle(parent, default)
    local togg = mk("Frame", {
        Size = UDim2.fromOffset(40,20),
        Position = UDim2.new(1,-40,0.5,-10),
        BackgroundColor3 = default and Color3.fromRGB(0,170,120) or Color3.fromRGB(60,60,60)
    }, parent)
    mk("UICorner", {CornerRadius = UDim.new(1,0)}, togg)
    local knob = mk("Frame", {
        Size = UDim2.fromOffset(18,18),
        Position = default and UDim2.new(1,-19,0.5,-9) or UDim2.new(0,1,0.5,-9),
        BackgroundColor3 = Color3.fromRGB(245,245,245)
    }, togg)
    mk("UICorner", {CornerRadius = UDim.new(1,0)}, knob)
    local state = default or false
    togg.InputBegan:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 then
            state = not state
            togg.BackgroundColor3 = state and Color3.fromRGB(0,170,120) or Color3.fromRGB(60,60,60)
            knob:TweenPosition(state and UDim2.new(1,-19,0.5,-9) or UDim2.new(0,1,0.5,-9), "Out", "Quad", 0.15, true)
            print("[UI] Toggle changed to", state)
        end
    end)
    return togg
end

do
    local r = row(28)
    local l = leftLabel("Auto Farm\nOptional Description here", r)
    l.TextColor3 = Color3.fromRGB(200,200,200)
    makeToggle(r, false)
end

-- 3) Walkspeed slider (8..32, default 16)
local function makeSlider(parent, minV, maxV, startV)
    local track = mk("Frame", {
        Size = UDim2.new(0.6,0,0,6),
        Position = UDim2.new(0,0,0.5,-3),
        BackgroundColor3 = Color3.fromRGB(60,60,60)
    }, parent)
    mk("UICorner", {CornerRadius = UDim.new(0,3)}, track)

    local fill = mk("Frame", {
        Size = UDim2.new(0,0,1,0),
        BackgroundColor3 = Color3.fromRGB(120,120,120)
    }, track)
    mk("UICorner", {CornerRadius = UDim.new(0,3)}, fill)

    local knob = mk("Frame", {
        Size = UDim2.fromOffset(10,14),
        BackgroundColor3 = Color3.fromRGB(200,200,200),
        Position = UDim2.new(0,0,-0.33,0)
    }, track)
    mk("UICorner", {CornerRadius = UDim.new(0,2)}, knob)

    local valBox = mk("TextLabel", {
        Size = UDim2.new(0,40,1,0),
        Position = UDim2.new(1,-40,0,0),
        BackgroundColor3 = Color3.fromRGB(40,40,40),
        Text = tostring(startV),
        TextColor3 = Color3.fromRGB(230,230,230),
        Font = Enum.Font.Gotham,
        TextSize = 14
    }, parent)
    mk("UICorner", {CornerRadius = UDim.new(0,4)}, valBox)

    local dragging = false
    local function setValue(v)
        v = math.clamp(v, minV, maxV)
        local alpha = (v - minV) / (maxV - minV)
        fill.Size = UDim2.new(alpha,0,1,0)
        knob.Position = UDim2.new(alpha, -5, -0.33, 0)
        valBox.Text = tostring(round(v,0))
        return v
    end
    setValue(startV)

    track.InputBegan:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            local rel = (io.Position.X - track.AbsolutePosition.X)/track.AbsoluteSize.X
            setValue(minV + (maxV-minV)*rel)
        end
    end)
    track.InputEnded:Connect(function(io)
        if io.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
            print("[UI] Walkspeed =", valBox.Text)
        end
    end)
    game:GetService("UserInputService").InputChanged:Connect(function(io)
        if dragging and io.UserInputType == Enum.UserInputType.MouseMovement then
            local mx = io.Position.X
            local rel = (mx - track.AbsolutePosition.X)/track.AbsoluteSize.X
            setValue(minV + (maxV-minV)*rel)
        end
    end)
end

do
    local r = row(28)
    leftLabel("Walkspeed", r)
    makeSlider(r, 8, 32, 16)
end

-- 4) Colorpicker (cycle colors)
do
    local r = row(28)
    leftLabel("Colorpicker", r)
    local colorBtn = mk("TextButton", {
        Size = UDim2.new(0,24,0,18),
        Position = UDim2.new(1,-24,0.5,-9),
        BackgroundColor3 = Color3.fromRGB(220,35,35),
        Text = ""
    }, r)
    mk("UICorner", {CornerRadius = UDim.new(0,3)}, colorBtn)
    local colors = {Color3.fromRGB(220,35,35), Color3.fromRGB(40,200,90), Color3.fromRGB(35,100,230)}
    local idx = 1
    colorBtn.MouseButton1Click:Connect(function()
        idx = idx % #colors + 1
        colorBtn.BackgroundColor3 = colors[idx]
        print("[UI] Colorpicker changed", idx)
    end)
end

-- 5) Damage checkbox
local function makeCheckbox(parent)
    local box = mk("TextButton", {
        Size = UDim2.fromOffset(20,20),
        Position = UDim2.new(1,-22,0.5,-10),
        BackgroundColor3 = Color3.fromRGB(45,45,45),
        Text = ""
    }, parent)
    mk("UICorner", {CornerRadius = UDim.new(0,3)}, box)
    local mark = mk("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.new(1,0,1,0),
        Text = "",
        TextColor3 = Color3.fromRGB(240,240,240),
        Font = Enum.Font.GothamBlack,
        TextSize = 16
    }, box)
    local checked = false
    box.MouseButton1Click:Connect(function()
        checked = not checked
        mark.Text = checked and "✓" or ""
        print("[UI] Damage checkbox =", checked)
    end)
end

do
    local r = row(28)
    leftLabel("Damage", r)
    makeCheckbox(r)
end

-- 6) Kill All hotkey label [Q]
do
    local r = row(28)
    leftLabel("Kill All", r)
    local keyBox = mk("TextLabel", {
        Size = UDim2.new(0,24,0,18),
        Position = UDim2.new(1,-24,0.5,-9),
        BackgroundColor3 = Color3.fromRGB(45,45,45),
        Text = "Q",
        TextColor3 = Color3.fromRGB(220,220,220),
        Font = Enum.Font.GothamBold,
        TextSize = 14
    }, r)
    mk("UICorner", {CornerRadius = UDim.new(0,3)}, keyBox)
end

print("[UI] Loaded mock menu (placeholders only)")
