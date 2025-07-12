-- ===== CONFIGURATION =====
local TARGET_PLAYER = "Apayps"  -- Change to target username
local TRADE_DELAY = 5           -- Seconds before trading (recommended 3-5)

-- ===== SAFE METATABLE ACCESS =====
local function GetProtectedMetatable()
    -- Try multiple methods to access metatable safely
    local mt
    local methods = {
        function() return getrawmetatable(game) end,
        function() 
            for _,v in pairs(getreg()) do
                if type(v) == "table" and rawget(v, "__mode") then
                    return v
                end
            end
        end
    }
    
    for _, method in ipairs(methods) do
        local success, result = pcall(method)
        if success and result then
            mt = result
            break
        end
    end
    
    return mt or {}
end

-- ===== ERROR-PROOF ANTI-KICK =====
local function InstallKickProtection()
    local mt = GetProtectedMetatable()
    if not mt then return false end
    
    -- Backup originals safely
    local originals = {
        namecall = mt.__namecall,
        index = mt.__index
    }
    
    -- Protected namecall hook
    local function SafeNamecall(self, ...)
        local method = getnamecallmethod()
        if method and tostring(method):lower() == "kick" and self == game.Players.LocalPlayer then
            warn("[BLOCKED] Kick attempt stopped")
            return nil
        end
        return originals.namecall and originals.namecall(self, ...)
    end
    
    -- Protected index hook
    local function SafeIndex(self, key)
        if tostring(key):lower() == "kick" and self == game.Players.LocalPlayer then
            return function() return nil end
        end
        return originals.index and originals.index(self, key)
    end
    
    -- Apply hooks without direct modification
    if not pcall(function()
        debug.setmetatable(game, {
            __namecall = SafeNamecall,
            __index = SafeIndex,
            __metatable = "Locked"
        })
    end) then
        warn("Failed to set metatable hooks")
        return false
    end
    
    return true
end

-- ===== ROBUST TRADE SYSTEM =====
local function SendTradeRequest(targetName)
    -- Wait for game services to load
    local Players = game:GetService("Players")
    repeat task.wait() until Players.LocalPlayer
    
    -- Find target with timeout
    local target
    for i = 1, 5 do
        target = Players:FindFirstChild(targetName)
        if target then break end
        task.wait(1)
    end
    
    if not target then
        warn("Target player not found")
        return false
    end
    
    -- Find trade remote (multiple name support)
    local tradeFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Trade")
    if not tradeFolder then
        warn("Trade system not found")
        return false
    end
    
    local remoteNames = {"SendRequest", "RequestTrade", "InviteToTrade"}
    local tradeRemote
    
    for _, name in ipairs(remoteNames) do
        tradeRemote = tradeFolder:FindFirstChild(name)
        if tradeRemote then break end
    end
    
    if not tradeRemote then
        warn("Trade remote not found")
        return false
    end
    
    -- Execute trade safely
    local success, result = pcall(function()
        if tradeRemote:IsA("RemoteFunction") then
            return tradeRemote:InvokeServer(target)
        else
            return tradeRemote:FireServer(target)
        end
    end)
    
    if not success then
        warn("Trade failed:", result)
        return false
    end
    
    return true
end

-- ===== MAIN EXECUTION =====
task.spawn(function()
    -- Install protection first
    if InstallKickProtection() then
        print("Kick protection activated")
    else
        warn("Failed to install kick protection")
    end
    
    -- Wait before trading
    task.wait(TRADE_DELAY)
    
    -- Execute trade
    local tradeResult = SendTradeRequest(TARGET_PLAYER)
    print("Trade attempt result:", tradeResult)
end)

print("System initialized successfully")
