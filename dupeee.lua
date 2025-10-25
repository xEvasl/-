--// LocalScript — Client-side only
--// Minimal grey UI + Duplicate/Delete logic for equipped items in Roblox
--// No server calls. No DataStores. No E-key handling (compatibility only).

-- =========================
-- ======  SETTINGS  =======
-- =========================
local DELETE_ALL_CLONES = false   -- false = delete most recent clone only; true = delete all clones made by this script
local TOAST_DURATION = 2.0        -- seconds the toast stays visible

-- =========================
-- ======  SERVICES  =======
-- =========================
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LOCAL_PLAYER = Players.LocalPlayer

-- =========================
-- =======  UI  ============
-- =========================
-- Build UI programmatically (small, clean, grey theme; rounded corners; no images)
local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "CloneMenuUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.new(0, 280, 0, 60)
panel.Position = UDim2.new(0, 20, 1, -80) -- bottom-left-ish
panel.BackgroundColor3 = Color3.fromRGB(42, 42, 42)    -- dark grey
panel.BorderSizePixel = 0
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness = 1
panelStroke.Color = Color3.fromRGB(90, 90, 90)         -- subtle border
panelStroke.Transparency = 0.2
panelStroke.Parent = panel

-- Subtle shadow (achieved via semi-transparent container behind)
local shadow = Instance.new("Frame")
shadow.Name = "Shadow"
shadow.Size = panel.Size
shadow.Position = panel.Position + UDim2.new(0, 4, 0, 4)
shadow.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
shadow.BackgroundTransparency = 0.75
shadow.BorderSizePixel = 0
shadow.ZIndex = panel.ZIndex - 1
shadow.Parent = screenGui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 8)
layout.Parent = panel

local function makeButton(text)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 120, 0, 40)
    btn.BackgroundColor3 = Color3.fromRGB(70, 70, 70)   -- mid grey
    btn.TextColor3 = Color3.fromRGB(230, 230, 230)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 16
    btn.AutoButtonColor = true
    btn.Text = text

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = btn

    local s = Instance.new("UIStroke")
    s.Color = Color3.fromRGB(110, 110, 110)
    s.Thickness = 1
    s.Transparency = 0.15
    s.Parent = btn

    btn.Parent = panel
    return btn
end

local duplicateBtn = makeButton("Duplicate")
local deleteBtn = makeButton("Delete")

-- Tiny toast/label for gentle messages
local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.Size = UDim2.new(0, 260, 0, 26)
toast.Position = UDim2.new(0, 20, 1, -115)
toast.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
toast.TextColor3 = Color3.fromRGB(235, 235, 235)
toast.Font = Enum.Font.Gotham
toast.TextSize = 14
toast.TextWrapped = true
toast.Visible = false
toast.BorderSizePixel = 0
toast.Parent = screenGui
local toastCorner = Instance.new("UICorner", toast)
toastCorner.CornerRadius = UDim.new(0, 8)
local toastStroke = Instance.new("UIStroke", toast)
toastStroke.Color = Color3.fromRGB(100, 100, 100)
toastStroke.Thickness = 1
toastStroke.Transparency = 0.2

local function showToast(msg)
    toast.Text = msg
    toast.Visible = true
    toast.TextTransparency = 1
    toast.BackgroundTransparency = 1
    local tweenIn = TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Sine), {TextTransparency = 0, BackgroundTransparency = 0})
    tweenIn:Play()
    tweenIn.Completed:Wait()
    task.delay(TOAST_DURATION, function()
        if toast.Visible then
            local tweenOut = TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Sine), {TextTransparency = 1, BackgroundTransparency = 1})
            tweenOut:Play()
            tweenOut.Completed:Wait()
            toast.Visible = false
        end
    end)
end

-- =========================
-- ===  HELPER UTILS   =====
-- =========================

