_G.walkAnimId = "88806903330819"
_G.idleAnimId = "108138386572761"
_G.jumpAnimId = "76076309961033"
_G.fallAnimId = "76076309961033"

_G.animBinds = {
    [Enum.KeyCode.R] = {
        id = "89364019904363",
        loop = true,
        toggle = true
    }
}

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local Torso = Character:WaitForChild("Torso")

local isWalking = false
local currentAnimType = nil
local currentAnimThread = nil
local activeTweens = {}

local Joints = {
    ["Head"] = Torso["Neck"],
    ["Left Arm"] = Torso["Left Shoulder"],
    ["Right Arm"] = Torso["Right Shoulder"],
    ["Left Leg"] = Torso["Left Hip"],
    ["Right Leg"] = Torso["Right Hip"],
    ["Torso"] = Character.HumanoidRootPart.RootJoint
}

local function playKeyframeAnim(animId)
    local Model = game:GetObjects("rbxassetid://" .. animId)[1]
    local Keyframes = Model:GetKeyframes()

    for i, Frame in ipairs(Keyframes) do
        local FrameDelay = Keyframes[i + 1] and (Keyframes[i + 1].Time - Frame.Time) or 0.1

        for _, Pose in ipairs(Frame:GetDescendants()) do
            if Pose:IsA("Pose") and Joints[Pose.Name] then
                local Joint = Joints[Pose.Name]
                TweenService:Create(Joint, TweenInfo.new(FrameDelay, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {
                    Transform = Pose.CFrame
                }):Play()
            end
        end

        task.wait(FrameDelay)
    end

    task.wait(0.1)
    for _, Joint in pairs(Joints) do
        Joint.Transform = CFrame.new()
    end
end

local function playLoopedAnimation(animId)
    local Model = game:GetObjects("rbxassetid://" .. animId)[1]
    local Keyframes = Model:GetKeyframes()
    local thread = {}
    currentAnimThread = thread

    while currentAnimThread == thread do
        for i, Frame in ipairs(Keyframes) do
            if currentAnimThread ~= thread then return end

            local FrameDelay = Keyframes[i + 1] and (Keyframes[i + 1].Time - Frame.Time) or 0.1

            for _, Pose in ipairs(Frame:GetDescendants()) do
                if Pose:IsA("Pose") and Joints[Pose.Name] then
                    local Joint = Joints[Pose.Name]
                    local tween = TweenService:Create(Joint, TweenInfo.new(FrameDelay, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {
                        Transform = Pose.CFrame
                    })
                    table.insert(activeTweens, tween)
                    tween:Play()
                end
            end

            if i < #Keyframes and currentAnimThread == thread then
                task.wait(FrameDelay)
            end
        end
    end

    currentAnimThread = nil
end

local function setAnimation(animId, animType)
    if currentAnimType == animType then return end

    currentAnimThread = nil
    task.wait()

    currentAnimType = animType
    task.spawn(function()
        playLoopedAnimation(animId)
    end)
end

RunService.Heartbeat:Connect(function()
    if currentAnimType and string.sub(currentAnimType, 1, 6) == "custom" then return end

    local moving = Humanoid.MoveDirection.Magnitude > 0.1
    if moving and not isWalking then
        isWalking = true
        setAnimation(_G.walkAnimId, "walk")
    elseif not moving and isWalking then
        isWalking = false
        setAnimation(_G.idleAnimId, "idle")
    end
end)

local isAirborne = false

Humanoid.StateChanged:Connect(function(oldState, newState)
    if currentAnimType and string.sub(currentAnimType, 1, 6) == "custom" then return end

    if newState == Enum.HumanoidStateType.Jumping then
        isAirborne = true
        setAnimation(_G.jumpAnimId, "jump")
    elseif newState == Enum.HumanoidStateType.Freefall then
        isAirborne = true
        setAnimation(_G.fallAnimId, "fall")
    elseif newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running or newState == Enum.HumanoidStateType.RunningNoPhysics then
        if isAirborne then
            isAirborne = false
            setAnimation(Humanoid.MoveDirection.Magnitude > 0.1 and _G.walkAnimId or _G.idleAnimId, Humanoid.MoveDirection.Magnitude > 0.1 and "walk" or "idle")
        end
    end
end)

local toggledAnims = {}
UserInputService.InputBegan:Connect(function(input, processed)
    if processed then return end

    local bind = _G.animBinds[input.KeyCode]
    if not bind then return end
    local animId = bind.id

    if bind.loop and bind.toggle then
        toggledAnims[animId] = not toggledAnims[animId]

        if toggledAnims[animId] then
            setAnimation(animId, "custom:" .. animId)
        else
            currentAnimType = nil
            setAnimation(isWalking and _G.walkAnimId or _G.idleAnimId, isWalking and "walk" or "idle")
        end
    elseif bind.loop then
        setAnimation(animId, "custom:" .. animId)
    else
        local prevType = currentAnimType
        currentAnimType = nil
        playKeyframeAnim(animId)
        setAnimation(isWalking and _G.walkAnimId or _G.idleAnimId, prevType)
    end
end)
