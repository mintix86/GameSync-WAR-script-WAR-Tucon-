-- Сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local VirtualInputManager = game:GetService("VirtualInputManager")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

-- Плавный цвет ХП
local function GetCIELUVColor(percentage)
    local green = Color3.fromRGB(46, 204, 113)
    local red = Color3.fromRGB(231, 76, 60)
    return red:Lerp(green, percentage)
end

-- Глобальные настройки
local Config = {
    MainColor = Color3.fromHex("c795ed"),
    Rainbow_Enabled = false,
    Rainbow_Speed = 0.5,
    
    -- Aim
    Aim_Enabled = false,
    Aim_Silent = false, 
    Aim_Bind = Enum.UserInputType.MouseButton2,
    Aim_Mode = "Camera", 
    Aim_Target = "Head", 
    Aim_Smooth = 20, 
    Aim_Predict = 0, 
    Aim_TeamCheck = false,
    Aim_FOV_Show = true,
    Aim_FOV_Radius = 150,
    
    -- Movement
    TP_Enabled = false,
    TP_Bind = Enum.KeyCode.E,
    Noclip_Enabled = false,
    Noclip_Bind = Enum.KeyCode.N,
    Fly_Enabled = false,
    Fly_Bind = Enum.KeyCode.F,
    Fly_Speed = 50,
    Fly_AntiFall = true,
    
    -- ESP
    ESP_Enabled = false,
    ESP_TeamCheck = false,
    ESP_ShowSelf = false,
    ESP_Box = true,
    ESP_Skeleton = false, 
    ESP_Tracers = false,
    
    ESP_Name = true;     ESP_Name_Pos = "Top",
    ESP_HPText = true;   ESP_HPText_Pos = "Right",
    ESP_Dist = true;     ESP_Dist_Pos = "Bottom",
    ESP_Faction = true;  ESP_Faction_Pos = "Top",
    ESP_HPBar = true;    ESP_HPBar_Pos = "Left",
    
    -- Misc
    Fling_Enabled = false, 
    Fling_Bind = Enum.KeyCode.V,
    Fling_SpinSpeed = 500,
    Fling_MaxDist = 10000, 
    
    Anti_Void = false, 
    Bypass_Chat = false,
    Anti_Kick = true, 
    Anti_Idle = true, 
    Square_Enabled = false,
    Square_Bind = Enum.KeyCode.P,
    Square_Mode = "Toggle", 
    Square_Visual = "3D Wireframe",
    
    Menu_Bind = Enum.KeyCode.RightShift,
    Unbind_Key = Enum.KeyCode.End
}

local UI_NAME = "GameSync_WAR"
local connections = {}
local bindButtons = {}
local themeObjects = {}
local espCache = {} 
local bindingTarget = nil 
local squareToggled = false

-- Кэш для Silent Aim
local CachedTarget = nil
local isFlingToggled = false
local FlingTarget = nil

-- === ФУНКЦИЯ ОЧИСТКИ ===
local FlingIndicator
pcall(function() FlingIndicator = Drawing.new("Text") end)

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
    
    if FlingIndicator then FlingIndicator:Remove() end
    if CoreGui:FindFirstChild(UI_NAME) then CoreGui[UI_NAME]:Destroy() end
    if CoreGui:FindFirstChild("GameSync_FOV") then CoreGui.GameSync_FOV:Destroy() end
    if workspace:FindFirstChild("TP_Preview") then workspace.TP_Preview:Destroy() end
    if LocalPlayer.Character then
        for _, obj in pairs(LocalPlayer.Character:GetDescendants()) do
            if obj.Name == "GameSync_Fly" or obj.Name == "GameSync_FlyGyro" then obj:Destroy() end
        end
    end
    print("--- GameSync WAR Unloaded ---")
end

if CoreGui:FindFirstChild(UI_NAME) then SelfDestruct() end

-- Индикатор захвата (Рванка)
if FlingIndicator then
    FlingIndicator.Size = 14; FlingIndicator.Center = true; FlingIndicator.Outline = true
    FlingIndicator.Color = Config.MainColor; FlingIndicator.Visible = false
    table.insert(themeObjects, {Obj = FlingIndicator, Prop = "Color"})
end

-- === FOV CIRCLE UI ===
local FOV_Gui = Instance.new("ScreenGui", CoreGui)
FOV_Gui.Name = "GameSync_FOV"; FOV_Gui.IgnoreGuiInset = true

local FOV_Circle = Instance.new("Frame", FOV_Gui)
FOV_Circle.BackgroundTransparency = 1
FOV_Circle.Size = UDim2.new(0, Config.Aim_FOV_Radius * 2, 0, Config.Aim_FOV_Radius * 2)
FOV_Circle.AnchorPoint = Vector2.new(0.5, 0.5)
local FOV_Stroke = Instance.new("UIStroke", FOV_Circle)
FOV_Stroke.Color = Config.MainColor; FOV_Stroke.Thickness = 1
Instance.new("UICorner", FOV_Circle).CornerRadius = UDim.new(1, 0)
table.insert(themeObjects, {Obj = FOV_Stroke, Prop = "Color"})

