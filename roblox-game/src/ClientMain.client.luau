-- ClientMain: HUD, minigra startu wyprawy i fanfary. Interfejs budowany z kodu,
-- w nowoczesnym „bąbelkowym" stylu topowych symulatorów: font Fredoka One,
-- gradienty, grube obwódki, animacje pop, responsywne skalowanie pod mobile.
-- Wklej jako LocalScript do StarterPlayer → StarterPlayerScripts (nazwa: ClientMain).
--
-- Klient NICZEGO nie liczy sam — wyświetla atrybuty ustawiane przez serwer
-- i wysyła prośby (sprint, zakup) przez RemoteEventy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local sprintRemote = remotes:WaitForChild("Sprint")
local buyRemote = remotes:WaitForChild("BuyUpgrade")
local notifyRemote = remotes:WaitForChild("Notify")
local sellRemote = remotes:WaitForChild("SellWeakest")
local rebirthRemote = remotes:WaitForChild("Rebirth")
local equipRemote = remotes:WaitForChild("EquipPet")
local hatchRemote = remotes:WaitForChild("HatchResult")
local autoHatchRemote = remotes:WaitForChild("ToggleAutoHatch")
local autoDeleteRemote = remotes:WaitForChild("SetAutoDelete")
local launchRemote = remotes:WaitForChild("LaunchStop")
local escapeRemote = remotes:WaitForChild("Escaped")
local wolfSceneRemote = remotes:WaitForChild("WolfScene")
local abortRemote = remotes:WaitForChild("AbortRun")

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local FONT = Enum.Font.FredokaOne

-- „12345" → „12.3K" … „1.5Qt" (wspólna drabinka sufiksów z GameConfig,
-- żeby HUD pokazywał te same absurdalne liczby co serwer)
local function fmt(n: number): string
	return Config.fmtNumber(n)
end

-- sekundy → „12:34"
local function fmtTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- ============================================================================
-- Tęczowy, świecący font SEKRETÓW — zarejestrowane etykiety cyklują barwę.
-- (pętla renderująca jest niżej, przy fanfarze — potrzebuje jej elementów)
-- ============================================================================

local rainbowLabels: { [TextLabel]: number } = {}
local secretFanfareUntil = 0

local function markRainbow(label: TextLabel)
	if rainbowLabels[label] == nil then
		rainbowLabels[label] = math.random()
	end
end

-- ============================================================================
-- Sprint jest PRZYMUSOWY podczas wyprawy — nie ma przycisku BIEG.
-- Wyprawa zaczyna się w STREFIE STARTU (minigra paska — sekcja niżej),
-- a serwer sam ustawia prędkość wg stanu (ExpeditionState).
-- ============================================================================

local launchShakeMag = 0    -- siła trzęsienia po strzale w pasek (wg tieru)
local launchShakeUntil = 0  -- os.clock() końca trzęsienia startowego

-- ============================================================================
-- Mini-biblioteka stylu (bąbelkowy wygląd współczesnych symulatorów)
-- ============================================================================

local function addCorner(instance: Instance, radius: number?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 14)
	corner.Parent = instance
end

local function addStroke(instance: Instance, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or Color3.fromRGB(20, 24, 38)
	stroke.Thickness = thickness or 2.5
	stroke.Parent = instance
	return stroke
end

local function addGradient(instance: Instance, top: Color3, bottom: Color3)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(top, bottom)
	gradient.Rotation = 90
	gradient.Parent = instance
end

local function addPadding(instance: Instance, pixels: number)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, pixels)
	padding.PaddingRight = UDim.new(0, pixels)
	padding.PaddingTop = UDim.new(0, pixels)
	padding.PaddingBottom = UDim.new(0, pixels)
	padding.Parent = instance
end

-- napis w stylu gry: gruby font + ciemna obwódka liter
local function styleText(label: TextLabel | TextButton, size: number)
	label.Font = FONT
	label.TextSize = size
	label.TextColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Color3.fromRGB(30, 30, 45)
	stroke.Thickness = 2
	stroke.Parent = label
end

-- kolorowa „pigułka" z gradientem (kasa, świat, eventy)
local function makePill(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2, top: Color3, bottom: Color3, textSize: number): TextLabel
	local pill = Instance.new("TextLabel")
	pill.Size = size
	pill.Position = position
	pill.AnchorPoint = anchor
	pill.BackgroundColor3 = Color3.new(1, 1, 1)
	pill.Text = ""
	pill.Parent = parent
	addCorner(pill, 999) -- pełne zaokrąglenie
	addStroke(pill)
	addGradient(pill, top, bottom)
	styleText(pill, textSize)
	return pill
end

-- ciemna karta-panel (kosz, zadania, dziennik)
local function makeCard(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2): Frame
	local card = Instance.new("Frame")
	card.Size = size
	card.Position = position
	card.AnchorPoint = anchor
	card.BackgroundColor3 = Color3.fromRGB(28, 34, 52)
	card.BackgroundTransparency = 0.12
	card.Parent = parent
	addCorner(card, 16)
	addStroke(card, Color3.fromRGB(255, 255, 255), 1.5).Transparency = 0.75
	return card
end

-- nagłówek karty (kolorowa belka u góry)
local function addHeader(card: Frame, text: string, top: Color3, bottom: Color3): TextLabel
	local header = Instance.new("TextLabel")
	header.Size = UDim2.new(1, -12, 0, 30)
	header.Position = UDim2.new(0.5, 0, 0, 6)
	header.AnchorPoint = Vector2.new(0.5, 0)
	header.BackgroundColor3 = Color3.new(1, 1, 1)
	header.Text = text
	header.Parent = card
	addCorner(header, 10)
	addGradient(header, top, bottom)
	styleText(header, 16)
	return header
end

-- treść karty (wielolinijkowy tekst)
local function addBody(card: Frame, textSize: number): TextLabel
	local body = Instance.new("TextLabel")
	body.Size = UDim2.new(1, -20, 1, -48)
	body.Position = UDim2.new(0.5, 0, 0, 42)
	body.AnchorPoint = Vector2.new(0.5, 0)
	body.BackgroundTransparency = 1
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.Text = ""
	body.Parent = card
	styleText(body, textSize)
	return body
end

-- przycisk z gradientem i animacją „pop" przy kliknięciu
local function makeButton(parent: Instance, size: UDim2, position: UDim2, anchor: Vector2, top: Color3, bottom: Color3, textSize: number, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.AnchorPoint = anchor
	button.BackgroundColor3 = Color3.new(1, 1, 1)
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = parent
	addCorner(button, 12)
	addStroke(button)
	addGradient(button, top, bottom)
	styleText(button, textSize)

	local scale = Instance.new("UIScale")
	scale.Parent = button
	button.Activated:Connect(function()
		scale.Scale = 0.9
		TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		onClick()
	end)
	return button
end

-- ============================================================================
-- Korzeń GUI + responsywne skalowanie (telefon dostaje mniejszy HUD)
-- ============================================================================

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local rootScale = Instance.new("UIScale")
rootScale.Parent = gui
local camera = workspace.CurrentCamera
local function updateScale()
	rootScale.Scale = math.clamp(camera.ViewportSize.X / 1280, 0.6, 1)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

-- ============================================================================
-- Góra: kasa, świat, event, powiadomienia
-- ============================================================================

local cashPill = makePill(gui, UDim2.new(0, 280, 0, 52), UDim2.new(0.5, 0, 0, 12), Vector2.new(0.5, 0),
	Color3.fromRGB(96, 205, 106), Color3.fromRGB(38, 140, 70), 24)

-- odznaka poziomu (kółko przy kasie) + pasek XP pod kasą
local levelBadge = Instance.new("TextLabel")
levelBadge.Size = UDim2.new(0, 52, 0, 52)
levelBadge.Position = UDim2.new(0, -8, 0.5, 0)
levelBadge.AnchorPoint = Vector2.new(1, 0.5)
levelBadge.BackgroundColor3 = Color3.new(1, 1, 1)
levelBadge.Text = ""
levelBadge.Parent = cashPill
addCorner(levelBadge, 999)
addStroke(levelBadge)
addGradient(levelBadge, Color3.fromRGB(255, 210, 90), Color3.fromRGB(220, 150, 40))
styleText(levelBadge, 18)
local levelBadgeScale = Instance.new("UIScale")
levelBadgeScale.Parent = levelBadge

local xpBack = Instance.new("Frame")
xpBack.Size = UDim2.new(0, 240, 0, 10)
xpBack.Position = UDim2.new(0.5, 0, 0, 68)
xpBack.AnchorPoint = Vector2.new(0.5, 0)
xpBack.BackgroundColor3 = Color3.fromRGB(28, 34, 52)
xpBack.Parent = gui
addCorner(xpBack, 999)
addStroke(xpBack, nil, 1.5)
local xpFill = Instance.new("Frame")
xpFill.Size = UDim2.new(0, 0, 1, 0)
xpFill.BackgroundColor3 = Color3.new(1, 1, 1)
xpFill.Parent = xpBack
addCorner(xpFill, 999)
addGradient(xpFill, Color3.fromRGB(120, 230, 255), Color3.fromRGB(60, 150, 230))

local worldPill = makePill(gui, UDim2.new(0, 210, 0, 32), UDim2.new(0.5, 0, 0, 84), Vector2.new(0.5, 0),
	Color3.fromRGB(160, 110, 235), Color3.fromRGB(105, 60, 190), 15)

local eventBanner = makePill(gui, UDim2.new(0, 270, 0, 40), UDim2.new(0, 14, 0, 12), Vector2.new(0, 0),
	Color3.fromRGB(255, 170, 70), Color3.fromRGB(220, 110, 30), 16)
eventBanner.Visible = false

task.spawn(function()
	while true do
		local name = workspace:GetAttribute("EventName")
		local endsAt = workspace:GetAttribute("EventEndsAt")
		if name and endsAt then
			local remaining = math.max(0, endsAt - os.time())
			eventBanner.Text = ("⚡ %s — %d s"):format(name, remaining)
			eventBanner.Visible = remaining > 0
		else
			eventBanner.Visible = false
		end
		task.wait(1)
	end
end)

-- powiadomienia (toast): wsuwa się i znika z animacją
local toast = Instance.new("TextLabel")
toast.Size = UDim2.new(0, 460, 0, 38)
toast.Position = UDim2.new(0.5, 0, 0, 126)
toast.AnchorPoint = Vector2.new(0.5, 0)
toast.BackgroundColor3 = Color3.fromRGB(28, 34, 52)
toast.Visible = false
toast.Parent = gui
addCorner(toast, 999)
styleText(toast, 16)
local toastStroke = toast:FindFirstChildOfClass("UIStroke")

local toastId = 0
local function showToast(message: string, duration: number?)
	toastId += 1
	local myId = toastId
	toast.Text = message
	toast.Visible = true
	toast.BackgroundTransparency = 1
	toast.TextTransparency = 1
	toastStroke.Transparency = 1
	toast.Position = UDim2.new(0.5, 0, 0, 114)
	TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0, 126),
		BackgroundTransparency = 0.15,
		TextTransparency = 0,
	}):Play()
	TweenService:Create(toastStroke, TweenInfo.new(0.25), { Transparency = 0 }):Play()
	task.delay(duration or 3, function()
		if toastId ~= myId then return end
		local out = TweenService:Create(toast, TweenInfo.new(0.3), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		})
		out:Play()
		TweenService:Create(toastStroke, TweenInfo.new(0.3), { Transparency = 1 }):Play()
		out.Completed:Once(function()
			if toastId == myId then
				toast.Visible = false
			end
		end)
	end)
