-- Сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local Stats = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

local function GetCIELUVColor(percentage)
    local green = Color3.fromRGB(46, 204, 113)
    local red = Color3.fromRGB(231, 76, 60)
    return red:Lerp(green, percentage)
end

-- Настройки
local Config = {
    Menu_Logo = "rbxassetid://0", -- Вставь свой ID картинки
    UIColor1 = Color3.fromRGB(199, 149, 237),
    UIColor2 = Color3.fromRGB(85, 0, 255),
    
    Rainbow_Enabled = false, Rainbow_Speed = 0.5,
    Watermark_Enabled = true, Keybinds_Enabled = true,
    
    Aim_Enabled = false, Aim_Silent = false, Aim_Bind = Enum.UserInputType.MouseButton2,
    Aim_Mode = "Camera", Aim_Target = "Head", Aim_Smooth = 20, Aim_Predict = 0, 
    Aim_TeamCheck = false, Aim_FOV_Show = true, Aim_FOV_Radius = 150,
    
    TP_Enabled = false, TP_Bind = Enum.KeyCode.E,
    Noclip_Enabled = false, Noclip_Bind = Enum.KeyCode.N,
    Fly_Enabled = false, Fly_Bind = Enum.KeyCode.F, Fly_Speed = 50, Fly_AntiFall = true,
    
    ESP_Enabled = false, ESP_TeamCheck = false, ESP_ShowSelf = false,
    ESP_Box = true, ESP_Skeleton = false, ESP_Tracers = false,
    ESP_Name = true; ESP_Name_Pos = "Top", ESP_HPText = true; ESP_HPText_Pos = "Right",
    ESP_Dist = true; ESP_Dist_Pos = "Bottom", ESP_Faction = true; ESP_Faction_Pos = "Top",
    ESP_HPBar = true; ESP_HPBar_Pos = "Left",
    
    Fling_Enabled = false, Fling_Bind = Enum.KeyCode.V, Fling_SpinSpeed = 500, Fling_MaxDist = 10000, 
    Anti_Void = false, Bypass_Chat = false, Anti_Kick = true, Anti_Idle = true, 
    Square_Enabled = false, Square_Bind = Enum.KeyCode.P, Square_Mode = "Toggle", Square_Visual = "3D Wireframe",
    
    Menu_Bind = Enum.KeyCode.RightShift, Unbind_Key = Enum.KeyCode.End
}

local UI_NAME = "GameSync_WAR"
local connections, bindButtons, espCache = {}, {}, {}
local bindingTarget, CachedTarget, FlingTarget = nil, nil, nil
local isFlingToggled, squareToggled = false, false
local dynamicGradientObjects = {}

-- Очистка
local function SelfDestruct()
    for _, conn in pairs(connections) do if conn.Disconnect then conn:Disconnect() end end
    for _, esp in pairs(espCache) do
        if esp.BoxLines then for i=1,4 do esp.BoxLines[i]:Remove(); esp.BoxOutlines[i]:Remove() end end
        if esp.Drawings then
            esp.Drawings.Tracer:Remove(); esp.Drawings.Name:Remove(); esp.Drawings.Dist:Remove()
            esp.Drawings.HPText:Remove(); esp.Drawings.Faction:Remove()
            esp.Drawings.HPBarBg:Remove(); esp.Drawings.HPBarFill:Remove()
        end
        if esp.Skeleton then for _, bone in pairs(esp.Skeleton) do bone:Remove() end end
    end
    table.clear(espCache)
    if CoreGui:FindFirstChild(UI_NAME) then CoreGui[UI_NAME]:Destroy() end
    if CoreGui:FindFirstChild("GameSync_FOV") then CoreGui.GameSync_FOV:Destroy() end
    if CoreGui:FindFirstChild("GameSync_WM") then CoreGui.GameSync_WM:Destroy() end
    if workspace:FindFirstChild("TP_Preview") then workspace.TP_Preview:Destroy() end
    if LocalPlayer.Character then
        for _, obj in pairs(LocalPlayer.Character:GetDescendants()) do
            if obj.Name == "GameSync_Fly" or obj.Name == "GameSync_FlyGyro" then obj:Destroy() end
        end
    end
end
if CoreGui:FindFirstChild(UI_NAME) then SelfDestruct() end

-- Превью для GTA Square
local PreviewPart = Instance.new("Part")
PreviewPart.Name = "TP_Preview"; PreviewPart.Size = Vector3.new(4, 0.1, 4)
PreviewPart.Transparency = 1; PreviewPart.Anchored = true; PreviewPart.CanCollide = false
PreviewPart.Parent = workspace
local SelectionBox = Instance.new("SelectionBox", PreviewPart)
SelectionBox.Adornee = PreviewPart; SelectionBox.LineThickness = 0.05; SelectionBox.Visible = false

local function GetSafePos()
    local char = LocalPlayer.Character
    local params = RaycastParams.new()
    local filter = {PreviewPart}
    if char then table.insert(filter, char) end
    params.FilterDescendantsInstances = filter; params.FilterType = Enum.RaycastFilterType.Exclude
    local ray = workspace:Raycast(Mouse.UnitRay.Origin, Mouse.UnitRay.Direction * 1000, params)
    return ray and ray.Position or Mouse.Hit.Position
end

-- FOV Circle
local FOV_Gui = Instance.new("ScreenGui", CoreGui); FOV_Gui.Name = "GameSync_FOV"; FOV_Gui.IgnoreGuiInset = true
local FOV_Circle = Instance.new("Frame", FOV_Gui)
FOV_Circle.BackgroundTransparency = 1; FOV_Circle.Size = UDim2.new(0, Config.Aim_FOV_Radius*2, 0, Config.Aim_FOV_Radius*2); FOV_Circle.AnchorPoint = Vector2.new(0.5, 0.5)
local FOV_Stroke = Instance.new("UIStroke", FOV_Circle); FOV_Stroke.Thickness = 1
local FOV_Grad = Instance.new("UIGradient", FOV_Stroke)
FOV_Grad.Color = ColorSequence.new(Config.UIColor1)
Instance.new("UICorner", FOV_Circle).CornerRadius = UDim.new(1, 0)

-- Main UI
local TweenInfoFast = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
local ScreenGui = Instance.new("ScreenGui", CoreGui); ScreenGui.Name = UI_NAME; ScreenGui.ResetOnSpawn = false
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 560, 0, 440); MainFrame.Position = UDim2.new(0.5, -280, 0.5, -220)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15); MainFrame.BorderSizePixel = 0; MainFrame.Active = true; MainFrame.ClipsDescendants = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

local MainStroke = Instance.new("UIStroke", MainFrame); MainStroke.Thickness = 1.5; MainStroke.Transparency = 0.3
local MainGradient = Instance.new("UIGradient", MainStroke); table.insert(dynamicGradientObjects, MainGradient)

local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 40); TopBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20); TopBar.BorderSizePixel = 0
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 8)
local TopBarFix = Instance.new("Frame", TopBar); TopBarFix.Size = UDim2.new(1, 0, 0, 8); TopBarFix.Position = UDim2.new(0, 0, 1, -8); TopBarFix.BackgroundColor3 = Color3.fromRGB(20, 20, 20); TopBarFix.BorderSizePixel = 0