-- === МИНИМАЛИСТИЧНЫЙ ИНТЕРФЕЙС ===
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = UI_NAME; ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 540, 0, 420)
MainFrame.Position = UDim2.new(0.5, -270, 0.5, -210)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
MainFrame.BorderSizePixel = 0; MainFrame.Active = true; MainFrame.ClipsDescendants = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 4)

local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 30); TopBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
TopBar.BorderSizePixel = 0

local Title = Instance.new("TextLabel", TopBar)
Title.Size = UDim2.new(1, -20, 1, 0); Title.Position = UDim2.new(0, 15, 0, 0)
Title.Text = "GAMESYNC WAR"; Title.TextColor3 = Config.MainColor
Title.Font = Enum.Font.GothamBold; Title.TextSize = 12
Title.BackgroundTransparency = 1; Title.TextXAlignment = Enum.TextXAlignment.Left
table.insert(themeObjects, {Obj = Title, Prop = "TextColor3"})

local TopBarLine = Instance.new("Frame", TopBar)
TopBarLine.Size = UDim2.new(1, 0, 0, 1); TopBarLine.Position = UDim2.new(0, 0, 1, -1)
TopBarLine.BackgroundColor3 = Config.MainColor; TopBarLine.BorderSizePixel = 0
table.insert(themeObjects, {Obj = TopBarLine, Prop = "BackgroundColor3"})

local dragging, dragInput, dragStart, startPos
table.insert(connections, TopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true; dragStart = input.Position; startPos = MainFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end))
table.insert(connections, UIS.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
end))
table.insert(connections, RunService.Heartbeat:Connect(function()
    if dragging and dragInput then 
        local delta = dragInput.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end))

local TabContainer = Instance.new("Frame", MainFrame)
TabContainer.Size = UDim2.new(1, -20, 0, 26); TabContainer.Position = UDim2.new(0, 10, 0, 40)
TabContainer.BackgroundTransparency = 1
local TabLayout = Instance.new("UIListLayout", TabContainer)
TabLayout.FillDirection = Enum.FillDirection.Horizontal; TabLayout.SortOrder = Enum.SortOrder.LayoutOrder; TabLayout.Padding = UDim.new(0, 5)

local PagesContainer = Instance.new("Frame", MainFrame)
PagesContainer.Size = UDim2.new(1, -20, 1, -85); PagesContainer.Position = UDim2.new(0, 10, 0, 75)
PagesContainer.BackgroundTransparency = 1

local tabs, pages = {}, {}
local function CreateTab(name, isFirst)
    local tabBtn = Instance.new("TextButton", TabContainer)
    tabBtn.Size = UDim2.new(0, 100, 1, 0); tabBtn.BackgroundColor3 = isFirst and Config.MainColor or Color3.fromRGB(25, 25, 25)
    tabBtn.Text = name; tabBtn.TextColor3 = isFirst and Color3.fromRGB(15, 15, 15) or Color3.new(1,1,1)
    tabBtn.Font = Enum.Font.GothamBold; tabBtn.TextSize = 11
    Instance.new("UICorner", tabBtn).CornerRadius = UDim.new(0, 4)
    if isFirst then table.insert(themeObjects, {Obj = tabBtn, Prop = "BackgroundColor3"}) end

    local page = Instance.new("ScrollingFrame", PagesContainer)
    page.Size = UDim2.new(1, 0, 1, 0); page.BackgroundTransparency = 1
    page.CanvasSize = UDim2.new(0, 0, 0, 0); page.AutomaticCanvasSize = Enum.AutomaticSize.Y
    page.ScrollBarThickness = 3; page.ScrollBarImageColor3 = Config.MainColor; page.Visible = isFirst
    page.BorderSizePixel = 0
    table.insert(themeObjects, {Obj = page, Prop = "ScrollBarImageColor3"})
    
    local layout = Instance.new("UIListLayout", page)
    layout.Padding = UDim.new(0, 6); layout.SortOrder = Enum.SortOrder.LayoutOrder

    table.insert(tabs, tabBtn); table.insert(pages, page)

    table.insert(connections, tabBtn.MouseButton1Click:Connect(function()
        for i, p in pairs(pages) do
            p.Visible = (p == page)
            if p == page then
                tabs[i].BackgroundColor3 = Config.MainColor; tabs[i].TextColor3 = Color3.fromRGB(15, 15, 15)
                for k, v in pairs(themeObjects) do if v.Obj == tabs[i] then table.remove(themeObjects, k) end end
                table.insert(themeObjects, {Obj = tabs[i], Prop = "BackgroundColor3"})
            else
                tabs[i].BackgroundColor3 = Color3.fromRGB(25, 25, 25); tabs[i].TextColor3 = Color3.new(1,1,1)
                for k, v in pairs(themeObjects) do if v.Obj == tabs[i] then table.remove(themeObjects, k) end end
            end
        end
    end))
    return page
end

