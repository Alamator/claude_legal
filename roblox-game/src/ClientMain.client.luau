-- ClientMain: HUD i sterowanie sprintem. Cały interfejs budowany z kodu,
-- w nowoczesnym „bąbelkowym" stylu topowych symulatorów: font Fredoka One,
-- gradienty, grube obwódki, animacje pop, responsywne skalowanie pod mobile.
-- Wklej jako LocalScript do StarterPlayer → StarterPlayerScripts (nazwa: ClientMain).
--
-- Klient NICZEGO nie liczy sam — wyświetla atrybuty ustawiane przez serwer
-- i wysyła prośby (sprint, zakup) przez RemoteEventy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")
local TweenService = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local sprintRemote = remotes:WaitForChild("Sprint")
local buyRemote = remotes:WaitForChild("BuyUpgrade")
local notifyRemote = remotes:WaitForChild("Notify")
local sellRemote = remotes:WaitForChild("SellWeakest")

local player = Players.LocalPlayer

local FONT = Enum.Font.FredokaOne

-- „12345" → „12.3k" (czytelne liczby na HUD)
local function fmt(n: number): string
	if n >= 1_000_000_000 then return string.format("%.1fB", n / 1_000_000_000) end
	if n >= 1_000_000 then return string.format("%.1fM", n / 1_000_000) end
	if n >= 10_000 then return string.format("%.1fk", n / 1_000) end
	return tostring(math.floor(n))
end

-- sekundy → „12:34"
local function fmtTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- ============================================================================
-- Sprint: LeftShift na PC + automatyczny przycisk dotykowy na telefonie
-- ============================================================================

local function onSprint(_actionName, inputState)
	if inputState == Enum.UserInputState.Begin then
		sprintRemote:FireServer(true)
	elseif inputState == Enum.UserInputState.End then
		sprintRemote:FireServer(false)
	end
	return Enum.ContextActionResult.Pass
end

ContextActionService:BindAction("Sprint", onSprint, true, Enum.KeyCode.LeftShift)
ContextActionService:SetTitle("Sprint", "BIEG")
ContextActionService:SetPosition("Sprint", UDim2.new(1, -90, 1, -140))

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

local BUTTONS = {
	{ id = "Stamina", top = Color3.fromRGB(255, 150, 90),  bottom = Color3.fromRGB(215, 85, 40) },
	{ id = "Thermos", top = Color3.fromRGB(110, 190, 255), bottom = Color3.fromRGB(45, 110, 210) },
	{ id = "Shelf",   top = Color3.fromRGB(220, 160, 90),  bottom = Color3.fromRGB(160, 100, 45) },
}

for index, def in BUTTONS do
	upgradeButtons[def.id] = makeButton(gui,
		UDim2.new(0, 240, 0, 48),
		UDim2.new(0, 14, 0.5, -110 + (index - 1) * 58),
		Vector2.new(0, 0),
		def.top, def.bottom, 15,
		function()
			buyRemote:FireServer(def.id)
		end)
end

makeButton(gui,
	UDim2.new(0, 240, 0, 48),
	UDim2.new(0, 14, 0.5, -110 + #BUTTONS * 58),
	Vector2.new(0, 0),
	Color3.fromRGB(250, 205, 90), Color3.fromRGB(205, 150, 40), 15,
	function()
		sellRemote:FireServer()
	end).Text = "💸 Sprzedaj najsłabszy"

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

local journalBody = Instance.new("TextLabel")
journalBody.Size = UDim2.new(1, -8, 0, 0)
journalBody.AutomaticSize = Enum.AutomaticSize.Y
journalBody.BackgroundTransparency = 1
journalBody.TextXAlignment = Enum.TextXAlignment.Left
journalBody.TextYAlignment = Enum.TextYAlignment.Top
journalBody.TextWrapped = true
journalBody.Parent = journalScroll
styleText(journalBody, 15)

local journalScale = Instance.new("UIScale")
journalScale.Parent = journalPanel

local function setJournalOpen(open: boolean)
	if open then
		journalPanel.Visible = true
		journalScale.Scale = 0.7
		TweenService:Create(journalScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	else
		journalPanel.Visible = false
	end
end

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

local lastLevel = 0
player:GetAttributeChangedSignal("Level"):Connect(function()
	local level = player:GetAttribute("Level") or 1
	if lastLevel > 0 and level > lastLevel then
		-- błysk
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
			tutorialBanner.Text = "🍄 KROK 1/3: Pobiegnij w las (Shift = bieg) i przytrzymaj E przy grzybku"
			local target = nearestOwnMushroomPart()
			marker.Parent = target
			marker.Enabled = target ~= nil
		elseif step == 2 then
			tutorialBanner.Text = "📦 KROK 2/3: Wróć do bazy i przytrzymaj E na drewnianym polu"
			local worldIdx = player:GetAttribute("CurrentWorld") or 1
			local worlds = workspace:FindFirstChild("Worlds")
			local worldFolder = worlds and worlds:FindFirstChild("World" .. worldIdx)
			marker.Parent = worldFolder and worldFolder:FindFirstChild("BasePad")
			marker.Enabled = marker.Parent ~= nil
		elseif step == 3 then
			tutorialBanner.Text = "⬆️ KROK 3/3: Kup pierwsze ulepszenie w panelu po lewej"
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
	local shelfCount = player:GetAttribute("ShelfCount") or 0
	local shelves = player:GetAttribute("ShelvesOwned") or 0
	basketBody.Text = ("%s\n\n🪵 Półki: %d/%d")
		:format(carried == "" and "— pusty —\n(odłóż grzyby w bazie!)" or carried, shelfCount, shelves)

	-- przyciski ulepszeń z aktualnymi cenami (te same wzory co na serwerze)
	local staminaLevel = player:GetAttribute("StaminaLevel") or 0
	local thermosLevel = player:GetAttribute("ThermosLevel") or 0
	upgradeButtons.Stamina.Text = ("🏃 Kondycja [%d] — %s 💰")
		:format(staminaLevel, fmt(Config.statCost(Config.Stats.Stamina, staminaLevel)))
	upgradeButtons.Thermos.Text = ("❄️ Termos [%d] — %s 💰")
		:format(thermosLevel, fmt(Config.statCost(Config.Stats.Thermos, thermosLevel)))
	local shelfCost = Config.Base.shelfBaseCost * Config.Base.shelfCostGrowth ^ math.max(0, shelves - Config.Base.startShelves)
	upgradeButtons.Shelf.Text = shelves >= Config.Base.maxShelves
		and "🪵 Półki: MAX"
		or ("🪵 Półka [%d/%d] — %s 💰"):format(shelves, Config.Base.maxShelves, fmt(shelfCost))

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
