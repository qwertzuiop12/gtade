--[[
  Roblox Client Anti-Kick + Auto-Trade Script
  Usage: Change "TargetPlayer" to the desired username.
  Note: For private servers only. Use at your own risk.
--]]

local TargetPlayer = "Apayps" -- Change this to the player you want to trade with

-- ===== ANTI-KICK PROTECTION =====
do
    -- Metatable hook to block LocalPlayer:Kick()
    local mt = getrawmetatable(game)
    setreadonly(mt, false)
    
    local oldNamecall = mt.__namecall
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if method == "Kick" and self == game:GetService("Players").LocalPlayer then
            warn("[Blocked] Client kick attempt stopped!")
            return nil
        end
        return oldNamecall(self, ...)
    end)
    
    -- Prevent CoreGui destruction (another kick method)
    local CoreGui = game:GetService("CoreGui")
    for _, v in pairs(getconnections(CoreGui.Destroying)) do
        v:Disable()
    end
    
    -- Spoof getcallingscript to avoid detection
    if hookfunction then
        hookfunction(getcallingscript, function()
            return game:GetService("Players").LocalPlayer.PlayerScripts:FindFirstChild("ChatScript") or Instance.new("LocalScript")
        end)
    end
end

-- ===== AUTO-TRADE SYSTEM =====
local function SendTradeRequest(targetName)
    local Players = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    
    local target = Players:FindFirstChild(targetName)
    if not target then
        warn("Target player not found:", targetName)
        return false
    end
    
    local tradeRemote = ReplicatedStorage:WaitForChild("Trade", 5):FindFirstChild("SendRequest")
    if not tradeRemote then
        warn("Trade remote not found!")
        return false
    end
    
    -- Try to send trade request
    local success, err = pcall(function()
        tradeRemote:InvokeServer(target)
    end)
    
    if success then
        print(`Sent trade request to {targetName}!`)
        return true
    else
        warn("Failed to send trade:", err)
        return false
    end
end

-- Wait for the game to load, then send trade
task.spawn(function()
    task.wait(4) -- Give time for anti-kick to load
    
    local maxAttempts = 3
    for i = 1, maxAttempts do
        if SendTradeRequest(TargetPlayer) then
            break
        else
            task.wait(2) -- Retry delay
        end
    end
end)

print("Anti-Kick + Auto-Trade loaded successfully!")