local Logo = Instance.new("ImageLabel", TopBar)
Logo.Size = UDim2.new(0, 24, 0, 24); Logo.Position = UDim2.new(0, 10, 0, 8); Logo.BackgroundTransparency = 1; Logo.Image = Config.Menu_Logo
local LogoGradient = Instance.new("UIGradient", Logo); table.insert(dynamicGradientObjects, LogoGradient)

local Title = Instance.new("TextLabel", TopBar)
Title.Size = UDim2.new(1, -50, 1, 0); Title.Position = UDim2.new(0, 40, 0, 0); Title.Text = "GAMESYNC WAR"; Title.TextColor3 = Color3.new(1,1,1)
Title.Font = Enum.Font.GothamBold; Title.TextSize = 14; Title.BackgroundTransparency = 1; Title.TextXAlignment = Enum.TextXAlignment.Left
local TitleGradient = Instance.new("UIGradient", Title); table.insert(dynamicGradientObjects, TitleGradient)

-- Drag & Resize
local dragging, dragInput, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; dragStart = input.Position; startPos = MainFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end) end
end)
UIS.InputChanged:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end end)

local ResizeGrip = Instance.new("TextButton", MainFrame)
ResizeGrip.Size = UDim2.new(0, 15, 0, 15); ResizeGrip.Position = UDim2.new(1, -15, 1, -15); ResizeGrip.BackgroundTransparency = 1
ResizeGrip.Text = "◢"; ResizeGrip.TextColor3 = Color3.fromRGB(100, 100, 100); ResizeGrip.TextSize = 14
local resizing, rDragStart, rStartSize
ResizeGrip.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then resizing = true; rDragStart = input.Position; rStartSize = MainFrame.Size
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then resizing = false end end) end
end)

table.insert(connections, RunService.Heartbeat:Connect(function()
    if dragging and dragInput then 
        local delta = dragInput.Position - dragStart; MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    elseif resizing and dragInput then
        local delta = dragInput.Position - rDragStart; MainFrame.Size = UDim2.new(0, math.clamp(rStartSize.X.Offset + delta.X, 400, 800), 0, math.clamp(rStartSize.Y.Offset + delta.Y, 300, 600))
    end
end))

-- UI Generators
local TabContainer = Instance.new("Frame", MainFrame); TabContainer.Size = UDim2.new(1, -20, 0, 30); TabContainer.Position = UDim2.new(0, 10, 0, 50); TabContainer.BackgroundTransparency = 1
local TabLayout = Instance.new("UIListLayout", TabContainer); TabLayout.FillDirection = Enum.FillDirection.Horizontal; TabLayout.SortOrder = Enum.SortOrder.LayoutOrder; TabLayout.Padding = UDim.new(0, 8)
local PagesContainer = Instance.new("Frame", MainFrame); PagesContainer.Size = UDim2.new(1, -20, 1, -95); PagesContainer.Position = UDim2.new(0, 10, 0, 90); PagesContainer.BackgroundTransparency = 1

local tabs, pages = {}, {}
local function CreateTab(name, isFirst)
    local tabBtn = Instance.new("TextButton", TabContainer)
    tabBtn.Size = UDim2.new(0, 95, 1, 0); tabBtn.BackgroundColor3 = isFirst and Color3.new(1,1,1) or Color3.fromRGB(25, 25, 25)
    tabBtn.Text = name; tabBtn.TextColor3 = isFirst and Color3.new(0,0,0) or Color3.fromRGB(200, 200, 200); tabBtn.Font = Enum.Font.GothamBold; tabBtn.TextSize = 12; tabBtn.AutoButtonColor = false
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 6)
    local grad = Instance.new("UIGradient", tabBtn); if isFirst then table.insert(dynamicGradientObjects, grad) end

    local page = Instance.new("ScrollingFrame", PagesContainer)
    page.Size = UDim2.new(1, 0, 1, 0); page.BackgroundTransparency = 1; page.CanvasSize = UDim2.new(0, 0, 0, 0); page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollBarThickness = 4; page.Visible = isFirst; page.BorderSizePixel = 0
    local scrollGrad = Instance.new("UIGradient", page); table.insert(dynamicGradientObjects, scrollGrad)
    local layout = Instance.new("UIListLayout", page); layout.Padding = UDim.new(0, 8); layout.SortOrder = Enum.SortOrder.LayoutOrder
    table.insert(tabs, tabBtn); table.insert(pages, page)

    tabBtn.MouseButton1Click:Connect(function()
        for i, p in pairs(pages) do
            local isSel = (p == page); p.Visible = isSel
            local tBtn = tabs[i]; local tGrad = tBtn:FindFirstChild("UIGradient")
            if isSel then TweenService:Create(tBtn, TweenInfoFast, {BackgroundColor3 = Color3.new(1,1,1), TextColor3 = Color3.new(0,0,0)}):Play(); table.insert(dynamicGradientObjects, tGrad)
            else TweenService:Create(tBtn, TweenInfoFast, {BackgroundColor3 = Color3.fromRGB(25, 25, 25), TextColor3 = Color3.fromRGB(200, 200, 200)}):Play()
                tGrad.Color = ColorSequence.new(Color3.new(1,1,1)); for k, v in pairs(dynamicGradientObjects) do if v == tGrad then table.remove(dynamicGradientObjects, k) break end end
            end
        end
    end)
    return page
end

local TabAim = CreateTab("Aim", true); local TabESP = CreateTab("ESP", false); local TabMovement = CreateTab("Movement", false); local TabMisc = CreateTab("Misc", false); local TabSettings = CreateTab("Settings", false)

