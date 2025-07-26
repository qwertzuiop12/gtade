-- Auto-Trade Bot for "Roqate" - Full Dynamic Item Adding
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Config
local TARGET_PLAYER = "Roqate"
local MAX_ITEMS_PER_TRADE = 4
local TRADE_COOLDOWN = 5 -- Seconds between trades
local ITEM_ADD_DELAY = 0.3 -- Delay between adding items

-- Remotes
local TradeRemotes = {
    SendRequest = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("SendRequest"),
    OfferItem = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("OfferItem"),
    AcceptTrade = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("AcceptTrade")
}

-- Trade state
local isTrading = false
local lastTradeTime = 0

-- Find player by name
local function findPlayer(name)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower() == name:lower() then
            return player
        end
    end
    return nil
end

-- Check if trade GUI is open
local function isTradeGUIOpen()
    return LocalPlayer.PlayerGui:FindFirstChild("TradeGUI") or LocalPlayer.PlayerGui:FindFirstChild("TradeGUI_Phone")
end

-- Get ALL items in "Weapons" category
local function getAllWeapons()
    -- This depends on how the game stores items
    -- Example: Check Backpack, Inventory, etc.
    local weapons = {}
    
    -- Check Backpack
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(weapons, {item.Name, "Weapons"})
                if #weapons >= MAX_ITEMS_PER_TRADE then
                    break
                end
            end
        end
    end
    
    -- Check Character (equipped items)
    local character = LocalPlayer.Character
    if character and #weapons < MAX_ITEMS_PER_TRADE then
        for _, item in ipairs(character:GetChildren()) do
            if item:IsA("Tool") then
                table.insert(weapons, {item.Name, "Weapons"})
                if #weapons >= MAX_ITEMS_PER_TRADE then
                    break
                end
            end
        end
    end
    
    return weapons
end

-- Add all available weapons to trade
local function addWeaponsToTrade()
    local weapons = getAllWeapons()
    
    if #weapons == 0 then
        warn("No weapons found to trade!")
        return false
    end
    
    -- Add up to MAX_ITEMS_PER_TRADE
    for i = 1, math.min(#weapons, MAX_ITEMS_PER_TRADE) do
        local itemData = weapons[i]
        TradeRemotes.OfferItem:FireServer(itemData[1], itemData[2])
        wait(ITEM_ADD_DELAY)
    end
    
    return true
end

-- Accept trade when ready
local function acceptTrade()
    -- Check if trade GUI is open (optional, but safer)
    if not isTradeGUIOpen() then
        warn("Trade GUI not found!")
        return false
    end
    
    -- Accept trade (using the remote)
    TradeRemotes.AcceptTrade:FireServer(285646582) -- Example ID (adjust if needed)
    return true
end

-- Main trade function
local function initiateTrade(targetPlayer)
    if isTrading or (os.time() - lastTradeTime) < TRADE_COOLDOWN then
        return
    end
    
    isTrading = true
    print(`Starting trade with {targetPlayer.Name}...`)
    
    -- 1. Send trade request
    TradeRemotes.SendRequest:InvokeServer(targetPlayer)
    wait(1) -- Wait for response
    
    -- 2. Check if trade GUI opened
    if not isTradeGUIOpen() then
        warn("Trade GUI did not open!")
        isTrading = false
        return
    end
    
    -- 3. Add weapons
    if not addWeaponsToTrade() then
        isTrading = false
        return
    end
    
    -- 4. Accept trade
    if not acceptTrade() then
        warn("Failed to accept trade!")
    else
        print(`Trade with {targetPlayer.Name} completed!`)
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
        print(`{TARGET_PLAYER} not found. Waiting...`)
    end
    wait(5) -- Check every 5 sec
end
