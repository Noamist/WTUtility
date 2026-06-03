local url = "https://raw.githubusercontent.com/Noamist/WTUtility/refs/heads/main/WTUtility_alpha.lua"

pcall(function()
    queue_on_teleport(('loadstring(game:HttpGet("%s"))()'):format(url))
end)

-- ============================
-- CONFIG
-- ============================
local TARGET_PATH = {"DroppedChest", "UBot130"}
local PREFIX = "Crate_"
local TP_COOLDOWN = 1

-- ============================
-- PLACE ID DETECTION
-- ============================
local PLACE_IDS = {
    [129548273770183] = 1,
    [92050243909420]  = 2,
    [99207780794303]  = 3,
    [80516087942243]  = 4,
}

local currentPlaceId = game.PlaceId
local currentChapter = PLACE_IDS[currentPlaceId]
local isChapter4 = (currentChapter == 4)

-- ============================
-- TELEPORT DATA PER CHAPTER
-- ============================
local TP_DATA = {
    [1] = {
        {"Spawn",         4.75,    3.00,    2.08},
        {"The Library",   19.88,   51.12,   21.29},
        {"The Futur",     2079.50, 1372.78, -2844.19},
        {"The Void",      1511.83, 1348.27, -2150.29},
        {"The Zenith",    1684.89, 388.12,  -2873.60},
        {"Purgatory",     1259.81, 86.22,   -2801.05},
        {"The Cyber",     1164.41, 1045.20, -2715.65},
        {"Obby Easy",     -86.77,  3.88,    -144.20},
        {"Obby Hard",     -82.17,  3.88,    -145.76},
        {"Enhancements",  -79.99,  3.59,    15.35},
        {"Upgrade Tree",  -190.66, 3.07,    -5.43},
    },
    [2] = {
        {"Spawn",             16.03,    3.00,   -11.07},
        {"The Cube",          64.27,    3.52,     5.98},
        {"Frutiger Aqua",    -843.11,   4.33,   -12.87},
        {"Frutiger Metro",    142.64,  110.87,  665.51},
        {"DORFic",           -1108.81, 511.74,  850.15},
        {"Frutiger Aurora",    50.84,  470.44, 2471.76},
        {"Frutiger Central", 1512.87,  397.69, 2532.75},
    },
    [3] = {
        {"Spawn",              32.80,    6.19,   -109.22},
        {"Levels",            138.34,   98.31,   -227.24},
        {"Lightposts",        266.21,  111.19,   -255.73},
        {"Day/Night Pads",    347.12,  156.92,   -140.74},
        {"Automation/Fruits", 156.61,  185.59,   -143.75},
        {"Dark Fragment",    -670.79,  963.36,  -6991.28},
        {"Dark Essence",     -630.15,  998.05,  -7078.72},
        {"Ruined Lamps",     -509.56, 1023.02,  -7024.73},
        {"The Meter",        -687.31, 1090.98,  -6839.56},
        {"Dark Upgrade Tree",-855.06, 1136.69,  -6897.06},
    },
    [4] = {
        {"Level 0",    82,     5,    -60},
        {"Level 1",   730,     1,      7},
        {"Level 2",  1228,   -16,    545},
        {"Level 3",   379,   208,   1079},
        {"Level 4", -1176,     3,   -596},
        {"Level 5", -1237,     3,      0},
        {"Level 6",    51,    -3,   -954},
    },
}

-- ============================
-- SERVICES
-- ============================
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer

local function getCharacter()
    local char = player.Character
    if not char or not char.Parent then
        char = player.CharacterAdded:Wait()
    end
    return char
end

local character = getCharacter()

-- ============================
-- STATE
-- ============================
local scanning  = false
local unloaded  = false
local lastTP    = 0
local toggleStates = {}

-- ============================
-- HELPERS
-- ============================
local function getCharRoot()
    local char = getCharacter()
    return char:FindFirstChild("HumanoidRootPart")
end

