local Players = game:GetService("Players")
local player = Players.LocalPlayer

local function setClipboard(txt)
    if setclipboard then setclipboard(txt)
    elseif toclipboard then toclipboard(txt)
    else warn("Clipboard function not supported by this executor") end
end

local foundItems = {}

-- Helper to safely read table keys/values
local function scanTable(tbl)
    for k, v in pairs(tbl) do
        if typeof(k) == "string" then
            table.insert(foundItems, k)
        end
        if typeof(v) == "string" then
            table.insert(foundItems, v)
        elseif typeof(v) == "table" then
            scanTable(v)
        end
    end
end

-- Recursively search any Instance for "Weapons"
local function deepSearch(obj)
    if obj.Name == "Weapons" then
        print("Found Weapons at:", obj:GetFullName())
        -- If it's a folder/model, collect child names
        for _, child in ipairs(obj:GetChildren()) do
            table.insert(foundItems, child.Name)
        end
        -- If it's a value container, try reading it
        pcall(function()
            if typeof(obj) == "Instance" and obj.ClassName:find("Value") and typeof(obj.Value) == "table" then
                scanTable(obj.Value)
            end
        end)
    end
    -- Keep searching deeper
    for _, child in ipairs(obj:GetChildren()) do
        deepSearch(child)
    end
end

-- Scan all children of the player
deepSearch(player)

-- Also scan Player scripts/tables
for _, child in pairs(getgc(true)) do
    -- Some games store inventory in tables in memory
    if type(child) == "table" and rawget(child, "Weapons") then
        print("Found Weapons table in GC!")
        scanTable(child.Weapons)
    end
end

-- Remove duplicates
local unique = {}
for _, v in ipairs(foundItems) do
    unique[v] = true
end
local finalList = {}
for k in pairs(unique) do
    table.insert(finalList, k)
end
table.sort(finalList)

-- Output + copy
if #finalList > 0 then
    local text = table.concat(finalList, "\n")
    print("Weapons Found:\n" .. text)
    setClipboard(text)
else
    warn("No weapons found!")
end