end

notifyRemote.OnClientEvent:Connect(showToast)

-- ============================================================================
-- Lewa kolumna: ulepszenia + sprzedaż (kolorowe przyciski)
-- ============================================================================

local upgradeButtons: { [string]: TextButton } = {}

-- grządki kupuje się na FIZYCZNYM stanowisku przy działce (nie w menu)
local BUTTONS = {
	{ id = "Stamina", top = Color3.fromRGB(255, 150, 90),  bottom = Color3.fromRGB(215, 85, 40) },
	{ id = "Thermos", top = Color3.fromRGB(110, 190, 255), bottom = Color3.fromRGB(45, 110, 210) },
}

-- SKLEP U SPRZEDAWCY: przyciski ulepszeń i sprzedaży pokazują się
-- dopiero, gdy stoisz przy straganie (NPC = sklep, nie HUD na stałe)
local shopButtons: { GuiObject } = {}

for index, def in BUTTONS do
	upgradeButtons[def.id] = makeButton(gui,
		UDim2.new(0, 240, 0, 48),
		UDim2.new(0, 14, 0.5, -110 + (index - 1) * 58),
		Vector2.new(0, 0),
		def.top, def.bottom, 15,
		function()
			buyRemote:FireServer(def.id)
		end)
	upgradeButtons[def.id].Visible = false
	table.insert(shopButtons, upgradeButtons[def.id])
end

