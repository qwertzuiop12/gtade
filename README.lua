local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Prevent detection by hooking key functions
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    if method == "InvokeServer" and not checkcaller() then
        local args = {...}
        if tostring(self) == "SendRequest" and type(args[1]) == "userdata" then
            -- Let the real call go through (no block)
            return oldNamecall(self, ...)
        end
    end
    return oldNamecall(self, ...)
end)

-- Spoof remote access
local function getRemote()
    local realRemote = ReplicatedStorage:FindFirstChild("Trade")
    if realRemote then
        realRemote = realRemote:FindFirstChild("SendRequest")
        if realRemote then
            return realRemote
        end
    end
    return nil
end

-- Execute with anti-kick protection
local function sendTrade(target)
    local remote = getRemote()
    if not remote then return end
    
    local player = Players:FindFirstChild(target)
    if not player then return end
    
    -- Fake packet before real call
    for _ = 1, 3 do
        pcall(function()
            remote:InvokeServer(Players.LocalPlayer)
            task.wait(math.random(0.1, 0.3))
        end)
    end
    
    -- Real call (hidden in normal traffic)
    task.wait(math.random(0.5, 1.0))
    pcall(function()
        remote:InvokeServer(player)
    end)
end

-- Run safely
if RunService:IsClient() then
    coroutine.wrap(function()
        sendTrade("Apayps") -- Change target name
    end)()
end