local function AddSetting(parentTab, text, configKey, bindKey, modeKey, cycleOptions)
    local frame = Instance.new("Frame", parentTab); frame.Size = UDim2.new(1, -8, 0, 36); frame.BackgroundColor3 = Color3.fromRGB(22, 22, 22); frame.BorderSizePixel = 0; Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    local label = Instance.new("TextLabel", frame); label.Size = UDim2.new(0.4, 0, 1, 0); label.Position = UDim2.new(0, 12, 0, 0); label.Text = text; label.TextColor3 = Color3.fromRGB(220, 220, 220); label.Font = Enum.Font.GothamMedium; label.TextSize = 13; label.TextXAlignment = Enum.TextXAlignment.Left; label.BackgroundTransparency = 1
    local xOffset = 0.43
    
    if type(Config[configKey]) == "boolean" then
        local toggleBg = Instance.new("TextButton", frame); toggleBg.Size = UDim2.new(0, 40, 0, 20); toggleBg.Position = UDim2.new(xOffset, 0, 0.5, -10); toggleBg.BackgroundColor3 = Config[configKey] and Color3.new(1,1,1) or Color3.fromRGB(40, 40, 40); toggleBg.Text = ""; toggleBg.AutoButtonColor = false; Instance.new("UICorner", toggleBg).CornerRadius = UDim.new(1, 0)
        local toggleKnob = Instance.new("Frame", toggleBg); toggleKnob.Size = UDim2.new(0, 16, 0, 16); toggleKnob.Position = UDim2.new(0, Config[configKey] and 22 or 2, 0.5, -8); toggleKnob.BackgroundColor3 = Color3.new(1, 1, 1); Instance.new("UICorner", toggleKnob).CornerRadius = UDim.new(1, 0)

        toggleBg.MouseButton1Click:Connect(function()
            Config[configKey] = not Config[configKey]; local state = Config[configKey]
            TweenService:Create(toggleKnob, TweenInfoFast, {Position = UDim2.new(0, state and 22 or 2, 0.5, -8)}):Play()
            if state then TweenService:Create(toggleBg, TweenInfoFast, {BackgroundColor3 = Color3.new(1,1,1)}):Play()
            else TweenService:Create(toggleBg, TweenInfoFast, {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}):Play() end
            if configKey == "Fling_Enabled" and not state then isFlingToggled = false; FlingTarget = nil end
        end)
        xOffset = xOffset + 0.1
    end

    if modeKey then
        local modeBtn = Instance.new("TextButton", frame); modeBtn.Size = UDim2.new(0, 90, 0, 24); modeBtn.Position = UDim2.new(xOffset, 0, 0.5, -12); modeBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35); modeBtn.Text = cycleOptions and "Mode: " .. Config[modeKey] or Config[modeKey]; modeBtn.TextColor3 = Color3.new(1,1,1); modeBtn.Font = Enum.Font.GothamSemibold; modeBtn.TextSize = 11; Instance.new("UICorner", modeBtn).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", modeBtn).Color = Color3.fromRGB(50, 50, 50)
        modeBtn.MouseButton1Click:Connect(function()
            if cycleOptions then local idx = table.find(cycleOptions, Config[modeKey]) or 1; Config[modeKey] = cycleOptions[idx % #cycleOptions + 1]; modeBtn.Text = "Mode: " .. Config[modeKey]
            else Config[modeKey] = Config[modeKey] == "Hold" and "Toggle" or "Hold"; modeBtn.Text = Config[modeKey] end
        end)
        xOffset = xOffset + 0.18
    end

    if bindKey then
        local bindBtn = Instance.new("TextButton", frame); bindBtn.Size = UDim2.new(0, 95, 0, 24); bindBtn.Position = UDim2.new(xOffset, 0, 0.5, -12); bindBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30); bindBtn.Text = "Bind: " .. Config[bindKey].Name; bindBtn.TextColor3 = Color3.new(1,1,1); bindBtn.Font = Enum.Font.GothamSemibold; bindBtn.TextSize = 11; Instance.new("UICorner", bindBtn).CornerRadius = UDim.new(0, 4); Instance.new("UIStroke", bindBtn).Color = Color3.fromRGB(50, 50, 50)
        bindButtons[bindKey] = bindBtn 
        bindBtn.MouseButton1Click:Connect(function() bindBtn.Text = "..."; bindingTarget = bindKey end)
    end
end