local TabAim = CreateTab("Aim", true)
local TabESP = CreateTab("ESP", false)
local TabMovement = CreateTab("Movement", false)
local TabMisc = CreateTab("Misc", false)

local function CreateButton(parent, text, color, pos, size)
    local btn = Instance.new("TextButton", parent)
    btn.Size = size; btn.Position = pos; btn.BackgroundColor3 = color
    btn.Text = text; btn.TextColor3 = Color3.new(1,1,1)
    btn.Font = Enum.Font.GothamSemibold; btn.TextSize = 11
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 3)
    return btn
end

local function AddSetting(parentTab, text, configKey, bindKey, modeKey, cycleOptions)
    local frame = Instance.new("Frame", parentTab)
    frame.Size = UDim2.new(1, -5, 0, 32); frame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    frame.BorderSizePixel = 0
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 4)

    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.4, 0, 1, 0); label.Position = UDim2.new(0, 10, 0, 0)
    label.Text = text; label.TextColor3 = Color3.new(1,1,1)
    label.Font = Enum.Font.Gotham; label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left; label.BackgroundTransparency = 1

    local xOffset = 0.45
    if type(Config[configKey]) == "boolean" then
        local stateColor = Config[configKey] and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(200, 60, 60)
        local toggle = CreateButton(frame, Config[configKey] and "ON" or "OFF", stateColor, UDim2.new(xOffset, 0, 0.5, -11), UDim2.new(0, 50, 0, 22))
        table.insert(connections, toggle.MouseButton1Click:Connect(function()
            Config[configKey] = not Config[configKey]
            toggle.Text = Config[configKey] and "ON" or "OFF"
            toggle.BackgroundColor3 = Config[configKey] and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(200, 60, 60)
            if configKey == "Fling_Enabled" and not Config.Fling_Enabled then
                isFlingToggled = false; FlingTarget = nil
            end
        end))
        xOffset = xOffset + 0.11
    end

    if modeKey then
        local isPosMode = cycleOptions and table.find(cycleOptions, "Top") 
        local btnSize = isPosMode and UDim2.new(0, 60, 0, 22) or UDim2.new(0, 80, 0, 22)
        local modeText = isPosMode and Config[modeKey] or (cycleOptions and "Mode: " .. Config[modeKey] or Config[modeKey])
        
        local modeBtn = CreateButton(frame, modeText, Color3.fromRGB(41, 128, 185), UDim2.new(xOffset, 0, 0.5, -11), btnSize)
        table.insert(connections, modeBtn.MouseButton1Click:Connect(function()
            if cycleOptions then
                local idx = table.find(cycleOptions, Config[modeKey]) or 1
                Config[modeKey] = cycleOptions[idx % #cycleOptions + 1]
                modeBtn.Text = isPosMode and Config[modeKey] or "Mode: " .. Config[modeKey]
            else
                Config[modeKey] = Config[modeKey] == "Hold" and "Toggle" or "Hold"
                modeBtn.Text = Config[modeKey]; squareToggled = false
            end
        end))
        xOffset = xOffset + (isPosMode and 0.13 or 0.17)
    end

    if bindKey then
        local bindBtn = CreateButton(frame, "Bind: " .. Config[bindKey].Name, Color3.fromRGB(45, 45, 45), UDim2.new(xOffset, 0, 0.5, -11), UDim2.new(0, 90, 0, 22))
        bindBtn.TextColor3 = Config.MainColor
        table.insert(themeObjects, {Obj = bindBtn, Prop = "TextColor3"})
        bindButtons[bindKey] = bindBtn 
        table.insert(connections, bindBtn.MouseButton1Click:Connect(function()
            bindBtn.Text = "..."; bindingTarget = bindKey
        end))
    end
end

local function AddSlider(parentTab, text, configKey, min, max)
    local frame = Instance.new("Frame", parentTab)
    frame.Size = UDim2.new(1, -5, 0, 42); frame.BackgroundColor3 = Color3.fromRGB(22, 22, 22)
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 4); frame.BorderSizePixel = 0
    
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -20, 0, 18); label.Position = UDim2.new(0, 10, 0, 4)
    label.Text = text .. ": " .. Config[configKey]; label.TextColor3 = Color3.new(1,1,1)
    label.Font = Enum.Font.Gotham; label.TextSize = 12; label.TextXAlignment = Enum.TextXAlignment.Left; label.BackgroundTransparency = 1
    
    local sliderBg = Instance.new("Frame", frame)
    sliderBg.Size = UDim2.new(1, -20, 0, 4); sliderBg.Position = UDim2.new(0, 10, 0, 28); sliderBg.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    Instance.new("UICorner", sliderBg).CornerRadius = UDim.new(0, 2); sliderBg.BorderSizePixel = 0
    
    local sliderFill = Instance.new("Frame", sliderBg)
    sliderFill.Size = UDim2.new((Config[configKey] - min)/(max - min), 0, 1, 0); sliderFill.BackgroundColor3 = Config.MainColor
    Instance.new("UICorner", sliderFill).CornerRadius = UDim.new(0, 2); sliderFill.BorderSizePixel = 0
    table.insert(themeObjects, {Obj = sliderFill, Prop = "BackgroundColor3"})
    
    local trigger = Instance.new("TextButton", sliderBg)
    trigger.Size = UDim2.new(1, 0, 1, 0); trigger.BackgroundTransparency = 1; trigger.Text = ""
    
    local isSliding = false
    table.insert(connections, trigger.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then isSliding = true end
    end))
    table.insert(connections, UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then isSliding = false end
    end))
    table.insert(connections, RunService.RenderStepped:Connect(function()
        if isSliding then
            local mousePos = UIS:GetMouseLocation().X
            local relPos = math.clamp((mousePos - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X, 0, 1)
            local value = math.floor(min + (max - min) * relPos)
            Config[configKey] = value; label.Text = text .. ": " .. value; sliderFill.Size = UDim2.new(relPos, 0, 1, 0)
            if configKey == "Aim_FOV_Radius" then FOV_Circle.Size = UDim2.new(0, value * 2, 0, value * 2) end
        end
    end))
end

-- ЗАПОЛНЕНИЕ МЕНЮ
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

AddSetting(TabMovement, "Teleport", "TP_Enabled", "TP_Bind")
AddSetting(TabMovement, "Noclip", "Noclip_Enabled", "Noclip_Bind")
AddSetting(TabMovement, "Fly (Car Supported)", "Fly_Enabled", "Fly_Bind")
AddSetting(TabMovement, "Anti-Fall Damage", "Fly_AntiFall")
AddSlider(TabMovement, "Fly Speed", "Fly_Speed", 10, 300)

AddSetting(TabMisc, "Vehicle Fling (Rvanka)", "Fling_Enabled", "Fling_Bind")
AddSlider(TabMisc, "Fling Spin Speed", "Fling_SpinSpeed", 50, 1000)
AddSlider(TabMisc, "Fling Break Dist", "Fling_MaxDist", 50, 10000)
AddSetting(TabMisc, "Anti-Void (Grip Protect)", "Anti_Void")
AddSetting(TabMisc, "Anti-Kick (Client Hook)", "Anti_Kick")
AddSetting(TabMisc, "Anti-AFK (Idle)", "Anti_Idle")
AddSetting(TabMisc, "Bypass Chat Filter", "Bypass_Chat")
AddSetting(TabMisc, "Rainbow UI", "Rainbow_Enabled")
AddSetting(TabMisc, "GTA Square", "Square_Enabled", "Square_Bind", "Square_Mode")


-- === СИСТЕМА ESP ===
local function CreateESP(player)
    local esp = { Drawings = {}, Skeleton = {}, BoxLines = {}, BoxOutlines = {} }
    
    pcall(function()
        for i = 1, 4 do
            local outline = Drawing.new("Line")
            outline.Thickness = 3; outline.Color = Color3.new(0,0,0)
            esp.BoxOutlines[i] = outline
            local line = Drawing.new("Line")
            line.Thickness = 1.5; esp.BoxLines[i] = line
        end
        esp.Drawings.Tracer = Drawing.new("Line"); esp.Drawings.Tracer.Thickness = 1.5
        local function MakeText()
            local txt = Drawing.new("Text")
            txt.Size = 13; txt.Center = true; txt.Outline = true; txt.Color = Color3.new(1,1,1)
            return txt
        end
        esp.Drawings.Name = MakeText(); esp.Drawings.Dist = MakeText(); esp.Drawings.HPText = MakeText(); esp.Drawings.Faction = MakeText()
        esp.Drawings.HPBarBg = Drawing.new("Square"); esp.Drawings.HPBarBg.Filled = true; esp.Drawings.HPBarBg.Color = Color3.new(0,0,0)
        esp.Drawings.HPBarFill = Drawing.new("Square"); esp.Drawings.HPBarFill.Filled = true
        for i = 1, 15 do
            local bone = Drawing.new("Line"); bone.Thickness = 1.5; esp.Skeleton[i] = bone
        end
    end)
    espCache[player] = esp
end

for _, p in pairs(Players:GetPlayers()) do CreateESP(p) end
table.insert(connections, Players.PlayerAdded:Connect(CreateESP))
table.insert(connections, Players.PlayerRemoving:Connect(function(p)
    if espCache[p] then
        pcall(function()
            for i=1,4 do espCache[p].BoxLines[i]:Remove(); espCache[p].BoxOutlines[i]:Remove() end
            espCache[p].Drawings.Tracer:Remove(); espCache[p].Drawings.Name:Remove(); espCache[p].Drawings.Dist:Remove()
            espCache[p].Drawings.HPText:Remove(); espCache[p].Drawings.Faction:Remove()
            espCache[p].Drawings.HPBarBg:Remove(); espCache[p].Drawings.HPBarFill:Remove()
            for _, b in pairs(espCache[p].Skeleton) do b:Remove() end
        end)
        espCache[p] = nil
    end
    if FlingTarget == p then isFlingToggled = false; FlingTarget = nil end
end))

local function DrawBoneLine(boneObj, char, p1Name, p2Name)
    if not boneObj then return end
    local p1 = char:FindFirstChild(p1Name)
    local p2 = char:FindFirstChild(p2Name)
    if p1 and p2 then
        local pos1, vis1 = Camera:WorldToViewportPoint(p1.Position)
        local pos2, vis2 = Camera:WorldToViewportPoint(p2.Position)
        if vis1 or vis2 then
            boneObj.Visible = true; boneObj.From = Vector2.new(pos1.X, pos1.Y); boneObj.To = Vector2.new(pos2.X, pos2.Y)
            boneObj.Color = Config.MainColor
            return
        end
    end
    boneObj.Visible = false
end

-- === ANTI-VOID ===
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
                local ConnectedHandle = child.Part1
                local matched = ToolMatch(ConnectedHandle)
                if matched and ConnectedHandle and ConnectedHandle.Parent then ConnectedHandle.Parent:Destroy() end
            end
        end))
    end
