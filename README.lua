-- ===== CONFIGURATION =====
local TARGET_PLAYER = "Apayps"  -- Change to target username
local TRADE_DELAY = 4           -- Seconds before sending trade
local MAX_TRADE_ATTEMPTS = 3    -- Max retry attempts

-- ===== ADVANCED ANTI-KICK SYSTEM (Your Code) =====
local getgenv, getnamecallmethod, hookmetamethod, hookfunction, newcclosure, checkcaller, lower, gsub, match = 
    getgenv, getnamecallmethod, hookmetamethod, hookfunction, newcclosure, checkcaller, string.lower, string.gsub, string.match

if getgenv().ED_AntiKick then return end

-- Cache services with clone protection
local cloneref = cloneref or function(...) return ... end
local clonefunction = clonefunction or function(...) return ... end
local Players = cloneref(game:GetService("Players"))
local LocalPlayer = cloneref(Players.LocalPlayer)
local StarterGui = cloneref(game:GetService("StarterGui"))
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))

local SetCore = clonefunction(StarterGui.SetCore)
local FindFirstChild = clonefunction(game.FindFirstChild)

local CompareInstances = (CompareInstances and function(i1, i2)
    return typeof(i1) == "Instance" and typeof(i2) == "Instance" and CompareInstances(i1, i2)
end) or function(i1, i2)
    return typeof(i1) == "Instance" and typeof(i2) == "Instance"
end

local CanCastToSTDString = function(...)
    return pcall(FindFirstChild, game, ...)
end

-- Global configuration
getgenv().ED_AntiKick = {
    Enabled = true,
    SendNotifications = true,
    CheckCaller = true
}

-- Hook metamethods
local OldNamecall; OldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(...)
    local self, message = ...
    local method = getnamecallmethod()
    
    if ((ED_AntiKick.CheckCaller and not checkcaller()) or true) and 
       CompareInstances(self, LocalPlayer) and 
       gsub(method, "^%l", string.upper) == "Kick" and 
       ED_AntiKick.Enabled then
        
        if CanCastToSTDString(message) then
            if ED_AntiKick.SendNotifications then
                SetCore(StarterGui, "SendNotification", {
                    Title = "Anti-Kick Active",
                    Text = "Blocked kick attempt: "..tostring(message),
                    Duration = 2
                })
            end
            return
        end
    end
    return OldNamecall(...)
end))

-- Hook Kick function directly
local OldKick; OldKick = hookfunction(LocalPlayer.Kick, newcclosure(function(...)
    local self, message = ...
    if ((ED_AntiKick.CheckCaller and not checkcaller()) or true) and 
       CompareInstances(self, LocalPlayer) and 
       ED_AntiKick.Enabled then
        
        if CanCastToSTDString(message) then
            if ED_AntiKick.SendNotifications then
                SetCore(StarterGui, "SendNotification", {
                    Title = "Anti-Kick Active",
                    Text = "Blocked direct kick attempt",
                    Duration = 2
                })
            end
            return
        end
    end
    return OldKick(...)
end))

-- ===== ENHANCED TRADE SYSTEM =====
local function SendTradeRequest(targetName)
    -- Wait for replication
    if not Players:FindFirstChild(targetName) then
        Players.PlayerAdded:Wait()
        task.wait(0.5)
    end

    local target = Players:FindFirstChild(targetName)
    if not target then
        warn("Player not found:", targetName)
        return false
    end

    -- Find trade remote with multiple fallbacks
    local tradeFolder = ReplicatedStorage:WaitForChild("Trade", 5)
    if not tradeFolder then
        warn("Trade system not found")
        return false
    end

    local tradeRemote = tradeFolder:FindFirstChild("SendRequest") or 
                       tradeFolder:FindFirstChild("RequestTrade") or
                       tradeFolder:FindFirstChild("InviteToTrade")

    if not tradeRemote then
        warn("Trade remote not found")
        return false
    end

    -- Attempt trade with protection
    local success, result = pcall(function()
        if tradeRemote:IsA("RemoteFunction") then
            return tradeRemote:InvokeServer(target)
        elseif tradeRemote:IsA("RemoteEvent") then
            return tradeRemote:FireServer(target)
        end
    end)

    if success then
        print("Sent trade to", targetName)
        return true
    else
        warn("Trade failed:", result)
        return false
    end
end

-- ===== AUTOMATION HANDLER =====
task.spawn(function()
    task.wait(TRADE_DELAY)
    
    -- Attempt trade with retries
    local attempts = 0
    repeat
        attempts += 1
        if SendTradeRequest(TARGET_PLAYER) then break end
        task.wait(1.5) -- Cooldown between attempts
    until attempts >= MAX_TRADE_ATTEMPTS
    
    -- Final status
    if ED_AntiKick.SendNotifications then
        SetCore(StarterGui, "SendNotification", {
            Title = "Trade System",
            Text = attempts <= MAX_TRADE_ATTEMPTS and 
                   "Trade sent to "..TARGET_PLAYER or 
                   "Failed to trade with "..TARGET_PLAYER,
            Duration = 3
        })
    end
end)

-- Initial notification
if ED_AntiKick.SendNotifications then
    StarterGui:SetCore("SendNotification", {
        Title = "System Active",
        Text = "Anti-Kick & Trade system loaded",
        Duration = 3
    })
end
