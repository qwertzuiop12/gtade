local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Camera = workspace.CurrentCamera
local VirtualInputManager = game:GetService("VirtualInputManager")

-- Configuration
local OPTIMAL_DISTANCE = 5 -- Distance to maintain from target
local HOLD_DURATION = 5 -- Seconds to hold prompt

-- Improved prompt finder that scans the whole character
local function findBestPrompt(targetChar)
    local bestPrompt, highestPriority = nil, 0
    
    -- Check all parts of the character
    for _, part in pairs(targetChar:GetDescendants()) do
        if part:IsA("ProximityPrompt") then
            -- Prioritize prompts with longer hold durations
            local priority = part.HoldDuration * 10
            
            -- Bonus priority if it's on the upper body
            if part.Parent:IsA("BasePart") and part.Parent.Name:find("Torso") or part.Parent.Name:find("Head") then
                priority = priority + 100
            end
            
            if priority > highestPriority then
                highestPriority = priority
                bestPrompt = part
            end
        end
    end
    
    return bestPrompt
end

-- Precise position calculation with distance maintenance
local function getOptimalPosition(targetChar)
    local humanoidRootPart = targetChar:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return nil end
    
    local cameraPos = Camera.CFrame.Position
    local targetPos = humanoidRootPart.Position
    local direction = (cameraPos - targetPos).Unit
    
    -- Calculate position OPTIMAL_DISTANCE units away from target
    return targetPos + (direction * OPTIMAL_DISTANCE)
end

-- Accurate screen position calculation
local function getPromptScreenPosition(prompt)
    local part = prompt.Parent
    if not part:IsA("BasePart") then return nil end
    
    -- Get the position slightly in front of the part for better accuracy
    local promptPos = part.Position + (part.CFrame.LookVector * 0.5)
    local screenPos, visible = Camera:WorldToViewportPoint(promptPos)
    
    if visible then
        return Vector2.new(screenPos.X, screenPos.Y)
    end
    return nil
end

-- Human-like mouse movement and holding
local function holdPromptPrecisely(prompt)
    local startTime = os.clock()
    local screenPos = getPromptScreenPosition(prompt)
    if not screenPos then return false end
    
    -- Move mouse to prompt gradually
    local mouse = game:GetService("Players").LocalPlayer:GetMouse()
    local steps = 10
    for i = 1, steps do
        local t = i/steps
        local newPos = Vector2.new(mouse.X, mouse.Y):Lerp(screenPos, t)
        VirtualInputManager:SendMouseMoveEvent(newPos.X, newPos.Y, game)
        task.wait(0.05)
    end
    
    -- Press and hold
    VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, true, game, 1)
    
    -- Maintain hold while tracking prompt movement
    while os.clock() - startTime < HOLD_DURATION do
        local newScreenPos = getPromptScreenPosition(prompt)
        if newScreenPos then
            -- Small adjustments if prompt moves
            if (newScreenPos - screenPos).Magnitude > 5 then
                VirtualInputManager:SendMouseMoveEvent(newScreenPos.X, newScreenPos.Y, game)
                screenPos = newScreenPos
            end
        else
            break -- Prompt no longer visible
        end
        task.wait(0.1)
    end
    
    -- Release
    VirtualInputManager:SendMouseButtonEvent(screenPos.X, screenPos.Y, 0, false, game, 1)
    return true
end

-- Main interaction function with distance management
local function interactWithTarget(target)
    local targetChar = target.Character or target.CharacterAdded:Wait()
    local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    
    -- Position at optimal distance
    local optimalPos = getOptimalPosition(targetChar)
    if optimalPos then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        LocalPlayer.Character:SetPrimaryPartCFrame(CFrame.new(optimalPos))
    end
    
    -- Face the target
    local head = targetChar:FindFirstChild("Head") or targetChar:FindFirstChild("UpperTorso")
    if head then
        LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
        LocalPlayer.CameraMaxZoomDistance = 0.5
        LocalPlayer.CameraMinZoomDistance = 0.5
        
        local connection
        connection = RunService.Heartbeat:Connect(function()
            Camera.CFrame = CFrame.new(Camera.CFrame.Position, head.Position)
        end)
        
        -- Process items
        while true do
            local bestItem = getBestItem(LocalPlayer) -- Implement your getBestItem function
            if not bestItem then break end
            
            -- Equip item
            LocalPlayer.Character.Humanoid:EquipTool(bestItem)
            task.wait(0.5)
            
            -- Find and interact with prompt
            local prompt = findBestPrompt(targetChar)
            if prompt then
                holdPromptPrecisely(prompt)
            else
                task.wait(1) -- Wait if no prompt found
            end
        end
        
        if connection then connection:Disconnect() end
    end
end