end
if LocalPlayer.Character then OnCharacterAdded(LocalPlayer.Character) end
table.insert(connections, LocalPlayer.CharacterAdded:Connect(OnCharacterAdded))

-- === AIMBOT LOGIC ===
local function GetClosestTarget()
    local closestPlayer = nil
    local shortestDistance = Config.Aim_FOV_Radius
    local mousePos = UIS:GetMouseLocation()

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and p.Character then
            local hum = p.Character:FindFirstChild("Humanoid")
            if hum and hum.Health > 0 then
                if Config.Aim_TeamCheck and p.Team == LocalPlayer.Team then continue end
                local targetPartName = Config.Aim_Target == "Torso" and "HumanoidRootPart" or "Head"
                local targetPart = p.Character:FindFirstChild(targetPartName)
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

-- === ЗАЩИЩЕННЫЕ ХУКИ (PCALL) ===
local successHook, hookError = pcall(function()
    if hookmetamethod then
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            if not checkcaller() then
                local method = getnamecallmethod()
                
                -- Защита от Kick
                if Config.Anti_Kick and self == LocalPlayer and tostring(method):lower() == "kick" then
                    return
                end
                
                -- Обход чата
                if Config.Bypass_Chat and method == "FireServer" and tostring(self) == "SayMessageRequest" then
                    local args = {...}
                    if type(args[1]) == "string" then
                        local sep = "\243\160\128\149\243\160\128\150\243\160\128\151\243\160\128\152"
                        local txt = string.gsub(args[1], "[%p]+", "")
                        local words = string.split(txt, " ")
                        for i = 1, #words do
                            local w = words[i]
                            local nw = ""
                            for j = 1, #w do nw = nw .. string.sub(w, j, j); if j % 2 == 0 and j ~= #w then nw = nw .. sep end end
                            words[i] = nw
                        end
                        args[1] = table.concat(words, " ")
                        return oldNamecall(self, unpack(args))
                    end
                end
            end
            return oldNamecall(self, ...)
        end)

        local oldIndex
        oldIndex = hookmetamethod(game, "__index", function(t, k)
            if not checkcaller() and Config.Aim_Silent and typeof(t) == "Instance" and t:IsA("Mouse") and (k == "Hit" or k == "Target") then
                if CachedTarget and CachedTarget.Character then
                    local targetPartName = Config.Aim_Target == "Torso" and "HumanoidRootPart" or "Head"
                    local targetPart = CachedTarget.Character:FindFirstChild(targetPartName)
                    if targetPart then
                        return k == "Hit" and targetPart.CFrame or targetPart
                    end
                end
            end
            return oldIndex(t, k)
        end)
    end
