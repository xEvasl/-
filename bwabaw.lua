--[[
Universal RotUp! Premium (single source for both server & client)
Paste THIS SAME code as:
  • Script      -> ServerScriptService
  • LocalScript -> StarterPlayer/StarterPlayerScripts
No external modules. Server-side cloning for full parity with placement.
]]

-- ========= SETTINGS (shared) =========
local SETTINGS = {
    DELETE_ALL_CLONES = false, -- true => Delete removes all clones
    TOAST_DURATION    = 2.0,   -- sec
}

-- ========= SERVICES =========
local RunService          = game:GetService("RunService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local CollectionService   = game:GetService("CollectionService")

-- ========= Shared helpers =========
local function copyAttributes(fromInstance, toInstance)
    local ok, attrs = pcall(function() return fromInstance:GetAttributes() end)
    if ok and attrs then
        for k, v in pairs(attrs) do pcall(function() toInstance:SetAttribute(k, v) end) end
    end
end

local function tagCopy(fromInstance, toInstance)
    local ok, tags = pcall(function() return CollectionService:GetTags(fromInstance) end)
    if ok and tags then
        for _, tag in ipairs(tags) do pcall(function() CollectionService:AddTag(toInstance, tag) end) end
    end
end

local function deepCloneWithAttributesAndTags(source)
    local clone = source:Clone()
    local function listWithSelf(root)
        local t = {root}
        for _, d in ipairs(root:GetDescendants()) do table.insert(t, d) end
        return t
    end
    local src = listWithSelf(source)
    local dst = listWithSelf(clone)
    for i = 1, math.min(#src, #dst) do
        local s, d = src[i], dst[i]
        copyAttributes(s, d)
        tagCopy(s, d)
        if s:IsA("BasePart") and d:IsA("BasePart") then
            pcall(function()
                d.Anchored     = s.Anchored
                d.CanCollide   = s.CanCollide
                d.Material     = s.Material
                d.Color        = s.Color
                d.Transparency = s.Transparency
                d.Reflectance  = s.Reflectance
            end)
        end
        if s:IsA("Tool") and d:IsA("Tool") then
            pcall(function()
                d.ToolTip        = s.ToolTip
                d.RequiresHandle = s.RequiresHandle
                d.CanBeDropped   = s.CanBeDropped
                d.Grip           = s.Grip
            end)
        end
    end
    return clone
end

local function wrapModelInTool(modelClone)
    local tool = Instance.new("Tool")
    tool.Name = modelClone.Name
    tool.RequiresHandle = false
    tool.CanBeDropped   = true
    copyAttributes(modelClone, tool)
    tagCopy(modelClone, tool)
    modelClone.Parent = tool
    return tool
end

-- ======================
-- ===== SERVER SIDE ====
-- ======================
if RunService:IsServer() then
    -- Create remotes (once)
    local folder = ReplicatedStorage:FindFirstChild("RotUp_Remotes")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "RotUp_Remotes"
        folder.Parent = ReplicatedStorage
    end

    local REQ_DUPLICATE = folder:FindFirstChild("RequestDuplicate") or Instance.new("RemoteEvent")
    REQ_DUPLICATE.Name = "RequestDuplicate"; REQ_DUPLICATE.Parent = folder

    local REQ_DELETE = folder:FindFirstChild("RequestDelete") or Instance.new("RemoteEvent")
    REQ_DELETE.Name = "RequestDelete"; REQ_DELETE.Parent = folder

    local function getEquippedToolServer(char)
        if not char then return nil end
        for _, inst in ipairs(char:GetChildren()) do
            if inst:IsA("Tool") then return inst end
        end
        return nil
    end

    local function ensureHandle(tool)
        if not tool:IsA("Tool") then return end
        if not tool.RequiresHandle then return end
        if tool:FindFirstChild("Handle") then return end
        local candidate
        for _, d in ipairs(tool:GetDescendants()) do
            if d:IsA("BasePart") then candidate = d; break end
        end
        if candidate then
            candidate.Name = "Handle"
        end
    end

    local function findClonesServer(player)
        local t = {}
        local backpack = player:FindFirstChild("Backpack")
        if backpack then
            for _, inst in ipairs(backpack:GetChildren()) do
                if inst:IsA("Tool") and inst:GetAttribute("IsClone")==true then table.insert(t, inst) end
            end
        end
        local char = player.Character
        if char then
            for _, inst in ipairs(char:GetChildren()) do
                if inst:IsA("Tool") and inst:GetAttribute("IsClone")==true then table.insert(t, inst) end
            end
        end
        table.sort(t, function(a,b)
            local ta = tonumber(a:GetAttribute("CloneTimestamp")) or 0
            local tb = tonumber(b:GetAttribute("CloneTimestamp")) or 0
            return ta < tb
        end)
        return t
    end

    -- Server-side duplicate (full parity)
    REQ_DUPLICATE.OnServerEvent:Connect(function(player, equippedRef)
        local char = player.Character
        if not char then return end

        -- Validate equipped on SERVER
        local equipped
        if typeof(equippedRef) == "Instance" and equippedRef:IsDescendantOf(char) and equippedRef:IsA("Tool") then
            equipped = equippedRef
        else
            equipped = getEquippedToolServer(char)
        end
        if not equipped then return end

        local cloneRoot
        if equipped:IsA("Tool") then
            cloneRoot = deepCloneWithAttributesAndTags(equipped)
        else
            cloneRoot = wrapModelInTool(deepCloneWithAttributesAndTags(equipped))
        end

        cloneRoot:SetAttribute("IsClone", true)
        cloneRoot:SetAttribute("CloneTimestamp", os.clock())

        ensureHandle(cloneRoot)

        local backpack = player:FindFirstChild("Backpack")
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if backpack then
            cloneRoot.Parent = backpack
            if humanoid then
                humanoid:EquipTool(cloneRoot) -- equip on SERVER