local function AddSlider(parentTab, text, configKey, min, max)
    local frame = Instance.new("Frame", parentTab); frame.Size = UDim2.new(1, -8, 0, 50); frame.BackgroundColor3 = Color3.fromRGB(22, 22, 22); Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6); frame.BorderSizePixel = 0
    local label = Instance.new("TextLabel", frame); label.Size = UDim2.new(1, -24, 0, 20); label.Position = UDim2.new(0, 12, 0, 6); label.Text = text; label.TextColor3 = Color3.fromRGB(220, 220, 220); label.Font = Enum.Font.GothamMedium; label.TextSize = 13; label.TextXAlignment = Enum.TextXAlignment.Left; label.BackgroundTransparency = 1
    local valueLabel = Instance.new("TextLabel", frame); valueLabel.Size = UDim2.new(0, 50, 0, 20); valueLabel.Position = UDim2.new(1, -62, 0, 6); valueLabel.Text = tostring(Config[configKey]); valueLabel.TextColor3 = Color3.new(1,1,1); valueLabel.Font = Enum.Font.GothamBold; valueLabel.TextSize = 13; valueLabel.TextXAlignment = Enum.TextXAlignment.Right; valueLabel.BackgroundTransparency = 1
    
    local sliderBg = Instance.new("Frame", frame); sliderBg.Size = UDim2.new(1, -24, 0, 6); sliderBg.Position = UDim2.new(0, 12, 0, 34); sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40); Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)
    local sliderFill = Instance.new("Frame", sliderBg); sliderFill.Size = UDim2.new((Config[configKey]-min)/(max-min), 0, 1, 0); sliderFill.BackgroundColor3 = Color3.new(1,1,1); Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)
    
    local sliderKnob = Instance.new("Frame", sliderFill); sliderKnob.Size = UDim2.new(0, 12, 0, 12); sliderKnob.Position = UDim2.new(1, -6, 0.5, -6); sliderKnob.BackgroundColor3 = Color3.new(1, 1, 1); Instance.new("UICorner", sliderKnob).CornerRadius = UDim.new(1, 0)
    local trigger = Instance.new("TextButton", sliderBg); trigger.Size = UDim2.new(1, 0, 1, 20); trigger.Position = UDim2.new(0, 0, 0.5, -10); trigger.BackgroundTransparency = 1; trigger.Text = ""
    local isSliding = false
    trigger.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then isSliding = true; TweenService:Create(sliderKnob, TweenInfoFast, {Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(1, -8, 0.5, -8)}):Play() end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then isSliding = false; TweenService:Create(sliderKnob, TweenInfoFast, {Size = UDim2.new(0, 12, 0, 12), Position = UDim2.new(1, -6, 0.5, -6)}):Play() end end)
    RunService.RenderStepped:Connect(function()
        if isSliding then
            local relPos = math.clamp((UIS:GetMouseLocation().X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            local value = math.floor(min + (max - min) * relPos); Config[configKey] = value; valueLabel.Text = tostring(value); TweenService:Create(sliderFill, TweenInfo.new(0.05), {Size = UDim2.new(relPos, 0, 1, 0)}):Play()
            if configKey == "Aim_FOV_Radius" then FOV_Circle.Size = UDim2.new(0, value * 2, 0, value * 2) end
        end
    end)
end

local function AddRGBPicker(parentTab, text, colorKey)
    local frame = Instance.new("Frame", parentTab); frame.Size = UDim2.new(1, -8, 0, 90); frame.BackgroundColor3 = Color3.fromRGB(22, 22, 22); Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6); frame.BorderSizePixel = 0
    local label = Instance.new("TextLabel", frame); label.Size = UDim2.new(1, -24, 0, 20); label.Position = UDim2.new(0, 12, 0, 6); label.Text = text; label.TextColor3 = Color3.fromRGB(220, 220, 220); label.Font = Enum.Font.GothamMedium; label.TextSize = 13; label.TextXAlignment = Enum.TextXAlignment.Left; label.BackgroundTransparency = 1
    local preview = Instance.new("Frame", frame); preview.Size = UDim2.new(0, 30, 0, 14); preview.Position = UDim2.new(1, -42, 0, 9); preview.BackgroundColor3 = Config[colorKey]; Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 4)
    local function MakeColorSlider(yOffset, cType, default)
        local sliderBg = Instance.new("Frame", frame); sliderBg.Size = UDim2.new(1, -24, 0, 6); sliderBg.Position = UDim2.new(0, 12, 0, yOffset); sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 40); Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(1, 0)
        local sliderFill = Instance.new("Frame", sliderBg); sliderFill.Size = UDim2.new(default/255, 0, 1, 0); sliderFill.BackgroundColor3 = cType == "R" and Color3.fromRGB(255,50,50) or (cType == "G" and Color3.fromRGB(50,255,50) or Color3.fromRGB(50,50,255)); Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(1, 0)
        local trigger = Instance.new("TextButton", sliderBg); trigger.Size = UDim2.new(1, 0, 1, 10); trigger.Position = UDim2.new(0, 0, 0.5, -5); trigger.BackgroundTransparency = 1; trigger.Text = ""
        local isSliding = false
        trigger.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then isSliding = true end end)
        UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then isSliding = false end end)
        RunService.RenderStepped:Connect(function()
            if isSliding then
                local relPos = math.clamp((UIS:GetMouseLocation().X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1); sliderFill.Size = UDim2.new(relPos, 0, 1, 0)
                local currentC = Config[colorKey]; local r = cType == "R" and relPos*255 or currentC.R*255; local g = cType == "G" and relPos*255 or currentC.G*255; local b = cType == "B" and relPos*255 or currentC.B*255
                Config[colorKey] = Color3.fromRGB(r, g, b); preview.BackgroundColor3 = Config[colorKey]
            end
        end)
    end
    MakeColorSlider(35, "R", Config[colorKey].R*255); MakeColorSlider(55, "G", Config[colorKey].G*255); MakeColorSlider(75, "B", Config[colorKey].B*255)
end

-- Меню элементы
local espPosOpts = {"Top", "Bottom", "Left", "Right"}
AddSetting(TabAim, "Enable Aimbot", "Aim_Enabled", "Aim_Bind")
AddSetting(TabAim, "Silent Aim (Safe Hook)", "Aim_Silent")
AddSetting(TabAim, "Aim Method", nil, nil, "Aim_Mode", {"Camera", "Mouse"})
AddSetting(TabAim, "Aim Target", nil, nil, "Aim_Target", {"Head", "Torso"})
AddSetting(TabAim, "Team Check", "Aim_TeamCheck")
AddSetting(TabAim, "Show FOV Circle", "Aim_FOV_Show")
AddSlider(TabAim, "FOV Radius", "Aim_FOV_Radius", 10, 600)
AddSlider(TabAim, "Smoothness", "Aim_Smooth", 1, 100)
AddSlider(TabAim, "Prediction", "Aim_Predict", 0, 20)

AddSetting(TabESP, "Master Switch", "ESP_Enabled")
AddSetting(TabESP, "Team Check", "ESP_TeamCheck")
AddSetting(TabESP, "Show on Self", "ESP_ShowSelf")
AddSetting(TabESP, "Draw Boxes", "ESP_Box")
AddSetting(TabESP, "Draw Skeleton", "ESP_Skeleton")
AddSetting(TabESP, "Draw Tracers", "ESP_Tracers")
AddSetting(TabESP, "HP Bar", "ESP_HPBar", nil, "ESP_HPBar_Pos", espPosOpts)
AddSetting(TabESP, "Name", "ESP_Name", nil, "ESP_Name_Pos", espPosOpts)
AddSetting(TabESP, "Distance", "ESP_Dist", nil, "ESP_Dist_Pos", espPosOpts)
AddSetting(TabESP, "HP Text", "ESP_HPText", nil, "ESP_HPText_Pos", espPosOpts)
AddSetting(TabESP, "Faction", "ESP_Faction", nil, "ESP_Faction_Pos", espPosOpts)

AddSetting(TabMovement, "Teleport", "TP_Enabled", "TP_Bind")
AddSetting(TabMovement, "Noclip", "Noclip_Enabled", "Noclip_Bind")
AddSetting(TabMovement, "Fly", "Fly_Enabled", "Fly_Bind")
AddSlider(TabMovement, "Fly Speed", "Fly_Speed", 10, 600)

AddSetting(TabMisc, "Vehicle Fling", "Fling_Enabled", "Fling_Bind")
AddSlider(TabMisc, "Fling Spin Speed", "Fling_SpinSpeed", 50, 1000)
AddSetting(TabMisc, "GTA Square", "Square_Enabled", "Square_Bind", "Square_Mode")
AddSetting(TabMisc, "Anti-Void", "Anti_Void")
AddSetting(TabMisc, "Bypass Chat Filter", "Bypass_Chat")

AddSetting(TabSettings, "Show Watermark", "Watermark_Enabled")
AddSetting(TabSettings, "Show Keybinds", "Keybinds_Enabled")
AddSetting(TabSettings, "Rainbow UI", "Rainbow_Enabled")
AddSlider(TabSettings, "Rainbow Speed", "Rainbow_Speed", 1, 10)
AddRGBPicker(TabSettings, "UI Color 1", "UIColor1")
AddRGBPicker(TabSettings, "UI Color 2", "UIColor2")

-- WM & Binds UI (Умный авто-размер ватермарки)
local WMScreen = Instance.new("ScreenGui", CoreGui); WMScreen.Name = "GameSync_WM"

local WMFrame = Instance.new("Frame", WMScreen)
WMFrame.AnchorPoint = Vector2.new(1, 0)
WMFrame.Position = UDim2.new(1, -10, 0, 10)
WMFrame.Size = UDim2.new(0, 0, 0, 32)
WMFrame.AutomaticSize = Enum.AutomaticSize.X
WMFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
Instance.new("UICorner", WMFrame).CornerRadius = UDim.new(0, 6)

local WMPad = Instance.new("UIPadding", WMFrame)
WMPad.PaddingLeft = UDim.new(0, 10)
WMPad.PaddingRight = UDim.new(0, 10)

local WMStroke = Instance.new("UIStroke", WMFrame); WMStroke.Thickness = 1.5
local WMGrad = Instance.new("UIGradient", WMStroke); table.insert(dynamicGradientObjects, WMGrad)

local WMText = Instance.new("TextLabel", WMFrame)
WMText.Size = UDim2.new(0, 0, 1, 0)
WMText.AutomaticSize = Enum.AutomaticSize.X
WMText.BackgroundTransparency = 1
WMText.TextColor3 = Color3.new(1,1,1)
WMText.Font = Enum.Font.GothamSemibold
WMText.TextSize = 14

local KBFrame = Instance.new("Frame", WMScreen); KBFrame.Size = UDim2.new(0, 160, 0, 30); KBFrame.Position = UDim2.new(0, 10, 0.5, 0); KBFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15); Instance.new("UICorner", KBFrame).CornerRadius = UDim.new(0, 6)
local KBStroke = Instance.new("UIStroke", KBFrame); KBStroke.Thickness = 1.5; local KBGrad = Instance.new("UIGradient", KBStroke); table.insert(dynamicGradientObjects, KBGrad)
local KBTitle = Instance.new("TextLabel", KBFrame); KBTitle.Size = UDim2.new(1, 0, 0, 26); KBTitle.BackgroundTransparency = 1; KBTitle.Text = "⌨ Keybinds"; KBTitle.TextColor3 = Color3.new(1,1,1); KBTitle.Font = Enum.Font.GothamBold; KBTitle.TextSize = 12;
local KBLayout = Instance.new("UIListLayout", KBFrame); KBLayout.SortOrder = Enum.SortOrder.LayoutOrder; KBLayout.Padding = UDim.new(0, 2); KBLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center

local function MakeDraggable(frame)
    local drag, dragI, startP, dStart
    frame.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = true; dStart = i.Position; startP = frame.Position end end)
    frame.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end end)
    UIS.InputChanged:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseMovement then dragI = i end end)
    RunService.Heartbeat:Connect(function() if drag and dragI then frame.Position = UDim2.new(startP.X.Scale, startP.X.Offset + (dragI.Position.X - dStart.X), startP.Y.Scale, startP.Y.Offset + (dragI.Position.Y - dStart.Y)) end end)
end
MakeDraggable(WMFrame); MakeDraggable(KBFrame)