end)

if not successHook then
    warn("[GameSync WAR] Хуки отключены экзекутором. Silent Aim работать не будет. Ошибка: " .. tostring(hookError))
end

-- === ANTI-IDLE ===
table.insert(connections, LocalPlayer.Idled:Connect(function()
    if Config.Anti_Idle then
        VirtualInputManager:SendMouseButtonEvent(0, 0, 2, true, nil, 0)
        task.wait(1)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 2, false, nil, 0)
    end
end))

-- === ПРЕВЬЮ ОБЪЕКТЫ ===
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

local function IsBindActive(bind)
    if not bind then return false end
    return (bind.EnumType == Enum.KeyCode and UIS:IsKeyDown(bind)) or (bind.EnumType == Enum.UserInputType and UIS:IsMouseButtonPressed(bind))
end

-- === MAIN LOOPS ===
local lastNoclipState = false
table.insert(connections, RunService.Stepped:Connect(function()
    if Config.Noclip_Enabled then
        if LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") and part.CanCollide then part.CanCollide = false end
            end
        end
        lastNoclipState = true
    elseif lastNoclipState then
        if LocalPlayer.Character then
            for _, part in pairs(LocalPlayer.Character:GetDescendants()) do
                if part:IsA("BasePart") then part.CanCollide = true end
            end
        end
        lastNoclipState = false
    end
end))

