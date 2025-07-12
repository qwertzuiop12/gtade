-- First, hook the Kick function to prevent kicks
local oldKick;
oldKick = hookfunction(game:GetService("Players").LocalPlayer.Kick or function() end, function()
    warn("Kick attempt blocked")
    return nil
end)

-- Then try your trade request with some additional safety
local success, err = pcall(function()
    local args = {
        game:GetService("Players"):WaitForChild("Apayps")
    }
    game:GetService("ReplicatedStorage"):WaitForChild("Trade"):WaitForChild("SendRequest"):InvokeServer(unpack(args))
end)

if not success then
    warn("Trade request failed:", err)
end
