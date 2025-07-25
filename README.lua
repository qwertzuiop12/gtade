local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local VirtualInput = game:GetService("VirtualInputManager")
local localPlayer = Players.LocalPlayer

-- **CONFIG**  
local TRADE_PARTNER = "Roqate"  
local ITEMS_TO_SELECT = 4  
local DELAY = 0.5  -- Base delay between actions  

-- **PATHS (from your logs)**  
local PATHS = {
    leaderboard = "MainGUI.Lobby.Leaderboard.Container.PlayerList."..TRADE_PARTNER..".ActionButton",
    trade_button = "MainGUI.Lobby.Leaderboard.Popup.Container.Action.Trade",
    add_items = "TradeGUI_Phone.Container.Trade.Actions.AddItems.ActionButton",
    item_selection = "TradeGUI_Phone.Container.Items.Main.Weapons.Items.Container.Current.Container.NewItem.Container.ActionButton",
    close_items = "TradeGUI_Phone.Container.Items.Tabs.Close.ActionButton",
    accept_trade = "TradeGUI_Phone.Container.Trade.Actions.Accept.ActionButton",
    confirm_trade = "TradeGUI_Phone.Container.Trade.Actions.Accept.Confirm.ActionButton",
    close_leaderboard = "MainGUI.Lobby.Leaderboard.Container.Close"
}

-- **VISUAL CLICK FUNCTION (moves mouse & clicks)**  
local function visualClick(guiObject)
    if not guiObject or not guiObject:IsA("GuiObject") then return false end
    
    -- Get button position
    local absPos = guiObject.AbsolutePosition
    local absSize = guiObject.AbsoluteSize
    local centerX = absPos.X + (absSize.X / 2)
    local centerY = absPos.Y + (absSize.Y / 2)
    
    -- **Visual feedback (prints position)**
    print(`🔵 VISUAL CLICKING [{guiObject.Name}] at ({math.floor(centerX)}, {math.floor(centerY)})`)
    
    -- Simulate mouse movement
    VirtualInput:SendMouseMoveEvent(centerX, centerY, game)
    wait(0.1)
    
    -- Simulate click (down + up)
    VirtualInput:SendMouseButtonEvent(centerX, centerY, 0, true, game, 0)  -- Mouse down
    wait(0.05)
    VirtualInput:SendMouseButtonEvent(centerX, centerY, 0, false, game, 0) -- Mouse up
    
    return true
end

-- **Finds GUI element and clicks it visually**  
local function clickPath(path)
    local current = localPlayer:WaitForChild("PlayerGui")
    for _, part in ipairs(path:split(".")) do
        current = current:WaitForChild(part)
    end
    
    if current:IsA("GuiObject") then
        visualClick(current)
        wait(DELAY)
    end
end

-- **MAIN TRADE LOOP**  
local function performTrade()
    print("\n=== STARTING TRADE WITH "..TRADE_PARTNER.." ===")
    
    -- 1. Find & click Roqate in leaderboard
    clickPath(PATHS.leaderboard)
    wait(DELAY * 2)  -- Wait for popup
    
    -- 2. Click Trade button
    clickPath(PATHS.trade_button)
    wait(DELAY * 3)  -- Wait for trade UI
    
    -- 3. Click "Add Items"
    clickPath(PATHS.add_items)
    wait(DELAY)
    
    -- 4. Select first [X] items
    for i = 1, ITEMS_TO_SELECT do
        clickPath(PATHS.item_selection)
        print(`  ➔ Selected item #{i}`)
        wait(DELAY)
    end
    
    -- 5. Close items menu
    clickPath(PATHS.close_items)
    wait(DELAY)
    
    -- 6. Accept trade
    clickPath(PATHS.accept_trade)
    wait(DELAY * 2)  -- Wait for confirm button
    
    -- 7. Confirm trade
    clickPath(PATHS.confirm_trade)
    print("✅ TRADE COMPLETE! Waiting to restart...")
    wait(DELAY * 3)
    
    -- 8. Close leaderboard (optional)
    clickPath(PATHS.close_leaderboard)
end

-- **AUTO-RESTARTING LOOP**  
while true do
    local success, err = pcall(performTrade)
    if not success then
        warn("⚠️ TRADE FAILED:", err)
    end
    wait(5)  -- Cooldown before next trade
end