-- Résoudre un chemin type "Workspace/A/B/C"
local function resolvePath(pathStr)
    local parts = string.split(pathStr, "/")
    local node = game
    for _, part in ipairs(parts) do
        if part == "Workspace" then
            node = workspace
        else
            node = node:FindFirstChild(part)
            if not node then return nil end
        end
    end
    return node
end

-- TP vers un objet (BasePart ou Model avec PrimaryPart)
local function tpToObject(obj)
    if not obj then return end
    local root = getCharRoot()
    if not root then return end
    local part = obj:IsA("BasePart") and obj
        or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")))
    if part then
        root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
    end
end

-- Activer un ProximityPrompt
local function fireProximityPrompt(pp)
    if not pp or not pp:IsA("ProximityPrompt") then return end
    -- Méthode fiable côté LocalScript
    local function tryFire()
        local ok = pcall(function()
            fireproximityprompt(pp) -- executor global
        end)
        if not ok then
            -- fallback : simuler l'input
            pp:InputHoldBegin()
            task.wait(0.05)
            pp:InputHoldEnd()
        end
    end
    tryFire()
end

-- Activer un ClickDetector
local function fireClickDetector(cd)
    if not cd or not cd:IsA("ClickDetector") then return end
    local ok = pcall(function()
        fireclickdetector(cd) -- executor global
    end)
    if not ok then
        -- fallback
        cd:InputHoldBegin()
    end
end

-- ============================
-- UI ROOT
-- ============================
local gui = Instance.new("ScreenGui")
gui.Name = "CrateScannerUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- ============================
-- MAIN WINDOW
-- ============================
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 310, 0, 420)
main.Position = UDim2.new(0, 20, 0, 20)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 10)
mainCorner.Parent = main

-- ============================
-- HEADER
-- ============================
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 40)
header.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
header.BorderSizePixel = 0
header.Parent = main

Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local chapterLabel = currentChapter
    and ("Chest Utility  —  Ch." .. currentChapter)
    or  "Chest Utility  —  Ch.???"

local titleLbl = Instance.new("TextLabel")
titleLbl.Size = UDim2.new(1, -40, 1, 0)
titleLbl.Position = UDim2.new(0, 10, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = chapterLabel
titleLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 16
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.Parent = header

local hideBtn = Instance.new("TextButton")
hideBtn.Size = UDim2.new(0, 30, 0, 30)
hideBtn.Position = UDim2.new(1, -35, 0, 5)
hideBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
hideBtn.Text = "-"
hideBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
hideBtn.Font = Enum.Font.GothamBold
hideBtn.TextSize = 20
hideBtn.Parent = header
Instance.new("UICorner", hideBtn).CornerRadius = UDim.new(0, 6)

-- ============================
-- TABS
-- ============================
local tabs = Instance.new("Frame")
tabs.Size = UDim2.new(1, 0, 0, 35)
tabs.Position = UDim2.new(0, 0, 0, 40)
tabs.BackgroundTransparency = 1
tabs.Parent = main

local function createTab(name, posX)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 90, 0, 30)
    btn.Position = UDim2.new(0, posX, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Parent = tabs
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    return btn
end

local tabMain     = createTab("Main",      10)
local tabTP       = createTab("Teleports", 105)
local tabSettings = createTab("Settings",  200)

-- ============================
-- CONTENT FRAME
-- ============================
local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -90)
content.Position = UDim2.new(0, 10, 0, 80)
content.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
content.BorderSizePixel = 0
content.Parent = main
Instance.new("UICorner", content).CornerRadius = UDim.new(0, 8)