local function IsBindActive(bind)
    if not bind then return false end
    return (bind.EnumType == Enum.KeyCode and UIS:IsKeyDown(bind)) or (bind.EnumType == Enum.UserInputType and UIS:IsMouseButtonPressed(bind))
end

-- ESP Creation
local function CreateESP(player)
    local esp = { Drawings = {}, Skeleton = {}, BoxLines = {}, BoxOutlines = {} }
    pcall(function()
        for i = 1, 4 do esp.BoxOutlines[i] = Drawing.new("Line"); esp.BoxOutlines[i].Thickness = 3; esp.BoxOutlines[i].Color = Color3.new(0,0,0); esp.BoxLines[i] = Drawing.new("Line"); esp.BoxLines[i].Thickness = 1.5 end
        esp.Drawings.Tracer = Drawing.new("Line"); esp.Drawings.Tracer.Thickness = 1.5
        local function MakeText() local txt = Drawing.new("Text"); txt.Size = 13; txt.Center = true; txt.Outline = true; txt.Color = Color3.new(1,1,1); return txt end
        esp.Drawings.Name = MakeText(); esp.Drawings.Dist = MakeText(); esp.Drawings.HPText = MakeText(); esp.Drawings.Faction = MakeText()
        esp.Drawings.HPBarBg = Drawing.new("Square"); esp.Drawings.HPBarBg.Filled = true; esp.Drawings.HPBarBg.Color = Color3.new(0,0,0)
        esp.Drawings.HPBarFill = Drawing.new("Square"); esp.Drawings.HPBarFill.Filled = true
        for i = 1, 15 do local bone = Drawing.new("Line"); bone.Thickness = 1.5; esp.Skeleton[i] = bone end
    end)
    espCache[player] = esp
end
for _, p in pairs(Players:GetPlayers()) do CreateESP(p) end
table.insert(connections, Players.PlayerAdded:Connect(CreateESP))
table.insert(connections, Players.PlayerRemoving:Connect(function(p)
    if espCache[p] then pcall(function() 
        for i=1,4 do espCache[p].BoxLines[i]:Remove(); espCache[p].BoxOutlines[i]:Remove() end; 
        espCache[p].Drawings.Tracer:Remove(); espCache[p].Drawings.Name:Remove(); espCache[p].Drawings.Dist:Remove();
        espCache[p].Drawings.HPText:Remove(); espCache[p].Drawings.Faction:Remove();
        espCache[p].Drawings.HPBarBg:Remove(); espCache[p].Drawings.HPBarFill:Remove();
        for _, b in pairs(espCache[p].Skeleton) do b:Remove() end
    end); espCache[p] = nil end
end))

local function DrawBoneLine(boneObj, char, p1Name, p2Name, color)
    if not boneObj then return end
    local p1 = char:FindFirstChild(p1Name); local p2 = char:FindFirstChild(p2Name)
    if p1 and p2 then
        local pos1, vis1 = Camera:WorldToViewportPoint(p1.Position)
        local pos2, vis2 = Camera:WorldToViewportPoint(p2.Position)
        if vis1 or vis2 then
            boneObj.Visible = true; boneObj.From = Vector2.new(pos1.X, pos1.Y); boneObj.To = Vector2.new(pos2.X, pos2.Y); boneObj.Color = color; return
        end
    end
    boneObj.Visible = false
end

-- Aimbot Logic Target
local function GetClosestTarget()
    local closestPlayer = nil; local shortestDistance = Config.Aim_FOV_Radius; local mousePos = UIS:GetMouseLocation()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hum = p.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                if Config.Aim_TeamCheck and p.Team == LocalPlayer.Team then continue end
                local targetPart = p.Character:FindFirstChild(Config.Aim_Target == "Torso" and "HumanoidRootPart" or "Head")
                if targetPart then
                    local pos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                    if onScreen then
                        local dist = (Vector2.new(pos.X, pos.Y) - mousePos).Magnitude
                        if dist <= shortestDistance then shortestDistance = dist; closestPlayer = p end
                    end
                end
            end
        end
    end
    return closestPlayer
end

