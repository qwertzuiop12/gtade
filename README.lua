-- Complete Auto-Trade Bot for Player "Roqate"
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- Configuration
local TARGET_PLAYER = "Roqate"
local MAX_ITEMS_PER_TRADE = 4
local TRADE_COOLDOWN = 5 -- seconds between trades
local ITEM_ADD_DELAY = 0.3 -- seconds between adding items
local SCROLL_DELAY = 0.5 -- seconds between scroll actions
local MAX_SCROLL_ATTEMPTS = 10 -- max times to scroll looking for items
local COUNTDOWN_TIMEOUT = 30 -- seconds to wait for countdown
local TRADE_COMPLETE_TIMEOUT = 10 -- seconds to wait for trade completion

-- Trade state tracking
local isTrading = false
local lastTradeTime = 0
local currentTradeItems = {}

--[[
    UTILITY FUNCTIONS
]]

-- Function to find a player by name
local function findPlayerByName(name)
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Name:lower() == name:lower() then
            return player
        end
    end
    return nil
end

-- Function to simulate human-like mouse movement and clicks
local function simulateClick(guiObject)
    if not guiObject or not guiObject:IsA("GuiObject") then return false end
    
    -- Calculate center position of the GUI element
    local absPos = guiObject.AbsolutePosition
    local absSize = guiObject.AbsoluteSize
    local centerX = absPos.X + absSize.X/2
    local centerY = absPos.Y + absSize.Y/2
    
    -- Simulate human-like movement with slight randomness
    local steps = math.random(3, 8)
    for i = 1, steps do
        local progress = i/steps
        local offsetX = (math.random() * 20 - 10) * progress
        local offsetY = (math.random() * 20 - 10) * progress
        
        VirtualInputManager:SendMouseMoveEvent(
            centerX * progress + offsetX,
            centerY * progress + offsetY,
            game:GetService("CoreGui")
        )
        wait(0.05)
    end
    
    -- Final precise position
    VirtualInputManager:SendMouseMoveEvent(
        centerX,
        centerY,
        game:GetService("CoreGui")
    )
    wait(0.1)
    
    -- Click with random duration (50-150ms)
    VirtualInputManager:SendMouseButtonEvent(
        centerX,
        centerY,
        0, -- Left mouse button
        true, -- Down
        game:GetService("CoreGui"),
        math.random(50, 150)
    )
    wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(
        centerX,
        centerY,
        0, -- Left mouse button
        false, -- Up
        game:GetService("CoreGui"),
        1
    )
    
    return true
end

-- Function to find a GUI element by path
local function findGuiElement(path, parent)
    parent = parent or PlayerGui
    local parts = {}
    for part in path:gmatch("[^>]+") do
        table.insert(parts, part:match("^%s*(.-)%s*$"))
    end
    
    local current = parent
    for i, part in ipairs(parts) do
        current = current:FindFirstChild(part)
        if not current then return nil end
    end
    
    return current
end

-- Function to click a GUI element by path with retries
local function clickGuiElement(path, maxRetries, parent)
    maxRetries = maxRetries or 3
    local retries = 0
    
    while retries < maxRetries do
        local element = findGuiElement(path, parent)
        if element and element:IsA("GuiObject") then
            if simulateClick(element) then
                return true
            end
        end
        retries = retries + 1
        wait(0.5)
    end
    
    warn("Failed to click GUI element: "..path)
    return false
end