local flyBodyVel = nil
local flyGyro = nil
local lastAntiFallTick = tick()

table.insert(connections, RunService.RenderStepped:Connect(function()
    local t = tick()
    
    -- Безопасный вызов поиска
    pcall(function() CachedTarget = GetClosestTarget() end)
    
    if Config.Rainbow_Enabled then
        Config.MainColor = Color3.fromHSV((t * Config.Rainbow_Speed) % 1, 1, 1)
        for _, item in pairs(themeObjects) do item.Obj[item.Prop] = Config.MainColor end
    end
    
    if FlingIndicator then
        FlingIndicator.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2 + 30)
    end
    
    FOV_Circle.Visible = Config.Aim_FOV_Show
    if FOV_Circle.Visible then
        local mPos = UIS:GetMouseLocation()
        FOV_Circle.Position = UDim2.new(0, mPos.X, 0, mPos.Y)
    end
    
    -- LEGIT AIM
    if Config.Aim_Enabled and not Config.Aim_Silent and IsBindActive(Config.Aim_Bind) then
        local target = CachedTarget
        if target and target.Character then
            local targetPartName = Config.Aim_Target == "Torso" and "HumanoidRootPart" or "Head"
            local targetPart = target.Character:FindFirstChild(targetPartName)
            if targetPart then
                local predVel = targetPart.Velocity * (Config.Aim_Predict / 100)
                local aimPos = targetPart.Position + predVel
                if Config.Aim_Mode == "Camera" then
                    local targetCFrame = CFrame.new(Camera.CFrame.Position, aimPos)
                    local smoothFactor = Config.Aim_Smooth == 1 and 1 or (1 / Config.Aim_Smooth)
                    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, smoothFactor)
                elseif Config.Aim_Mode == "Mouse" and mousemoverel then
                    local pos, onScreen = Camera:WorldToViewportPoint(aimPos)
                    if onScreen then
                        local mousePos = UIS:GetMouseLocation()
                        local moveX = (pos.X - mousePos.X)
                        local moveY = (pos.Y - mousePos.Y)
                        local smooth = Config.Aim_Smooth == 1 and 1 or Config.Aim_Smooth
                        mousemoverel(moveX / smooth, moveY / smooth)
                    end
                end
            end
        end
    end

    -- GTA SQUARE
    local isSquareActive = (Config.Square_Enabled and ((Config.Square_Mode == "Hold" and IsBindActive(Config.Square_Bind)) or (Config.Square_Mode == "Toggle" and squareToggled)))
    if isSquareActive then
        local pos = GetSafePos()
        SelectionBox.Color3 = Config.MainColor
        if Config.Square_Visual == "Classic" then
            PreviewPart.Size = Vector3.new(4, 0.1, 4); PreviewPart.CFrame = CFrame.new(pos + Vector3.new(0, 0.05, 0))
        else
            PreviewPart.Size = Vector3.new(2, 0.6, 1.2)
            PreviewPart.CFrame = CFrame.new(pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(math.sin(t*2)*0.2, t * 1.5, math.cos(t*2)*0.2)
        end
        SelectionBox.Visible = true
    else
        SelectionBox.Visible = false
    end

    -- PERFECT 2D ESP
    for player, esp in pairs(espCache) do
        local isVisible = false
        pcall(function()
            local char = player.Character
            local isSelf = (player == LocalPlayer)

            if Config.ESP_Enabled and char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Head") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 and (not isSelf or Config.ESP_ShowSelf) then
                if not (Config.ESP_TeamCheck and player.Team == LocalPlayer.Team and not isSelf) then
                    
                    local head = char.Head
                    local hrp = char.HumanoidRootPart
                    local headPos, onScreen1 = Camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                    
                    local leftFoot = char:FindFirstChild("LeftFoot") or char:FindFirstChild("Left Leg")
                    local rightFoot = char:FindFirstChild("RightFoot") or char:FindFirstChild("Right Leg")
                    local bottomY = hrp.Position.Y - 3
                    if leftFoot and rightFoot then bottomY = math.min(leftFoot.Position.Y, rightFoot.Position.Y) - 0.2 end
                    local bottomPos, onScreen2 = Camera:WorldToViewportPoint(Vector3.new(hrp.Position.X, bottomY, hrp.Position.Z))

                    if onScreen1 or onScreen2 then
                        isVisible = true
                        local height = math.abs(headPos.Y - bottomPos.Y)
                        local width = height * 0.55 
                        local minX = headPos.X - width/2; local minY = headPos.Y
                        local maxX = headPos.X + width/2; local maxY = bottomPos.Y

                        if Config.ESP_Box and esp.BoxLines then
                            local c = Config.MainColor
                            local TL = Vector2.new(minX, minY); local TR = Vector2.new(maxX, minY)
                            local BL = Vector2.new(minX, maxY); local BR = Vector2.new(maxX, maxY)

                            local function setLine(l, f, t, v, col) l.Visible = v; if v then l.From = f; l.To = t; l.Color = col end end
                            setLine(esp.BoxOutlines[1], TL, TR, true, Color3.new(0,0,0)); setLine(esp.BoxOutlines[2], TR, BR, true, Color3.new(0,0,0))
                            setLine(esp.BoxOutlines[3], BR, BL, true, Color3.new(0,0,0)); setLine(esp.BoxOutlines[4], BL, TL, true, Color3.new(0,0,0))
                            setLine(esp.BoxLines[1], TL, TR, true, c); setLine(esp.BoxLines[2], TR, BR, true, c)
                            setLine(esp.BoxLines[3], BR, BL, true, c); setLine(esp.BoxLines[4], BL, TL, true, c)
                        else
                            if esp.BoxLines then for i=1,4 do esp.BoxLines[i].Visible = false; esp.BoxOutlines[i].Visible = false end end
                        end

                        if esp.Drawings then
                            if Config.ESP_Tracers then
                                esp.Drawings.Tracer.Visible = true; esp.Drawings.Tracer.Color = Config.MainColor
                                esp.Drawings.Tracer.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)
                                esp.Drawings.Tracer.To = Vector2.new(headPos.X, maxY) 
                            else esp.Drawings.Tracer.Visible = false end

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
                        end

                        if Config.ESP_Skeleton and esp.Skeleton then
                            if char:FindFirstChild("UpperTorso") then
                                DrawBoneLine(esp.Skeleton[1], char, "Head", "UpperTorso"); DrawBoneLine(esp.Skeleton[2], char, "UpperTorso", "LowerTorso")
                                DrawBoneLine(esp.Skeleton[3], char, "UpperTorso", "LeftUpperArm"); DrawBoneLine(esp.Skeleton[4], char, "LeftUpperArm", "LeftLowerArm")
                                DrawBoneLine(esp.Skeleton[5], char, "LeftLowerArm", "LeftHand"); DrawBoneLine(esp.Skeleton[6], char, "UpperTorso", "RightUpperArm")
                                DrawBoneLine(esp.Skeleton[7], char, "RightUpperArm", "RightLowerArm"); DrawBoneLine(esp.Skeleton[8], char, "RightLowerArm", "RightHand")
                                DrawBoneLine(esp.Skeleton[9], char, "LowerTorso", "LeftUpperLeg"); DrawBoneLine(esp.Skeleton[10], char, "LeftUpperLeg", "LeftLowerLeg")
                                DrawBoneLine(esp.Skeleton[11], char, "LeftLowerLeg", "LeftFoot"); DrawBoneLine(esp.Skeleton[12], char, "LowerTorso", "RightUpperLeg")
                                DrawBoneLine(esp.Skeleton[13], char, "RightUpperLeg", "RightLowerLeg"); DrawBoneLine(esp.Skeleton[14], char, "RightLowerLeg", "RightFoot")
                            elseif char:FindFirstChild("Torso") then
                                DrawBoneLine(esp.Skeleton[1], char, "Head", "Torso"); DrawBoneLine(esp.Skeleton[2], char, "Torso", "Left Arm")
                                DrawBoneLine(esp.Skeleton[3], char, "Torso", "Right Arm"); DrawBoneLine(esp.Skeleton[4], char, "Torso", "Left Leg"); DrawBoneLine(esp.Skeleton[5], char, "Torso", "Right Leg")
                            end
                        else if esp.Skeleton then for _, bone in pairs(esp.Skeleton) do bone.Visible = false end end end
                    end
                end
            end
        end)

        if not isVisible then 
            pcall(function()
                if esp.BoxLines then for i=1,4 do esp.BoxLines[i].Visible = false; esp.BoxOutlines[i].Visible = false end end
                if esp.Drawings then
                    esp.Drawings.Tracer.Visible = false; esp.Drawings.Name.Visible = false; esp.Drawings.Dist.Visible = false
                    esp.Drawings.HPText.Visible = false; esp.Drawings.Faction.Visible = false
                    esp.Drawings.HPBarBg.Visible = false; esp.Drawings.HPBarFill.Visible = false
                end
                if esp.Skeleton then for _, bone in pairs(esp.Skeleton) do bone.Visible = false end end
            end)
        end
    end

    -- === CAR FLY & RVANKA ===
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChild("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    
    local inVehicle = false
    local vehicleRoot = nil
    
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
            if dist > Config.Fling_MaxDist then
                isFlingToggled = false
                FlingTarget = nil
            else
                if inVehicle and vehicleRoot then
                    if flyBodyVel then flyBodyVel:Destroy(); flyBodyVel = nil end
                    if flyGyro then flyGyro:Destroy(); flyGyro = nil end
                    
                    vehicleRoot.CFrame = targetHrp.CFrame * CFrame.Angles(math.rad(math.random(0,360)), math.rad(math.random(0,360)), math.rad(math.random(0,360)))
                    vehicleRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                    local s = Config.Fling_SpinSpeed
                    vehicleRoot.AssemblyAngularVelocity = Vector3.new(math.random(-s, s), math.random(-s, s), math.random(-s, s))
                end
            end
        else
            isFlingToggled = false
            FlingTarget = nil
        end
    else
        isFlingToggled = false
        FlingTarget = nil
    end

    if FlingIndicator then
        if isFlingToggled and FlingTarget then
            FlingIndicator.Visible = true
            FlingIndicator.Text = "[ Fling Locked: " .. FlingTarget.Name .. " ]"
        else
            FlingIndicator.Visible = false
        end
    end

    if not isFlingToggled then
        local flyPart = inVehicle and vehicleRoot or hrp
        
        if Config.Fly_Enabled and flyPart then
            if not flyBodyVel then
                flyBodyVel = Instance.new("BodyVelocity")
                flyBodyVel.Name = "GameSync_Fly"
                flyBodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
                flyBodyVel.Parent = flyPart
            end
            if not flyGyro then
                flyGyro = Instance.new("BodyGyro")
                flyGyro.Name = "GameSync_FlyGyro"
                flyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
                flyGyro.P = 15000; flyGyro.D = 500
                flyGyro.Parent = flyPart
            end
            
            if flyBodyVel.Parent ~= flyPart then flyBodyVel.Parent = flyPart end
            if flyGyro.Parent ~= flyPart then flyGyro.Parent = flyPart end

            local moveDir = Vector3.zero
            if UIS:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + Camera.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - Camera.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - Camera.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + Camera.CFrame.RightVector end
            
            flyBodyVel.Velocity = moveDir * Config.Fly_Speed
            
            if inVehicle then
                flyGyro.CFrame = Camera.CFrame
            else
                flyGyro.CFrame = CFrame.new(flyPart.Position, flyPart.Position + Camera.CFrame.LookVector * Vector3.new(1,0,1))
            end
            
            if Config.Fly_AntiFall and not inVehicle and t - lastAntiFallTick > 0.5 then
                flyPart.CFrame = flyPart.CFrame * CFrame.new(0, 0.05, 0)
                lastAntiFallTick = t
            end
        else
            if flyBodyVel then 
                if Config.Fly_AntiFall and flyPart and not inVehicle then flyPart.Velocity = Vector3.new(0,0,0) end
                flyBodyVel:Destroy(); flyBodyVel = nil 
            end
            if flyGyro then flyGyro:Destroy(); flyGyro = nil end
        end
    end
end))

