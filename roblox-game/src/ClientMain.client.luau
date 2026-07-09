-- ClientMain: HUD i sterowanie sprintem. Cały interfejs budowany z kodu.
-- Wklej jako LocalScript do StarterPlayer → StarterPlayerScripts (nazwa: ClientMain).
--
-- Klient NICZEGO nie liczy sam — wyświetla atrybuty ustawiane przez serwer
-- i wysyła prośby (sprint, zakup) przez RemoteEventy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContextActionService = game:GetService("ContextActionService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local sprintRemote = remotes:WaitForChild("Sprint")
local buyRemote = remotes:WaitForChild("BuyUpgrade")
local notifyRemote = remotes:WaitForChild("Notify")
local sellRemote = remotes:WaitForChild("SellWeakest")

local player = Players.LocalPlayer

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
-- Budowa HUD
-- ============================================================================

local gui = Instance.new("ScreenGui")
gui.Name = "HUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(parent, size, position, textSize): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundColor3 = Color3.fromRGB(25, 30, 25)
	label.BackgroundTransparency = 0.35
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextSize = textSize
	label.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label
	return label
end

-- Kasa + dochód (góra, środek)
local cashLabel = makeLabel(gui, UDim2.new(0, 260, 0, 44), UDim2.new(0.5, -130, 0, 8), 22)

-- Pasek kondycji (dół, środek)
local staminaBack = Instance.new("Frame")
staminaBack.Size = UDim2.new(0, 300, 0, 20)
staminaBack.Position = UDim2.new(0.5, -150, 1, -76)
staminaBack.BackgroundColor3 = Color3.fromRGB(25, 30, 25)
staminaBack.BackgroundTransparency = 0.35
staminaBack.Parent = gui
local staminaCorner = Instance.new("UICorner")
staminaCorner.CornerRadius = UDim.new(0, 10)
staminaCorner.Parent = staminaBack

local staminaFill = Instance.new("Frame")
staminaFill.Size = UDim2.new(1, 0, 1, 0)
staminaFill.BackgroundColor3 = Color3.fromRGB(90, 200, 90)
staminaFill.Parent = staminaBack
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 10)
fillCorner.Parent = staminaFill

-- Pity (pod paskiem kondycji)
local pityLabel = makeLabel(gui, UDim2.new(0, 300, 0, 22), UDim2.new(0.5, -150, 1, -50), 14)

-- Kosz (prawa strona)
local carriedPanel = makeLabel(gui, UDim2.new(0, 240, 0, 220), UDim2.new(1, -250, 0.5, -110), 14)
carriedPanel.TextXAlignment = Enum.TextXAlignment.Left
carriedPanel.TextYAlignment = Enum.TextYAlignment.Top
carriedPanel.TextWrapped = true
local carriedPadding = Instance.new("UIPadding")
carriedPadding.PaddingLeft = UDim.new(0, 10)
carriedPadding.PaddingTop = UDim.new(0, 8)
carriedPadding.Parent = carriedPanel

-- Powiadomienia (góra, pod kasą)
local toast = makeLabel(gui, UDim2.new(0, 420, 0, 34), UDim2.new(0.5, -210, 0, 60), 16)
toast.Visible = false

-- Baner aktywnego eventu (lewy górny róg) — czyta atrybuty workspace
local eventBanner = makeLabel(gui, UDim2.new(0, 260, 0, 36), UDim2.new(0, 10, 0, 8), 16)
eventBanner.BackgroundColor3 = Color3.fromRGB(120, 70, 160)
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

-- Panel ulepszeń (lewa strona)
local upgradeNames = {
	{ id = "Stamina", icon = "🏃", label = "Kondycja" },
	{ id = "Thermos", icon = "❄️", label = "Termos" },
	{ id = "Shelf", icon = "🪵", label = "Półka" },
}
local upgradeButtons: { [string]: TextButton } = {}