-- Function to find text matching a pattern in the trade GUI
local function findTradeText(pattern)
    local tradeGui = findGuiElement("TradeGUI_Phone")
    if not tradeGui then return nil end
    
    for _, descendant in ipairs(tradeGui:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
            local text = descendant.Text
            if text and text:match(pattern) then
                return descendant, text
            end
        end
    end
    return nil
end

--[[
    TRADE FUNCTIONS
]]

-- Function to find and add all items from the Items frame
local function addAllItems()
    -- Open items menu if not already open
    local itemsFrame = findGuiElement("TradeGUI_Phone > Container > Items")
    if not itemsFrame or not itemsFrame.Visible then
        if not clickGuiElement("TradeGUI_Phone > Container > Trade > Actions > AddItems > ActionButton") then
            warn("Failed to open items menu")
            return false
        end
        wait(1)
    end

    -- Find the scroll frame that contains the items
    local scrollFrame = findGuiElement("TradeGUI_Phone > Container > Items > Scroll") or
                       findGuiElement("TradeGUI_Phone > Container > Items > ScrollingFrame") or
                       findGuiElement("TradeGUI_Phone > Container > Items > Container")
    
    if not scrollFrame then
        warn("Scroll frame not found in Items frame")
        return false
    end

    -- Get all clickable items (buttons, frames, etc.)
    local function getVisibleItems()
        local items = {}
        for _, child in ipairs(scrollFrame:GetDescendants()) do
            if (child:IsA("TextButton") or child:IsA("ImageButton") or child:IsA("Frame")) and 
               child.Visible and child.Active then
                table.insert(items, child)
            end
        end
        return items
    end

    local items = getVisibleItems()
    
    -- If no items found, try scrolling
    local scrollAttempts = 0
    while #items == 0 and scrollAttempts < MAX_SCROLL_ATTEMPTS do
        -- Scroll down
        VirtualInputManager:SendMouseWheelEvent(0, -1, scrollFrame)
        wait(SCROLL_DELAY)
        
        -- Check for items again
        items = getVisibleItems()
        scrollAttempts = scrollAttempts + 1
    end

    if #items == 0 then
        warn("No items found in the Items frame")
        return false
    end

    -- Add up to MAX_ITEMS_PER_TRADE items
    local itemsAdded = 0
    for _, item in ipairs(items) do
        if itemsAdded >= MAX_ITEMS_PER_TRADE then break end
        
        if simulateClick(item) then
            itemsAdded = itemsAdded + 1
            wait(ITEM_ADD_DELAY)
        end
    end

    -- Close items menu
    if not clickGuiElement("TradeGUI_Phone > Container > Items > Tabs > Close > ActionButton") then
        warn("Warning: Failed to close items menu")
    end

    return itemsAdded > 0
end

-- Function to monitor the trade countdown and accept
local function monitorAndAcceptTrade()
    -- Wait for the countdown (5...4...3...2...1)
    local countdownFound = false
    local startTime = os.time()
    
    while os.time() - startTime < COUNTDOWN_TIMEOUT do
        -- Look for countdown text (e.g., "5", "4", etc.)
        local countdownElement, countdownText = findTradeText("^[1-5]$")
        
        if countdownElement then
            print("Countdown detected:", countdownText)
            -- When we see "1", accept the trade
            if countdownText == "1" then
                countdownFound = true
                break
            end
        end
        
        wait(0.1)
    end
    
    if not countdownFound then
        warn("Trade countdown not detected")
        return false
    end
    
    -- Click accept button
    if not clickGuiElement("TradeGUI_Phone > Container > Trade > Actions > Accept > ActionButton") then
        warn("Failed to click Accept button")
        return false
    end
    
    wait(0.5)
    
    -- Click confirm button
    if not clickGuiElement("TradeGUI_Phone > Container > Trade > Actions > Accept > Confirm > ActionButton") then
        warn("Failed to click Confirm button")
        return false
    end
    
    -- Wait for trade completion (detect "Accepted" frame)
    startTime = os.time()
    local tradeCompleted = false
    
    while os.time() - startTime < TRADE_COMPLETE_TIMEOUT do
        -- Check for accepted trade GUI
        local acceptedFrame = findGuiElement("TradeGUI_Phone > Container > Trade > TheirOffer > Accepted") or
                             findTradeText("Trade Accepted")
        
        if acceptedFrame then
            tradeCompleted = true
            break
        end
        
        wait(0.1)
    end
    
    if not tradeCompleted then
        warn("Trade completion not detected")
        return false
    end
    
    return true
end

-- Function to initiate trade with player
local function initiateTradeWithPlayer(player)
    if isTrading or os.time() - lastTradeTime < TRADE_COOLDOWN then
        return
    end
    
    isTrading = true
    print("Initiating trade with", player.Name)
    
    -- Click player's action button
    if not clickGuiElement("MainGUI > Lobby > Leaderboard > Container > PlayerList > "..player.Name.." > ActionButton") then
        warn("Failed to click player action button")
        isTrading = false
        return
    end
    
    wait(0.5)
    
    -- Click trade button
    if not clickGuiElement("MainGUI > Lobby > Leaderboard > Popup > Container > Action > Trade") then
        warn("Failed to click trade button")
        isTrading = false
        return
    end
    
    wait(1)
    
    -- Add items to trade
    if not addAllItems() then
        warn("Failed to add items to trade")
        isTrading = false
        return
    end
    
    wait(0.5)
    
    -- Monitor and accept trade
    if not monitorAndAcceptTrade() then
        warn("Failed to complete trade")
        isTrading = false
        return
    end
    
    print("Trade with", player.Name, "completed successfully")
    lastTradeTime = os.time()
    isTrading = false
end

--[[
    MAIN LOOP
]]

-- Main loop to check for target player
local function mainLoop()
    while true do
        local targetPlayer = findPlayerByName(TARGET_PLAYER)
        
        if targetPlayer and targetPlayer ~= LocalPlayer then
            initiateTradeWithPlayer(targetPlayer)
        else
            print("Player", TARGET_PLAYER, "not found in server. Waiting...")
        end
        
        wait(5) -- Check every 5 seconds
    end
end

-- Start the script
print("Auto-Trade Bot started. Looking for player:", TARGET_PLAYER)
mainLoop()