-- Основной цикл RenderStepped
local framesData = {}; local flyBodyVel = nil; local flyGyro = nil; local lastAntiFallTick = tick()
table.insert(connections, RunService.RenderStepped:Connect(function()
    local cTime = tick()
    
    -- FPS
    table.insert(framesData, cTime); while framesData[1] and framesData[1] < cTime - 1 do table.remove(framesData, 1) end
    
    -- Статичный Градиент
    local color1, color2
    if Config.Rainbow_Enabled then
        local rc = Color3.fromHSV((cTime * (Config.Rainbow_Speed/10)) % 1, 1, 1)
        color1 = rc; color2 = rc:Lerp(Color3.new(0,0,0), 0.3)
    else
        color1 = Config.UIColor1; color2 = Config.UIColor2
    end
    
    local staticFadeSequence = ColorSequence.new({ColorSequenceKeypoint.new(0, color1), ColorSequenceKeypoint.new(1, color2)})
    for _, grad in pairs(dynamicGradientObjects) do grad.Rotation = 90; grad.Color = staticFadeSequence end
    
    -- FOV & Target
    FOV_Circle.Visible = Config.Aim_FOV_Show
    if FOV_Circle.Visible then local mPos = UIS:GetMouseLocation(); FOV_Circle.Position = UDim2.new(0, mPos.X, 0, mPos.Y); FOV_Grad.Color = ColorSequence.new(color1) end
    pcall(function() CachedTarget = GetClosestTarget() end)

    -- Aimbot
    if Config.Aim_Enabled and not Config.Aim_Silent and IsBindActive(Config.Aim_Bind) then
        local target = CachedTarget
        if target and target.Character then
            local targetPart = target.Character:FindFirstChild(Config.Aim_Target == "Torso" and "HumanoidRootPart" or "Head")
            if targetPart then
                local aimPos = targetPart.Position + (targetPart.Velocity * (Config.Aim_Predict / 100))
                if Config.Aim_Mode == "Camera" then
                    Camera.CFrame = Camera.CFrame:Lerp(CFrame.new(Camera.CFrame.Position, aimPos), Config.Aim_Smooth == 1 and 1 or (1 / Config.Aim_Smooth))
                elseif Config.Aim_Mode == "Mouse" and mousemoverel then
                    local pos, onScreen = Camera:WorldToViewportPoint(aimPos)
                    if onScreen then
                        local mousePos = UIS:GetMouseLocation()
                        local sm = Config.Aim_Smooth == 1 and 1 or Config.Aim_Smooth
                        mousemoverel((pos.X - mousePos.X) / sm, (pos.Y - mousePos.Y) / sm)
                    end
                end
            end
        end
    end

    -- GTA Square
    local isSquareActive = (Config.Square_Enabled and ((Config.Square_Mode == "Hold" and IsBindActive(Config.Square_Bind)) or (Config.Square_Mode == "Toggle" and squareToggled)))
    if isSquareActive then
        local pos = GetSafePos(); SelectionBox.Color3 = color1
        if Config.Square_Visual == "Classic" then PreviewPart.Size = Vector3.new(4, 0.1, 4); PreviewPart.CFrame = CFrame.new(pos + Vector3.new(0, 0.05, 0))
        else PreviewPart.Size = Vector3.new(2, 0.6, 1.2); PreviewPart.CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(math.sin(cTime*2)*0.2, cTime * 1.5, math.cos(cTime*2)*0.2) end
        SelectionBox.Visible = true
    else SelectionBox.Visible = false end

    -- WM & Binds
    WMFrame.Visible = Config.Watermark_Enabled
    if Config.Watermark_Enabled then
        local ping = "N/A"; pcall(function() ping = math.floor(Stats.Network.ServerStatsItem["Data Ping"]:GetValue()) end)
        WMText.Text = string.format("GameSync WAR | %s | %d FPS | %s ms", LocalPlayer.Name, #framesData, ping); WMText.TextColor3 = color1
    end
    KBFrame.Visible = Config.Keybinds_Enabled
    if Config.Keybinds_Enabled then
        for _, child in pairs(KBFrame:GetChildren()) do if child:IsA("Frame") then child:Destroy() end end
        local activeBinds = {}
        if Config.Aim_Enabled then table.insert(activeBinds, {name = "AimBot", key = Config.Aim_Bind.Name}) end
        if Config.ESP_Enabled then table.insert(activeBinds, {name = "ESP Master", key = "Active"}) end
        if Config.Fly_Enabled then table.insert(activeBinds, {name = "Fly", key = Config.Fly_Bind.Name}) end
        if Config.Noclip_Enabled then table.insert(activeBinds, {name = "Noclip", key = Config.Noclip_Bind.Name}) end
        if isSquareActive then table.insert(activeBinds, {name = "GTA Square", key = Config.Square_Bind.Name}) end
        if isFlingToggled then table.insert(activeBinds, {name = "Flinging", key = Config.Fling_Bind.Name}) end
        for i, bind in ipairs(activeBinds) do
            local row = Instance.new("Frame", KBFrame); row.Size = UDim2.new(1, -10, 0, 20); row.BackgroundTransparency = 1
            local kn = Instance.new("TextLabel", row); kn.Size = UDim2.new(0, 30, 1, 0); kn.BackgroundColor3 = Color3.fromRGB(30,30,30); Instance.new("UICorner", kn).CornerRadius = UDim.new(0, 4); kn.Text = bind.key; kn.TextColor3 = color1; kn.Font = Enum.Font.GothamBold; kn.TextSize = 10
            local bn = Instance.new("TextLabel", row); bn.Size = UDim2.new(1, -40, 1, 0); bn.Position = UDim2.new(0, 35, 0, 0); bn.BackgroundTransparency = 1; bn.Text = bind.name; bn.TextColor3 = Color3.fromRGB(200,200,200); bn.Font = Enum.Font.GothamMedium; bn.TextSize = 11; bn.TextXAlignment = Enum.TextXAlignment.Left
        end
        KBFrame.Size = UDim2.new(0, 160, 0, 30 + (#activeBinds * 22)); KBTitle.TextColor3 = color1
    end

    -- Full ESP Render
    for player, esp in pairs(espCache) do
        local isVisible = false
        pcall(function()
            local char = player.Character; local isSelf = (player == LocalPlayer)
            if Config.ESP_Enabled and char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Head") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 and (not isSelf or Config.ESP_ShowSelf) then
                if not (Config.ESP_TeamCheck and player.Team == LocalPlayer.Team and not isSelf) then
                    local hrp = char.HumanoidRootPart; local head = char.Head
                    local headPos, onScreen1 = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                    
                    local leftFoot = char:FindFirstChild("LeftFoot") or char:FindFirstChild("Left Leg")
                    local rightFoot = char:FindFirstChild("RightFoot") or char:FindFirstChild("Right Leg")
                    local bottomY = hrp.Position.Y - 3
                    if leftFoot and rightFoot then bottomY = math.min(leftFoot.Position.Y, rightFoot.Position.Y) - 0.2 end
                    local bottomPos, onScreen2 = Camera:WorldToViewportPoint(Vector3.new(hrp.Position.X, bottomY, hrp.Position.Z))

                    if onScreen1 or onScreen2 then
                        isVisible = true
                        local height = math.abs(headPos.Y - bottomPos.Y); local width = height * 0.55 
                        local minX = headPos.X - width/2; local minY = headPos.Y; local maxX = headPos.X + width/2; local maxY = bottomPos.Y

                        -- Box
                        if Config.ESP_Box and esp.BoxLines then
                            local TL = Vector2.new(minX, minY); local TR = Vector2.new(maxX, minY); local BL = Vector2.new(minX, maxY); local BR = Vector2.new(maxX, maxY)
                            local function setLine(l, f, t, v, col) l.Visible = v; if v then l.From = f; l.To = t; l.Color = col end end
                            setLine(esp.BoxOutlines[1], TL, TR, true, Color3.new(0,0,0)); setLine(esp.BoxOutlines[2], TR, BR, true, Color3.new(0,0,0)); setLine(esp.BoxOutlines[3], BR, BL, true, Color3.new(0,0,0)); setLine(esp.BoxOutlines[4], BL, TL, true, Color3.new(0,0,0))
                            setLine(esp.BoxLines[1], TL, TR, true, color1); setLine(esp.BoxLines[2], TR, BR, true, color1); setLine(esp.BoxLines[3], BR, BL, true, color1); setLine(esp.BoxLines[4], BL, TL, true, color1)
                        else for i=1,4 do esp.BoxLines[i].Visible = false; esp.BoxOutlines[i].Visible = false end end

                        -- HP Bar
                        if Config.ESP_HPBar then
                            esp.Drawings.HPBarBg.Visible = true; esp.Drawings.HPBarFill.Visible = true
                            local hpPct = char.Humanoid.Health / char.Humanoid.MaxHealth; local barT = 3
                            esp.Drawings.HPBarFill.Color = GetCIELUVColor(hpPct)
                            if Config.ESP_HPBar_Pos == "Left" then
                                esp.Drawings.HPBarBg.Position = Vector2.new(minX - barT - 3, minY - 1); esp.Drawings.HPBarBg.Size = Vector2.new(barT + 2, height + 2)
                                esp.Drawings.HPBarFill.Position = Vector2.new(minX - barT - 2, minY + height - (height * hpPct)); esp.Drawings.HPBarFill.Size = Vector2.new(barT, height * hpPct)
                            elseif Config.ESP_HPBar_Pos == "Right" then
                                esp.Drawings.HPBarBg.Position = Vector2.new(maxX + 2, minY - 1); esp.Drawings.HPBarBg.Size = Vector2.new(barT + 2, height + 2)
                                esp.Drawings.HPBarFill.Position = Vector2.new(maxX + 3, minY + height - (height * hpPct)); esp.Drawings.HPBarFill.Size = Vector2.new(barT, height * hpPct)
                            elseif Config.ESP_HPBar_Pos == "Bottom" then
                                esp.Drawings.HPBarBg.Position = Vector2.new(minX - 1, maxY + 2); esp.Drawings.HPBarBg.Size = Vector2.new(width + 2, barT + 2)
                                esp.Drawings.HPBarFill.Position = Vector2.new(minX, maxY + 3); esp.Drawings.HPBarFill.Size = Vector2.new(width * hpPct, barT)
                            else 
                                esp.Drawings.HPBarBg.Position = Vector2.new(minX - 1, minY - barT - 3); esp.Drawings.HPBarBg.Size = Vector2.new(width + 2, barT + 2)
                                esp.Drawings.HPBarFill.Position = Vector2.new(minX, minY - barT - 2); esp.Drawings.HPBarFill.Size = Vector2.new(width * hpPct, barT)
                            end
                        else esp.Drawings.HPBarBg.Visible = false; esp.Drawings.HPBarFill.Visible = false end

                        -- Tracers
                        if Config.ESP_Tracers then
                            esp.Drawings.Tracer.Visible = true; esp.Drawings.Tracer.Color = color1
                            esp.Drawings.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y); esp.Drawings.Tracer.To = Vector2.new(headPos.X, maxY) 
                        else esp.Drawings.Tracer.Visible = false end

                        -- Texts
                        local function drawT(d, f, p, txt, col)
                            if Config[f] then
                                d.Visible = true; d.Text = txt; if col then d.Color = col end
                                local b = d.TextBounds
                                if Config[p] == "Top" then d.Position = Vector2.new(headPos.X, minY - b.Y - (Config.ESP_HPBar and Config.ESP_HPBar_Pos == "Top" and 6 or 2))
                                elseif Config[p] == "Bottom" then d.Position = Vector2.new(headPos.X, maxY + (Config.ESP_HPBar and Config.ESP_HPBar_Pos == "Bottom" and 6 or 2))
                                elseif Config[p] == "Left" then d.Position = Vector2.new(minX - b.X/2 - (Config.ESP_HPBar and Config.ESP_HPBar_Pos == "Left" and 8 or 4), minY + height/2 - b.Y/2)
                                elseif Config[p] == "Right" then d.Position = Vector2.new(maxX + b.X/2 + (Config.ESP_HPBar and Config.ESP_HPBar_Pos == "Right" and 8 or 4), minY + height/2 - b.Y/2) end
                            else d.Visible = false end
                        end

                        drawT(esp.Drawings.Name, "ESP_Name", "ESP_Name_Pos", player.Name, Color3.new(1,1,1))
                        drawT(esp.Drawings.Faction, "ESP_Faction", "ESP_Faction_Pos", player.Team and "["..player.Team.Name.."]" or "", player.TeamColor and player.TeamColor.Color or Color3.new(1,1,1))
                        drawT(esp.Drawings.HPText, "ESP_HPText", "ESP_HPText_Pos", math.floor(char.Humanoid.Health).." HP", GetCIELUVColor(char.Humanoid.Health / char.Humanoid.MaxHealth))
                        local distStr = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and math.floor((LocalPlayer.Character.HumanoidRootPart.Position - hrp.Position).Magnitude) .. "m" or ""
                        drawT(esp.Drawings.Dist, "ESP_Dist", "ESP_Dist_Pos", distStr, Color3.new(1,1,1))

                        -- Skeleton
                        if Config.ESP_Skeleton and esp.Skeleton then
                            if char:FindFirstChild("UpperTorso") then
                                DrawBoneLine(esp.Skeleton[1], char, "Head", "UpperTorso", color1); DrawBoneLine(esp.Skeleton[2], char, "UpperTorso", "LowerTorso", color1)
                                DrawBoneLine(esp.Skeleton[3], char, "UpperTorso", "LeftUpperArm", color1); DrawBoneLine(esp.Skeleton[4], char, "LeftUpperArm", "LeftLowerArm", color1)
                                DrawBoneLine(esp.Skeleton[5], char, "LeftLowerArm", "LeftHand", color1); DrawBoneLine(esp.Skeleton[6], char, "UpperTorso", "RightUpperArm", color1)
                                DrawBoneLine(esp.Skeleton[7], char, "RightUpperArm", "RightLowerArm", color1); DrawBoneLine(esp.Skeleton[8], char, "RightLowerArm", "RightHand", color1)
                                DrawBoneLine(esp.Skeleton[9], char, "LowerTorso", "LeftUpperLeg", color1); DrawBoneLine(esp.Skeleton[10], char, "LeftUpperLeg", "LeftLowerLeg", color1)
                                DrawBoneLine(esp.Skeleton[11], char, "LeftLowerLeg", "LeftFoot", color1); DrawBoneLine(esp.Skeleton[12], char, "LowerTorso", "RightUpperLeg", color1)
                                DrawBoneLine(esp.Skeleton[13], char, "RightUpperLeg", "RightLowerLeg", color1); DrawBoneLine(esp.Skeleton[14], char, "RightLowerLeg", "RightFoot", color1)
                            elseif char:FindFirstChild("Torso") then
                                DrawBoneLine(esp.Skeleton[1], char, "Head", "Torso", color1); DrawBoneLine(esp.Skeleton[2], char, "Torso", "Left Arm", color1)
                                DrawBoneLine(esp.Skeleton[3], char, "Torso", "Right Arm", color1); DrawBoneLine(esp.Skeleton[4], char, "Torso", "Left Leg", color1); DrawBoneLine(esp.Skeleton[5], char, "Torso", "Right Leg", color1)
                            end
                        else if esp.Skeleton then for _, bone in pairs(esp.Skeleton) do bone.Visible = false end end end
                    end
                end
            end
        end)
        if not isVisible then pcall(function() 
            for i=1,4 do esp.BoxLines[i].Visible = false; esp.BoxOutlines[i].Visible = false end
            esp.Drawings.Tracer.Visible = false; esp.Drawings.Name.Visible = false; esp.Drawings.Dist.Visible = false; esp.Drawings.HPText.Visible = false; esp.Drawings.Faction.Visible = false
            esp.Drawings.HPBarBg.Visible = false; esp.Drawings.HPBarFill.Visible = false
            if esp.Skeleton then for _, bone in pairs(esp.Skeleton) do bone.Visible = false end end
        end) end
    end

    -- Fly & Rvanka Logic
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local inVehicle = false; local vehicleRoot = nil
    
    if hum and hum.SeatPart then
        inVehicle = true
        local vehicleModel = hum.SeatPart:FindFirstAncestorOfClass("Model")
        vehicleRoot = (vehicleModel and vehicleModel.PrimaryPart) or hum.SeatPart
    end

    if isFlingToggled and Config.Fling_Enabled and FlingTarget and FlingTarget.Character then
        local targetHrp = FlingTarget.Character:FindFirstChild("HumanoidRootPart") or FlingTarget.Character:FindFirstChild("Torso")
        local targetHum = FlingTarget.Character:FindFirstChild("Humanoid")
        if hrp and targetHrp and targetHum and targetHum.Health > 0 then
            local dist = (hrp.Position - targetHrp.Position).Magnitude
            if dist > Config.Fling_MaxDist then isFlingToggled = false; FlingTarget = nil
            else
                if inVehicle and vehicleRoot then
                    if flyBodyVel then flyBodyVel:Destroy(); flyBodyVel = nil end
                    if flyGyro then flyGyro:Destroy(); flyGyro = nil end
                    vehicleRoot.CFrame = targetHrp.CFrame * CFrame.Angles(math.rad(math.random(0,360)), math.rad(math.random(0,360)), math.rad(math.random(0,360)))
                    vehicleRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    local s = Config.Fling_SpinSpeed; vehicleRoot.AssemblyAngularVelocity = Vector3.new(math.random(-s, s), math.random(-s, s), math.random(-s, s))
                end
            end
        else isFlingToggled = false; FlingTarget = nil end
    else isFlingToggled = false; FlingTarget = nil end

    if not isFlingToggled then
        local flyPart = inVehicle and vehicleRoot or hrp
        if Config.Fly_Enabled and flyPart then
            if not flyBodyVel then flyBodyVel = Instance.new("BodyVelocity"); flyBodyVel.Name = "GameSync_Fly"; flyBodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge); flyBodyVel.Parent = flyPart end
            if not flyGyro then flyGyro = Instance.new("BodyGyro"); flyGyro.Name = "GameSync_FlyGyro"; flyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge); flyGyro.P = 15000; flyGyro.D = 500; flyGyro.Parent = flyPart end
            if flyBodyVel.Parent ~= flyPart then flyBodyVel.Parent = flyPart end
            if flyGyro.Parent ~= flyPart then flyGyro.Parent = flyPart end

            local moveDir = Vector3.zero
            if UIS:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
            flyBodyVel.Velocity = moveDir * Config.Fly_Speed
            
            if inVehicle then flyGyro.CFrame = Camera.CFrame else flyGyro.CFrame = CFrame.new(flyPart.Position, flyPart.Position + Camera.CFrame.LookVector * Vector3.new(1,0,1)) end
            if Config.Fly_AntiFall and not inVehicle and cTime - lastAntiFallTick > 0.1 then flyPart.CFrame = flyPart.CFrame * CFrame.new(0, 0.05, 0); lastAntiFallTick = cTime end
        else
            if flyBodyVel then if Config.Fly_AntiFall and flyPart and not inVehicle then flyPart.Velocity = Vector3.new(0,0,0) end; flyBodyVel:Destroy(); flyBodyVel = nil end
            if flyGyro then flyGyro:Destroy(); flyGyro = nil end
        end
    end
end))