for index, upgrade in upgradeNames do
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, 230, 0, 46)
	button.Position = UDim2.new(0, 10, 0.5, -80 + (index - 1) * 54)
	button.BackgroundColor3 = Color3.fromRGB(40, 70, 40)
	button.BackgroundTransparency = 0.15
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	button.Activated:Connect(function()
		buyRemote:FireServer(upgrade.id)
	end)
	upgradeButtons[upgrade.id] = button
end

-- Przycisk sprzedaży najsłabszego grzyba z półki (zwalnia slot)
local sellButton = Instance.new("TextButton")
sellButton.Size = UDim2.new(0, 230, 0, 46)
sellButton.Position = UDim2.new(0, 10, 0.5, -80 + #upgradeNames * 54)
sellButton.BackgroundColor3 = Color3.fromRGB(90, 60, 30)
sellButton.BackgroundTransparency = 0.15
sellButton.TextColor3 = Color3.new(1, 1, 1)
sellButton.Font = Enum.Font.GothamBold
sellButton.TextSize = 15
sellButton.Text = "💸 Sprzedaj najsłabszy z półki"
sellButton.Parent = gui
local sellCorner = Instance.new("UICorner")
sellCorner.CornerRadius = UDim.new(0, 8)
sellCorner.Parent = sellButton
sellButton.Activated:Connect(function()
	sellRemote:FireServer()
end)

-- Panel dziennych zadań + licznik skrzynki (lewy dolny róg)
local questsPanel = makeLabel(gui, UDim2.new(0, 260, 0, 110), UDim2.new(0, 10, 1, -122), 13)
questsPanel.TextXAlignment = Enum.TextXAlignment.Left
questsPanel.TextYAlignment = Enum.TextYAlignment.Top
questsPanel.TextWrapped = true
local questsPadding = Instance.new("UIPadding")
questsPadding.PaddingLeft = UDim.new(0, 10)
questsPadding.PaddingTop = UDim.new(0, 8)
questsPadding.Parent = questsPanel

-- Dziennik grzybiarza: przycisk (prawy górny róg) + zwijany panel
local journalButton = Instance.new("TextButton")
journalButton.Size = UDim2.new(0, 150, 0, 36)
journalButton.Position = UDim2.new(1, -160, 0, 8)
journalButton.BackgroundColor3 = Color3.fromRGB(70, 50, 30)
journalButton.BackgroundTransparency = 0.2
journalButton.TextColor3 = Color3.new(1, 1, 1)
journalButton.Font = Enum.Font.GothamBold
journalButton.TextSize = 15
journalButton.Text = "📖 Dziennik"
journalButton.Parent = gui
local journalButtonCorner = Instance.new("UICorner")
journalButtonCorner.CornerRadius = UDim.new(0, 8)
journalButtonCorner.Parent = journalButton

local journalPanel = makeLabel(gui, UDim2.new(0, 340, 0, 340), UDim2.new(0.5, -170, 0.5, -170), 14)
journalPanel.TextXAlignment = Enum.TextXAlignment.Left
journalPanel.TextYAlignment = Enum.TextYAlignment.Top
journalPanel.TextWrapped = true
journalPanel.Visible = false
local journalPadding = Instance.new("UIPadding")
journalPadding.PaddingLeft = UDim.new(0, 12)
journalPadding.PaddingTop = UDim.new(0, 10)
journalPadding.Parent = journalPanel

journalButton.Activated:Connect(function()
	journalPanel.Visible = not journalPanel.Visible
end)

-- Samouczek: instrukcja na środku + pływający znacznik nad celem
local tutorialLabel = makeLabel(gui, UDim2.new(0, 540, 0, 40), UDim2.new(0.5, -270, 0, 104), 17)
tutorialLabel.BackgroundColor3 = Color3.fromRGB(160, 120, 30)
tutorialLabel.Visible = false

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
			tutorialLabel.Text = "🍄 KROK 1/3: Pobiegnij w las (Shift = bieg) i przytrzymaj E przy grzybku"
			local target = nearestOwnMushroomPart()
			marker.Parent = target
			marker.Enabled = target ~= nil
		elseif step == 2 then
			tutorialLabel.Text = "📦 KROK 2/3: Wróć do bazy i przytrzymaj E na drewnianym polu"
			marker.Parent = workspace:FindFirstChild("BasePad")
			marker.Enabled = marker.Parent ~= nil
		elseif step == 3 then
			tutorialLabel.Text = "⬆️ KROK 3/3: Kup pierwsze ulepszenie w panelu po lewej"
			marker.Enabled = false
			marker.Parent = nil
		else
			marker.Enabled = false
			marker.Parent = nil
		end
		tutorialLabel.Visible = step >= 1 and step <= 3
		task.wait(1)
	end
end)