local function HandleBinds(input, isKey, isMouse)
    if IsBindActive(Config.Menu_Bind) then MainFrame.Visible = not MainFrame.Visible end
    
    if IsBindActive(Config.TP_Bind) and Config.TP_Enabled then
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = {LocalPlayer.Character, PreviewPart}
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            local ray = workspace:Raycast(Mouse.UnitRay.Origin, Mouse.UnitRay.Direction * 1000, rayParams)
            hrp.CFrame = CFrame.new((ray and ray.Position or Mouse.Hit.Position) + Vector3.new(0, 3, 0))
        end
    end
    
    if IsBindActive(Config.Fling_Bind) and Config.Fling_Enabled then
        if isFlingToggled then
            isFlingToggled = false
            FlingTarget = nil
        else
            local target = CachedTarget
            if target then
                isFlingToggled = true
                FlingTarget = target
            end
        end
    end
    
    if IsBindActive(Config.Noclip_Bind) then Config.Noclip_Enabled = not Config.Noclip_Enabled end
    if IsBindActive(Config.Fly_Bind) then Config.Fly_Enabled = not Config.Fly_Enabled end
    if Config.Square_Enabled and Config.Square_Mode == "Toggle" and IsBindActive(Config.Square_Bind) then
        squareToggled = not squareToggled
    end
    if IsBindActive(Config.Unbind_Key) then SelfDestruct() end
end

table.insert(connections, UIS.InputBegan:Connect(function(input, processed)
    local isMouse = string.find(input.UserInputType.Name, "MouseButton")
    local isKey = input.UserInputType == Enum.UserInputType.Keyboard

    if bindingTarget then
        if input.UserInputState == Enum.UserInputState.Begin then
            if isKey and input.KeyCode == Enum.KeyCode.Escape then
                bindingTarget = nil; return
            end
            if isKey and input.KeyCode ~= Enum.KeyCode.Unknown then
                Config[bindingTarget] = input.KeyCode
                if bindButtons[bindingTarget] then bindButtons[bindingTarget].Text = "Bind: " .. input.KeyCode.Name end
                bindingTarget = nil
            elseif isMouse then
                Config[bindingTarget] = input.UserInputType
                if bindButtons[bindingTarget] then bindButtons[bindingTarget].Text = "Bind: " .. input.UserInputType.Name end
                bindingTarget = nil
            end
        end
        return
    end

    if processed and not isMouse then return end 

    if input.UserInputState == Enum.UserInputState.Begin then
        HandleBinds(input, isKey, isMouse)
    end
end))

print("GameSync WAR (V25) Loaded Successfully. Safe Hooks Active.")