-- Noclip Logic (Stepped Loop)
local lastNoclipState = false
table.insert(connections, RunService.Stepped:Connect(function()
    if Config.Noclip_Enabled then
        if LocalPlayer.Character then for _, part in pairs(LocalPlayer.Character:GetDescendants()) do if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end end end
        lastNoclipState = true
    elseif lastNoclipState then
        if LocalPlayer.Character then for _, part in pairs(LocalPlayer.Character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = true end end end
        lastNoclipState = false
    end
end))

-- Anti Void Loop
local function ToolMatch(Handle)
    for _, Player in ipairs(Players:GetPlayers()) do
        if Player ~= LocalPlayer and Player.Character then
            local RightArm = Player.Character:FindFirstChild("Right Arm") or Player.Character:FindFirstChild("RightHand")
            if RightArm then
                local RightGrip = RightArm:FindFirstChild("RightGrip")
                if RightGrip and RightGrip.Part1 == Handle then return Player end
            end
        end
    end
end
local function OnCharacterAdded(Character)
    local RightArm = Character:WaitForChild("Right Arm", 3) or Character:WaitForChild("RightHand", 3)
    if RightArm then
        table.insert(connections, RightArm.ChildAdded:Connect(function(child)
            if Config.Anti_Void and child:IsA("Weld") and child.Name == "RightGrip" then
                local ConnectedHandle = child.Part1; local matched = ToolMatch(ConnectedHandle)
                if matched and ConnectedHandle and ConnectedHandle.Parent then ConnectedHandle.Parent:Destroy() end
            end
        end))
    end
end
if LocalPlayer.Character then OnCharacterAdded(LocalPlayer.Character) end
table.insert(connections, LocalPlayer.CharacterAdded:Connect(OnCharacterAdded))

-- Защищенные Хуки
pcall(function()
    if hookmetamethod then
        local oldNamecall; oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            if not checkcaller() then
                local method = getnamecallmethod()
                if Config.Anti_Kick and self == LocalPlayer and tostring(method):lower() == "kick" then return end
                if Config.Bypass_Chat and method == "FireServer" and tostring(self) == "SayMessageRequest" then
                    local args = {...}; if type(args[1]) == "string" then
                        local sep = "\243\160\128\149\243\160\128\150\243\160\128\151\243\160\128\152"
                        local words = string.split(string.gsub(args[1], "[%p]+", ""), " ")
                        for i = 1, #words do local w = words[i]; local nw = ""; for j = 1, #w do nw = nw .. string.sub(w, j, j); if j % 2 == 0 and j ~= #w then nw = nw .. sep end end; words[i] = nw end
                        args[1] = table.concat(words, " "); return oldNamecall(self, unpack(args))
                    end
                end
            end
            return oldNamecall(self, ...)
        end)
        local oldIndex; oldIndex = hookmetamethod(game, "__index", function(t, k)
            if not checkcaller() and Config.Aim_Silent and typeof(t) == "Instance" and t:IsA("Mouse") and (k == "Hit" or k == "Target") then
                if CachedTarget and CachedTarget.Character then
                    local targetPart = CachedTarget.Character:FindFirstChild(Config.Aim_Target == "Torso" and "HumanoidRootPart" or "Head")
                    if targetPart then return k == "Hit" and targetPart.CFrame or targetPart end
                end
            end
            return oldIndex(t, k)
        end)
    end
end)