-- Safely get equipped Tool from Character (hotbar-equipped)
local function getEquippedTool()
    local char = LOCAL_PLAYER.Character
    if not char then return nil end
    -- Usually, an equipped item is a Tool parented to Character
    for _, inst in ipairs(char:GetChildren()) do
        if inst:IsA("Tool") then
            return inst
        end
    end
    return nil
end

-- Copy all attributes from 'fromInstance' to 'toInstance'
local function copyAttributes(fromInstance, toInstance)
    local ok, attrs = pcall(function() return fromInstance:GetAttributes() end)
    if ok and attrs then
        for k, v in pairs(attrs) do
            pcall(function()
                toInstance:SetAttribute(k, v)
            end)
        end
    end
end

-- Copy all CollectionService tags from 'fromInstance' to 'toInstance'
local function tagCopy(fromInstance, toInstance)
    local ok, tags = pcall(function() return CollectionService:GetTags(fromInstance) end)
    if ok and tags then
        for _, tag in ipairs(tags) do
            pcall(function()
                CollectionService:AddTag(toInstance, tag)
            end)
        end
    end
end

-- Deep clone an instance and ensure Attributes & Tags are copied for every corresponding descendant
local function deepCloneWithAttributesAndTags(source)
    -- Perform a raw Clone first (copies hierarchy & most properties)
    local clone = source:Clone()

    -- Build flat lists including self for 1:1 index mapping
    local function withSelfList(root)
        local list = {root}
        for _, d in ipairs(root:GetDescendants()) do
            table.insert(list, d)
        end
        return list
    end

    local srcList = withSelfList(source)
    local cloneList = withSelfList(clone)

    for i = 1, math.min(#srcList, #cloneList) do
        local src = srcList[i]
        local dst = cloneList[i]

        -- Attributes
        copyAttributes(src, dst)

        -- Tags
        tagCopy(src, dst)

        -- Ensure BasePart physics flags match exactly (usually already identical, but we enforce)
        if src:IsA("BasePart") and dst:IsA("BasePart") then
            pcall(function()
                dst.Anchored = src.Anchored
                dst.CanCollide = src.CanCollide
                dst.Material = src.Material
                dst.Color = src.Color
                dst.Transparency = src.Transparency
                dst.Reflectance = src.Reflectance
                if src:IsA("MeshPart") then
                    -- MeshId/TextureId/Size are already cloned; leave as-is
                end
            end)
        end

        -- If it's a Tool, keep important tool properties (already cloned, but we harden)
        if src:IsA("Tool") and dst:IsA("Tool") then
            pcall(function()
                dst.ToolTip = src.ToolTip
                dst.RequiresHandle = src.RequiresHandle
                dst.CanBeDropped = src.CanBeDropped
                dst.Grip = src.Grip
            end)
        end
    end

    return clone
end

-- Return an array of Tools in Backpack/Character that are marked as clones by this script
local function findClones()
    local results = {}
    local backpack = LOCAL_PLAYER:FindFirstChildOfClass("PlayerGui") and LOCAL_PLAYER:FindFirstChild("Backpack") or LOCAL_PLAYER:FindFirstChild("Backpack")
    backpack = LOCAL_PLAYER:FindFirstChild("Backpack") -- ensure backpack
    if backpack then
        for _, inst in ipairs(backpack:GetChildren()) do
            if inst:IsA("Tool") and inst:GetAttribute("IsClone") == true then
                table.insert(results, inst)
            end
        end
    end
    local char = LOCAL_PLAYER.Character
    if char then
        for _, inst in ipairs(char:GetChildren()) do
            if inst:IsA("Tool") and inst:GetAttribute("IsClone") == true then
                table.insert(results, inst)
            end
        end
    end
    -- Sort by CloneTimestamp (newest last)
    table.sort(results, function(a, b)
        local ta = tonumber(a:GetAttribute("CloneTimestamp")) or 0
        local tb = tonumber(b:GetAttribute("CloneTimestamp")) or 0
        return ta < tb
    end)
    return results
end

-- Delete the latest clone or all clones
local function deleteLatestClone()
    local clones = findClones()
    if #clones == 0 then
        showToast("No clones to delete.")
        return
    end

    if DELETE_ALL_CLONES then
        local count = 0
        for _, tool in ipairs(clones) do
            count += 1
            pcall(function() tool:Destroy() end)
        end
        showToast(("Deleted %d clone(s)."):format(count))
    else
        local latest = clones[#clones]
        pcall(function() latest:Destroy() end)
        showToast("Deleted latest clone.")
    end
end

-- Wrap a non-Tool item (e.g., Model with BaseParts) into a Tool so it behaves like a hotbar item
-- NOTE: Some games place Models directly; if your placement system expects a Tool, this wrapper keeps compatibility.
local function wrapModelInTool(modelClone)
    local tool = Instance.new("Tool")
    tool.Name = modelClone.Name
    tool.RequiresHandle = false        -- no Handle required; we place the model under the Tool
    tool.CanBeDropped = true           -- keep original behavior flexible
    -- copy attributes/tags from the model onto the wrapper too (so placement systems that key off the Tool still work)
    copyAttributes(modelClone, tool)
    tagCopy(modelClone, tool)

    -- parent the cloned model under the tool
    modelClone.Parent = tool

    -- If original model had a primary part, keep alignment behavior (informational; not strictly needed)
    pcall(function()
        if modelClone.PrimaryPart then
            tool.Grip = CFrame.new()
        end
    end)

    return tool
end

-- =========================
-- ===  CORE ACTIONS   =====
-- =========================

local function duplicateEquipped()
    local equipped = getEquippedTool()
    if not equipped then
        showToast("Equip an item first.")
        return
    end

    -- We must preserve class/children/attributes/tags so existing E-key placement accepts the clone as original.
    -- If the equipped item is a Tool, clone the Tool. If it's somehow a Model (edge case), wrap it in a Tool.
    local cloneRoot

    if equipped:IsA("Tool") then
        local toolClone = deepCloneWithAttributesAndTags(equipped)

        -- Mark this clone so we can safely delete only clones later
        toolClone:SetAttribute("IsClone", true)
        toolClone:SetAttribute("CloneTimestamp", os.clock())

        -- Final safety: ensure descendant BasePart physics flags match (non-anchored by default unless original was anchored)
        for _, part in ipairs(toolClone:GetDescendants()) do
            if part:IsA("BasePart") then
                -- Already aligned above in deepClone; kept here for clarity
                -- Do not force anchoring; placement system will manage anchoring on place.
            end
        end

        cloneRoot = toolClone
    else
        -- Edge case: If the equipped instance isn't a Tool (rare on live games), try to treat it as a Model
        -- This keeps the hotbar workflow by wrapping the cloned Model into a Tool wrapper.
        local modelClone = deepCloneWithAttributesAndTags(equipped)
        cloneRoot = wrapModelInTool(modelClone)
        cloneRoot:SetAttribute("IsClone", true)
        cloneRoot:SetAttribute("CloneTimestamp", os.clock())
    end

    -- Parent to Backpack so it appears in hotbar
    local backpack = LOCAL_PLAYER:WaitForChild("Backpack")
    cloneRoot.Parent = backpack

    showToast("Cloned to hotbar.")
end

-- =========================
-- ===  WIRE  EVENTS   =====
-- =========================
duplicateBtn.MouseButton1Click:Connect(function()
    duplicateEquipped()
end)

deleteBtn.MouseButton1Click:Connect(function()
    deleteLatestClone()
end)

-- Optional: keep shadow synced if resolution changes (simple)
RunService.RenderStepped:Connect(function()
    if shadow and panel then
        shadow.Position = panel.Position + UDim2.new(0, 4, 0, 4)
        shadow.Size = panel.Size
    end
end)