-- ============================
-- PAGES
-- ============================
local pages = {}
local function createPage(name)
    local page = Instance.new("Frame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = content
    pages[name] = page
    return page
end

local pageMain     = createPage("Main")
local pageTP       = createPage("Teleports")
local pageSettings = createPage("Settings")

local function showPage(name)
    for n, p in pairs(pages) do p.Visible = (n == name) end
end
tabMain.MouseButton1Click:Connect(function()     showPage("Main") end)
tabTP.MouseButton1Click:Connect(function()       showPage("Teleports") end)
tabSettings.MouseButton1Click:Connect(function() showPage("Settings") end)
showPage("Main")

-- ============================
-- HIDE / SHOW
-- ============================
local hidden = false
hideBtn.MouseButton1Click:Connect(function()
    hidden = not hidden
    content.Visible = not hidden
    tabs.Visible    = not hidden
    hideBtn.Text    = hidden and "+" or "-"
end)

-- ============================
-- MAIN PAGE — ScrollingFrame
-- ============================
local scrollMain = Instance.new("ScrollingFrame")
scrollMain.Size = UDim2.new(1, 0, 1, 0)
scrollMain.BackgroundTransparency = 1
scrollMain.BorderSizePixel = 0
scrollMain.ScrollBarThickness = 4
scrollMain.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
scrollMain.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollMain.Parent = pageMain

local mainListLayout = Instance.new("UIListLayout")
mainListLayout.SortOrder = Enum.SortOrder.LayoutOrder
mainListLayout.Padding = UDim.new(0, 5)
mainListLayout.Parent = scrollMain

local mainPadding = Instance.new("UIPadding")
mainPadding.PaddingLeft   = UDim.new(0, 8)
mainPadding.PaddingRight  = UDim.new(0, 8)
mainPadding.PaddingTop    = UDim.new(0, 6)
mainPadding.PaddingBottom = UDim.new(0, 6)
mainPadding.Parent = scrollMain

mainListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollMain.CanvasSize = UDim2.new(0, 0, 0, mainListLayout.AbsoluteContentSize.Y + 12)
end)

-- Compteur d'ordre dans Main
local mainOrder = 0
local function nextOrder()
    local o = mainOrder
    mainOrder = mainOrder + 1
    return o
end

-- ============================
-- WIDGET BUILDERS
-- ============================

-- Bouton TP simple (vert foncé)
local function addTPButton(labelText, order, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(30, 90, 50)
    btn.Text = "↗  " .. labelText
    btn.TextColor3 = Color3.fromRGB(200, 255, 200)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.LayoutOrder = order
    btn.Parent = scrollMain
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function()
        if unloaded then return end
        callback()
    end)
    return btn
end

-- Bouton Toggle (rouge/vert)
local function addToggleButton(labelText, order, loopFn, cooldown)
    cooldown = cooldown or 0.3
    local key = labelText

    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 30)
    row.BackgroundTransparency = 1
    row.LayoutOrder = order
    row.Parent = scrollMain

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 0, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = labelText
    lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
    lbl.Font = Enum.Font.Gotham
    lbl.TextSize = 13
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.Parent = row

    local togBtn = Instance.new("TextButton")
    togBtn.Size = UDim2.new(0, 60, 0, 26)
    togBtn.Position = UDim2.new(1, -62, 0, 2)
    togBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    togBtn.Text = "OFF"
    togBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    togBtn.Font = Enum.Font.GothamBold
    togBtn.TextSize = 13
    togBtn.Parent = row
    Instance.new("UICorner", togBtn).CornerRadius = UDim.new(0, 6)

    toggleStates[key] = false

    togBtn.MouseButton1Click:Connect(function()
        if unloaded then return end
        toggleStates[key] = not toggleStates[key]
        if toggleStates[key] then
            togBtn.Text = "ON"
            togBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 50)
            task.spawn(function()
                while toggleStates[key] and not unloaded do
                    loopFn()
                    task.wait(cooldown)
                end
            end)
        else
            togBtn.Text = "OFF"
            togBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        end
    end)
    return togBtn
end

-- Séparateur
local function addSeparator(order)
    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, 0, 0, 1)
    sep.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    sep.BorderSizePixel = 0
    sep.LayoutOrder = order
    sep.Parent = scrollMain
end

-- ============================
-- AUTO COLLECT (tous chapitres)
-- ============================
addSeparator(nextOrder())
-- Label section
local secCollect = Instance.new("TextLabel")
secCollect.Size = UDim2.new(1, 0, 0, 20)
secCollect.BackgroundTransparency = 1
secCollect.Text = "AUTO COLLECT"
secCollect.TextColor3 = Color3.fromRGB(140, 140, 140)
secCollect.Font = Enum.Font.GothamBold
secCollect.TextSize = 11
secCollect.TextXAlignment = Enum.TextXAlignment.Left
secCollect.LayoutOrder = nextOrder()
secCollect.Parent = scrollMain