-- ============================================================================
-- Odświeżanie HUD z atrybutów gracza (ustawia je serwer)
-- ============================================================================

local function refresh()
	local cash = player:GetAttribute("Cash") or 0
	local income = player:GetAttribute("IncomePerSec") or 0
	cashLabel.Text = ("💰 %s   (+%s/s)"):format(fmt(cash), fmt(income))

	local stamina = player:GetAttribute("Stamina") or 0
	local staminaMax = math.max(1, player:GetAttribute("StaminaMax") or 1)
	local fraction = stamina / staminaMax
	staminaFill.Size = UDim2.new(fraction, 0, 1, 0)
	staminaFill.BackgroundColor3 = fraction > 0.3
		and Color3.fromRGB(90, 200, 90)
		or Color3.fromRGB(220, 90, 60)

	local pity = player:GetAttribute("Pity") or 0
	pityLabel.Text = ("🍀 Gwarancja Rzadkiego: %d/%d"):format(pity, Config.Pity.cutsForGuaranteedRare)

	local carried = player:GetAttribute("CarriedSummary") or ""
	local shelfCount = player:GetAttribute("ShelfCount") or 0
	local shelves = player:GetAttribute("ShelvesOwned") or 0
	carriedPanel.Text = ("🧺 KOSZ (odłóż w bazie!)\n%s\n\n🪵 Półki: %d/%d")
		:format(carried == "" and "— pusty —" or carried, shelfCount, shelves)

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
	local quests = player:GetAttribute("QuestsText") or ""
	questsPanel.Text = ("📋 DZISIAJ   🎁 skrzynka za %s\n%s"):format(fmtTime(chestIn), quests)

	-- dziennik grzybiarza
	local journalCount = player:GetAttribute("JournalCount") or 0
	local journalTotal = player:GetAttribute("JournalTotal") or 0
	journalButton.Text = ("📖 Dziennik %d/%d"):format(journalCount, journalTotal)
	journalPanel.Text = ("📖 DZIENNIK GRZYBIARZA (%d/%d)\n\n%s")
		:format(journalCount, journalTotal, player:GetAttribute("JournalText") or "")
end

player.AttributeChanged:Connect(refresh)
refresh()

-- ============================================================================
-- Powiadomienia i zarobek offline
-- ============================================================================

local toastUntil = 0
notifyRemote.OnClientEvent:Connect(function(message: string)
	toast.Text = message
	toast.Visible = true
	local shownAt = os.clock()
	toastUntil = shownAt + 3
	task.delay(3, function()
		if os.clock() >= toastUntil then
			toast.Visible = false
		end
	end)
end)

task.spawn(function()
	-- atrybut pojawia się chwilę po wejściu, jeśli coś zarobiliśmy offline
	for _ = 1, 20 do
		local earned = player:GetAttribute("OfflineEarned")
		if earned and earned > 0 then
			toast.Text = ("🌙 Zarobiłeś %s 💰 kiedy cię nie było!"):format(fmt(earned))
			toast.Visible = true
			task.delay(6, function() toast.Visible = false end)
			break
		end
		task.wait(0.5)
	end
end)
