-- ===== CONFIG =====
local TARGET_PLAYER = "Apayps"  -- Change this to target username
local DELAY_BEFORE_TRADE = 5    -- Seconds to wait before trading

-- ===== ANTI-KICK PROTECTION =====
do
    -- Secure metatable access
    local mt = getrawmetatable(game)
    if not mt then
        warn("Failed to get metatable - using fallback")
        mt = {}
        setrawmetatable(game, mt)
    end
    
    setreadonly(mt, false)

    -- Backup original functions
    local oldNamecall = mt.__namecall or function() end
    local oldIndex = mt.__index or function() end

    -- Block kicks via namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method and tostring(method):lower() == "kick" then
            warn("[BLOCKED] Kick attempt stopped")
            return nil
        end
        return oldNamecall(self, ...)
    end)

    -- Block property access kicks
    mt.__index = newcclosure(function(self, key)
        if tostring(key):lower() == "kick" then
            return function() 
                warn("[BLOCKED] Property kick attempt")
                return nil 
            end
        end
        return oldIndex(self, key)
    end)
end

-- ===== TRADE SYSTEM =====
local function SendTradeRequest(targetName)
    -- Wait for game to fully load
    repeat task.wait() until game:IsLoaded() and game.Players.LocalPlayer

    -- Find target player
    local target
    for i = 1, 5 do  -- Try 5 times
        target = game.Players:FindFirstChild(targetName)
        if target then break end
        task.wait(1)
    end

    if not target then
        warn("Target player not found:", targetName)
        return false
    end

    -- Find trade remote (multiple possible names)
    local tradeRemote
    local possibleNames = {"SendRequest", "RequestTrade", "InviteToTrade"}
    
    for _, name in pairs(possibleNames) do
        tradeRemote = game.ReplicatedStorage:FindFirstChild("Trade", true):FindFirstChild(name)
        if tradeRemote then break end
    end

    if not tradeRemote then
        warn("Trade remote not found")
        return false
    end

    -- Send trade request
    local success, err = pcall(function()
        if tradeRemote:IsA("RemoteFunction") then
            return tradeRemote:InvokeServer(target)
        else
            return tradeRemote:FireServer(target)
        end
    end)

    if success then
        print("Successfully sent trade to", targetName)
        return true
    else
        warn("Trade failed:", err)
        return false
    end
end

-- ===== DELAYED EXECUTION =====
task.spawn(function()
    task.wait(DELAY_BEFORE_TRADE)  -- Wait before trading
    SendTradeRequest(TARGET_PLAYER)
end)

print("Anti-Kick & Trade system loaded successfully")