local function getTargetFolder()
    local folder = workspace
    for _, name in ipairs(TARGET_PATH) do
        folder = folder:FindFirstChild(name)
        if not folder then return nil end
    end
    return folder
end

local function handleCrate(crate)
    if unloaded then return end
    if os.clock() - lastTP < TP_COOLDOWN then return end
    character = getCharacter()
    local root = character:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local primary = crate.PrimaryPart
        or crate:FindFirstChild("Container")
        or crate:FindFirstChildWhichIsA("BasePart")
    if not primary then return end
    root.CFrame = primary.CFrame + Vector3.new(0, 3, 0)
    lastTP = os.clock()
end

local function scanCrates()
    local folder = getTargetFolder()
    if not folder then return end
    for _, obj in ipairs(folder:GetChildren()) do
        if obj:IsA("Model") and obj.Name:sub(1, #PREFIX) == PREFIX then
            handleCrate(obj)
        end
    end
end

addToggleButton("Auto Collect Chest", nextOrder(), scanCrates, 0.3)
addSeparator(nextOrder())

-- ============================
-- FONCTIONNALITÉS PAR CHAPITRE
-- ============================

if currentChapter == 1 then

    local sec = Instance.new("TextLabel")
    sec.Size = UDim2.new(1, 0, 0, 20)
    sec.BackgroundTransparency = 1
    sec.Text = "CHAPITRE 1"
    sec.TextColor3 = Color3.fromRGB(140, 200, 255)
    sec.Font = Enum.Font.GothamBold
    sec.TextSize = 11
    sec.TextXAlignment = Enum.TextXAlignment.Left
    sec.LayoutOrder = nextOrder()
    sec.Parent = scrollMain

    -- Convert into Eons (TP)
    addTPButton("Convert into Eons", nextOrder(), function()
        local obj = resolvePath("Workspace/TimeButtons/Button")
        tpToObject(obj)
    end)

    addSeparator(nextOrder())

    -- Open Enhancements (ProximityPrompt nommé)
    addToggleButton("Open Enhancements", nextOrder(), function()
        local parent = resolvePath("Workspace/Son 😭😭😭😭😭/Model/Book")
        if not parent then return end
        local pp = parent:FindFirstChild("EnhancementPrompt")
            or parent:FindFirstChildWhichIsA("ProximityPrompt")
        fireProximityPrompt(pp)
    end, 0.5)

    -- Claim Lobby Rewards (TP double avec délai)
    local claimBtn = Instance.new("TextButton")
    claimBtn.Size = UDim2.new(1, 0, 0, 30)
    claimBtn.BackgroundColor3 = Color3.fromRGB(130, 60, 160)
    claimBtn.Text = "🎁  Claim Lobby Rewards"
    claimBtn.TextColor3 = Color3.fromRGB(240, 200, 255)
    claimBtn.Font = Enum.Font.GothamBold
    claimBtn.TextSize = 13
    claimBtn.LayoutOrder = nextOrder()
    claimBtn.Parent = scrollMain
    Instance.new("UICorner", claimBtn).CornerRadius = UDim.new(0, 6)
    claimBtn.MouseButton1Click:Connect(function()
        if unloaded then return end
        task.spawn(function()
            local p1 = resolvePath("Workspace/Obby/LocksReward/claimPart")
            tpToObject(p1)
            task.wait(1)
            local p2 = resolvePath("Workspace/Obby/RerollsReward/claimPart")
            tpToObject(p2)
        end)
    end)

elseif currentChapter == 2 then

    local sec = Instance.new("TextLabel")
    sec.Size = UDim2.new(1, 0, 0, 20)
    sec.BackgroundTransparency = 1
    sec.Text = "CHAPITRE 2"
    sec.TextColor3 = Color3.fromRGB(140, 255, 180)
    sec.Font = Enum.Font.GothamBold
    sec.TextSize = 11
    sec.TextXAlignment = Enum.TextXAlignment.Left
    sec.LayoutOrder = nextOrder()
    sec.Parent = scrollMain

    -- Convert into Generations (TP)
    addTPButton("Convert into Generations", nextOrder(), function()
        local obj = resolvePath("Workspace/Button")
        tpToObject(obj)
    end)

    addSeparator(nextOrder())

    -- Auto Click Cube
    addToggleButton("Auto Click Cube", nextOrder(), function()
        local cd = resolvePath("Workspace/Clicks/n")
        if cd then
            local detector = cd:FindFirstChildWhichIsA("ClickDetector") or cd
            fireClickDetector(detector:IsA("ClickDetector") and detector or cd:FindFirstChildWhichIsA("ClickDetector"))
        end
    end, 0.1)

    -- Auto Click Button
    addToggleButton("Auto Click Button", nextOrder(), function()
        local cd = resolvePath("Workspace/Buttonfr/n")
        if cd then
            local detector = cd:FindFirstChildWhichIsA("ClickDetector")
            if detector then fireClickDetector(detector) end
        end
    end, 0.1)

elseif currentChapter == 3 then

    local sec = Instance.new("TextLabel")
    sec.Size = UDim2.new(1, 0, 0, 20)
    sec.BackgroundTransparency = 1
    sec.Text = "CHAPITRE 3"
    sec.TextColor3 = Color3.fromRGB(255, 200, 100)
    sec.Font = Enum.Font.GothamBold
    sec.TextSize = 11
    sec.TextXAlignment = Enum.TextXAlignment.Left
    sec.LayoutOrder = nextOrder()
    sec.Parent = scrollMain

    -- Convert into Mercury (TP)
    addTPButton("Convert into Mercury", nextOrder(), function()
        local obj = resolvePath("Workspace/Button")
        tpToObject(obj)
    end)

    -- Convert into Dark Fragments (TP)
    addTPButton("Convert into Dark Fragments", nextOrder(), function()
        local obj = resolvePath("Workspace/ruinpad")
        tpToObject(obj)
    end)

    addSeparator(nextOrder())

    -- Auto Add Stats
    addToggleButton("Auto Add Stats", nextOrder(), function()
        local pp = resolvePath("Workspace/Essence/upgrades/EssenceProx")
        if pp then
            local prompt = pp:FindFirstChildWhichIsA("ProximityPrompt") or pp
            if prompt:IsA("ProximityPrompt") then fireProximityPrompt(prompt)
            else
                local p2 = pp:FindFirstChildWhichIsA("ProximityPrompt")
                if p2 then fireProximityPrompt(p2) end
            end
        end
    end, 0.2)

    -- Auto Add Dark Essence
    addToggleButton("Auto Add Dark Essence", nextOrder(), function()
        local pp = resolvePath("Workspace/Essence/upgrades/MoreStatsProx")
        if pp then
            local prompt = pp:IsA("ProximityPrompt") and pp
                or pp:FindFirstChildWhichIsA("ProximityPrompt")
            if prompt then fireProximityPrompt(prompt) end
        end
    end, 0.2)

elseif currentChapter == 4 then

    local sec = Instance.new("TextLabel")
    sec.Size = UDim2.new(1, 0, 0, 20)
    sec.BackgroundTransparency = 1
    sec.Text = "CHAPITRE 4"
    sec.TextColor3 = Color3.fromRGB(255, 120, 120)
    sec.Font = Enum.Font.GothamBold
    sec.TextSize = 11
    sec.TextXAlignment = Enum.TextXAlignment.Left
    sec.LayoutOrder = nextOrder()
    sec.Parent = scrollMain

    -- Convert into Archives (TP) — EN PREMIER
    addTPButton("Convert into Archives", nextOrder(), function()
        local obj = resolvePath("Workspace/Level 0/Gameplay/archive_button")
        tpToObject(obj)
    end)

    addSeparator(nextOrder())

    -- Auto ChanceBench
    addToggleButton("Auto ChanceBench", nextOrder(), function()
        local node = resolvePath("Workspace/Level 1/Gameplay/ChanceBench/Desk")
        if not node then return end
        local pp = node:FindFirstChildWhichIsA("ProximityPrompt")
        if pp then fireProximityPrompt(pp) end
    end, 0.3)

    -- Auto MemoriesBench
    addToggleButton("Auto MemoriesBench", nextOrder(), function()
        local node = resolvePath("Workspace/Level 1/Gameplay/MemoriesBench/Desk")
        if not node then return end
        local pp = node:FindFirstChildWhichIsA("ProximityPrompt")
        if pp then fireProximityPrompt(pp) end
    end, 0.3)

    -- Auto Resistance
    addToggleButton("Auto Resistance", nextOrder(), function()
        local node = resolvePath("Workspace/Level 2/Deco/Upgrade/essenceboost")
        if not node then return end
        local pp = node:FindFirstChildWhichIsA("ProximityPrompt")
        if pp then fireProximityPrompt(pp) end
    end, 0.3)

    addSeparator(nextOrder())

    -- Auto Upgrade Archives
    addToggleButton("Auto Upgrade Archives", nextOrder(), function()
        local node = resolvePath("Workspace/Level 6/Gameplay/upgradeArchive")
        if not node then return end
        local pp = node:FindFirstChildWhichIsA("ProximityPrompt")
        if pp then fireProximityPrompt(pp) end
    end, 0.3)

    -- Auto Upgrade Scraps
    addToggleButton("Auto Upgrade Scraps", nextOrder(), function()
        local node = resolvePath("Workspace/Level 6/Gameplay/upgradeScrap")
        if not node then return end
        local pp = node:FindFirstChildWhichIsA("ProximityPrompt")
        if pp then fireProximityPrompt(pp) end
    end, 0.3)

    -- Auto Upgrade ???
    addToggleButton("Auto Upgrade ???", nextOrder(), function()
        local node = resolvePath("Workspace/Level 6/Gameplay/upgrade")
        if not node then return end
        local pp = node:FindFirstChildWhichIsA("ProximityPrompt")
        if pp then fireProximityPrompt(pp) end
    end, 0.3)

end

-- ============================
-- TELEPORT PAGE — ScrollingFrame
-- ============================
local scrollTP = Instance.new("ScrollingFrame")
scrollTP.Size = UDim2.new(1, 0, 1, 0)
scrollTP.BackgroundTransparency = 1
scrollTP.BorderSizePixel = 0
scrollTP.ScrollBarThickness = 4
scrollTP.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
scrollTP.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollTP.Parent = pageTP

local tpListLayout = Instance.new("UIListLayout")
tpListLayout.SortOrder = Enum.SortOrder.LayoutOrder
tpListLayout.Padding = UDim.new(0, 4)
tpListLayout.Parent = scrollTP

local tpPadding = Instance.new("UIPadding")
tpPadding.PaddingLeft   = UDim.new(0, 8)
tpPadding.PaddingRight  = UDim.new(0, 8)
tpPadding.PaddingTop    = UDim.new(0, 6)
tpPadding.PaddingBottom = UDim.new(0, 6)
tpPadding.Parent = scrollTP

local function tpToCoords(x, y, z)
    if unloaded then return end
    local root = getCharRoot()
    if root then root.CFrame = CFrame.new(x, y, z) end
end

local function createScrollTPButton(text, order, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.LayoutOrder = order
    btn.Parent = scrollTP
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(callback)
    return btn
end

local function createDailyRewardButton(order)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(180, 140, 20)
    btn.Text = "⭐ Daily Reward"
    btn.TextColor3 = Color3.fromRGB(255, 255, 220)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 13
    btn.LayoutOrder = order
    btn.Parent = scrollTP
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function()
        if unloaded then return end
        local root = getCharRoot()
        if not root then return end
        local reward = workspace:FindFirstChild("dailyreward", true)
        if reward then
            local part = reward:IsA("BasePart") and reward
                or reward:FindFirstChildWhichIsA("BasePart")
            if part then root.CFrame = part.CFrame + Vector3.new(0, 3, 0) end
        end
    end)
end

if currentChapter and TP_DATA[currentChapter] then
    local order = 0
    createDailyRewardButton(order) ; order = order + 1

    local sep = Instance.new("Frame")
    sep.Size = UDim2.new(1, 0, 0, 2)
    sep.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    sep.BorderSizePixel = 0
    sep.LayoutOrder = order
    sep.Parent = scrollTP ; order = order + 1

    for _, entry in ipairs(TP_DATA[currentChapter]) do
        local name, x, y, z = entry[1], entry[2], entry[3], entry[4]
        createScrollTPButton(name, order, function() tpToCoords(x, y, z) end)
        order = order + 1
    end
else
    createDailyRewardButton(0)
    local unknownLabel = Instance.new("TextLabel")
    unknownLabel.Size = UDim2.new(1, 0, 0, 40)
    unknownLabel.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
    unknownLabel.Text = "⚠ Chapitre inconnu"
    unknownLabel.TextColor3 = Color3.fromRGB(255, 180, 180)
    unknownLabel.Font = Enum.Font.GothamBold
    unknownLabel.TextSize = 13
    unknownLabel.LayoutOrder = 1
    unknownLabel.Parent = scrollTP
    Instance.new("UICorner", unknownLabel).CornerRadius = UDim.new(0, 8)
end

tpListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    scrollTP.CanvasSize = UDim2.new(0, 0, 0, tpListLayout.AbsoluteContentSize.Y + 12)
end)