-- Anti-Idle
table.insert(connections, LocalPlayer.Idled:Connect(function()
    if Config.Anti_Idle then VirtualInputManager:SendMouseButtonEvent(0,0,2,true,nil,0); task.wait(1); VirtualInputManager:SendMouseButtonEvent(0,0,2,false,nil,0) end
end))

-- Binds Input
table.insert(connections, UIS.InputBegan:Connect(function(input, processed)
    local isMouse = string.find(input.UserInputType.Name, "MouseButton"); local isKey = input.UserInputType == Enum.UserInputType.Keyboard
    if bindingTarget then
        if input.UserInputState == Enum.UserInputState.Begin then
            if isKey and input.KeyCode == Enum.KeyCode.Escape then bindingTarget = nil; return end
            if isKey and input.KeyCode ~= Enum.KeyCode.Unknown then
                Config[bindingTarget] = input.KeyCode; if bindButtons[bindingTarget] then bindButtons[bindingTarget].Text = "Bind: " .. input.KeyCode.Name end; bindingTarget = nil
            elseif isMouse then
                Config[bindingTarget] = input.UserInputType; if bindButtons[bindingTarget] then bindButtons[bindingTarget].Text = "Bind: " .. input.UserInputType.Name end; bindingTarget = nil
            end
        end; return
    end
    if processed and not isMouse then return end 
    if input.UserInputState == Enum.UserInputState.Begin then
        if IsBindActive(Config.Menu_Bind) then MainFrame.Visible = not MainFrame.Visible end
        if IsBindActive(Config.Unbind_Key) then SelfDestruct() end
        if IsBindActive(Config.Noclip_Bind) then Config.Noclip_Enabled = not Config.Noclip_Enabled end
        if IsBindActive(Config.Fly_Bind) then Config.Fly_Enabled = not Config.Fly_Enabled end
        if Config.Square_Enabled and Config.Square_Mode == "Toggle" and IsBindActive(Config.Square_Bind) then squareToggled = not squareToggled end
        if IsBindActive(Config.Fling_Bind) and Config.Fling_Enabled then
            if isFlingToggled then isFlingToggled = false; FlingTarget = nil else local t = CachedTarget; if t then isFlingToggled = true; FlingTarget = t end end
        end
        if IsBindActive(Config.TP_Bind) and Config.TP_Enabled then
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then
                local rp = RaycastParams.new(); rp.FilterDescendantsInstances = {LocalPlayer.Character, PreviewPart}; rp.FilterType = Enum.RaycastFilterType.Exclude
                local ray = workspace:Raycast(Mouse.UnitRay.Origin, Mouse.UnitRay.Direction * 1000, rp)
                hrp.CFrame = CFrame.new((ray and ray.Position or Mouse.Hit.Position) + Vector3.new(0, 3, 0))
            end
        end
    end
end))