local sellButton = makeButton(gui,
	UDim2.new(0, 240, 0, 48),
	UDim2.new(0, 14, 0.5, -110 + #BUTTONS * 58),
	Vector2.new(0, 0),
	Color3.fromRGB(250, 205, 90), Color3.fromRGB(205, 150, 40), 15,
	function()
		sellRemote:FireServer()
	end)
sellButton.Text = "💸 Sprzedaj najsłabszy"
sellButton.Visible = false
table.insert(shopButtons, sellButton)

-- pokaż sklep tylko przy straganie sprzedawcy (bieżący świat)
task.spawn(function()
	while true do
		task.wait(0.4)
		local worldIdx = player:GetAttribute("CurrentWorld") or 1
		local worldsFolder = workspace:FindFirstChild("Worlds")
		local worldFolder = worldsFolder and worldsFolder:FindFirstChild("World" .. worldIdx)
		local counter = worldFolder and worldFolder:FindFirstChild("StallCounter")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local near = counter ~= nil and root ~= nil
			and (counter.Position - root.Position).Magnitude < 15
		for _, button in shopButtons do
			button.Visible = near == true
		end
	end
end)

-- ============================================================================
-- Prawa strona: kosz; lewy dół: dzienne zadania
-- ============================================================================

local basketCard = makeCard(gui, UDim2.new(0, 250, 0, 230), UDim2.new(1, -14, 0.5, 0), Vector2.new(1, 0.5))
addHeader(basketCard, "🧺 KOSZ", Color3.fromRGB(120, 200, 120), Color3.fromRGB(60, 140, 70))
local basketBody = addBody(basketCard, 14)

local questsCard = makeCard(gui, UDim2.new(0, 270, 0, 130), UDim2.new(0, 14, 1, -14), Vector2.new(0, 1))
local questsHeader = addHeader(questsCard, "📋 DZISIAJ", Color3.fromRGB(255, 170, 70), Color3.fromRGB(215, 110, 35))
local questsBody = addBody(questsCard, 13)

-- ============================================================================
-- Dziennik grzybiarza: przycisk + wyskakujący panel z przewijaniem
-- ============================================================================

local journalPanel = makeCard(gui, UDim2.new(0, 360, 0, 380), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
journalPanel.Visible = false
local journalHeader = addHeader(journalPanel, "📖 DZIENNIK", Color3.fromRGB(200, 150, 90), Color3.fromRGB(140, 95, 50))

local journalScroll = Instance.new("ScrollingFrame")
journalScroll.Size = UDim2.new(1, -20, 1, -50)
journalScroll.Position = UDim2.new(0.5, 0, 0, 42)
journalScroll.AnchorPoint = Vector2.new(0.5, 0)
journalScroll.BackgroundTransparency = 1
journalScroll.ScrollBarThickness = 6
journalScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
journalScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
journalScroll.Parent = journalPanel

local journalListLayout = Instance.new("UIListLayout")
journalListLayout.SortOrder = Enum.SortOrder.LayoutOrder
journalListLayout.Padding = UDim.new(0, 10)
journalListLayout.Parent = journalScroll

-- SIATKA SYLWETEK: podgląd 3D każdego gatunku bieżącego świata.
-- Niezdobyty = CAŁY CZARNY (sama sylwetka + „???"), zdobyty = pełne kolory.
local journalGrid = Instance.new("Frame")
journalGrid.Size = UDim2.new(1, -8, 0, 0)
journalGrid.AutomaticSize = Enum.AutomaticSize.Y
journalGrid.BackgroundTransparency = 1
journalGrid.LayoutOrder = 1
journalGrid.Parent = journalScroll
local journalGridLayout = Instance.new("UIGridLayout")
journalGridLayout.CellSize = UDim2.new(0, 100, 0, 118)
journalGridLayout.CellPadding = UDim2.new(0, 7, 0, 7)
journalGridLayout.SortOrder = Enum.SortOrder.LayoutOrder
journalGridLayout.Parent = journalGrid

local journalBody = Instance.new("TextLabel")
journalBody.Size = UDim2.new(1, -8, 0, 0)
journalBody.AutomaticSize = Enum.AutomaticSize.Y
journalBody.BackgroundTransparency = 1
journalBody.TextXAlignment = Enum.TextXAlignment.Left
journalBody.TextYAlignment = Enum.TextYAlignment.Top
journalBody.TextWrapped = true
journalBody.LayoutOrder = 2
journalBody.Parent = journalScroll
styleText(journalBody, 15)

local function buildJournalTiles()
	for _, child in journalGrid:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local worldIdx = player:GetAttribute("CurrentWorld") or 1
	local world = Config.Worlds[worldIdx]
	if not world then return end
	local ok, owned = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("JournalSpeciesJSON") or "{}")
	end)
	if not ok then
		owned = {}
	end

	for speciesIdx, species in world.species do
		local has = owned[("%d:%d"):format(worldIdx, speciesIdx)] == true

		local tile = Instance.new("Frame")
		tile.LayoutOrder = speciesIdx
		tile.BackgroundColor3 = Color3.fromRGB(38, 42, 58)
		tile.BackgroundTransparency = 0.2
		addCorner(tile, 12)
		tile.Parent = journalGrid

		local viewport = Instance.new("ViewportFrame")
		viewport.Size = UDim2.new(1, -8, 1, -32)
		viewport.Position = UDim2.new(0.5, 0, 0, 4)
		viewport.AnchorPoint = Vector2.new(0.5, 0)
		viewport.BackgroundTransparency = 1
		viewport.Ambient = Color3.fromRGB(210, 210, 225)
		viewport.LightColor = Color3.fromRGB(255, 255, 255)
		viewport.Parent = tile

		-- model gatunku: import z Models/Grzyby, a bez niego mini-grzybek
		local model: Model
		local modelsRoot = ReplicatedStorage:FindFirstChild("Models")
		local speciesFolder = modelsRoot and modelsRoot:FindFirstChild("Grzyby")
		local template = speciesFolder and speciesFolder:FindFirstChild(species.name)
		if template and template:IsA("Model") then
			model = template:Clone()
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("ParticleEmitter") or descendant:IsA("Light") then
					descendant:Destroy()
				end
			end
		else
			model = Instance.new("Model")
			local stem = Instance.new("Part")
			stem.Shape = Enum.PartType.Cylinder
			stem.Size = Vector3.new(1.2, 0.6, 0.6)
			stem.Color = Color3.fromRGB(240, 232, 210)
			stem.Anchored = true
			stem.CFrame = CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
			stem.Parent = model
			local cap = Instance.new("Part")
			cap.Shape = Enum.PartType.Ball
			cap.Size = Vector3.new(1.7, 1.15, 1.7)
			cap.Color = world.theme.caps[(speciesIdx - 1) % #world.theme.caps + 1]
			cap.Anchored = true
			cap.CFrame = CFrame.new(0, 1.35, 0)
			cap.Parent = model
		end
		if not has then
			-- sylwetka: wszystko na czarno do czasu zdobycia
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") then
					descendant.Color = Color3.fromRGB(10, 10, 14)
					descendant.Material = Enum.Material.SmoothPlastic
				end
			end
		end
		model.Parent = viewport
		local viewportCamera = Instance.new("Camera")
		viewportCamera.Parent = viewport
		viewport.CurrentCamera = viewportCamera
		local boxCF, boxSize = model:GetBoundingBox()
		local radius = math.max(boxSize.X, boxSize.Y, boxSize.Z, 1)
		viewportCamera.CFrame = CFrame.lookAt(
			boxCF.Position + Vector3.new(radius * 0.9, radius * 0.65, -radius * 1.25),
			boxCF.Position)

		local nameLabel = Instance.new("TextLabel")
		nameLabel.AnchorPoint = Vector2.new(0.5, 1)
		nameLabel.Position = UDim2.new(0.5, 0, 1, -4)
		nameLabel.Size = UDim2.new(1, -8, 0, 24)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Font = FONT
		nameLabel.TextScaled = true
		nameLabel.TextColor3 = has and Color3.new(1, 1, 1) or Color3.fromRGB(130, 130, 145)
		nameLabel.TextStrokeTransparency = 0.5
		nameLabel.Text = has and species.name or "???"
		nameLabel.Parent = tile
	end
end

local journalScale = Instance.new("UIScale")
journalScale.Parent = journalPanel

local function setJournalOpen(open: boolean)
	if open then
		buildJournalTiles()
		journalPanel.Visible = true
		journalScale.Scale = 0.7
		TweenService:Create(journalScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	else
		journalPanel.Visible = false
	end
end

player:GetAttributeChangedSignal("JournalSpeciesJSON"):Connect(function()
	if journalPanel.Visible then
		buildJournalTiles()
	end
end)
player:GetAttributeChangedSignal("CurrentWorld"):Connect(function()
	if journalPanel.Visible then
		buildJournalTiles()
	end
end)

local journalButton = makeButton(gui,
	UDim2.new(0, 170, 0, 42),
	UDim2.new(1, -14, 0, 12),
	Vector2.new(1, 0),
	Color3.fromRGB(200, 150, 90), Color3.fromRGB(140, 95, 50), 15,
	function()
		setJournalOpen(not journalPanel.Visible)
	end)

makeButton(journalPanel,
	UDim2.new(0, 30, 0, 30),
	UDim2.new(1, -6, 0, 6),
	Vector2.new(1, 0),
	Color3.fromRGB(240, 100, 90), Color3.fromRGB(190, 55, 45), 16,
	function()
		setJournalOpen(false)
	end).Text = "✕"

-- ============================================================================
-- Rebirth: przycisk + minimalistyczny modal (mnożnik → mnożnik, jedna decyzja)
-- ============================================================================

local rebirthPanel = makeCard(gui, UDim2.new(0, 300, 0, 300), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
rebirthPanel.Visible = false
addHeader(rebirthPanel, "🌀 REBIRTH", Color3.fromRGB(190, 120, 255), Color3.fromRGB(120, 60, 200))

-- duża linia mnożnika: „×1.5 → ×2.0" — sedno decyzji w jednym spojrzeniu
local rebirthMultLine = Instance.new("TextLabel")
rebirthMultLine.Size = UDim2.new(1, -24, 0, 56)
rebirthMultLine.Position = UDim2.new(0.5, 0, 0, 52)
rebirthMultLine.AnchorPoint = Vector2.new(0.5, 0)
rebirthMultLine.BackgroundTransparency = 1
rebirthMultLine.Parent = rebirthPanel
styleText(rebirthMultLine, 34)
rebirthMultLine.TextColor3 = Color3.fromRGB(210, 160, 255)

local rebirthSubtitle = Instance.new("TextLabel")
rebirthSubtitle.Size = UDim2.new(1, -24, 0, 20)
rebirthSubtitle.Position = UDim2.new(0.5, 0, 0, 108)
rebirthSubtitle.AnchorPoint = Vector2.new(0.5, 0)
rebirthSubtitle.BackgroundTransparency = 1
rebirthSubtitle.Text = "stały mnożnik dochodu i szczęścia"
rebirthSubtitle.Parent = rebirthPanel
styleText(rebirthSubtitle, 14)
rebirthSubtitle.TextTransparency = 0.25

local rebirthInfo = Instance.new("TextLabel")
rebirthInfo.Size = UDim2.new(1, -32, 0, 72)
rebirthInfo.Position = UDim2.new(0.5, 0, 0, 140)
rebirthInfo.AnchorPoint = Vector2.new(0.5, 0)
rebirthInfo.BackgroundTransparency = 1
rebirthInfo.TextWrapped = true
rebirthInfo.Text = "Zeruje: kasę, ulepszenia, półki, światy\nZostaje: poziom, dziennik, seria dzienna"
rebirthInfo.Parent = rebirthPanel
styleText(rebirthInfo, 14)
rebirthInfo.TextTransparency = 0.15

local rebirthConfirm = makeButton(rebirthPanel,
	UDim2.new(1, -32, 0, 48),
	UDim2.new(0.5, 0, 1, -14),
	Vector2.new(0.5, 1),
	Color3.fromRGB(190, 120, 255), Color3.fromRGB(120, 60, 200), 17,
	function()
		rebirthRemote:FireServer()
		rebirthPanel.Visible = false
	end)
local rebirthConfirmGradient = rebirthConfirm:FindFirstChildOfClass("UIGradient")

makeButton(rebirthPanel,
	UDim2.new(0, 30, 0, 30),
	UDim2.new(1, -6, 0, 6),
	Vector2.new(1, 0),
	Color3.fromRGB(240, 100, 90), Color3.fromRGB(190, 55, 45), 16,
	function()
		rebirthPanel.Visible = false
	end).Text = "✕"

local rebirthPanelScale = Instance.new("UIScale")
rebirthPanelScale.Parent = rebirthPanel

local rebirthButton = makeButton(gui,
	UDim2.new(0, 170, 0, 42),
	UDim2.new(1, -14, 0, 62),
	Vector2.new(1, 0),
	Color3.fromRGB(190, 120, 255), Color3.fromRGB(120, 60, 200), 15,
	function()
		rebirthPanel.Visible = not rebirthPanel.Visible
		if rebirthPanel.Visible then
			rebirthPanelScale.Scale = 0.7
			TweenService:Create(rebirthPanelScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)

-- ============================================================================
-- Pety: panel z listą (klik = załóż/zdejmij)
-- ============================================================================

local petsPanel = makeCard(gui, UDim2.new(0, 340, 0, 380), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
petsPanel.Visible = false
local petsHeader = addHeader(petsPanel, "🐾 PETY", Color3.fromRGB(120, 200, 160), Color3.fromRGB(55, 140, 100))

local petsScroll = Instance.new("ScrollingFrame")
petsScroll.Size = UDim2.new(1, -20, 1, -50)
petsScroll.Position = UDim2.new(0.5, 0, 0, 42)
petsScroll.AnchorPoint = Vector2.new(0.5, 0)
petsScroll.BackgroundTransparency = 1
petsScroll.ScrollBarThickness = 6
petsScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
petsScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
petsScroll.Parent = petsPanel

local petsLayout = Instance.new("UIListLayout")
petsLayout.Padding = UDim.new(0, 6)
petsLayout.SortOrder = Enum.SortOrder.LayoutOrder
petsLayout.Parent = petsScroll

makeButton(petsPanel,
	UDim2.new(0, 30, 0, 30),
	UDim2.new(1, -6, 0, 6),
	Vector2.new(1, 0),
	Color3.fromRGB(240, 100, 90), Color3.fromRGB(190, 55, 45), 16,
	function()
		petsPanel.Visible = false
	end).Text = "✕"

local function decodePets(): { any }
	local ok, pets = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("PetsJSON") or "[]")
	end)
	return ok and pets or {}
end

local function rebuildPetList()
	for _, child in petsScroll:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	local pets = decodePets()
	petsHeader.Text = ("🐾 PETY (%d/%d)"):format(#pets, Config.Pets.maxOwned)
	for index, pet in pets do
		local rarity = Config.Pets.rarities[pet.r]
		local name = Config.Pets.poolsByWorld[pet.w][pet.p]
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, -8, 0, 52)
		row.BackgroundColor3 = pet.eq and Color3.fromRGB(50, 90, 65) or Color3.fromRGB(40, 46, 66)
		row.AutoButtonColor = true
		row.LayoutOrder = index
		row.Text = ("%s %s (%s)\n+%d%% 💰  +%d%% 🍀%s"):format(
			pet.eq and "✅" or "▫️", name, rarity.name,
			math.floor((Config.Pets.incomeBonusByRarity[pet.r] or 0) * 100),
			math.floor((Config.Pets.luckBonusByRarity[pet.r] or 0) * 100),
			pet.eq and "   [ZAŁOŻONY]" or "")
		row.Parent = petsScroll
		addCorner(row, 10)
		styleText(row, 14)
		if rarity.secret then
			row.Text = "✨ " .. row.Text
			markRainbow(row) -- SEKRET: tęczowy świecący font
		else
			row.TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.5)
		end
		row.Activated:Connect(function()
			equipRemote:FireServer(index)
		end)
	end
end

player:GetAttributeChangedSignal("PetsJSON"):Connect(function()
	if petsPanel.Visible then
		rebuildPetList()
	end
end)

local petsButton = makeButton(gui,
	UDim2.new(0, 170, 0, 42),
	UDim2.new(1, -14, 0, 112),
	Vector2.new(1, 0),
	Color3.fromRGB(120, 200, 160), Color3.fromRGB(55, 140, 100), 15,
	function()
		petsPanel.Visible = not petsPanel.Visible
		if petsPanel.Visible then
			rebuildPetList()
		end
	end)
petsButton.Text = "🐾 Pety"

-- ============================================================================
-- Panel jaja: pokazuje się przy podejściu do gniazda — dropy z szansami
-- (klik w peta = zaznacz auto-usuwanie), szczęście z passów, przycisk AUTO
-- ============================================================================

local function decodeAutoDelete(): { [string]: boolean }
	local ok, result = pcall(function()
		return HttpService:JSONDecode(player:GetAttribute("AutoDeleteJSON") or "{}")
	end)
	return ok and result or {}
end

local eggPanel = makeCard(gui, UDim2.new(0, 290, 0, 316), UDim2.new(0, 262, 0.5, 0), Vector2.new(0, 0.5))
eggPanel.Visible = false
local eggHeader = addHeader(eggPanel, "🥚 JAJO", Color3.fromRGB(245, 200, 110), Color3.fromRGB(205, 150, 60))

local eggRows: { TextButton } = {}
for i = 1, 5 do
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -20, 0, 36)
	row.Position = UDim2.new(0.5, 0, 0, 40 + (i - 1) * 40)
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.BackgroundColor3 = Color3.fromRGB(40, 46, 66)
	row.AutoButtonColor = true
	row.Text = ""
	row.Parent = eggPanel
	addCorner(row, 8)
	styleText(row, 13)
	row.Activated:Connect(function()
		if i >= 5 then
			showToast("🔒 SEKRETÓW nie można auto-usuwać.")
			return
		end
		local worldIdx = player:GetAttribute("CurrentWorld") or 1
		local marked = decodeAutoDelete()[worldIdx .. ":" .. i] == true
		autoDeleteRemote:FireServer(worldIdx, i, not marked)
	end)
	eggRows[i] = row
end

local eggLuckLine = Instance.new("TextLabel")
eggLuckLine.Size = UDim2.new(1, -20, 0, 20)
eggLuckLine.Position = UDim2.new(0.5, 0, 0, 242)
eggLuckLine.AnchorPoint = Vector2.new(0.5, 0)
eggLuckLine.BackgroundTransparency = 1
eggLuckLine.Parent = eggPanel
styleText(eggLuckLine, 13)

local autoButton = makeButton(eggPanel,
	UDim2.new(1, -20, 0, 36),
	UDim2.new(0.5, 0, 1, -10),
	Vector2.new(0.5, 1),
	Color3.fromRGB(120, 200, 160), Color3.fromRGB(55, 140, 100), 14,
	function()
		if player:GetAttribute("OwnsAutoHatch") then
			autoHatchRemote:FireServer()
		else
			local pass = Config.GamePasses.AutoHatch
			if pass.id ~= 0 then
				MarketplaceService:PromptGamePassPurchase(player, pass.id)
			else
				showToast("⚠️ Pass nieaktywny — uzupełnij ID w GameConfig (faza 8).")
			end
		end
	end)

local function refreshEggPanel()
	local worldIdx = player:GetAttribute("CurrentWorld") or 1
	local pool = Config.Pets.poolsByWorld[worldIdx]
	local luck = player:GetAttribute("EggLuck") or 1
	eggHeader.Text = ("🥚 JAJO — %s 💰"):format(fmt(Config.Pets.eggCostByWorld[worldIdx]))

	-- szanse z uwzględnieniem szczęścia (te same wagi co na serwerze;
	-- SEKRET nigdy nie jest podbijany — twarde 0,1%)
	local lastIndex = #Config.Pets.hatchWeights
	local weights, total = {}, 0
	for i, weight in Config.Pets.hatchWeights do
		local boosted = i >= Config.Pets.luckAffectsFrom
			and not (Config.Pets.luckSkipsLast and i == lastIndex)
		local adjusted = boosted and weight * luck or weight
		weights[i] = adjusted
		total += adjusted
	end

	local autoDelete = decodeAutoDelete()
	for i, row in eggRows do
		local rarity = Config.Pets.rarities[i]
		local chance = weights[i] / total * 100
		local marked = autoDelete[worldIdx .. ":" .. i] == true
		row.Text = ("%s%s%.1f%%  %s (%s)  +%d%% 💰"):format(
			marked and "🗑️ " or "", rarity.secret and "✨ " or "",
			chance, pool[i], rarity.name,
			math.floor((Config.Pets.incomeBonusByRarity[i] or 0) * 100))
		if rarity.secret then
			markRainbow(row) -- tęczowy świecący wiersz Sekreta
		else
			row.TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.5)
		end
		row.BackgroundTransparency = marked and 0.6 or 0.1
	end

	eggLuckLine.Text = ("🍀 Szczęście jaja: ×%d%s"):format(luck,
		player:GetAttribute("OwnsTripleHatch") and "   |   🥚×3 aktywne" or "")
	if player:GetAttribute("OwnsAutoHatch") then
		autoButton.Text = player:GetAttribute("AutoHatchOn")
			and "🤖 AUTO: WŁĄCZONE (klik = stop)"
			or "🤖 AUTO: wyłączone (klik = start)"
	else
		autoButton.Text = ("🤖 AUTO — pass %d R$"):format(Config.GamePasses.AutoHatch.priceRobux)
	end
end

-- pokazuj panel tylko przy jajku bieżącego świata
task.spawn(function()
	while true do
		local worldIdx = player:GetAttribute("CurrentWorld") or 1
		local worlds = workspace:FindFirstChild("Worlds")
		local worldFolder = worlds and worlds:FindFirstChild("World" .. worldIdx)
		local egg = worldFolder and worldFolder:FindFirstChild("WorldEgg")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local near = egg and root and (egg.Position - root.Position).Magnitude <= 16
		if near then
			eggPanel.Visible = true
			refreshEggPanel()
		else
			eggPanel.Visible = false
		end
		task.wait(0.5)
	end
end)

-- ============================================================================
-- Dół: pasek kondycji + pity
-- ============================================================================

local staminaBack = Instance.new("Frame")
staminaBack.Size = UDim2.new(0, 320, 0, 24)
staminaBack.Position = UDim2.new(0.5, 0, 1, -68)
staminaBack.AnchorPoint = Vector2.new(0.5, 1)
staminaBack.BackgroundColor3 = Color3.fromRGB(28, 34, 52)
staminaBack.Parent = gui
addCorner(staminaBack, 999)
addStroke(staminaBack)

local staminaFill = Instance.new("Frame")
staminaFill.Size = UDim2.new(1, 0, 1, 0)
staminaFill.BackgroundColor3 = Color3.new(1, 1, 1)
staminaFill.Parent = staminaBack
addCorner(staminaFill, 999)
local staminaGradient = Instance.new("UIGradient")
staminaGradient.Color = ColorSequence.new(Color3.fromRGB(130, 230, 130), Color3.fromRGB(60, 170, 80))
staminaGradient.Rotation = 90
staminaGradient.Parent = staminaFill

local staminaText = Instance.new("TextLabel")
staminaText.Size = UDim2.new(1, 0, 1, 0)
staminaText.BackgroundTransparency = 1
staminaText.Parent = staminaBack
styleText(staminaText, 14)

local pityPill = makePill(gui, UDim2.new(0, 260, 0, 26), UDim2.new(0.5, 0, 1, -36), Vector2.new(0.5, 1),
	Color3.fromRGB(120, 220, 160), Color3.fromRGB(55, 150, 95), 13)

-- ============================================================================
-- Samouczek: baner + pływający znacznik nad celem
-- ============================================================================

local tutorialBanner = makePill(gui, UDim2.new(0, 560, 0, 42), UDim2.new(0.5, 0, 0, 172), Vector2.new(0.5, 0),
	Color3.fromRGB(255, 210, 90), Color3.fromRGB(220, 160, 40), 16)
tutorialBanner.Visible = false

-- ============================================================================
-- Combo: licznik z „punchem" i rosnącym dźwiękiem + fanfara level-upu
-- ============================================================================

-- wbudowany dźwięk silnika (podmienimy na własny w fazie oprawy audio)
local ding = Instance.new("Sound")
ding.SoundId = "rbxasset://sounds/electronicpingshort.wav"
ding.Volume = 0.6
ding.Parent = gui

local comboLabel = Instance.new("TextLabel")
comboLabel.Size = UDim2.new(0, 220, 0, 60)
comboLabel.Position = UDim2.new(0.5, 0, 0.32, 0)
comboLabel.AnchorPoint = Vector2.new(0.5, 0.5)
comboLabel.BackgroundTransparency = 1
comboLabel.Visible = false
comboLabel.Parent = gui
styleText(comboLabel, 34)
comboLabel.TextColor3 = Color3.fromRGB(255, 170, 70)
local comboScale = Instance.new("UIScale")
comboScale.Parent = comboLabel

local lastCombo = 0
player:GetAttributeChangedSignal("ComboCount"):Connect(function()
	local combo = player:GetAttribute("ComboCount") or 0
	if combo >= 2 then
		comboLabel.Text = ("🔥 COMBO ×%d"):format(combo)
		comboLabel.Visible = true
		comboScale.Scale = 1.35
		TweenService:Create(comboScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	elseif combo == 0 then
		comboLabel.Visible = false
	end
	-- dźwięk ścięcia z pitchem rosnącym wraz z combo (satysfakcja serii)
	if combo > 0 and combo >= lastCombo then
		ding.PlaybackSpeed = math.min(0.9 + combo * 0.06, 2)
		ding:Play()
	end
	lastCombo = combo
end)

-- fanfara poziomu: błysk ekranu, wielki napis, seria rosnących dźwięków
local levelFlash = Instance.new("Frame")
levelFlash.Size = UDim2.fromScale(1, 1)
levelFlash.BackgroundColor3 = Color3.fromRGB(255, 230, 150)
levelFlash.BackgroundTransparency = 1
levelFlash.ZIndex = 5
levelFlash.Parent = gui

local levelUpLabel = Instance.new("TextLabel")
levelUpLabel.Size = UDim2.new(0, 500, 0, 90)
levelUpLabel.Position = UDim2.new(0.5, 0, 0.4, 0)
levelUpLabel.AnchorPoint = Vector2.new(0.5, 0.5)
levelUpLabel.BackgroundTransparency = 1
levelUpLabel.Visible = false
levelUpLabel.ZIndex = 6
levelUpLabel.Parent = gui
styleText(levelUpLabel, 44)
levelUpLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
local levelUpScale = Instance.new("UIScale")
levelUpScale.Parent = levelUpLabel

-- fioletowa fanfara rebirtha (używa tych samych elementów co level-up)
local lastRebirths = -1
player:GetAttributeChangedSignal("Rebirths"):Connect(function()
	local rebirths = player:GetAttribute("Rebirths") or 0
	if lastRebirths >= 0 and rebirths > lastRebirths then
		levelFlash.BackgroundColor3 = Color3.fromRGB(200, 150, 255)
		levelFlash.BackgroundTransparency = 0.45
		TweenService:Create(levelFlash, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		levelUpLabel.TextColor3 = Color3.fromRGB(210, 160, 255)
		levelUpLabel.Text = ("🌀 REBIRTH ×%d!"):format(rebirths)
		levelUpLabel.Visible = true
		levelUpLabel.TextTransparency = 0
		levelUpScale.Scale = 0.4
		TweenService:Create(levelUpScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(1.8, function()
			TweenService:Create(levelUpLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.delay(0.4, function()
				levelUpLabel.Visible = false
				levelUpLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
			end)
		end)
		for step = 0, 3 do
			task.delay(step * 0.11, function()
				ding.PlaybackSpeed = 0.8 + step * 0.3
				ding:Play()
			end)
		end
	end
	lastRebirths = rebirths
end)

local lastLevel = 0
player:GetAttributeChangedSignal("Level"):Connect(function()
	local level = player:GetAttribute("Level") or 1
	if lastLevel > 0 and level > lastLevel then
		-- błysk
		levelFlash.BackgroundColor3 = Color3.fromRGB(255, 230, 150)
		levelFlash.BackgroundTransparency = 0.55
		TweenService:Create(levelFlash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		-- napis z punchem
		levelUpLabel.Text = ("⬆️ POZIOM %d!"):format(level)
		levelUpLabel.Visible = true
		levelUpLabel.TextTransparency = 0
		levelUpScale.Scale = 0.5
		TweenService:Create(levelUpScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		task.delay(1.4, function()
			TweenService:Create(levelUpLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			task.delay(0.4, function() levelUpLabel.Visible = false end)
		end)
		-- odznaka podskakuje
		levelBadgeScale.Scale = 1.4
		TweenService:Create(levelBadgeScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		-- trzy rosnące dźwięki
		for step = 0, 2 do
			task.delay(step * 0.12, function()
				ding.PlaybackSpeed = 1 + step * 0.25
				ding:Play()
			end)
		end
	end
	lastLevel = level
end)

-- pętla tęczowego fontu SEKRETÓW (wiersze paneli, podpisy petów, fanfara)
task.spawn(function()
	while true do
		local now = os.clock()
		for label, offset in rainbowLabels do
			if label.Parent then
				label.TextColor3 = Color3.fromHSV((now * 0.6 + offset) % 1, 0.85, 1)
			else
				rainbowLabels[label] = nil -- sprzątanie po zniszczonych etykietach
			end
		end
		if now < secretFanfareUntil then
			levelUpLabel.TextColor3 = Color3.fromHSV((now * 0.9) % 1, 0.9, 1)
		end
		task.wait(0.08)
	end
end)

local marker = Instance.new("BillboardGui")
marker.Name = "TutorialMarker"
marker.Size = UDim2.new(0, 70, 0, 70)
marker.StudsOffset = Vector3.new(0, 5, 0)
marker.AlwaysOnTop = true
marker.Enabled = false
local markerLabel = Instance.new("TextLabel")
markerLabel.Size = UDim2.fromScale(1, 1)
markerLabel.BackgroundTransparency = 1
markerLabel.Text = "⬇️"
markerLabel.TextScaled = true
markerLabel.Parent = marker

local function nearestOwnMushroomPart(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local folder = workspace:FindFirstChild("Mushrooms_" .. player.UserId)
	if not (root and folder) then
		return nil
	end
	local best: BasePart? = nil
	local bestDist = math.huge
	for _, node in folder:GetChildren() do
		local part = node:FindFirstChildWhichIsA("BasePart")
		if part then
			local dist = (part.Position - (root :: BasePart).Position).Magnitude
			if dist < bestDist then
				best, bestDist = part, dist
			end
		end
	end
	return best
end

task.spawn(function()
	while true do
		local step = player:GetAttribute("TutorialStep") or 0
		if step == 1 then
			tutorialBanner.Text = "🍄 KROK 1/3: Stań na 🚀 STREFIE STARTU, traf w pasek i WBIEGNIJ w grzybka!"
			local target = nearestOwnMushroomPart()
			marker.Parent = target
			marker.Enabled = target ~= nil
		elseif step == 2 then
			tutorialBanner.Text = "📦 KROK 2/3: Uciekaj do bazy! Grzyb wpadnie do plecaka — wciśnij [1] i zasadź w wybranej grządce"
			local worldIdx = player:GetAttribute("CurrentWorld") or 1
			local worlds = workspace:FindFirstChild("Worlds")
			local worldFolder = worlds and worlds:FindFirstChild("World" .. worldIdx)
			marker.Parent = worldFolder and worldFolder:FindFirstChild("BasePad")
			marker.Enabled = marker.Parent ~= nil
		elseif step == 3 then
			tutorialBanner.Text = "⬆️ KROK 3/3: Kup pierwsze ulepszenie u sprzedawcy 🍄 (stragan przy bazie)"
			marker.Enabled = false
			marker.Parent = nil
		else
			marker.Enabled = false
			marker.Parent = nil
		end
		tutorialBanner.Visible = step >= 1 and step <= 3
		task.wait(1)
	end
end)

-- ============================================================================
-- Odświeżanie HUD z atrybutów gracza (ustawia je serwer)
-- ============================================================================

local function refresh()
	local cash = player:GetAttribute("Cash") or 0
	local income = player:GetAttribute("IncomePerSec") or 0
	cashPill.Text = ("💰 %s  (+%s/s)"):format(fmt(cash), fmt(income))
	worldPill.Text = "🌍 " .. (player:GetAttribute("WorldName") or "…")

	-- poziom + pasek XP (zawsze rośnie — to on trzyma wzrok)
	levelBadge.Text = tostring(player:GetAttribute("Level") or 1)
	local xp = player:GetAttribute("XP") or 0
	local xpNeeded = math.max(1, player:GetAttribute("XPNeeded") or 1)
	TweenService:Create(xpFill, TweenInfo.new(0.25), { Size = UDim2.new(math.min(xp / xpNeeded, 1), 0, 1, 0) }):Play()

	local stamina = player:GetAttribute("Stamina") or 0
	local staminaMax = math.max(1, player:GetAttribute("StaminaMax") or 1)
	local fraction = stamina / staminaMax
	TweenService:Create(staminaFill, TweenInfo.new(0.2), { Size = UDim2.new(fraction, 0, 1, 0) }):Play()
	staminaGradient.Color = fraction > 0.3
		and ColorSequence.new(Color3.fromRGB(130, 230, 130), Color3.fromRGB(60, 170, 80))
		or ColorSequence.new(Color3.fromRGB(250, 130, 100), Color3.fromRGB(200, 65, 45))
	staminaText.Text = ("🏃 %d / %d"):format(stamina, staminaMax)

	local pity = player:GetAttribute("Pity") or 0
	pityPill.Text = ("🍀 Gwarancja Rzadkiego: %d/%d"):format(pity, Config.Pity.cutsForGuaranteedRare)

	local carried = player:GetAttribute("CarriedSummary") or ""
	local carriedCount = player:GetAttribute("CarriedCount") or 0
	local carrySlots = player:GetAttribute("CarrySlots") or 2
	local shelfCount = player:GetAttribute("ShelfCount") or 0
	local plotCap = player:GetAttribute("PlotCapacity") or 10
	basketBody.Text = ("🎒 Miejsca: %d/%d\n%s\n\n🌱 Grządki: %d/%d (zbieraj z zielonych pól!)")
		:format(carriedCount, carrySlots,
			carried == "" and "— pusto — (leć do lasu po łup!)" or carried,
			shelfCount, plotCap)

	-- przyciski ulepszeń z aktualnymi cenami (te same wzory co na serwerze)
	local staminaLevel = player:GetAttribute("StaminaLevel") or 0
	local thermosLevel = player:GetAttribute("ThermosLevel") or 0
	upgradeButtons.Stamina.Text = ("🏃 Kondycja [%d] — %s 💰")
		:format(staminaLevel, fmt(Config.statCost(Config.Stats.Stamina, staminaLevel)))
	upgradeButtons.Thermos.Text = ("❄️ Termos [%d] — %s 💰")
		:format(thermosLevel, fmt(Config.statCost(Config.Stats.Thermos, thermosLevel)))
	-- (grządki: cena i zakup na zielonym stanowisku przy działce)

	-- dzienne zadania + skrzynka czasowa
	local chestIn = player:GetAttribute("ChestIn") or 0
	questsHeader.Text = ("📋 DZISIAJ   🎁 %s"):format(fmtTime(chestIn))
	questsBody.Text = player:GetAttribute("QuestsText") or ""

	-- dziennik grzybiarza
	local journalCount = player:GetAttribute("JournalCount") or 0
	local journalTotal = player:GetAttribute("JournalTotal") or 0
	journalButton.Text = ("📖 Dziennik %d/%d"):format(journalCount, journalTotal)
	journalHeader.Text = ("📖 DZIENNIK %d/%d"):format(journalCount, journalTotal)
	journalBody.Text = player:GetAttribute("JournalText") or ""

	-- rebirth: przycisk pokazuje obecny mnożnik, modal — decyzję i cenę
	local rebirths = player:GetAttribute("Rebirths") or 0
	local rebirthMultNow = player:GetAttribute("RebirthMult") or 1
	local rebirthCost = player:GetAttribute("RebirthCost") or 0
	rebirthButton.Text = ("🌀 ×%.1f"):format(rebirthMultNow)
	rebirthMultLine.Text = ("×%.1f  →  ×%.1f"):format(rebirthMultNow, rebirthMultNow + Config.Rebirth.incomeBonusPerRebirth)
	local canAfford = cash >= rebirthCost
	rebirthConfirm.Text = ("REBIRTH — %s 💰"):format(fmt(rebirthCost))
	if rebirthConfirmGradient then
		rebirthConfirmGradient.Color = canAfford
			and ColorSequence.new(Color3.fromRGB(190, 120, 255), Color3.fromRGB(120, 60, 200))
			or ColorSequence.new(Color3.fromRGB(110, 110, 125), Color3.fromRGB(70, 70, 85))
	end
end

player.AttributeChanged:Connect(refresh)
refresh()

-- ============================================================================
-- Zarobek offline: modal „Witaj z powrotem!"
-- ============================================================================

task.spawn(function()
	-- atrybut pojawia się chwilę po wejściu, jeśli coś zarobiliśmy offline
	for _ = 1, 20 do
		local earned = player:GetAttribute("OfflineEarned")
		if earned and earned > 0 then
			local overlay = Instance.new("TextButton") -- klik gdziekolwiek zamyka
			overlay.Size = UDim2.fromScale(1, 1)
			overlay.BackgroundColor3 = Color3.new(0, 0, 0)
			overlay.BackgroundTransparency = 0.45
			overlay.Text = ""
			overlay.AutoButtonColor = false
			overlay.Parent = gui

			local modal = makeCard(overlay, UDim2.new(0, 340, 0, 210), UDim2.new(0.5, 0, 0.5, 0), Vector2.new(0.5, 0.5))
			addHeader(modal, "🌙 WITAJ Z POWROTEM!", Color3.fromRGB(160, 110, 235), Color3.fromRGB(105, 60, 190))
			local body = addBody(modal, 17)
			body.TextXAlignment = Enum.TextXAlignment.Center
			body.Text = ("Twoje grzyby pracowały!\n\n💰 +%s"):format(fmt(earned))

			makeButton(modal, UDim2.new(0, 130, 0, 44), UDim2.new(0.5, -70, 1, -12), Vector2.new(0.5, 1),
				Color3.fromRGB(96, 205, 106), Color3.fromRGB(38, 140, 70), 16,
				function()
					overlay:Destroy()
				end).Text = "Super!"

			-- ×2 zarobku offline za Robux (obsługa zakupu: serwer, ProcessReceipt)
			local product = Config.DevProducts.OfflineDouble
			makeButton(modal, UDim2.new(0, 150, 0, 44), UDim2.new(0.5, 78, 1, -12), Vector2.new(0.5, 1),
				Color3.fromRGB(255, 200, 80), Color3.fromRGB(215, 140, 35), 16,
				function()
					if product.id ~= 0 then
						MarketplaceService:PromptProductPurchase(player, product.id)
						overlay:Destroy()
					else
						showToast("⚠️ Produkt nieaktywny — uzupełnij ID w GameConfig (faza 8).")
					end
				end).Text = ("×2 = %s 💰  (%d R$)"):format(fmt(earned * 2), product.priceRobux)

			local modalScale = Instance.new("UIScale")
			modalScale.Scale = 0.7
			modalScale.Parent = modal
			TweenService:Create(modalScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			break
		end
		task.wait(0.5)
	end
end)

-- ============================================================================
-- Fanfara wyklucia peta (kolor błysku = rzadkość)
-- ============================================================================

hatchRemote.OnClientEvent:Connect(function(petName: string, rarityIdx: number, equipped: boolean)
	local rarity = Config.Pets.rarities[rarityIdx]
	if rarity.secret then
		secretFanfareUntil = os.clock() + 2.2 -- napis fanfary cykluje tęczą
	end
	levelFlash.BackgroundColor3 = rarity.color
	levelFlash.BackgroundTransparency = 0.55
	TweenService:Create(levelFlash, TweenInfo.new(0.7), { BackgroundTransparency = 1 }):Play()
	levelUpLabel.TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.4)
	levelUpLabel.Text = ("🐾 %s! (%s)"):format(petName, rarity.name)
	levelUpLabel.Visible = true
	levelUpLabel.TextTransparency = 0
	levelUpScale.Scale = 0.4
	TweenService:Create(levelUpScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.8, function()
		TweenService:Create(levelUpLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.delay(0.4, function()
			levelUpLabel.Visible = false
			levelUpLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
		end)
	end)
	for step = 0, 2 do
		task.delay(step * 0.1, function()
			ding.PlaybackSpeed = 1.1 + step * 0.2
			ding:Play()
		end)
	end
	showToast(equipped and ("🐾 %s dołącza do drużyny!"):format(petName)
		or ("🐾 %s trafia do kolekcji (drużyna pełna)."):format(petName))
end)

-- ============================================================================
-- Renderer petów: lewitujące stworki przy KAŻDYM graczu na serwerze
-- (czysto wizualne, bez fizyki — pozycje liczone co klatkę z lerpem)
-- ============================================================================

local PET_OFFSETS = {
	Vector3.new(-2.6, 2, 2),
	Vector3.new(2.6, 2, 2),
	Vector3.new(0, 2.4, 3.2),
}

local petFolder = Instance.new("Folder")
petFolder.Name = "PetModels"
petFolder.Parent = workspace

-- MODELE Z BLENDERA: jeśli w ReplicatedStorage.Models.Pety leży model
-- o nazwie peta (np. "Wiewiór Rudzik"), lewituje ON zamiast kulki.
-- Części animujemy tu sami (FxClient celowo omija PetModels — pet jest
-- w ciągłym ruchu): *Pierscien/Halo/Dysk/Orbita* wirują,
-- *Warkocz/Drobiny/Materia/Ksiezyc/Skalki* falują.
local PET_SPIN_KEYS = { "Pierscien", "Halo", "Dysk", "Orbita" }
local PET_BOB_KEYS = { "Warkocz", "Drobiny", "Materia", "Ksiezyc", "Skalki" }
local PET_TARGET_SIZE = 1.9 -- najdłuższy bok peta w studach

type PetAnimPart = { part: BasePart, offset: CFrame, kind: string?, seed: number }

local petModels: { [Player]: { Model } } = {}
local importedAnim: { [Model]: { PetAnimPart } } = {}

local function petPartKind(name: string): string?
	for _, key in PET_SPIN_KEYS do
		if string.find(name, key, 1, true) then return "spin" end
	end
	for _, key in PET_BOB_KEYS do
		if string.find(name, key, 1, true) then return "bob" end
	end
	return nil
end

local function clearPetModels(owner: Player)
	for _, model in petModels[owner] or {} do
		importedAnim[model] = nil
		model:Destroy()
	end
	petModels[owner] = nil
end

local function buildPetModels(owner: Player)
	clearPetModels(owner)
	local ok, pets = pcall(function()
		return HttpService:JSONDecode(owner:GetAttribute("PetsJSON") or "[]")
	end)
	if not ok then return end

	local models = {}
	for _, pet in pets do
		if pet.eq and #models < #PET_OFFSETS then
			local rarity = Config.Pets.rarities[pet.r]
			local petName = Config.Pets.poolsByWorld[pet.w][pet.p]

			local modelsRoot = ReplicatedStorage:FindFirstChild("Models")
			local petsFolder = modelsRoot and modelsRoot:FindFirstChild("Pety")
			local template = petsFolder and petsFolder:FindFirstChild(petName)

			local model: Model
			local body: BasePart
			if template and template:IsA("Model") then
				-- MODEL PETA z Blendera: przygotuj, przeskaluj, spisz animacje
				model = template:Clone()
				local biggest: BasePart? = nil
				local biggestVolume = 0
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") then
						part.Anchored = true
						part.CanCollide = false
						part.CanQuery = false
						if string.find(part.Name, "Glow", 1, true) then
							part.Material = Enum.Material.Neon
						else
							-- "tekstura" po nazwie (futro, szkło, metal...)
							local material = Config.materialFor(part.Name)
							if material then
								part.Material = material
							end
						end
						local volume = part.Size.X * part.Size.Y * part.Size.Z
						if volume > biggestVolume then
							biggest, biggestVolume = part, volume
						end
					end
				end
				if not model.PrimaryPart then
					model.PrimaryPart = biggest
				end
				local _, size = model:GetBoundingBox()
				local longest = math.max(size.X, size.Y, size.Z)
				if longest > 0 then
					model:ScaleTo(model:GetScale() * PET_TARGET_SIZE / longest)
				end
				body = model.PrimaryPart :: BasePart
				local animParts: { PetAnimPart } = {}
				for _, part in model:GetDescendants() do
					if part:IsA("BasePart") then
						table.insert(animParts, {
							part = part,
							offset = body.CFrame:ToObjectSpace(part.CFrame),
							kind = petPartKind(part.Name),
							seed = math.random() * 10,
						})
					end
				end
				importedAnim[model] = animParts
			else
				-- fallback proceduralny: kulka w kolorze rzadkości + ślepka
				model = Instance.new("Model")
				body = Instance.new("Part")
				body.Name = "Body"
				body.Shape = Enum.PartType.Ball
				body.Size = Vector3.new(1.6, 1.6, 1.6)
				body.Color = rarity.color
				body.Material = pet.r >= 4 and Enum.Material.Neon or Enum.Material.SmoothPlastic
				body.Anchored = true
				body.CanCollide = false
				body.CanQuery = false
				body.Parent = model

				for _, side in { -0.35, 0.35 } do
					local eye = Instance.new("Part")
					eye.Shape = Enum.PartType.Ball
					eye.Size = Vector3.new(0.3, 0.3, 0.3)
					eye.Color = Color3.fromRGB(25, 25, 35)
					eye.Anchored = true
					eye.CanCollide = false
					eye.CanQuery = false
					eye.Name = "Eye"
					eye.Parent = model
					eye:SetAttribute("SideX", side)
				end
			end
			model.Name = ("Pet_%d_%d"):format(owner.UserId, #models + 1)

			local tag = Instance.new("BillboardGui")
			tag.Size = UDim2.new(0, 110, 0, 22)
			tag.StudsOffset = Vector3.new(0, 1.4, 0)
			tag.AlwaysOnTop = false
			tag.Parent = body
			local tagLabel = Instance.new("TextLabel")
			tagLabel.Size = UDim2.fromScale(1, 1)
			tagLabel.BackgroundTransparency = 1
			tagLabel.Font = Enum.Font.FredokaOne
			tagLabel.TextScaled = true
			tagLabel.TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.5)
			tagLabel.Text = petName
			tagLabel.Parent = tag
			if rarity.secret then
				-- SEKRET: tęczowy podpis + smuga iskier za petem
				markRainbow(tagLabel)
				local emitter = Instance.new("ParticleEmitter")
				emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
				emitter.LightEmission = 1
				emitter.Rate = 6
				emitter.Lifetime = NumberRange.new(0.6, 1.2)
				emitter.Speed = NumberRange.new(0.3, 0.8)
				emitter.Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.18),
					NumberSequenceKeypoint.new(1, 0),
				})
				emitter.SpreadAngle = Vector2.new(180, 180)
				emitter.Parent = body
			end

			model.PrimaryPart = body
			model.Parent = petFolder
			table.insert(models, model)
		end
	end
	petModels[owner] = models
end

local function watchPlayer(other: Player)
	buildPetModels(other)
	other:GetAttributeChangedSignal("PetsJSON"):Connect(function()
		buildPetModels(other)
	end)
end

for _, other in Players:GetPlayers() do
	watchPlayer(other)
end
Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(clearPetModels)

RunService.Heartbeat:Connect(function()
	local now = os.clock()
	for owner, models in petModels do
		local character = owner.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then continue end
		for index, model in models do
			local body = model.PrimaryPart
			if not body then continue end
			local offset = PET_OFFSETS[index]
			local bob = math.sin(now * 3 + index * 2) * 0.35
			local target = root.CFrame * CFrame.new(offset.X, offset.Y + bob, offset.Z)
			local newCFrame = body.CFrame:Lerp(target, 0.12)
			local anim = importedAnim[model]
			if anim then
				-- model z Blendera: każda część jedzie za ciałem, a nazwane
				-- części dostają własny ruch (pierścienie wirują, warkocze falują)
				for _, info in anim do
					local cf = newCFrame * info.offset
					if info.kind == "spin" then
						cf = cf * CFrame.Angles(0, (now + info.seed) * 1.4, 0)
					elseif info.kind == "bob" then
						cf = cf * CFrame.new(0, math.sin((now + info.seed * 10) * 1.8) * 0.14, 0)
					end
					info.part.CFrame = cf
				end
			else
				body.CFrame = newCFrame
				for _, part in model:GetChildren() do
					if part.Name == "Eye" then
						part.CFrame = newCFrame * CFrame.new(part:GetAttribute("SideX"), 0.15, -0.65)
					end
				end
			end
		end
	end
end)

-- ============================================================================
-- STREFA STARTU (minigra): kamera zza pleców, HUD schowany, pionowy
-- zaokrąglony pasek z gradientem zielony (dół) → czerwony (góra).
-- Wskaźnik lata góra-dół po TEJ SAMEJ krzywej, którą liczy serwer
-- (wspólny zegar GetServerTimeNow) — klik = LaunchStop, serwer ocenia.
-- ============================================================================

local launchGui = Instance.new("ScreenGui")
launchGui.Name = "LaunchBar"
launchGui.ResetOnSpawn = false
launchGui.IgnoreGuiInset = true
launchGui.Enabled = false
launchGui.Parent = player:WaitForChild("PlayerGui")

local launchBar = Instance.new("Frame")
launchBar.AnchorPoint = Vector2.new(0, 0.5)
launchBar.Position = UDim2.new(0, 36, 0.5, 0)
launchBar.Size = UDim2.new(0, 46, 0.55, 0)
launchBar.BackgroundColor3 = Color3.new(1, 1, 1)
launchBar.BorderSizePixel = 0
launchBar.Parent = launchGui
addCorner(launchBar, 23)
local launchBarStroke = Instance.new("UIStroke")
launchBarStroke.Thickness = 3
launchBarStroke.Color = Color3.fromRGB(28, 28, 44)
launchBarStroke.Parent = launchBar
local launchGradient = Instance.new("UIGradient")
launchGradient.Rotation = 90 -- pion: pierwszy kolor u góry
launchGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 60, 50)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(255, 160, 40)),
	ColorSequenceKeypoint.new(0.65, Color3.fromRGB(255, 225, 70)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(90, 220, 90)),
})
launchGradient.Parent = launchBar

local launchIndicator = Instance.new("Frame")
launchIndicator.AnchorPoint = Vector2.new(0.5, 0.5)
launchIndicator.Position = UDim2.new(0.5, 0, 1, 0)
launchIndicator.Size = UDim2.new(1, 14, 0, 9)
launchIndicator.BackgroundColor3 = Color3.new(1, 1, 1)
launchIndicator.BorderSizePixel = 0
launchIndicator.ZIndex = 3
launchIndicator.Parent = launchBar
addCorner(launchIndicator, 5)
local launchIndicatorStroke = Instance.new("UIStroke")
launchIndicatorStroke.Thickness = 2.5
launchIndicatorStroke.Color = Color3.fromRGB(24, 24, 40)
launchIndicatorStroke.Parent = launchIndicator

local launchHint = Instance.new("TextLabel")
launchHint.AnchorPoint = Vector2.new(0.5, 1)
launchHint.Position = UDim2.new(0.5, 0, 1, -44)
launchHint.Size = UDim2.new(0, 520, 0, 42)
launchHint.BackgroundTransparency = 1
launchHint.Font = FONT
launchHint.TextSize = 26
launchHint.TextColor3 = Color3.new(1, 1, 1)
launchHint.TextStrokeTransparency = 0.25
launchHint.Text = "KLIKNIJ, by wystartować! Im wyżej trafisz, tym mocniejszy start 🔥"
launchHint.Parent = launchGui

local aiming = false
local launchClicked = false
local wolfScene: { position: Vector3, startedAt: number, endsAt: number }? = nil

-- ============================================================================
-- MINI-HUD BIEGU: podczas wyprawy CAŁY zwykły HUD znika — widać tylko
-- to, co dotyczy biegu: pasek kondycji + koszyk.
-- ============================================================================

local runGui = Instance.new("ScreenGui")
runGui.Name = "RunHUD"
runGui.ResetOnSpawn = false
runGui.Enabled = false
runGui.Parent = player:WaitForChild("PlayerGui")

local runBasket = Instance.new("TextLabel")
runBasket.AnchorPoint = Vector2.new(0.5, 1)
runBasket.Position = UDim2.new(0.5, 0, 1, -66)
runBasket.Size = UDim2.new(0, 240, 0, 34)
runBasket.BackgroundTransparency = 1
runBasket.Font = FONT
runBasket.TextScaled = true
runBasket.TextColor3 = Color3.new(1, 1, 1)
runBasket.TextStrokeTransparency = 0.25
runBasket.Text = "🧺 0/1"
runBasket.Parent = runGui

local runStaminaBack = Instance.new("Frame")
runStaminaBack.AnchorPoint = Vector2.new(0.5, 1)
runStaminaBack.Position = UDim2.new(0.5, 0, 1, -28)
runStaminaBack.Size = UDim2.new(0, 460, 0, 30)
runStaminaBack.BackgroundColor3 = Color3.fromRGB(28, 32, 44)
runStaminaBack.BackgroundTransparency = 0.25
runStaminaBack.Parent = runGui
addCorner(runStaminaBack, 15)
local runStaminaFill = Instance.new("Frame")
runStaminaFill.Position = UDim2.new(0, 3, 0.5, 0)
runStaminaFill.AnchorPoint = Vector2.new(0, 0.5)
runStaminaFill.Size = UDim2.new(1, -6, 1, -6)
runStaminaFill.BackgroundColor3 = Color3.fromRGB(120, 230, 110)
runStaminaFill.Parent = runStaminaBack
addCorner(runStaminaFill, 12)
local runStaminaText = Instance.new("TextLabel")
runStaminaText.Size = UDim2.fromScale(1, 0.8)
runStaminaText.Position = UDim2.fromScale(0.5, 0.5)
runStaminaText.AnchorPoint = Vector2.new(0.5, 0.5)
runStaminaText.BackgroundTransparency = 1
runStaminaText.Font = FONT
runStaminaText.TextScaled = true
runStaminaText.TextColor3 = Color3.new(1, 1, 1)
runStaminaText.TextStrokeTransparency = 0.35
runStaminaText.ZIndex = 3
runStaminaText.Text = "🏃 100/100"
runStaminaText.Parent = runStaminaBack

-- przycisk ZAWRÓĆ — przerywa bieg w głąb (gra zawraca do bazy)
local abortButton = Instance.new("TextButton")
abortButton.AnchorPoint = Vector2.new(0.5, 1)
abortButton.Position = UDim2.new(0.5, 0, 1, -112)
abortButton.Size = UDim2.new(0, 190, 0, 42)
abortButton.BackgroundColor3 = Color3.fromRGB(235, 80, 70)
abortButton.Font = FONT
abortButton.TextScaled = true
abortButton.TextColor3 = Color3.new(1, 1, 1)
abortButton.TextStrokeTransparency = 0.5
abortButton.Text = "↩️ ZAWRÓĆ"
abortButton.Parent = runGui
addCorner(abortButton, 14)
local abortStroke = Instance.new("UIStroke")
abortStroke.Thickness = 3
abortStroke.Color = Color3.fromRGB(120, 30, 25)
abortStroke.Parent = abortButton
abortButton.Activated:Connect(function()
	abortRemote:FireServer()
end)

local function refreshRunHud()
	local stamina = player:GetAttribute("Stamina") or 0
	local staminaMax = math.max(player:GetAttribute("StaminaMax") or 100, 1)
	local fraction = math.clamp(stamina / staminaMax, 0, 1)
	runStaminaFill.Size = UDim2.new(fraction, -6, 1, -6)
	runStaminaFill.BackgroundColor3 = fraction > 0.35
		and Color3.fromRGB(120, 230, 110)
		or Color3.fromRGB(240, 110, 80)
	runStaminaText.Text = ("🏃 %d/%d"):format(stamina, staminaMax)
	runBasket.Text = ("🧺 %d/%d"):format(
		player:GetAttribute("CarriedCount") or 0,
		player:GetAttribute("CarrySlots") or 1)
	abortButton.Visible = (player:GetAttribute("ExpeditionPhase") or "out") == "out"
end
for _, attribute in { "Stamina", "StaminaMax", "CarriedCount", "CarrySlots", "ExpeditionPhase" } do
	player:GetAttributeChangedSignal(attribute):Connect(refreshRunHud)
end
refreshRunHud()

-- ============================================================================
-- AUTO-BIEG „na szynach": podczas wyprawy porusza się GRA, nie gracz —
-- w głąb (+Z) w fazie "out", do bazy (-Z) w fazie "return". Gracz może
-- tylko sterować bokami (A/D, drążek); zatrzymać się NIE można.
-- ============================================================================

local controlsOk, controls = pcall(function()
	return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()
end)

RunService:BindToRenderStep("PickAShroomForcedRun", Enum.RenderPriority.Character.Value + 1, function()
	if player:GetAttribute("ExpeditionState") ~= "run" then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	humanoid.Jump = false -- bez skakania na szynach
	local phase = player:GetAttribute("ExpeditionPhase") or "out"
	local forward
	if phase == "out" then
		-- biegniesz TAM, GDZIE PATRZYSZ (1. osoba, swobodne rozglądanie),
		-- ale zawsze W GŁĄB: składowa +Z nie spada poniżej 0,35
		local look = camera.CFrame.LookVector
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = flat.Magnitude > 0.05 and flat.Unit or Vector3.new(0, 0, 1)
		forward = Vector3.new(flat.X, 0, math.max(flat.Z, 0.35)).Unit
	else
		forward = Vector3.new(0, 0, -1) -- powrót: prosto do bazy
	end
	local strafe = 0
	if controlsOk and controls then
		strafe = controls:GetMoveVector().X
	end
	local sideways = camera.CFrame.RightVector
	local direction = forward + Vector3.new(sideways.X, 0, sideways.Z) * strafe * 0.9
	humanoid:Move(direction.Unit, false)
end)

local function setAiming(on: boolean)
	aiming = on
	launchGui.Enabled = on
	if on then
		launchClicked = false
		camera.CameraType = Enum.CameraType.Scriptable
	elseif not wolfScene then
		camera.CameraType = Enum.CameraType.Custom
	end
end

-- kamera biegu: faza "out" = PRAWDZIWA 1. osoba Roblox (LockFirstPerson —
-- można się swobodnie rozglądać myszką), faza "return" = widok z góry
local function updateRunCamera()
	local state = player:GetAttribute("ExpeditionState")
	local phase = player:GetAttribute("ExpeditionPhase") or "out"
	if state == "run" and phase == "out" then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
		if not wolfScene then
			camera.CameraType = Enum.CameraType.Custom
		end
	else
		player.CameraMode = Enum.CameraMode.Classic
	end
end
player:GetAttributeChangedSignal("ExpeditionPhase"):Connect(updateRunCamera)

player:GetAttributeChangedSignal("ExpeditionState"):Connect(function()
	local state = player:GetAttribute("ExpeditionState")
	setAiming(state == "aiming")
	updateRunCamera()
	-- HUD wg stanu: baza = pełny HUD; minigra/cutscenka = nic;
	-- bieg = tylko mini-HUD (kondycja + koszyk + ZAWRÓĆ)
	gui.Enabled = state == nil or state == "base"
	runGui.Enabled = state == "run"
	if state == "run" then
		-- trzęsienie ekranu po strzale — tier 1 (idealny) trzęsie najmocniej
		local tier = player:GetAttribute("LaunchTier") or 4
		launchShakeMag = (4 - tier) * 0.9
		launchShakeUntil = os.clock() + 0.7 + (4 - tier) * 0.3
		refreshRunHud()
	elseif (state == nil or state == "base") and not wolfScene then
		camera.CameraType = Enum.CameraType.Custom
	end
end)

UserInputService.InputBegan:Connect(function(input, _processed)
	if not aiming or launchClicked then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.Space then
		launchClicked = true
		launchRemote:FireServer()
	end
end)

-- ============================================================================
-- CUTSCENKA WILKA: świat zamiera (serwer trzyma prędkości na 0), kamera
-- powoli najeżdża na wilka wyłaniającego się z lasu, wielki baner z nazwą —
-- dopiero po niej zaczyna się pościg.
-- ============================================================================

local wolfGui = Instance.new("ScreenGui")
wolfGui.Name = "WolfScene"
wolfGui.ResetOnSpawn = false
wolfGui.IgnoreGuiInset = true
wolfGui.Parent = player:WaitForChild("PlayerGui")

local wolfBanner = Instance.new("TextLabel")
wolfBanner.AnchorPoint = Vector2.new(0.5, 0)
wolfBanner.Position = UDim2.new(0.5, 0, 0.12, 0)
wolfBanner.Size = UDim2.new(0, 620, 0, 74)
wolfBanner.BackgroundTransparency = 1
wolfBanner.Font = FONT
wolfBanner.TextScaled = true
wolfBanner.TextColor3 = Color3.fromRGB(255, 70, 55)
wolfBanner.TextStrokeColor3 = Color3.fromRGB(25, 8, 8)
wolfBanner.TextStrokeTransparency = 0
wolfBanner.Rotation = -3
wolfBanner.Visible = false
wolfBanner.Parent = wolfGui
local wolfBannerScale = Instance.new("UIScale")
wolfBannerScale.Parent = wolfBanner

wolfSceneRemote.OnClientEvent:Connect(function(position, wolfName, seconds)
	wolfScene = {
		position = position,
		startedAt = os.clock(),
		endsAt = os.clock() + seconds,
	}
	camera.CameraType = Enum.CameraType.Scriptable
	wolfBanner.Text = ("🐺 %s!"):format(tostring(wolfName))
	wolfBanner.Visible = true
	wolfBanner.TextTransparency = 0
	wolfBannerScale.Scale = 0.2
	TweenService:Create(wolfBannerScale,
		TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(seconds, function()
		wolfScene = nil
		wolfBanner.Visible = false
		if not aiming then
			camera.CameraType = Enum.CameraType.Custom
		end
	end)
end)

-- 🏆 fanfara ucieczki z łupem — wielki bąbelkowy napis jak przy level-upie
escapeRemote.OnClientEvent:Connect(function(labelText)
	levelUpLabel.TextColor3 = Color3.fromRGB(255, 215, 90)
	levelUpLabel.Text = ("🏆 ZDOBYWASZ: %s!"):format(tostring(labelText))
	levelUpLabel.Visible = true
	levelUpLabel.TextTransparency = 0
	levelUpScale.Scale = 0.3
	TweenService:Create(levelUpScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	for step = 0, 2 do
		task.delay(step * 0.12, function()
			ding.PlaybackSpeed = 1 + step * 0.25
			ding:Play()
		end)
	end
	task.delay(2.2, function()
		TweenService:Create(levelUpLabel, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.delay(0.4, function()
			levelUpLabel.Visible = false
			levelUpLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
		end)
	end)
end)

-- ============================================================================
-- Pętla renderowania: kamera minigry + wskaźnik paska + trzęsienie ekranu
-- (bieg podczas wyprawy i „kop" startu przez Humanoid.CameraOffset).
-- ============================================================================

RunService.RenderStepped:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")

	if wolfScene and root then
		-- REVEAL WILKA: kamera sunie od gracza w stronę bestii (ease in-out),
		-- pod koniec lekko drży — groza rośnie, aż baner zniknie i START
		local now = os.clock()
		local alpha = math.clamp((now - wolfScene.startedAt)
			/ math.max(wolfScene.endsAt - wolfScene.startedAt, 0.05), 0, 1)
		local eased = alpha * alpha * (3 - 2 * alpha)
		local wolfPos = wolfScene.position + Vector3.new(0, 2.2, 0)
		local side = root.CFrame.RightVector
		local startPos = root.Position + Vector3.new(0, 3.2, 0) - side * 5
		local toPlayer = (root.Position - wolfPos)
		local endPos = wolfPos + toPlayer.Unit * 9 + side * 3 + Vector3.new(0, 1.2, 0)
		local cameraPos = startPos:Lerp(endPos, eased)
		local sceneCF = CFrame.lookAt(cameraPos, wolfPos)
		if alpha > 0.65 then
			local tremor = (alpha - 0.65) * 0.02
			sceneCF = sceneCF * CFrame.Angles(
				math.sin(now * 31) * tremor, math.sin(now * 27) * tremor, 0)
		end
		camera.CFrame = sceneCF
	elseif aiming and root then
		-- kamera zza pleców, lekko przybliżona, patrzy w głąb lasu
		local look = root.CFrame.LookVector
		camera.CFrame = CFrame.lookAt(
			root.Position - look * 9 + Vector3.new(0, 4, 0),
			root.Position + look * 14 + Vector3.new(0, 2, 0))
		-- wskaźnik: ta sama krzywa co na serwerze (0 = dół, 1 = góra)
		local startTime = player:GetAttribute("LaunchStart") or 0
		local position = Config.launchPosition(startTime, workspace:GetServerTimeNow())
		launchIndicator.Position = UDim2.new(0.5, 0, 1 - position, 0)
	elseif player:GetAttribute("ExpeditionState") == "run" and root then
		local phase = player:GetAttribute("ExpeditionPhase") or "out"
		if phase == "return" then
			-- powrót: kamera wysoko z góry (zablokowana) — widzisz siebie,
			-- drogę do bazy i WILKA za plecami
			if camera.CameraType ~= Enum.CameraType.Scriptable then
				camera.CameraType = Enum.CameraType.Scriptable
			end
			-- kamera ZA plecami uciekiniera (strona lasu, +Z), lekko z góry:
			-- biegniesz do bazy TYŁEM do kamery (naturalnie), wilk goni od
			-- strony kamery, widać całą postać z głową
			camera.CFrame = CFrame.lookAt(
				root.Position + Vector3.new(0, 26, 20),
				root.Position + Vector3.new(0, 3, -8))
			-- 1. osoba ukryła ciało (LocalTransparencyModifier=1); przy kamerze
			-- z góry MUSISZ widzieć postać — wymuszamy widoczność wszystkich
			-- części (też głowy) i twarzy
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") or part:IsA("Decal") then
					part.LocalTransparencyModifier = 0
				end
			end
		end
		-- faza "out": natywna 1. osoba Roblox (LockFirstPerson) —
		-- swobodne rozglądanie; kamerą zarządza silnik, nie my
	end

	if not humanoid then
		return
	end
	local state = player:GetAttribute("ExpeditionState")
	local running = state == "run" and humanoid.MoveDirection.Magnitude > 0.1
	local now = os.clock()
	local intensity = (running and 1 or 0)
		+ (now < launchShakeUntil and launchShakeMag or 0)
	local target = intensity > 0
		and Vector3.new(
			math.sin(now * 13) * 0.1 * intensity,
			math.abs(math.sin(now * 17)) * 0.16 * intensity,
			0)
		or Vector3.zero
	humanoid.CameraOffset = humanoid.CameraOffset:Lerp(target, intensity > 0 and 0.35 or 0.15)
end)