-- ============================
-- SETTINGS PAGE (UNLOAD)
-- ============================
-- Auto Reload Script
local autoReload = false

local reloadBtn = Instance.new("TextButton")
reloadBtn.Size = UDim2.new(1, -20, 0, 30)
reloadBtn.Position = UDim2.new(0, 10, 0, 50)
reloadBtn.BackgroundColor3 = Color3.fromRGB(200, 120, 40)
reloadBtn.Text = "Auto Reload: OFF"
reloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
reloadBtn.Font = Enum.Font.GothamBold
reloadBtn.TextSize = 14
reloadBtn.Parent = pageSettings
Instance.new("UICorner", reloadBtn).CornerRadius = UDim.new(0, 6)

reloadBtn.MouseButton1Click:Connect(function()
    autoReload = not autoReload
    reloadBtn.Text = autoReload and "Auto Reload: ON" or "Auto Reload: OFF"
    reloadBtn.BackgroundColor3 = autoReload
        and Color3.fromRGB(50, 200, 50)
        or  Color3.fromRGB(200, 120, 40)
end)

local unload = Instance.new("TextButton")
unload.Size = UDim2.new(1, -20, 0, 30)
unload.Position = UDim2.new(0, 10, 0, 10)
unload.BackgroundColor3 = Color3.fromRGB(50, 50, 200)
unload.Text = "Unload"
unload.TextColor3 = Color3.fromRGB(255, 255, 255)
unload.Font = Enum.Font.GothamBold
unload.TextSize = 14
unload.Parent = pageSettings
Instance.new("UICorner", unload).CornerRadius = UDim.new(0, 6)

unload.MouseButton1Click:Connect(function()
    unloaded = true
    scanning = false
    for k in pairs(toggleStates) do toggleStates[k] = false end
    if gui and gui.Parent then gui:Destroy() end
end)

-- AUTO RELOAD ON PLACE CHANGE (VERSION FIX)
task.spawn(function()
    local lastPlace = game.PlaceId

    while task.wait(1) do
        if autoReload then
            local newPlace = game.PlaceId

            if newPlace ~= lastPlace then
                lastPlace = newPlace

                -- Nettoyage avant reload
                unloaded = true
                for k in pairs(toggleStates) do toggleStates[k] = false end
                if gui and gui.Parent then gui:Destroy() end

                -- Recharge le script depuis ton URL
                local url = "https://raw.githubusercontent.com/Noamist/WTUtility/refs/heads/main/WTUtility_alpha.lua"
                local ok, err = pcall(function()
                    loadstring(game:HttpGet(url))()
                end)

                if not ok then
                    warn("AutoReload error:", err)
                end

                return -- on quitte ce thread, le nouveau script en recréera un
            end
        end
    end
end)

