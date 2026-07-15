-- GameServer: cała logika gry — spawny grzybów, ścinanie (losowanie),
-- świeżość, kondycja/sprint, dostawa na półki, dochód, ulepszenia, światy,
-- dziennik, dzienne zadania, skrzynka, samouczek, wizualne półki, zapis.
-- Wklej jako Script do ServerScriptService (nazwa: GameServer).
--
-- ZASADA (GDD): serwer NIGDY nie ufa klientowi. Klient tylko prosi
-- (sprint on/off, kup ulepszenie) — wszystkie decyzje i liczby są tutaj.
--
-- Skrót prototypowy (do zmiany w fazie MVP): grzyby innych graczy są
-- widoczne dla wszystkich, ale ściąć swoje może tylko właściciel.
-- Docelowo (GDD §4) rendering per-gracz po stronie klienta.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local DataService = require(ServerScriptService:WaitForChild("DataService"))
local EventService = require(ServerScriptService:WaitForChild("EventService"))

local NODES_PER_PLAYER = 42    -- las ma być PEŁEN grzybów (głównie tanich)
local NODE_RESPAWN_DELAY = 4   -- sekundy do wyrośnięcia nowej miejscówki
-- rozkład miejscówek po pierścieniach: przy wejściu zatrzęsienie tanich —
-- nawet zupełnie nowy gracz ZAWSZE coś utnie; w głębi rzadziej, ale lepiej
local NODE_RING_WEIGHTS = { 40, 25, 17, 11, 7 }
local AUTOSAVE_INTERVAL = 120

-- ============================================================================
-- MODELE Z BLENDERA — auto-podpięcie. Jeśli w ReplicatedStorage.Models
-- leży model o właściwej nazwie, gra klonuje GO zamiast budować z klocków.
-- Niczego nie trzeba przełączać: brak folderu/modelu = wygląd proceduralny.
-- Oczekiwana struktura (szczegóły: blender/PODPIECIE-MODELI.md):
--   ReplicatedStorage/Models/Grzyby/<nazwa gatunku z GameConfig>
-- ============================================================================

local modelsRoot = ReplicatedStorage:FindFirstChild("Models")

local function findTemplate(category: string?, name: string): Model?
	if not modelsRoot then return nil end
	local holder: Instance = modelsRoot
	if category then
		local sub = modelsRoot:FindFirstChild(category)
		if not sub then return nil end
		holder = sub
	end
	local template = holder:FindFirstChild(name)
	if template and template:IsA("Model") then
		return template
	end
	return nil
end

-- Klon gotowy do wstawienia: zakotwiczony, bez kolizji, *Glow → Neon
-- (gdyby ktoś zapomniał ustawić przy imporcie), opcjonalnie przeskalowany.
-- targetHeight NORMALIZUJE rozmiar (FBX-y potrafią wyjść ogromne albo
-- malutkie — gra i tak sprowadza model do właściwej wielkości).
local function prepareClone(template: Model, scale: number?, targetHeight: number?): Model
	local clone = template:Clone()
	local biggest: BasePart? = nil
	local biggestVolume = 0
	for _, part in clone:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			if string.find(part.Name, "Glow", 1, true) then
				part.Material = Enum.Material.Neon
			else
				-- "tekstura" po nazwie: drewno/kamień/szkło/lód/trawa...
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
	if not clone.PrimaryPart then
		clone.PrimaryPart = biggest
	end
	local factor = scale or 1
	if targetHeight then
		local _, size = clone:GetBoundingBox()
		if size.Y > 0.01 then
			factor *= targetHeight / size.Y
		end
	end
	if factor ~= 1 then
		clone:ScaleTo(clone:GetScale() * factor)
	end
	return clone
end

-- Stawia klon tak, by DNO jego bounding boxa stało w punkcie (x, y, z).
local function placeClone(clone: Model, x: number, y: number, z: number, yaw: number?)
	local box, size = clone:GetBoundingBox()
	local pivotToCenter = clone:GetPivot():ToObjectSpace(box)
	local targetCenter = CFrame.new(x, y + size.Y / 2, z) * CFrame.Angles(0, yaw or 0, 0)
	clone:PivotTo(targetCenter * pivotToCenter:Inverse())
	return size
end

-- ============================================================================
-- Remotes (tworzone przez serwer — klient robi WaitForChild)
-- ============================================================================

local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = ReplicatedStorage

local function makeRemote(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local sprintRemote = makeRemote("Sprint")       -- klient → serwer: (bool) sprintuję?
local buyRemote = makeRemote("BuyUpgrade")      -- klient → serwer: ("Stamina"|"Thermos"|"Shelf")
local notifyRemote = makeRemote("Notify")       -- serwer → klient(y): (tekst) ogłoszenia
local sellRemote = makeRemote("SellWeakest")    -- klient → serwer: sprzedaj najsłabszy grzyb z półki
local rebirthRemote = makeRemote("Rebirth")     -- klient → serwer: prośba o rebirth
local equipRemote = makeRemote("EquipPet")      -- klient → serwer: (indeks) załóż/zdejmij peta
local hatchRemote = makeRemote("HatchResult")   -- serwer → klient: wynik wyklucia (do fanfary)
local autoHatchRemote = makeRemote("ToggleAutoHatch") -- klient → serwer: włącz/wyłącz auto
local autoDeleteRemote = makeRemote("SetAutoDelete")  -- klient → serwer: (świat, pet, bool)
local launchRemote = makeRemote("LaunchStop")   -- klient → serwer: zatrzymaj wskaźnik startu wyprawy
local escapeRemote = makeRemote("Escaped")      -- serwer → klient: (etykieta łupu) uciekłeś wilkowi
local wolfSceneRemote = makeRemote("WolfScene") -- serwer → klient: (pozycja, nazwa, sekundy) cutscenka wilka
local abortRemote = makeRemote("AbortRun")      -- klient → serwer: przerwij bieg (zawróć do bazy)

-- eventy globalne dla całego serwera; Deszcz meteorów (onlyWorld) czeka
-- na porządną implementację wspólnych spawnów w fazie MVP
EventService.init(notifyRemote, "Deciduous")

-- ============================================================================
-- Struktury mapy (zbudowane przez MapBuilder)
-- ============================================================================

local worldsFolder = workspace:WaitForChild("Worlds")

local ringPartsByWorld: { [number]: { Part } } = {}
local basePads: { [number]: Part } = {}
local baseReturnCFrames: { [number]: CFrame } = {}

for _, worldFolder in worldsFolder:GetChildren() do
	local worldIdx = worldFolder:GetAttribute("WorldIndex")
	if not worldIdx then continue end

	local rings = {}
	for _, part in worldFolder.Rings:GetChildren() do
		local ringIndex = part:GetAttribute("RingIndex")
		if ringIndex then
			rings[ringIndex] = part
		end
	end
	ringPartsByWorld[worldIdx] = rings

	local pad = worldFolder:FindFirstChild("BasePad")
	basePads[worldIdx] = pad
	baseReturnCFrames[worldIdx] = CFrame.new(pad.Position + Vector3.new(0, 3, -10))
end

-- ============================================================================
-- Stan sesji graczy
-- ============================================================================

type Carried = {
	worldIdx: number,
	speciesIdx: number,
	rarityIdx: number,
	mutationIdx: number,
	mutationIdx2: number, -- druga mutacja (0 = brak; event „podwójne mutacje")
	freshness: number,
	earned: number?,      -- urobek na polu (tylko grzyby zasadzone na grządce)
	lvl: number?,         -- poziom grzyba 1..100 (tylko zasadzone)
}

local sessions: { [Player]: {
	data: any,
	loadedOk: boolean,
	stamina: number,
	sprinting: boolean,
	exhausted: boolean,
	exhaustedUntil: number, -- os.clock() końca „zadyszki"
	carried: { Carried },
	tutorialStep: number, -- 1..3 = aktywny krok, 0 = ukończony
	nextChestAt: number,  -- os.time() następnej skrzynki czasowej
	plotIndex: number,    -- slot działki gracza w pasie bazy
	plotLabels: any,      -- liczniki urobku ([slot] = { napis_płaski, napis_unoszący })
	pendingOfflineBonus: number, -- druga połowa zarobku offline (×2 za Robux)
	comboCount: number,   -- aktualna seria ścięć
	comboLastAt: number,  -- os.clock() ostatniego ścięcia
	passes: { [string]: boolean }, -- posiadane Game Passy (cache)
	autoHatch: boolean,   -- włączone auto-otwieranie jaj (wymaga passa)
	nextAutoHatchAt: number,
	expedition: string,   -- "base" | "aiming" (minigra startu) | "run" (wyprawa)
	runPhase: string,     -- podczas "run": "out" (w głąb, auto-bieg) | "return" (powrót)
	fullToastAt: number,  -- os.clock() ostatniego toastu "koszyk pełny" (anty-spam)
	lastZ: number,        -- poprzednia pozycja Z (kondycja spala się TYLKO w głąb)
	launchStart: number,  -- GetServerTimeNow() startu oscylatora minigry
	launchMult: number,   -- aktywny mnożnik head startu
	launchUntil: number,  -- os.clock() końca head startu
	wolf: any,            -- aktywny pościg: { model, speed, name } albo nil
	journalJSON: string?, -- cache JSON-a zdobytych gatunków (nil = przelicz)
	baseIncomeLabel: any, -- etykieta "$X/s" na czerwonym markerze działki
	launchCooldownUntil: number, -- os.clock(): pad startu nie odpali przed tym czasem
} } = {}

-- właścicielstwo Game Passów: sprawdzane raz przy wejściu (i po zakupie)
local function loadPasses(player: Player, s)
	task.spawn(function()
		for key, pass in Config.GamePasses do
			local owns = false
			if pass.id ~= 0 then
				local ok, result = pcall(function()
					return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
				end)
				owns = ok and result == true
			end
			s.passes[key] = owns
		end
		player:SetAttribute("OwnsTripleHatch", s.passes.TripleHatch == true)
		player:SetAttribute("OwnsAutoHatch", s.passes.AutoHatch == true)
		player:SetAttribute("EggLuck", (s.passes.EggLuck6 and 6) or (s.passes.EggLuck3 and 3) or 1)
	end)
end

local rebuildHook = nil -- ustawiane niżej na refreshShelfDisplay (kolejność definicji)

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, _passId, purchased)
	local s = sessions[player]
	if purchased and s then
		loadPasses(player, s) -- odśwież po zakupie, efekt działa od razu
		task.delay(1, function()
			if sessions[player] and rebuildHook then
				rebuildHook(player) -- np. pass +5 grządek = działka rośnie od razu
			end
		end)
	end
end)

local plotCounter = 0

local function currentWorld(s): any
	return Config.Worlds[s.data.currentWorld]
end

local function staminaMax(data): number
	return Config.Stats.Stamina.baseBar + Config.Stats.Stamina.perLevel * data.staminaLevel
end

local function decayPerSec(data, item: Carried): number
	local world = Config.Worlds[item.worldIdx or 1]
	return Config.decayPerSec(world.freshnessDecayPerSec, data.thermosLevel, false, item.rarityIdx)
end

-- trwały mnożnik dochodu z rebirthów (GDD: silnik długiego progresu)
local function rebirthMult(data): number
	return 1 + (data.rebirths or 0) * Config.Rebirth.incomeBonusPerRebirth
end

-- pojemność koszyka: 2 bazowo, +2 z passem „Głęboki Koszyk"
local function carryCapacity(s): number
	return Config.Carry.baseSlots
		+ (s.passes.CarrySlots and Config.GamePasses.CarrySlots.effect.extraCarry or 0)
end

-- pojemność działki: kupione grządki (10→20 za kasę) + pass „Grzybowa Grządka +5"
local function plotCapacity(s): number
	return s.data.plotsOwned
		+ (s.passes.ExtraPlots and Config.GamePasses.ExtraPlots.effect.extraPlots or 0)
end

-- sumaryczne bonusy z założonych petów: (+% dochodu, +% szczęścia)
local function petBonuses(data): (number, number)
	local income, luck = 0, 0
	for _, pet in data.pets or {} do
		if pet.eq then
			income += Config.Pets.incomeBonusByRarity[pet.r] or 0
			luck += Config.Pets.luckBonusByRarity[pet.r] or 0
		end
	end
	return income, luck
end

-- wartość WŁASNA grzyba: gatunek × rzadkość × mutacje × świeżość × świat
-- (bez mnożników konta — używana też do wyceny ulepszeń poziomu)
local function itemBaseIncome(item: Carried): number
	local world = Config.Worlds[item.worldIdx or 1]
	local species = world.species[item.speciesIdx]
	local rarity = Config.Rarities[item.rarityIdx]
	local mutationMult = item.mutationIdx > 0 and Config.Mutations[item.mutationIdx].incomeMult or 1
	local mutation2Idx = item.mutationIdx2 or 0
	if mutation2Idx > 0 then
		mutationMult *= Config.Mutations[mutation2Idx].incomeMult
	end
	return Config.shelfIncome(species.baseIncome, rarity.incomeMult, mutationMult, item.freshness, world.incomeMult)
end

local function itemIncome(item: Carried, data): number
	local petIncome = petBonuses(data)
	return itemBaseIncome(item) * Config.mushroomLevelMult(item.lvl)
		* rebirthMult(data) * (1 + petIncome)
end

-- koszt ulepszenia grzyba o 1 poziom (rośnie ×1,10 za poziom)
local function mushroomUpgradeCost(item: Carried): number
	local lvl = item.lvl or 1
	return math.max(5, math.floor(itemBaseIncome(item)
		* Config.MushroomLevels.costBaseSeconds
		* Config.MushroomLevels.costGrowth ^ (lvl - 1)))
end

local function shelfIncomePerSec(data): number
	local total = 0
	for _, item in data.shelf do
		total += itemIncome(item, data)
	end
	return total
end

local function itemLabel(item: Carried): string
	local world = Config.Worlds[item.worldIdx or 1]
	local species = world.species[item.speciesIdx]
	local rarity = Config.Rarities[item.rarityIdx]
	local mutation = item.mutationIdx > 0 and (" [" .. Config.Mutations[item.mutationIdx].name .. "]") or ""
	local mutation2Idx = item.mutationIdx2 or 0
	if mutation2Idx > 0 then
		mutation ..= " [" .. Config.Mutations[mutation2Idx].name .. "]"
	end
	local levelSuffix = (item.lvl or 1) > 1 and (" L%d"):format(item.lvl) or ""
	return ("%s (%s)%s%s %d%%"):format(species.name, rarity.name, mutation, levelSuffix, math.floor(item.freshness))
end

-- ============================================================================
-- Efekty („juice"): iskierki, rozbryzg przy ścięciu, pływający tekst nagrody
-- ============================================================================

local function addSparkle(parent: BasePart, color: Color3, rate: number): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(1, 2)
	emitter.Speed = NumberRange.new(0.3, 0.8)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = parent
	return emitter
end

local function burstAt(position: Vector3, color: Color3)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = CFrame.new(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Enabled = false
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.6
	emitter.Lifetime = NumberRange.new(0.3, 0.7)
	emitter.Speed = NumberRange.new(4, 9)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Parent = part
	part.Parent = workspace
	emitter:Emit(18)
	Debris:AddItem(part, 2)
end

-- unoszący się napis nagrody („+3 🍄", nazwa rzadkiego znaleziska)
local function floatingText(position: Vector3, text: string, color: Color3)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = CFrame.new(position)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 160, 0, 44)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(30, 30, 45)
	stroke.Thickness = 2
	stroke.Parent = label
	label.Parent = billboard
	part.Parent = workspace
	TweenService:Create(billboard, TweenInfo.new(1.1, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 6, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(1.1), { TextTransparency = 1 }):Play()
	TweenService:Create(stroke, TweenInfo.new(1.1), { Transparency = 1 }):Play()
	Debris:AddItem(part, 1.3)
end

-- ============================================================================
-- Dziennik grzybiarza, dzienne zadania, skrzynka (GDD §6-7)
-- ============================================================================

local templateById = {}
for _, template in Config.Daily.templates do
	templateById[template.id] = template
end

local JOURNAL_TOTAL = 0
for _, world in Config.Worlds do
	JOURNAL_TOTAL += #world.species * #Config.Rarities
end

local function journalKey(item: Carried): string
	return ("%d:%d:%d"):format(item.worldIdx, item.speciesIdx, item.rarityIdx)
end

local function journalCount(data): number
	local count = 0
	for _ in data.journal do
		count += 1
	end
	return count
end

-- strona dziennika dla bieżącego świata gracza
local function journalText(data): string
	local worldIdx = data.currentWorld
	local world = Config.Worlds[worldIdx]
	local lines = { ("— %s —"):format(world.name) }
	for speciesIdx, species in world.species do
		local found = 0
		for rarityIdx = 1, #Config.Rarities do
			if data.journal[("%d:%d:%d"):format(worldIdx, speciesIdx, rarityIdx)] then
				found += 1
			end
		end
		table.insert(lines, ("%s — %d/%d"):format(species.name, found, #Config.Rarities))
	end
	local mutationNames = {}
	for _, mutation in Config.Mutations do
		if data.mutationsSeen[mutation.id] then
			table.insert(mutationNames, mutation.name)
		end
	end
	table.insert(lines, "")
	table.insert(lines, ("Mutacje %d/%d: %s"):format(
		#mutationNames, #Config.Mutations,
		#mutationNames > 0 and table.concat(mutationNames, ", ") or "—"))
	return table.concat(lines, "\n")
end

local function questsText(data): string
	local lines = {}
	for _, quest in data.daily.quests do
		local template = templateById[quest.id]
		if template then
			local mark = quest.done and "✅" or "▫️"
			table.insert(lines, ("%s %s — %d/%d"):format(
				mark, template.text, math.min(quest.progress, template.target), template.target))
		end
	end
	return table.concat(lines, "\n")
end

-- losuje 3 zadania na nowy dzień (UTC)
local function ensureDaily(data)
	local today = os.date("!%Y-%m-%d")
	if data.daily and data.daily.date == today then
		return
	end
	local pool = table.clone(Config.Daily.templates)
	local quests = {}
	for _ = 1, math.min(Config.Daily.questCount, #pool) do
		local index = math.random(#pool)
		table.insert(quests, { id = pool[index].id, progress = 0, done = false })
		table.remove(pool, index)
	end
	data.daily = { date = today, quests = quests }
end

-- Wypycha stan do klienta przez atrybuty (HUD tylko je czyta)
local function syncAttributes(player: Player)
	local s = sessions[player]
	if not s then return end
	local data = s.data
	player:SetAttribute("Cash", math.floor(data.cash))
	player:SetAttribute("Stamina", math.floor(s.stamina))
	player:SetAttribute("StaminaMax", staminaMax(data))
	player:SetAttribute("StaminaLevel", data.staminaLevel)
	player:SetAttribute("ThermosLevel", data.thermosLevel)
	player:SetAttribute("PlotsBought", data.plotsOwned)
	player:SetAttribute("PlotCapacity", plotCapacity(s))
	player:SetAttribute("ShelfCount", #data.shelf)
	player:SetAttribute("CarriedCount", #s.carried)
	player:SetAttribute("CarrySlots", carryCapacity(s))
	player:SetAttribute("IncomePerSec", math.floor(shelfIncomePerSec(data)))
	player:SetAttribute("Pity", data.pity)
	player:SetAttribute("WorldName", currentWorld(s).name)
	player:SetAttribute("CurrentWorld", data.currentWorld)

	local lines = {}
	for _, item in s.carried do
		table.insert(lines, itemLabel(item))
	end
	player:SetAttribute("CarriedSummary", table.concat(lines, "\n"))

	player:SetAttribute("PetsJSON", HttpService:JSONEncode(data.pets or {}))
	player:SetAttribute("AutoDeleteJSON", HttpService:JSONEncode(data.autoDelete or {}))
	player:SetAttribute("AutoHatchOn", s.autoHatch)
	player:SetAttribute("Rebirths", data.rebirths)
	player:SetAttribute("RebirthCost", Config.rebirthCost(data.rebirths))
	player:SetAttribute("RebirthMult", rebirthMult(data))
	player:SetAttribute("Level", data.level)
	player:SetAttribute("XP", math.floor(data.xp))
	player:SetAttribute("XPNeeded", Config.xpForLevel(data.level))
	player:SetAttribute("ComboCount", s.comboCount)
	player:SetAttribute("StreakDay", data.streakDay)
	player:SetAttribute("TutorialStep", s.tutorialStep)
	player:SetAttribute("ChestIn", math.max(0, s.nextChestAt - os.time()))
	player:SetAttribute("JournalCount", journalCount(data))
	player:SetAttribute("JournalTotal", JOURNAL_TOTAL)
	player:SetAttribute("JournalText", journalText(data))
	player:SetAttribute("QuestsText", questsText(data))

	-- zdobyte GATUNKI ("świat:gatunek") dla sylwetek w dzienniku; cache
	-- unieważnia journalAdd przy nowym wpisie
	if not s.journalJSON then
		local owned = {}
		for key in data.journal do
			local worldPart, speciesPart = string.match(key, "^(%d+):(%d+):")
			if worldPart then
				owned[worldPart .. ":" .. speciesPart] = true
			end
		end
		s.journalJSON = HttpService:JSONEncode(owned)
	end
	player:SetAttribute("JournalSpeciesJSON", s.journalJSON)
end

-- Dopisuje znalezisko do dziennika; wypłaca nagrody za kamienie milowe.
local function journalAdd(player: Player, item: Carried)
	local s = sessions[player]
	if not s then return end
	local data = s.data

	local newEntry = false
	if not data.journal[journalKey(item)] then
		data.journal[journalKey(item)] = true
		newEntry = true
		s.journalJSON = nil -- sylwetka gatunku w dzienniku się odsłoni
	end
	for _, mutationIdx in { item.mutationIdx, item.mutationIdx2 or 0 } do
		if mutationIdx > 0 then
			local mutationId = Config.Mutations[mutationIdx].id
			if not data.mutationsSeen[mutationId] then
				data.mutationsSeen[mutationId] = true
				notifyRemote:FireClient(player, ("📖 Nowa mutacja w Dzienniku: %s!"):format(mutationId))
			end
		end
	end
	if newEntry then
		local count = journalCount(data)
		for _, milestone in Config.Journal.milestones do
			if milestone.count == count then
				data.cash += milestone.reward
				notifyRemote:FireAllClients(("📖 %s ma już %d wpisów w Dzienniku Grzybiarza! (+%s 💰)")
					:format(player.DisplayName, count, Config.fmtNumber(milestone.reward)))
			end
		end
	end
end

-- Przyznaje XP; obsługuje wejścia na poziom (kaskadowo) z nagrodami i fanfarą.
local function awardXp(player: Player, amount: number)
	local s = sessions[player]
	if not s then return end
	local data = s.data
	if data.level >= Config.XP.maxLevel then return end

	data.xp += amount
	while data.level < Config.XP.maxLevel and data.xp >= Config.xpForLevel(data.level) do
		data.xp -= Config.xpForLevel(data.level)
		data.level += 1

		local reward = Config.XP.cashRewardBase * Config.XP.cashRewardGrowth ^ data.level
		local isMilestone = data.level % Config.XP.milestoneEvery == 0
		if isMilestone then
			reward *= Config.XP.milestoneMult
		end
		data.cash += reward

		notifyRemote:FireClient(player, ("⬆️ POZIOM %d! Nagroda: %s 💰%s"):format(
			data.level, Config.fmtNumber(reward),
			isMilestone and " (kamień milowy ×5!)" or ""))
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			burstAt(root.Position, Color3.fromRGB(255, 220, 120))
			floatingText(root.Position + Vector3.new(0, 3, 0),
				("POZIOM %d!"):format(data.level), Color3.fromRGB(255, 220, 120))
		end
		if isMilestone then
			notifyRemote:FireAllClients(("🏆 %s osiągnął poziom %d!"):format(player.DisplayName, data.level))
		end
	end
end

-- Seria logowań dzień po dniu: przerwiesz — wracasz do dnia 1.
local function grantDailyStreak(player: Player)
	local s = sessions[player]
	if not s then return end
	local data = s.data
	local today = os.date("!%Y-%m-%d")
	if data.lastLoginDate == today then
		return
	end
	local yesterday = os.date("!%Y-%m-%d", os.time() - 86400)
	data.streakDay = (data.lastLoginDate == yesterday) and data.streakDay + 1 or 1
	data.lastLoginDate = today

	local base = Config.Streak.baseRewards[math.min(data.streakDay, #Config.Streak.baseRewards)]
	local reward = math.floor(base * (1 + data.level * Config.Streak.levelScale))
	data.cash += reward
	notifyRemote:FireClient(player, ("🔥 Seria dzienna: dzień %d — +%s 💰! Wróć jutro po więcej.")
		:format(data.streakDay, Config.fmtNumber(reward)))
end

-- Aktualizuje postęp dziennych zadań o danym typie statystyki.
-- absolute=true ustawia postęp na wartość (np. liczba grzybów na półkach).
local function questProgress(player: Player, stat: string, amount: number, absolute: boolean)
	local s = sessions[player]
	if not s then return end
	for _, quest in s.data.daily.quests do
		local template = templateById[quest.id]
		if template and template.stat == stat and not quest.done then
			if absolute then
				quest.progress = math.max(quest.progress, amount)
			else
				quest.progress += amount
			end
			if quest.progress >= template.target then
				quest.done = true
				s.data.cash += template.reward
				notifyRemote:FireClient(player, ("✅ Zadanie wykonane: %s! Nagroda %s 💰")
					:format(template.text, Config.fmtNumber(template.reward)))
			end
		end
	end
end

-- ============================================================================
-- Wizualne półki w bazie (GDD §6 — grzyby widoczne dla wszystkich)
-- ============================================================================

-- DZIAŁKA GRZĄDEK: każdy grzyb ZASADZONY w ziemi (rzędy po 5, „po 5 na
-- stronę"), a pod grządką zielone pole zliczające urobek — wejście na nie
-- zbiera kasę (dźwięk + particlesy). Odbudowywana przy każdej zmianie.
local COLLECT_DEBOUNCE = 0.35

-- pozycja grządki o danym numerze na WŁASNYM decku gracza.
-- Układ wg szkicu właściciela: rzędy po 5 z DUŻYMI przerwami (rozstaw 9),
-- rzędy chodzą PARAMI zwróconymi do siebie — pady zbioru ($) obu rzędów
-- wychodzą na wspólną alejkę między nimi.
-- Zwraca: x, z grządki oraz z pada zbioru.
local function plotCell(s, slot: number): (number, number, number)
	local pad = basePads[s.data.currentWorld]
	local deckCenter = Config.Base.deckCenters[s.plotIndex + 1] or 0
	local column = (slot - 1) % 5
	local row = (slot - 1) // 5
	local x = pad.Position.X + deckCenter - 18 + column * 9

	local pairIdx = row // 2
	local pairBase = pad.Position.Z - 13 - pairIdx * 28
	local plantZ, padZ
	if row % 2 == 0 then
		plantZ = pairBase          -- przedni rząd pary: pad GŁĘBIEJ (do alejki)
		padZ = pairBase - 5.5
	else
		plantZ = pairBase - 16     -- tylny rząd pary: pad PŁYCEJ (do alejki)
		padZ = plantZ + 5.5
	end
	return x, plantZ, padZ
end

-- grzyb zasadzony w grządce o danym numerze (shelf to gęsta lista,
-- każdy wpis pamięta swój slot — wybór grządki należy do gracza)
local function shelfAt(data, slot: number)
	for _, item in data.shelf do
		if item.slot == slot then
			return item
		end
	end
	return nil
end

local buyPlot -- (deklaracja: stanowisko kupna grządki woła to przy E)

local function refreshShelfDisplay(player: Player)
	local s = sessions[player]
	if not s then return end

	local old = workspace:FindFirstChild("PlotArea_" .. player.UserId)
	if old then old:Destroy() end
	s.plotLabels = {}
	s.baseIncomeLabel = nil

	local pad = basePads[s.data.currentWorld]
	if not pad then return end
	-- KAŻDY GRACZ MA WŁASNY DECK (Config.Base.deckCenters); siatka 5 kolumn
	-- × do 5 rzędów z DUŻYMI odstępami — grzyby mają oddychać
	local deckCenter = Config.Base.deckCenters[s.plotIndex + 1] or 0
	local origin = pad.Position + Vector3.new(deckCenter - 18, 0, -9)
	local function cellXZ(index: number): (number, number, number)
		return plotCell(s, index)
	end

	local area = Instance.new("Model")
	area.Name = "PlotArea_" .. player.UserId

	-- czerwony marker działki (jak w topowych symulatorach): nick + $X/s
	local markerAnchor = Instance.new("Part")
	markerAnchor.Transparency = 1
	markerAnchor.CanCollide = false
	markerAnchor.CanQuery = false
	markerAnchor.Anchored = true
	markerAnchor.Size = Vector3.new(1, 1, 1)
	markerAnchor.CFrame = CFrame.new(origin + Vector3.new(13, 15, -10))
	markerAnchor.Parent = area
	local marker = Instance.new("BillboardGui")
	marker.Size = UDim2.new(0, 210, 0, 74)
	marker.MaxDistance = 220
	marker.Parent = markerAnchor
	local markerDot = Instance.new("TextLabel")
	markerDot.Size = UDim2.new(0, 40, 0, 40)
	markerDot.Position = UDim2.new(0.5, 0, 0, 0)
	markerDot.AnchorPoint = Vector2.new(0.5, 0)
	markerDot.BackgroundColor3 = Color3.fromRGB(225, 55, 55)
	markerDot.Font = Enum.Font.FredokaOne
	markerDot.TextScaled = true
	markerDot.Text = "🍄"
	markerDot.TextColor3 = Color3.new(1, 1, 1)
	markerDot.Parent = marker
	local markerCorner = Instance.new("UICorner")
	markerCorner.CornerRadius = UDim.new(1, 0)
	markerCorner.Parent = markerDot
	local markerName = Instance.new("TextLabel")
	markerName.Size = UDim2.new(1, 0, 0, 18)
	markerName.Position = UDim2.new(0, 0, 0, 42)
	markerName.BackgroundTransparency = 1
	markerName.Font = Enum.Font.FredokaOne
	markerName.TextScaled = true
	markerName.TextColor3 = Color3.fromRGB(255, 120, 120)
	markerName.TextStrokeTransparency = 0.4
	markerName.Text = ("Baza: %s"):format(player.DisplayName)
	markerName.Parent = marker
	local markerIncome = Instance.new("TextLabel")
	markerIncome.Size = UDim2.new(1, 0, 0, 16)
	markerIncome.Position = UDim2.new(0, 0, 0, 60)
	markerIncome.BackgroundTransparency = 1
	markerIncome.Font = Enum.Font.FredokaOne
	markerIncome.TextScaled = true
	markerIncome.TextColor3 = Color3.fromRGB(160, 245, 170)
	markerIncome.TextStrokeTransparency = 0.4
	markerIncome.Text = Config.fmtNumber(shelfIncomePerSec(s.data)) .. "$/s"
	markerIncome.Parent = marker
	s.baseIncomeLabel = markerIncome

	-- najlepszy okaz sypie złotymi iskrami (flex)
	local bestItem, bestIncome = nil, -1
	for _, item in s.data.shelf do
		local income = itemIncome(item, s.data)
		if income > bestIncome then
			bestItem, bestIncome = item, income
		end
	end

	for index = 1, plotCapacity(s) do
		local soilX, soilZ, padZ = cellXZ(index)
		local groundY = pad.Position.Y

		local item = shelfAt(s.data, index)

		-- DONICA-stanowisko (jak podesty w topowych simach): stalowa rama
		-- + ziemia w środku; pusta = jaśniejsza, zachęca do zasadzenia
		local planter = Instance.new("Part")
		planter.Name = "Planter"
		planter.Size = Vector3.new(4.6, 0.5, 3.8)
		planter.Position = Vector3.new(soilX, groundY + 0.15, soilZ)
		planter.Color = Color3.fromRGB(45, 52, 66)
		planter.Material = Enum.Material.Metal
		planter.Anchored = true
		planter.Parent = area
		local soil = Instance.new("Part")
		soil.Name = "Soil"
		soil.Size = Vector3.new(3.6, 0.4, 2.8)
		soil.Position = Vector3.new(soilX, groundY + 0.45, soilZ)
		soil.Color = item and Color3.fromRGB(86, 60, 38) or Color3.fromRGB(120, 92, 62)
		soil.Material = Enum.Material.Ground
		soil.Anchored = true
		soil.CanCollide = false
		soil.Parent = area

		if not item then
			-- pusta grządka: podpowiedź, że tu można zasadzić z plecaka
			local hint = Instance.new("BillboardGui")
			hint.Size = UDim2.new(0, 130, 0, 26)
			hint.StudsOffset = Vector3.new(0, 2, 0)
			hint.MaxDistance = 26
			hint.Parent = soil
			local hintLabel = Instance.new("TextLabel")
			hintLabel.Size = UDim2.fromScale(1, 1)
			hintLabel.BackgroundTransparency = 1
			hintLabel.Font = Enum.Font.FredokaOne
			hintLabel.TextScaled = true
			hintLabel.TextColor3 = Color3.fromRGB(200, 245, 200)
			hintLabel.TextStrokeTransparency = 0.5
			hintLabel.Text = "🌱 wolna grządka"
			hintLabel.Parent = hint
		end

		if item then
			-- zasadzony grzyb: DUŻY (robi wrażenie już od lvl 1), kapelusz
			-- w kolorze rzadkości, rośnie z poziomem (lvl 100 = KOLOS)
			local isBest = item == bestItem
			local lvl = item.lvl or 1
			local lvlScale = 1 + (lvl - 1) * Config.MushroomLevels.sizePerLevel
			local scale = (isBest and 2.3 or 1.9) * lvlScale
			local miniStem = Instance.new("Part")
			miniStem.Shape = Enum.PartType.Cylinder
			miniStem.Size = Vector3.new(1.0, 0.5, 0.5) * scale
			miniStem.Color = Color3.fromRGB(240, 232, 210)
			miniStem.Material = Enum.Material.SmoothPlastic
			miniStem.Anchored = true
			miniStem.CanCollide = false
			miniStem.CFrame = CFrame.new(soilX, groundY + 0.7 * scale, soilZ)
				* CFrame.Angles(0, 0, math.rad(90))
			miniStem.Parent = area

			local miniCap = Instance.new("Part")
			miniCap.Shape = Enum.PartType.Ball
			miniCap.Size = Vector3.new(1.5, 1.0, 1.5) * scale
			miniCap.Color = Config.Rarities[item.rarityIdx].color
			miniCap.Material = (item.mutationIdx > 0 or (item.mutationIdx2 or 0) > 0)
				and Enum.Material.Neon or Enum.Material.SmoothPlastic
			miniCap.Anchored = true
			miniCap.CanCollide = false
			miniCap.CFrame = CFrame.new(soilX, groundY + 1.2 * scale, soilZ)
			miniCap.Parent = area
			if isBest and bestIncome > 0 then
				addSparkle(miniCap, Color3.fromRGB(255, 220, 120), 3)
			end

			-- BILLBOARD nad grzybem (styl topowych symulatorów):
			-- nazwa w kolorze rzadkości • mutacja • świat • $X/s na zielono
			local species = Config.Worlds[item.worldIdx].species[item.speciesIdx]
			local rarity = Config.Rarities[item.rarityIdx]
			local plate = Instance.new("BillboardGui")
			plate.Size = UDim2.new(0, 190, 0, 78)
			plate.StudsOffset = Vector3.new(0, 0.8 * scale + 1.6, 0)
			plate.MaxDistance = 140
			plate.Parent = miniCap
			local nameLine = Instance.new("TextLabel")
			nameLine.Size = UDim2.new(1, 0, 0, 30)
			nameLine.BackgroundTransparency = 1
			nameLine.Font = Enum.Font.FredokaOne
			nameLine.TextScaled = true
			nameLine.TextColor3 = rarity.color:Lerp(Color3.new(1, 1, 1), 0.35)
			nameLine.TextStrokeTransparency = 0.15
			nameLine.Text = species.name
			nameLine.Parent = plate
			local infoLine = Instance.new("TextLabel")
			infoLine.Size = UDim2.new(1, 0, 0, 20)
			infoLine.Position = UDim2.new(0, 0, 0, 30)
			infoLine.BackgroundTransparency = 1
			infoLine.Font = Enum.Font.FredokaOne
			infoLine.TextScaled = true
			infoLine.TextStrokeTransparency = 0.3
			local mutationBits = {}
			for _, mutationIdx in { item.mutationIdx, item.mutationIdx2 or 0 } do
				if mutationIdx > 0 then
					table.insert(mutationBits, Config.Mutations[mutationIdx].name:upper())
				end
			end
			if #mutationBits > 0 then
				infoLine.TextColor3 = Color3.fromRGB(255, 215, 90)
				infoLine.Text = ("✨ %s • %s"):format(table.concat(mutationBits, "+"),
					Config.Worlds[item.worldIdx].name)
			else
				infoLine.TextColor3 = Color3.fromRGB(205, 210, 225)
				infoLine.Text = ("%s • %s"):format(rarity.name, Config.Worlds[item.worldIdx].name)
			end
			infoLine.Parent = plate
			local incomeLine = Instance.new("TextLabel")
			incomeLine.Size = UDim2.new(1, 0, 0, 26)
			incomeLine.Position = UDim2.new(0, 0, 0, 50)
			incomeLine.BackgroundTransparency = 1
			incomeLine.Font = Enum.Font.FredokaOne
			incomeLine.TextScaled = true
			incomeLine.TextColor3 = Color3.fromRGB(130, 245, 140)
			incomeLine.TextStrokeTransparency = 0.15
			incomeLine.Text = ("$%s/s"):format(Config.fmtNumber(itemIncome(item, s.data)))
			incomeLine.Parent = plate

			-- TABLET ULEPSZENIA (lvl 1→100): STAŁA pomarańczowa tablica nad
			-- grządką (SurfaceGui — NIE obraca się za graczem), interaktywna:
			-- klik/tap (ClickDetector) kupuje poziom. Zero przytrzymywania E.
			if lvl < Config.MushroomLevels.maxLevel then
				local tablet = Instance.new("Part")
				tablet.Name = "UpgradeTablet"
				tablet.Size = Vector3.new(4.4, 2.3, 0.35)
				tablet.CFrame = CFrame.new(soilX, groundY + 1.9 * scale + 1.8, soilZ - 1.0)
					* CFrame.Angles(math.rad(-14), 0, 0)
				tablet.Color = Color3.fromRGB(58, 44, 22)
				tablet.Material = Enum.Material.SmoothPlastic
				tablet.Anchored = true
				tablet.CanCollide = false
				tablet.Parent = area

				local face = Instance.new("SurfaceGui")
				face.Face = Enum.NormalId.Back -- ścianka od strony przejścia (+Z)
				face.Parent = tablet
				local panel = Instance.new("Frame")
				panel.Size = UDim2.fromScale(0.97, 0.94)
				panel.Position = UDim2.fromScale(0.5, 0.5)
				panel.AnchorPoint = Vector2.new(0.5, 0.5)
				panel.BackgroundColor3 = Color3.fromRGB(250, 165, 35)
				panel.Parent = face
				local panelCorner = Instance.new("UICorner")
				panelCorner.CornerRadius = UDim.new(0, 40)
				panelCorner.Parent = panel
				local panelStroke = Instance.new("UIStroke")
				panelStroke.Thickness = 8
				panelStroke.Color = Color3.fromRGB(50, 40, 25)
				panelStroke.Parent = panel
				local upCost = Instance.new("TextLabel")
				upCost.Size = UDim2.fromScale(0.9, 0.52)
				upCost.Position = UDim2.fromScale(0.5, 0.06)
				upCost.AnchorPoint = Vector2.new(0.5, 0)
				upCost.BackgroundTransparency = 1
				upCost.Font = Enum.Font.FredokaOne
				upCost.TextScaled = true
				upCost.TextColor3 = Color3.fromRGB(120, 250, 130)
				upCost.TextStrokeColor3 = Color3.fromRGB(25, 55, 25)
				upCost.TextStrokeTransparency = 0.1
				upCost.Text = ("⬆️ $%s"):format(Config.fmtNumber(mushroomUpgradeCost(item)))
				upCost.Parent = panel
				local upLvl = Instance.new("TextLabel")
				upLvl.Size = UDim2.fromScale(0.9, 0.3)
				upLvl.Position = UDim2.fromScale(0.5, 0.62)
				upLvl.AnchorPoint = Vector2.new(0.5, 0)
				upLvl.BackgroundTransparency = 1
				upLvl.Font = Enum.Font.FredokaOne
				upLvl.TextScaled = true
				upLvl.TextColor3 = Color3.fromRGB(70, 150, 60)
				upLvl.Text = ("Poziom %d ➜ %d"):format(lvl, lvl + 1)
				upLvl.Parent = panel

				local clicker = Instance.new("ClickDetector")
				clicker.MaxActivationDistance = 30
				clicker.Parent = tablet
				clicker.MouseClick:Connect(function(who)
					if who ~= player then return end
					local planted = shelfAt(s.data, index)
					if not planted or (planted.lvl or 1) >= Config.MushroomLevels.maxLevel then
						return
					end
					local cost = mushroomUpgradeCost(planted)
					if s.data.cash < cost then
						notifyRemote:FireClient(player, ("❌ Ulepszenie kosztuje %s 💰 — za mało kasy."):format(Config.fmtNumber(cost)))
						return
					end
					s.data.cash -= cost
					planted.lvl = (planted.lvl or 1) + 1
					burstAt(miniCap.Position, miniCap.Color)
					floatingText(miniCap.Position + Vector3.new(0, 1.5, 0),
						("⬆️ LVL %d!"):format(planted.lvl),
						Config.Rarities[planted.rarityIdx].color)
					if planted.lvl == Config.MushroomLevels.maxLevel then
						notifyRemote:FireAllClients(("🍄👑 %s wymaksował grzyba: %s (lvl 100)!")
							:format(player.DisplayName, itemLabel(planted)))
					end
					refreshShelfDisplay(player) -- grzyb rośnie + świeża cena
					syncAttributes(player)
				end)
			else
				-- lvl 100: kolos świeci własną chwałą zamiast prompta
				addSparkle(miniCap, Color3.fromRGB(255, 235, 160), 4)
			end

			-- ZIELONE POLE ZBIORU ($) od strony alejki: licznik urobku +
			-- zbiór wejściem. Matowe (bez świecenia), napis WZDŁUŻ grządki.
			local collect = Instance.new("Part")
			collect.Name = "CollectPad"
			collect.Size = Vector3.new(4.6, 0.24, 2.4)
			collect.Position = Vector3.new(soilX, groundY - 0.05, padZ)
			collect.Color = Color3.fromRGB(110, 235, 105)
			collect.Material = Enum.Material.SmoothPlastic
			collect.Anchored = true
			collect.CanCollide = false
			collect.Parent = area

			local gui = Instance.new("SurfaceGui")
			gui.Face = Enum.NormalId.Top
			-- canvas dopasowany do pada (domyślne 800×600 + limit fontu 100 px
			-- dawały mikroskopijny napis)
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			gui.Parent = collect
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(0.92, 0.8)
			label.Position = UDim2.fromScale(0.5, 0.5)
			label.AnchorPoint = Vector2.new(0.5, 0.5)
			label.BackgroundTransparency = 1
			label.Font = Enum.Font.FredokaOne
			label.TextScaled = true
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Text = "$" .. Config.fmtNumber(item.earned or 0)
			label.Parent = gui
			local labelStroke = Instance.new("UIStroke")
			labelStroke.Thickness = 3
			labelStroke.Color = Color3.fromRGB(20, 60, 30)
			labelStroke.Parent = label

			-- LICZNIK unoszący się nad polem — zawsze zwrócony do kamery,
			-- czytelny pod każdym kątem (płaski napis ginie z perspektywy gracza)
			local floatGui = Instance.new("BillboardGui")
			floatGui.Size = UDim2.new(0, 150, 0, 44)
			floatGui.StudsOffset = Vector3.new(0, 1.6, 0)
			floatGui.MaxDistance = 90
			floatGui.Parent = collect
			local floatLabel = Instance.new("TextLabel")
			floatLabel.Size = UDim2.fromScale(1, 1)
			floatLabel.BackgroundTransparency = 1
			floatLabel.Font = Enum.Font.FredokaOne
			floatLabel.TextScaled = true
			floatLabel.TextColor3 = Color3.fromRGB(150, 255, 150)
			floatLabel.TextStrokeColor3 = Color3.fromRGB(15, 55, 25)
			floatLabel.TextStrokeTransparency = 0
			floatLabel.Text = "$" .. Config.fmtNumber(item.earned or 0)
			floatLabel.Parent = floatGui

			-- oba napisy odświeża pętla dochodu (klucz = numer grządki)
			s.plotLabels[index] = { label, floatLabel }

			local sound = Instance.new("Sound")
			sound.SoundId = Config.Base.collectSoundId
			sound.Volume = 0.5
			sound.Parent = collect

			local lastCollect = 0
			collect.Touched:Connect(function(hit)
				local character = hit.Parent
				local who = character and Players:GetPlayerFromCharacter(character)
				if who ~= player then return end -- zbiera tylko właściciel
				if os.clock() - lastCollect < COLLECT_DEBOUNCE then return end
				lastCollect = os.clock()
				local planted = shelfAt(s.data, index)
				if not planted then return end
				local earned = math.floor(planted.earned or 0)
				if earned < 1 then return end
				planted.earned = (planted.earned or 0) - earned
				s.data.cash += earned
				label.Text = "$0"
				floatLabel.Text = "$0"
				sound.PlaybackSpeed = 1 + math.random() * 0.25
				sound:Play()
				burstAt(collect.Position + Vector3.new(0, 1, 0), Color3.fromRGB(120, 235, 130))
				floatingText(collect.Position + Vector3.new(0, 1.5, 0),
					("+%s 💰"):format(Config.fmtNumber(earned)), Color3.fromRGB(140, 235, 140))
				syncAttributes(player)
			end)
		end
	end

	-- STANOWISKO KUPNA GRZĄDKI: zielony pad z ceną na NASTĘPNYM polu siatki
	-- (kupujesz przy grządkach, nie w menu). Drogo — to decyzja, nie klik.
	if s.data.plotsOwned < Config.Base.maxPlotsBuyable then
		local nextIndex = plotCapacity(s) + 1
		local buyX, buyZ = cellXZ(nextIndex)
		local price = math.floor(Config.Base.plotBaseCost
			* Config.Base.plotCostGrowth ^ (s.data.plotsOwned - Config.Base.basePlots))

		local buyPad = Instance.new("Part")
		buyPad.Name = "BuyPlotPad"
		buyPad.Size = Vector3.new(4.6, 0.3, 3.6)
		buyPad.Position = Vector3.new(buyX, pad.Position.Y, buyZ)
		buyPad.Color = Color3.fromRGB(96, 210, 96)
		buyPad.Material = Enum.Material.SmoothPlastic
		buyPad.Anchored = true
		buyPad.CanCollide = false
		buyPad.Parent = area

		local buyGui = Instance.new("SurfaceGui")
		buyGui.Face = Enum.NormalId.Top
		buyGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		buyGui.PixelsPerStud = 40
		buyGui.Parent = buyPad
		local buyLabel = Instance.new("TextLabel")
		buyLabel.Size = UDim2.fromScale(0.92, 0.75)
		buyLabel.Position = UDim2.fromScale(0.5, 0.5)
		buyLabel.AnchorPoint = Vector2.new(0.5, 0.5)
		buyLabel.BackgroundTransparency = 1
		buyLabel.Font = Enum.Font.FredokaOne
		buyLabel.TextScaled = true
		buyLabel.TextColor3 = Color3.new(1, 1, 1)
		buyLabel.Text = "$" .. Config.fmtNumber(price)
		buyLabel.Parent = buyGui
		local buyStroke = Instance.new("UIStroke")
		buyStroke.Thickness = 3
		buyStroke.Color = Color3.fromRGB(20, 60, 30)
		buyStroke.Parent = buyLabel

		local buyPlate = Instance.new("BillboardGui")
		buyPlate.Size = UDim2.new(0, 170, 0, 34)
		buyPlate.StudsOffset = Vector3.new(0, 2.4, 0)
		buyPlate.MaxDistance = 70
		buyPlate.Parent = buyPad
		local buyTitle = Instance.new("TextLabel")
		buyTitle.Size = UDim2.fromScale(1, 1)
		buyTitle.BackgroundTransparency = 1
		buyTitle.Font = Enum.Font.FredokaOne
		buyTitle.TextScaled = true
		buyTitle.TextColor3 = Color3.fromRGB(170, 255, 185)
		buyTitle.TextStrokeTransparency = 0.3
		buyTitle.Text = ("🌱 NOWA GRZĄDKA (%d/%d)"):format(s.data.plotsOwned, Config.Base.maxPlotsBuyable)
		buyTitle.Parent = buyPlate

		local buyPrompt = Instance.new("ProximityPrompt")
		buyPrompt.ActionText = "Kup grządkę"
		buyPrompt.ObjectText = ("%s 💰"):format(Config.fmtNumber(price))
		buyPrompt.HoldDuration = 0.4
		buyPrompt.MaxActivationDistance = 9
		buyPrompt.RequiresLineOfSight = false
		buyPrompt.Parent = buyPad
		buyPrompt.Triggered:Connect(function(who)
			if who == player then
				buyPlot(player)
			end
		end)
	end

	area.Parent = workspace
end

rebuildHook = refreshShelfDisplay

-- kupno grządki (woła stanowisko przy działce; drogie — patrz Config.Base)
buyPlot = function(player: Player)
	local s = sessions[player]
	if not s then return end
	local data = s.data
	if data.plotsOwned >= Config.Base.maxPlotsBuyable then return end
	local price = math.floor(Config.Base.plotBaseCost
		* Config.Base.plotCostGrowth ^ (data.plotsOwned - Config.Base.basePlots))
	if data.cash < price then
		notifyRemote:FireClient(player, ("❌ Grządka kosztuje %s 💰 — za mało kasy."):format(Config.fmtNumber(price)))
		return
	end
	data.cash -= price
	data.plotsOwned += 1
	notifyRemote:FireClient(player, ("🌱 Nowa grządka! (%d/%d)"):format(data.plotsOwned, Config.Base.maxPlotsBuyable))
	refreshShelfDisplay(player)
	syncAttributes(player)
end

-- ============================================================================
-- Losowanie (serce gry — GDD §4)
-- ============================================================================

local function rollRarity(ringIndex: number): number
	local weights = Config.Rings[ringIndex].weights
	local total = 0
	for _, rarity in Config.Rarities do
		total += weights[rarity.id]
	end
	local pick = math.random() * total
	for index, rarity in Config.Rarities do
		pick -= weights[rarity.id]
		if pick <= 0 then
			return index
		end
	end
	return 1
end

-- Od najrzadszej: pierwsza wylosowana wygrywa. 0 = czysty grzyb.
-- Eventy podbijają szanse (Złoty Deszcz ×3, Tęcza otwiera Rainbow 1/150);
-- poziomy (+0,5%/poz.) i rebirthy (+2%/szt.) dają trwałe szczęście.
local function rollMutation(data, chanceMult: number?): number
	local _, petLuck = petBonuses(data)
	local luckMult = EventService.mutationChanceMult()
		* (1 + data.level * Config.XP.luckPerLevel + (data.rebirths or 0) * Config.Rebirth.luckPerRebirth + petLuck)
		* (chanceMult or 1)
	for index = #Config.Mutations, 1, -1 do
		local mutation = Config.Mutations[index]
		local chance = luckMult / mutation.oneIn
		if mutation.id == "Rainbow" and EventService.rainbowActive() then
			chance = 1 / EventService.rainbowOneIn()
		end
		if math.random() < chance then
			return index
		end
	end
	return 0
end

-- ============================================================================
-- Miejscówki grzybowe (spawny per-gracz, w bieżącym świecie gracza)
-- ============================================================================

local function playerFolder(player: Player): Folder
	local name = "Mushrooms_" .. player.UserId
	local folder = workspace:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = workspace
	end
	return folder
end

local spawnNode -- (deklaracja, bo cutNode woła spawnNode i odwrotnie)
local spawnWolf -- (deklaracja: cutNode budzi wilka; definicja w sekcji WYPRAWA)

local function cutNode(player: Player, node: Model, worldIdx: number, ringIndex: number)
	local s = sessions[player]
	if not s then return end

	-- koszyk pełny = NIE ścinasz (grzyb zostaje w lesie) — zmykaj do bazy!
	if #s.carried >= carryCapacity(s) then
		if os.clock() - s.fullToastAt > 1.5 then -- anty-spam przy wbieganiu
			s.fullToastAt = os.clock()
			notifyRemote:FireClient(player, "🧺 Koszyk pełny! Uciekaj z łupem do bazy!")
		end
		return
	end

	-- rozbryzg w kolorze kapelusza w miejscu ścięcia
	local cap = node:FindFirstChild("Cap")
	local cutPosition = cap and cap.Position or nil
	local cutColor = cap and cap.Color or Color3.fromRGB(220, 220, 220)
	local nodeSpecies = node:GetAttribute("SpeciesIdx") -- gatunek wylosowany przy spawnie
	node:Destroy()
	if cutPosition then
		burstAt(cutPosition, cutColor)
	end

	local rarityIdx = rollRarity(ringIndex)

	-- pity: gwarantowany Rzadki+ co N ścięć (GDD §2)
	if rarityIdx >= 3 then
		s.data.pity = 0
	else
		s.data.pity += 1
		if s.data.pity >= Config.Pity.cutsForGuaranteedRare then
			rarityIdx = 3
			s.data.pity = 0
		end
	end

	local world = Config.Worlds[worldIdx]
	local mutationIdx = rollMutation(s.data)
	local mutationIdx2 = 0
	if Config.DoubleMutations.enabled and mutationIdx > 0 then
		mutationIdx2 = rollMutation(s.data, Config.DoubleMutations.secondRollChanceMult)
		if mutationIdx2 == mutationIdx then
			mutationIdx2 = 0 -- ta sama mutacja dwa razy się nie liczy
		end
	end
	local item: Carried = {
		worldIdx = worldIdx,
		speciesIdx = nodeSpecies or math.random(#world.species),
		rarityIdx = rarityIdx,
		mutationIdx = mutationIdx,
		mutationIdx2 = mutationIdx2,
		freshness = Config.Freshness.startPercent,
	}

	-- do koszyka (miejsce sprawdzone na wejściu — bez wypychania)
	table.insert(s.carried, item)
	notifyRemote:FireClient(player, ("🍄 %s  (koszyk %d/%d)"):format(itemLabel(item), #s.carried, carryCapacity(s)))

	-- łup w koszyku = bieg przechodzi w fazę POWROTU (kamera z góry,
	-- gra zawraca gracza do bazy)
	s.runPhase = "return"
	player:SetAttribute("ExpeditionPhase", "return")

	-- ŁUP ŚCIĄGA DRAPIEŻNIKA: od pierwszego ścięcia goni cię wilk świata
	-- (im głębszy pierścień, tym szybszy — patrz Config.Wolves)
	spawnWolf(player, ringIndex)

	-- COMBO: kolejne ścięcie w oknie czasu podbija serię i mnożnik XP
	local now = os.clock()
	if now - s.comboLastAt <= Config.Combo.windowSeconds then
		s.comboCount += 1
	else
		s.comboCount = 1
	end
	s.comboLastAt = now
	local comboMult = math.min(1 + (s.comboCount - 1) * Config.Combo.xpMultPerStack, Config.Combo.maxMult)
	awardXp(player, Config.XP.perCutByRarity[rarityIdx] * comboMult)

	-- kamienie milowe combo sypią kasą (w sekundach dochodu z półek)
	local milestoneSeconds = Config.Combo.milestones[s.comboCount]
	if milestoneSeconds then
		local bonus = math.max(50, math.floor(shelfIncomePerSec(s.data) * milestoneSeconds))
		s.data.cash += bonus
		notifyRemote:FireClient(player, ("🔥 COMBO ×%d! Bonus: %s 💰"):format(s.comboCount, Config.fmtNumber(bonus)))
		if cutPosition then
			floatingText(cutPosition + Vector3.new(0, 2, 0),
				("COMBO ×%d!"):format(s.comboCount), Color3.fromRGB(255, 140, 60))
		end
	end

	-- pływający napis nad miejscem ścięcia, w kolorze rzadkości
	if cutPosition then
		local species = world.species[item.speciesIdx]
		floatingText(cutPosition, species.name, Config.Rarities[item.rarityIdx].color)
	end

	-- rzadkie trafienia ogłaszamy całemu serwerowi (GDD §4): Legendarny+,
	-- mutacja Frost lub rzadsza, każda podwójna mutacja
	-- (osobisty toast wysyła już logika koszyka wyżej)
	if item.rarityIdx >= 5 or item.mutationIdx >= 5 or item.mutationIdx2 > 0 then
		notifyRemote:FireAllClients(("🎉 %s znalazł: %s!"):format(player.DisplayName, itemLabel(item)))
	end

	journalAdd(player, item)
	questProgress(player, "cuts", 1, false)
	if item.rarityIdx >= 3 then
		questProgress(player, "rareCuts", 1, false)
	end
	if ringIndex >= 3 then
		questProgress(player, "deepCut", 1, false)
	end
	if s.tutorialStep == 1 then
		s.tutorialStep = 2
		notifyRemote:FireClient(player, "🎯 Super! Teraz wróć do bazy i odłóż grzyby (E na drewnianym polu).")
	end

	syncAttributes(player)
	-- event „Wysyp": grzyby odrastają szybciej
	task.delay(NODE_RESPAWN_DELAY / EventService.spawnRateMult(), function()
		if sessions[player] then
			spawnNode(player)
		end
	end)
end

spawnNode = function(player: Player)
	local s = sessions[player]
	if not s then return end
	local worldIdx = s.data.currentWorld
	local world = Config.Worlds[worldIdx]
	local rings = ringPartsByWorld[worldIdx]
	-- ważone losowanie pierścienia (blisko wejścia = najgęściej)
	local totalWeight = 0
	for index = 1, #rings do
		totalWeight += NODE_RING_WEIGHTS[index] or 1
	end
	local roll = math.random() * totalWeight
	local ringIndex = #rings
	for index = 1, #rings do
		roll -= NODE_RING_WEIGHTS[index] or 1
		if roll <= 0 then
			ringIndex = index
			break
		end
	end
	local ring = rings[ringIndex]

	local node = Instance.new("Model")
	node.Name = "MushroomNode"

	-- gatunek losowany JUŻ TERAZ (nie przy ścięciu): wygląd = loot,
	-- a jeśli gracz wgrał model gatunku z Blendera — stoi tu ten model
	local speciesIdx = math.random(#world.species)
	node:SetAttribute("SpeciesIdx", speciesIdx)

	-- każdy grzyb wygląda inaczej: kolor z palety świata, losowy rozmiar
	local scale = 0.8 + math.random() * 0.5
	local capColor = world.theme.caps[math.random(#world.theme.caps)]

	local x = ring.Position.X + (math.random() - 0.5) * (ring.Size.X - 10)
	local z = ring.Position.Z + (math.random() - 0.5) * (ring.Size.Z - 10)
	local y = ring.Position.Y + ring.Size.Y / 2

	local cap -- kotwica prompta/rozbryzgu (widoczny kapelusz albo niewidzialny box)
	local template = findTemplate("Grzyby", world.species[speciesIdx].name)
	if template then
		-- MODEL GATUNKU z Blendera zamiast klocków (rozmiar normalizowany:
		-- niezależnie od skali FBX grzyb w lesie ma ~3,4 studa × losowy scale)
		local model = prepareClone(template, scale, 3.4)
		local size = placeClone(model, x, y, z, math.random() * 2 * math.pi)
		model.Parent = node
		-- kolor rozbryzgu = kolor kapelusza modelu (część z "Kapelusz" w nazwie)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") and string.find(part.Name, "Kapelusz", 1, true) then
				capColor = part.Color
				break
			end
		end
		cap = Instance.new("Part")
		cap.Name = "Cap"
		cap.Transparency = 1
		cap.Size = Vector3.new(2, 2, 2) * scale
		cap.Color = capColor
		cap.Anchored = true
		cap.CanCollide = false
		cap.CFrame = CFrame.new(x, y + size.Y * 0.7, z)
		cap.Parent = node
	else
		local stem = Instance.new("Part")
		stem.Name = "Stem"
		stem.Shape = Enum.PartType.Cylinder
		stem.Size = Vector3.new(1.6, 0.8, 0.8) * scale
		stem.Color = Color3.fromRGB(240, 232, 210)
		stem.Material = Enum.Material.SmoothPlastic
		stem.Anchored = true
		stem.CFrame = CFrame.new(x, y + 0.8 * scale, z) * CFrame.Angles(0, 0, math.rad(90))
		stem.Parent = node

		cap = Instance.new("Part")
		cap.Name = "Cap"
		cap.Shape = Enum.PartType.Ball
		cap.Size = Vector3.new(2, 1.4, 2) * scale
		cap.Color = capColor
		cap.Material = Enum.Material.SmoothPlastic
		cap.Anchored = true
		cap.CFrame = CFrame.new(x, y + 1.9 * scale, z)
		cap.Parent = node

		-- białe kropki na kapeluszu (klasyka!)
		for _, offset in { Vector3.new(0.5, 0.45, 0.25), Vector3.new(-0.45, 0.5, -0.3), Vector3.new(0.05, 0.55, 0.5) } do
			local dot = Instance.new("Part")
			dot.Shape = Enum.PartType.Ball
			dot.Size = Vector3.new(0.4, 0.25, 0.4) * scale
			dot.Color = Color3.fromRGB(250, 248, 240)
			dot.Material = Enum.Material.SmoothPlastic
			dot.Anchored = true
			dot.CanCollide = false
			dot.CFrame = CFrame.new(Vector3.new(x, y + 1.9 * scale, z) + offset * scale)
			dot.Parent = node
		end
	end

	-- delikatne iskierki przyciągają wzrok; w głębi (pierścienie 4-5) grzyby świecą
	addSparkle(cap, capColor:Lerp(Color3.new(1, 1, 1), 0.5), 1.5)
	if ringIndex >= 4 then
		local light = Instance.new("PointLight")
		light.Color = capColor
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = cap
	end

	-- ZBIÓR PRZEZ WBIEGNIĘCIE (nowoczesny standard — zero przytrzymywania E):
	-- dotknięcie dowolnej części grzyba przez właściciela = ścięcie
	local cutDone = false
	local function onTouch(hit: BasePart)
		if cutDone then return end
		local who = hit.Parent and Players:GetPlayerFromCharacter(hit.Parent)
		if who ~= player then return end -- skrót prototypowy: swoje grzyby
		cutDone = true
		cutNode(player, node, worldIdx, ringIndex)
		if node.Parent then
			cutDone = false -- koszyk był pełny — grzyb został w lesie
		end
	end
	for _, part in node:GetDescendants() do
		if part:IsA("BasePart") then
			part.Touched:Connect(onTouch)
		end
	end

	-- podpis nad grzybem (dawniej pokazywał go prompt)
	local nameTag = Instance.new("BillboardGui")
	nameTag.Size = UDim2.new(0, 130, 0, 26)
	nameTag.StudsOffset = Vector3.new(0, 2.6 * scale, 0)
	nameTag.MaxDistance = 60
	nameTag.Parent = cap
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.fromScale(1, 1)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.35
	nameLabel.Text = world.species[speciesIdx].name
	nameLabel.Parent = nameTag

	node.Parent = playerFolder(player)
end

local function respawnAllNodes(player: Player)
	playerFolder(player):ClearAllChildren()
	for _ = 1, NODES_PER_PLAYER do
		spawnNode(player)
	end
end

-- ============================================================================
-- Dostawa do bazy (BasePady wszystkich światów)
-- ============================================================================

-- GRZYB JAKO PRZEDMIOT: Tool w plecaku (hotbar 1, 2, 3...) — gracz sam
-- wybiera, w KTÓREJ grządce go zasadzi (wyjmij grzyba i kliknij przy niej)
local plantEquipped -- (deklaracja — Tool.Activated woła to niżej)

local function giveMushroomTool(player: Player, item)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	local rarity = Config.Rarities[item.rarityIdx]
	local species = Config.Worlds[item.worldIdx].species[item.speciesIdx]

	local tool = Instance.new("Tool")
	tool.Name = ("🍄 %s [%s]"):format(species.name, rarity.name)
	tool.ToolTip = "Kliknij przy WOLNEJ grządce, żeby zasadzić"
	tool.CanBeDropped = false
	tool:SetAttribute("Uid", item.uid)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Ball
	handle.Size = Vector3.new(1.3, 1.0, 1.3)
	handle.Color = rarity.color
	handle.Material = (item.mutationIdx > 0 or (item.mutationIdx2 or 0) > 0)
		and Enum.Material.Neon or Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Parent = tool

	tool.Activated:Connect(function()
		plantEquipped(player, tool)
	end)
	tool.Parent = backpack
end

-- odtwarza Toole z zapisanego plecaka (wejście do gry / respawn)
local function rebuildTools(player: Player)
	local s = sessions[player]
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not s or not backpack then return end
	for _, tool in backpack:GetChildren() do
		if tool:GetAttribute("Uid") then
			tool:Destroy()
		end
	end
	for _, item in s.data.inventory do
		giveMushroomTool(player, item)
	end
end

-- powrót z lasu: łup przechodzi do PLECAKA (nie od razu na grządki!)
local function deliver(player: Player)
	local s = sessions[player]
	if not s or #s.carried == 0 then return end

	local moved = 0
	for _, item in s.carried do
		item.earned = 0 -- świeżość zamrożona w plecaku
		s.data.nextUid = (s.data.nextUid or 1)
		item.uid = s.data.nextUid
		s.data.nextUid += 1
		table.insert(s.data.inventory, item)
		giveMushroomTool(player, item)
		moved += 1
	end
	s.carried = {}

	notifyRemote:FireClient(player, ("🎒 +%d 🍄 w plecaku! Wciśnij [1], podejdź do WOLNEJ grządki i kliknij."):format(moved))
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		floatingText(root.Position + Vector3.new(0, 2, 0), ("+%d 🍄"):format(moved), Color3.fromRGB(140, 235, 140))
	end

	questProgress(player, "delivered", moved, false)
	if s.tutorialStep == 2 then
		s.tutorialStep = 3
		notifyRemote:FireClient(player, "🎯 Świetnie! Wciśnij [1] i zasadź grzyba w wybranej grządce, a ulepszenia kupisz u sprzedawcy 🍄.")
	end
	syncAttributes(player)
end

-- sadzenie WYCIĄGNIĘTEGO grzyba w najbliższej WOLNEJ grządce (max 8 studów)
plantEquipped = function(player: Player, tool: Tool)
	local s = sessions[player]
	if not s then return end
	local uid = tool:GetAttribute("Uid")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local itemIdx, item = nil, nil
	for index, candidate in s.data.inventory do
		if candidate.uid == uid then
			itemIdx, item = index, candidate
			break
		end
	end
	if not item then
		tool:Destroy()
		return
	end

	-- najbliższa wolna grządka NA WŁASNYM decku
	local bestSlot, bestDistance = nil, 8
	for slot = 1, plotCapacity(s) do
		if not shelfAt(s.data, slot) then
			local x, z = plotCell(s, slot)
			local distance = (Vector2.new(root.Position.X - x, root.Position.Z - z)).Magnitude
			if distance < bestDistance then
				bestSlot, bestDistance = slot, distance
			end
		end
	end
	if not bestSlot then
		notifyRemote:FireClient(player, "🌱 Podejdź do WOLNEJ grządki na swoim decku!")
		return
	end

	table.remove(s.data.inventory, itemIdx)
	item.slot = bestSlot
	item.earned = 0
	table.insert(s.data.shelf, item)
	tool:Destroy()

	local x, z = plotCell(s, bestSlot)
	burstAt(Vector3.new(x, 3, z), Config.Rarities[item.rarityIdx].color)
	floatingText(Vector3.new(x, 4, z), "🌱 Zasadzono!", Color3.fromRGB(140, 235, 140))
	questProgress(player, "shelfCount", #s.data.shelf, true)
	refreshShelfDisplay(player)
	syncAttributes(player)
end

-- oddawanie grzybów przez WBIEGNIĘCIE na pas dostawy (bez prompta —
-- na szynach powrotu i tak przez niego przebiegasz)
for _, pad in basePads do
	local oldPrompt = pad:FindFirstChildOfClass("ProximityPrompt")
	if oldPrompt then
		oldPrompt:Destroy()
	end
	pad.Touched:Connect(function(hit)
		local who = hit.Parent and Players:GetPlayerFromCharacter(hit.Parent)
		if who then
			deliver(who)
		end
	end)
end

-- ============================================================================
-- Podróże między światami (GDD §5)
-- ============================================================================

local function teleportToBase(player: Player, worldIdx: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		-- ląduj przed WŁASNYM deckiem
		local s = sessions[player]
		local deckOffset = s and (Config.Base.deckCenters[s.plotIndex + 1] or 0) or 0
		root.CFrame = baseReturnCFrames[worldIdx] * CFrame.new(deckOffset, 0, 0)
	end
	-- niska grawitacja Grzyboksiężyca: wyższy skok
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = Config.Worlds[worldIdx].lowGravity and 100 or 50
	end
end

local function travelTo(player: Player, worldIdx: number)
	local s = sessions[player]
	local world = Config.Worlds[worldIdx]
	if not s or not world then return end

	local key = tostring(worldIdx)
	if not s.data.worldsUnlocked[key] then
		if s.data.cash >= world.portalCost then
			s.data.cash -= world.portalCost
			s.data.worldsUnlocked[key] = true
			notifyRemote:FireAllClients(("🌍 %s odblokował świat: %s!"):format(player.DisplayName, world.name))
		else
			notifyRemote:FireClient(player, ('❌ Portal do „%s" kosztuje %s 💰 — za mało kasy.')
				:format(world.name, Config.fmtNumber(world.portalCost)))
			return
		end
	end

	s.data.currentWorld = worldIdx
	teleportToBase(player, worldIdx)
	respawnAllNodes(player)
	refreshShelfDisplay(player)
	notifyRemote:FireClient(player, ("🌍 Witaj w: %s (dochód ×%d)"):format(world.name, world.incomeMult))
	syncAttributes(player)
end

for _, worldFolder in worldsFolder:GetChildren() do
	for _, portalName in { "PortalNext", "PortalPrev" } do
		local portal = worldFolder:FindFirstChild(portalName)
		if portal then
			local target = portal:GetAttribute("TargetWorld")
			portal:FindFirstChildOfClass("ProximityPrompt").Triggered:Connect(function(player)
				travelTo(player, target)
			end)
		end
	end
end

-- ============================================================================
-- Skróty powrotne (GDD §3): kup raz, potem teleport do bazy z każdego użycia
-- ============================================================================

for _, worldFolder in worldsFolder:GetChildren() do
	local shortcuts = worldFolder:FindFirstChild("Shortcuts")
	if not shortcuts then continue end
	for _, portal in shortcuts:GetChildren() do
		local worldIdx = portal:GetAttribute("WorldIndex")
		local ringIndex = portal:GetAttribute("RingIndex")
		local prompt = portal:FindFirstChildOfClass("ProximityPrompt")
		local shortcut = Config.Shortcuts[ringIndex]
		if not (prompt and shortcut) then continue end

		prompt.Triggered:Connect(function(player)
			local s = sessions[player]
			if not s then return end
			local key = worldIdx .. ":" .. ringIndex -- klucze DataStore muszą być stringami

			if s.data.shortcuts[key] then
				teleportToBase(player, worldIdx)
				notifyRemote:FireClient(player, ("⚡ %s! Jesteś w bazie — odłóż grzyby."):format(shortcut.name))
			elseif s.data.cash >= shortcut.cost then
				s.data.cash -= shortcut.cost
				s.data.shortcuts[key] = true
				notifyRemote:FireClient(player, ("✅ Kupiono: %s! Od teraz teleportuje cię do bazy."):format(shortcut.name))
			else
				notifyRemote:FireClient(player, ("❌ %s kosztuje %s 💰 — za mało kasy."):format(shortcut.name, Config.fmtNumber(shortcut.cost)))
			end
			syncAttributes(player)
		end)
	end
end

-- ============================================================================
-- Sprzedaż najsłabszego grzyba z półki (zwalnia slot, daje 60 s jego dochodu)
-- ============================================================================

sellRemote.OnServerEvent:Connect(function(player)
	local s = sessions[player]
	if not s or #s.data.shelf == 0 then return end

	local worstIdx, worstIncome = 1, math.huge
	for index, item in s.data.shelf do
		local income = itemIncome(item, s.data)
		if income < worstIncome then
			worstIdx, worstIncome = index, income
		end
	end

	local value = worstIncome * Config.Base.sellFromShelfMult
	table.remove(s.data.shelf, worstIdx)
	s.data.cash += value
	notifyRemote:FireClient(player, ("💸 Sprzedano najsłabszy grzyb za %s 💰 (slot wolny)."):format(Config.fmtNumber(value)))
	refreshShelfDisplay(player)
	syncAttributes(player)
end)

-- ============================================================================
-- Pety: wykluwanie z jaj (gacha per świat) i zakładanie
-- ============================================================================

-- szczęście jaj z passów (×6 wygrywa z ×3): mnoży wagi od Rzadkiego wzwyż
local function eggLuck(s): number
	return (s.passes.EggLuck6 and 6) or (s.passes.EggLuck3 and 3) or 1
end

local function rollEggRarity(s): number
	local luck = eggLuck(s)
	local lastIndex = #Config.Pets.hatchWeights
	local weights, total = {}, 0
	for index, weight in Config.Pets.hatchWeights do
		-- szczęście podbija Epickiego/Legendarnego, ale NIGDY Sekreta (0,1% na twardo)
		local boosted = index >= Config.Pets.luckAffectsFrom
			and not (Config.Pets.luckSkipsLast and index == lastIndex)
		local adjusted = boosted and weight * luck or weight
		weights[index] = adjusted
		total += adjusted
	end
	local pick = math.random() * total
	for index, weight in weights do
		pick -= weight
		if pick <= 0 then
			return index
		end
	end
	return 1
end

-- jedno losowanie z jaja; false = brak kasy/miejsca (przerywa serię ×3)
local function hatchOnce(player: Player, worldIdx: number, quiet: boolean): boolean
	local s = sessions[player]
	if not s then return false end
	local data = s.data
	local cost = Config.Pets.eggCostByWorld[worldIdx]

	-- jajo działa tylko w ODBLOKOWANYM świecie (gdyby ktoś ominął ściany)
	if worldIdx ~= 1 and not data.worldsUnlocked[tostring(worldIdx)] then
		if not quiet then
			notifyRemote:FireClient(player, "🔒 Najpierw odblokuj ten świat portalem!")
		end
		return false
	end

	if #data.pets >= Config.Pets.maxOwned then
		if not quiet then
			notifyRemote:FireClient(player, "❌ Masz komplet petów! (max " .. Config.Pets.maxOwned .. ")")
		end
		return false
	end
	if data.cash < cost then
		if not quiet then
			notifyRemote:FireClient(player, ("❌ Jajo kosztuje %s 💰 — za mało kasy."):format(Config.fmtNumber(cost)))
		end
		return false
	end
	data.cash -= cost

	local rarityIdx = rollEggRarity(s)
	local petIdx = rarityIdx -- pozycja w puli = rzadkość (patrz GameConfig)
	local pool = Config.Pets.poolsByWorld[worldIdx]
	local petName = pool[petIdx]

	-- auto-usuwanie zaznaczonych dropów (Legendarny nigdy nie jest usuwany)
	if data.autoDelete[worldIdx .. ":" .. petIdx] and rarityIdx < 5 then
		notifyRemote:FireClient(player, ("🗑️ %s wykluty i usunięty automatycznie."):format(petName))
		syncAttributes(player)
		return true
	end

	local equippedCount = 0
	for _, pet in data.pets do
		if pet.eq then equippedCount += 1 end
	end
	local pet = { w = worldIdx, p = petIdx, r = rarityIdx, eq = equippedCount < Config.Pets.maxEquipped }
	table.insert(data.pets, pet)

	hatchRemote:FireClient(player, petName, rarityIdx, pet.eq)
	if rarityIdx == 5 then
		notifyRemote:FireAllClients(("✨🥚✨ %s wykluł SEKRETNEGO peta: %s!!! (1 na 1000)")
			:format(player.DisplayName, petName))
	elseif rarityIdx == 4 then
		notifyRemote:FireAllClients(("🥚 %s wykluł LEGENDARNEGO peta: %s!"):format(player.DisplayName, petName))
	end
	local worldFolder = worldsFolder:FindFirstChild("World" .. worldIdx)
	local egg = worldFolder and worldFolder:FindFirstChild("WorldEgg")
	if egg then
		burstAt(egg.Position, Config.Pets.rarities[rarityIdx].color)
	end
	syncAttributes(player)
	return true
end

-- pass „Otwórz ×3": jedno podejście = trzy losowania (każde płatne osobno)
local function hatchEgg(player: Player, worldIdx: number, quiet: boolean?)
	local s = sessions[player]
	if not s then return end
	local rolls = s.passes.TripleHatch and 3 or 1
	for roll = 1, rolls do
		if not hatchOnce(player, worldIdx, quiet == true or roll > 1) then
			break
		end
	end
end

for _, worldFolder in worldsFolder:GetChildren() do
	local egg = worldFolder:FindFirstChild("WorldEgg")
	if egg then
		local worldIdx = egg:GetAttribute("WorldIndex")
		egg:FindFirstChildOfClass("ProximityPrompt").Triggered:Connect(function(player)
			hatchEgg(player, worldIdx)
		end)
	end
end

equipRemote.OnServerEvent:Connect(function(player, index)
	local s = sessions[player]
	if not s or type(index) ~= "number" then return end
	local pet = s.data.pets[index]
	if not pet then return end

	if pet.eq then
		pet.eq = false
	else
		local equippedCount = 0
		for _, other in s.data.pets do
			if other.eq then equippedCount += 1 end
		end
		if equippedCount >= Config.Pets.maxEquipped then
			notifyRemote:FireClient(player, ("❌ Możesz mieć %d założone pety naraz."):format(Config.Pets.maxEquipped))
			return
		end
		pet.eq = true
	end
	syncAttributes(player)
end)

-- auto-otwieranie (pass): przełącznik; samo otwieranie robi pętla gry
autoHatchRemote.OnServerEvent:Connect(function(player)
	local s = sessions[player]
	if not s then return end
	if not s.passes.AutoHatch then
		notifyRemote:FireClient(player, "🔒 Auto-Otwieranie wymaga Game Passa.")
		return
	end
	s.autoHatch = not s.autoHatch
	s.nextAutoHatchAt = 0
	notifyRemote:FireClient(player, s.autoHatch
		and "🤖 Auto-otwieranie WŁĄCZONE — stań przy jajku."
		or "🤖 Auto-otwieranie wyłączone.")
	syncAttributes(player)
end)

-- zaznaczanie petów do auto-usuwania po wylosowaniu (klik w podglądzie jaja)
autoDeleteRemote.OnServerEvent:Connect(function(player, worldIdx, petIdx, enabled)
	local s = sessions[player]
	if not s or type(worldIdx) ~= "number" or type(petIdx) ~= "number" then return end
	local pool = Config.Pets.poolsByWorld[worldIdx]
	if not pool or petIdx < 1 or petIdx > #pool then return end
	if petIdx >= 5 then
		notifyRemote:FireClient(player, "🔒 SEKRETÓW nie można auto-usuwać.")
		return
	end
	s.data.autoDelete[worldIdx .. ":" .. petIdx] = (enabled == true) and true or nil
	syncAttributes(player)
end)

-- ============================================================================
-- Rebirth: reset postępu za trwały mnożnik dochodu i szczęścia
-- Zeruje: kasę, ulepszenia, półki, skróty, światy. Zostaje: poziom/XP,
-- dziennik, seria dzienna, samouczek.
-- ============================================================================

rebirthRemote.OnServerEvent:Connect(function(player)
	local s = sessions[player]
	if not s then return end
	local data = s.data
	if data.rebirths >= Config.Rebirth.maxRebirths then return end

	local cost = Config.rebirthCost(data.rebirths)
	if data.cash < cost then
		notifyRemote:FireClient(player, ("❌ Rebirth kosztuje %s 💰 — za mało kasy."):format(Config.fmtNumber(cost)))
		return
	end

	data.rebirths += 1
	data.cash = 0
	data.staminaLevel = 0
	data.thermosLevel = 0
	data.plotsOwned = Config.Base.basePlots
	data.shelf = {}
	data.inventory = {}
	data.shortcuts = {}
	data.currentWorld = 1
	data.worldsUnlocked = { ["1"] = true }
	data.pity = 0
	s.carried = {}
	rebuildTools(player) -- czyści grzybowe Toole z hotbara
	s.stamina = staminaMax(data)
	s.exhausted = false
	s.exhaustedUntil = 0
	s.comboCount = 0

	teleportToBase(player, 1)
	respawnAllNodes(player)
	refreshShelfDisplay(player)

	notifyRemote:FireAllClients(("🌀 %s zrobił REBIRTH ×%d! Jego dochód rośnie ×%.1f na stałe!")
		:format(player.DisplayName, data.rebirths, rebirthMult(data)))
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		burstAt(root.Position, Color3.fromRGB(190, 120, 255))
		floatingText(root.Position + Vector3.new(0, 3, 0),
			("REBIRTH ×%d!"):format(data.rebirths), Color3.fromRGB(190, 120, 255))
	end
	syncAttributes(player)
end)

-- ============================================================================
-- Ulepszenia (klient prosi, serwer decyduje)
-- ============================================================================

buyRemote.OnServerEvent:Connect(function(player, upgradeName)
	local s = sessions[player]
	if not s then return end
	local data = s.data

	local totalBefore = data.staminaLevel + data.thermosLevel + data.plotsOwned

	local cost: number? = nil
	if upgradeName == "Stamina" and data.staminaLevel < Config.Stats.Stamina.maxLevel then
		cost = Config.statCost(Config.Stats.Stamina, data.staminaLevel)
		if data.cash >= cost then
			data.cash -= cost
			data.staminaLevel += 1
		end
	elseif upgradeName == "Thermos" and data.thermosLevel < Config.Stats.Thermos.maxLevel then
		cost = Config.statCost(Config.Stats.Thermos, data.thermosLevel)
		if data.cash >= cost then
			data.cash -= cost
			data.thermosLevel += 1
		end
	elseif upgradeName == "Shelf" then
		-- kompatybilność: grządki kupuje się teraz na stanowisku przy działce
		buyPlot(player)
	end

	-- ostatni krok samouczka: pierwszy udany zakup
	if s.tutorialStep == 3 and data.staminaLevel + data.thermosLevel + data.plotsOwned > totalBefore then
		s.tutorialStep = 0
		data.tutorialDone = true
		data.cash += Config.Tutorial.reward
		notifyRemote:FireClient(player, ("🎓 Samouczek ukończony! +%s 💰 — powodzenia, grzybiarzu!")
			:format(Config.fmtNumber(Config.Tutorial.reward)))
	end
	syncAttributes(player)
end)

-- ============================================================================
-- Sprint i kondycja
-- ============================================================================

-- Sprint jest teraz PRZYMUSOWY podczas wyprawy (nie ma przełącznika).
-- Stary klient mógł jeszcze słać Sprint — ignorujemy dla kompatybilności.
sprintRemote.OnServerEvent:Connect(function() end)

local function applySpeed(player: Player)
	local s = sessions[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not s or not humanoid then return end

	if s.expedition == "aiming" or s.expedition == "cutscene" then
		humanoid.WalkSpeed = 0 -- minigra startu albo reveal wilka — stoisz
	elseif s.expedition == "run" then
		local boost = os.clock() < s.launchUntil and s.launchMult or 1
		humanoid.WalkSpeed = Config.Movement.sprintSpeed * boost
	else
		humanoid.WalkSpeed = Config.Movement.walkSpeed
	end
end

-- ============================================================================
-- WYPRAWA — nowa pętla rdzeniowa (redesign):
--   baza → strefa startu (minigra paska = head start) → las: przymusowy
--   sprint, kondycja spala się TYLKO w głąb → ścięcie budzi WILKA → ucieczka
--   do bazy (powrót nie zużywa kondycji) → fanfara łupu albo strata.
-- ============================================================================

local function despawnWolf(s)
	if s.wolf then
		if s.wolf.model then
			s.wolf.model:Destroy()
		end
		s.wolf = nil
	end
end

-- koniec wyprawy w bazie; escaped=true → fanfara zdobyczy (jeśli niesie łup)
local function endExpedition(player: Player, escaped: boolean)
	local s = sessions[player]
	if not s or s.expedition ~= "run" then return end
	s.expedition = "base"
	s.launchCooldownUntil = os.clock() + 4 -- pad startu chwilę odpoczywa
	player:SetAttribute("ExpeditionState", "base")
	if escaped and #s.carried > 0 then
		local labels = {}
		for _, item in s.carried do
			table.insert(labels, itemLabel(item))
		end
		escapeRemote:FireClient(player, table.concat(labels, ", "))
	end
	despawnWolf(s)
	applySpeed(player)
end

-- klockowy wilk (per świat: kolory i nazwa z Config.Wolves) — bez FX-kluczy
-- w nazwach części, żeby FxClient go nie animował (rusza nim serwer)
local function buildWolfModel(worldIdx: number): Model
	local cfg = Config.Wolves.byWorld[worldIdx] or Config.Wolves.byWorld[1]
	local model = Instance.new("Model")
	model.Name = "Wolf"

	local function wolfPart(name: string, size: Vector3, position: Vector3, color: Color3): Part
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = CFrame.new(position)
		part.Color = color
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Parent = model
		return part
	end

	-- przód wilka = -Z (CFrame.lookAt patrzy w -Z)
	local body = wolfPart("Cialo", Vector3.new(1.7, 1.4, 3.4), Vector3.new(0, 1.5, 0), cfg.body)
	wolfPart("Glowa", Vector3.new(1.3, 1.2, 1.2), Vector3.new(0, 2.2, -2.1), cfg.body)
	wolfPart("Pysk", Vector3.new(0.7, 0.55, 0.9), Vector3.new(0, 1.95, -2.9), cfg.accent)
	wolfPart("Ucho1", Vector3.new(0.35, 0.6, 0.22), Vector3.new(-0.4, 2.95, -2.1), cfg.accent)
	wolfPart("Ucho2", Vector3.new(0.35, 0.6, 0.22), Vector3.new(0.4, 2.95, -2.1), cfg.accent)
	local tail = wolfPart("Ogon", Vector3.new(0.5, 0.5, 1.7), Vector3.new(0, 2.1, 2.3), cfg.accent)
	tail.CFrame = tail.CFrame * CFrame.Angles(math.rad(-30), 0, 0)
	for index, offset in {
		Vector3.new(-0.55, 0.55, -1.2), Vector3.new(0.55, 0.55, -1.2),
		Vector3.new(-0.55, 0.55, 1.2), Vector3.new(0.55, 0.55, 1.2),
	} do
		wolfPart("Lapa" .. index, Vector3.new(0.45, 1.1, 0.45), offset, cfg.accent)
	end
	for _, side in { -0.3, 0.3 } do
		local eye = wolfPart("Slepie", Vector3.new(0.22, 0.22, 0.1),
			Vector3.new(side, 2.35, -2.72), cfg.eyes)
		eye.Material = Enum.Material.Neon
	end

	model.PrimaryPart = body
	return model
end

spawnWolf = function(player: Player, ringIndex: number)
	local s = sessions[player]
	if not s or s.wolf then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local worldIdx = s.data.currentWorld
	local cfg = Config.Wolves.byWorld[worldIdx] or Config.Wolves.byWorld[1]
	local speed = Config.Movement.sprintSpeed * (Config.Wolves.speedBase
		+ Config.Wolves.speedPerRing * (ringIndex - 1)
		+ Config.Wolves.speedPerWorld * (worldIdx - 1))

	local model = buildWolfModel(worldIdx)
	-- pojawia się W GŁĘBI lasu, za plecami uciekającego
	local spawnPosition = root.Position + Vector3.new(0, 0, Config.Wolves.spawnGap)
	model:PivotTo(CFrame.lookAt(spawnPosition, Vector3.new(root.Position.X, spawnPosition.Y, root.Position.Z)))
	model.Parent = workspace

	-- CUTSCENKA REVEALU: wilk i gracz stoją, kamera klienta powoli najeżdża;
	-- pościg (i bieg gracza) rusza dopiero po jej końcu
	local sceneSeconds = Config.Wolves.cutsceneSeconds
	s.wolf = { model = model, speed = speed, name = cfg.name,
		frozenUntil = os.clock() + sceneSeconds }
	s.expedition = "cutscene"
	player:SetAttribute("ExpeditionState", "cutscene")
	applySpeed(player)
	wolfSceneRemote:FireClient(player, spawnPosition, cfg.name, sceneSeconds)
	burstAt(spawnPosition + Vector3.new(0, 2, 0), cfg.eyes)

	task.delay(sceneSeconds, function()
		local session = sessions[player]
		if session and session.expedition == "cutscene" then
			session.expedition = "run"
			player:SetAttribute("ExpeditionState", "run")
			applySpeed(player)
			notifyRemote:FireClient(player, ("🐺 %s ruszył! UCIEKAJ DO BAZY!!!"):format(cfg.name))
		end
	end)
end

-- pościg: wilk płynie do gracza co klatkę; dogonienie = strata łupu
RunService.Heartbeat:Connect(function(dt: number)
	for player, s in sessions do
		-- domknięcie biegu w bazie co KLATKĘ (pętla 1 s dawałaby poślizg)
		if s.expedition == "run" then
			local runCharacter = player.Character
			local runRoot = runCharacter and runCharacter:FindFirstChild("HumanoidRootPart")
			if runRoot and runRoot.Position.Z <= 2 then
				endExpedition(player, true)
			end
		end

		local wolf = s.wolf
		if not wolf or not wolf.model then continue end
		if wolf.frozenUntil and os.clock() < wolf.frozenUntil then
			continue -- reveal trwa: wilk jeszcze stoi i straszy
		end
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			despawnWolf(s)
			continue
		end

		local wolfPosition = wolf.model:GetPivot().Position
		local flatWolf = Vector3.new(wolfPosition.X, 0, wolfPosition.Z)
		local flatPlayer = Vector3.new(root.Position.X, 0, root.Position.Z)
		local delta = flatPlayer - flatWolf
		local distance = delta.Magnitude

		if distance <= Config.Wolves.catchDistance then
			s.carried = {}
			notifyRemote:FireClient(player, ("🐺 %s cię dopadł! Łup przepadł..."):format(wolf.name))
			despawnWolf(s)
			s.expedition = "base"
			s.launchCooldownUntil = os.clock() + 4
			player:SetAttribute("ExpeditionState", "base")
			teleportToBase(player, s.data.currentWorld)
			applySpeed(player)
			syncAttributes(player)
			continue
		end

		local step = math.min(wolf.speed * dt, distance)
		local newFlat = flatWolf + delta.Unit * step
		local gallop = math.abs(math.sin(os.clock() * 9)) * 0.4
		wolf.model:PivotTo(CFrame.lookAt(
			Vector3.new(newFlat.X, 1.8 + gallop, newFlat.Z),
			Vector3.new(flatPlayer.X, 1.8, flatPlayer.Z)))
	end
end)

-- minigra startu: gracz staje na LaunchPadzie → oscylator rusza; klient
-- pokazuje TĘ SAMĄ krzywą (wspólny zegar serwera), klik = LaunchStop
local function startAiming(player: Player, worldIdx: number, pad: BasePart)
	local s = sessions[player]
	if not s or s.expedition ~= "base" then return end
	if worldIdx ~= s.data.currentWorld then return end
	if os.clock() < s.launchCooldownUntil then return end -- świeżo po wyprawie

	-- wyśrodkuj gracza na padzie, twarzą PROSTO w las (+Z) — kamera minigry
	-- patrzy wzdłuż LookVectora, więc widok od razu jest na wprost
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local center = Vector3.new(pad.Position.X, pad.Position.Y + 3, pad.Position.Z)
		root.CFrame = CFrame.lookAt(center, center + Vector3.new(0, 0, 30))
		root.AssemblyLinearVelocity = Vector3.zero
	end

	s.expedition = "aiming"
	s.launchStart = workspace:GetServerTimeNow()
	player:SetAttribute("LaunchStart", s.launchStart)
	player:SetAttribute("ExpeditionState", "aiming")
	applySpeed(player)
end

launchRemote.OnServerEvent:Connect(function(player)
	local s = sessions[player]
	if not s or s.expedition ~= "aiming" then return end

	local position = Config.launchPosition(s.launchStart, workspace:GetServerTimeNow())
	local tier, tierIdx = Config.Launch.tiers[#Config.Launch.tiers], #Config.Launch.tiers
	for index, candidate in Config.Launch.tiers do
		if position >= candidate.min then
			tier, tierIdx = candidate, index
			break
		end
	end

	s.launchMult = tier.mult
	s.launchUntil = os.clock() + tier.seconds
	s.expedition = "run"
	s.runPhase = "out"
	s.lastZ = 0
	player:SetAttribute("LaunchTier", tierIdx)
	player:SetAttribute("ExpeditionPhase", "out")
	player:SetAttribute("ExpeditionState", "run")
	notifyRemote:FireClient(player, tier.label)

	-- płomienie startu — im lepszy tier, tym mocniejsze
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 140, 40), Color3.fromRGB(255, 225, 90))
		emitter.LightEmission = 1
		emitter.Rate = 18 + (4 - tierIdx) * 30
		emitter.Lifetime = NumberRange.new(0.3, 0.7)
		emitter.Speed = NumberRange.new(2, 6)
		emitter.SpreadAngle = Vector2.new(40, 40)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35 + (4 - tierIdx) * 0.15),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Parent = root
		Debris:AddItem(emitter, tier.seconds)
	end
	applySpeed(player)
end)

-- przycisk ZAWRÓĆ: przerywa fazę "out" — gra zawraca gracza do bazy
abortRemote.OnServerEvent:Connect(function(player)
	local s = sessions[player]
	if not s or s.expedition ~= "run" or s.runPhase ~= "out" then return end
	s.runPhase = "return"
	player:SetAttribute("ExpeditionPhase", "return")
	notifyRemote:FireClient(player, "↩️ Zawracasz do bazy!")
end)

for _, worldFolder in worldsFolder:GetChildren() do
	local pad = worldFolder:FindFirstChild("LaunchPad")
	if pad then
		local padWorld = pad:GetAttribute("WorldIndex")
		pad.Touched:Connect(function(hit)
			local who = Players:GetPlayerFromCharacter(hit.Parent)
			if who then
				startAiming(who, padWorld, pad)
			end
		end)
	end
end

-- ============================================================================
-- Pętla gry: 1 tyknięcie na sekundę (kondycja, świeżość, dochód, skrzynka)
-- ============================================================================

task.spawn(function()
	while true do
		task.wait(1)
		for player, s in sessions do
			local data = s.data

			-- WYPRAWA: kondycja spala się TYLKO biegnąc W GŁĄB lasu (rosnące z);
			-- powrót jest „za darmo" ze stałą prędkością sprintu. Wyzerowanie
			-- bez łupu = auto-powrót do bazy. Regeneracja: tylko stan "base".
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local inBase = root and root.Position.Z <= 2 -- strefy baz leżą przy z < 0

			if s.expedition == "run" and root then
				-- auto-bieg: faza "out" pali kondycję; wyzerowanie = gra
				-- SAMA zawraca (faza "return" nie kosztuje nic)
				if s.runPhase == "out" and s.stamina > 0 then
					s.stamina = math.max(0, s.stamina - Config.Stats.Stamina.sprintDrainPerSec)
					if s.stamina <= 0 then
						s.runPhase = "return"
						player:SetAttribute("ExpeditionPhase", "return")
						notifyRemote:FireClient(player, #s.carried > 0
							and "😮‍💨 Koniec kondycji! UCIECZKA do bazy!"
							or "😮‍💨 Kondycja wyczerpana — zawracasz z pustymi rękami.")
					end
				end
				if inBase then
					-- dobiegł do bazy = koniec wyprawy (fanfara, jeśli niesie łup)
					endExpedition(player, true)
				end
			elseif s.expedition == "base" then
				if inBase then
					s.stamina = math.min(staminaMax(data), s.stamina + Config.Stats.Stamina.baseRegenPerSec)
				end
				local worldFolder = worldsFolder:FindFirstChild("World" .. data.currentWorld)
				local pad = worldFolder and worldFolder:FindFirstChild("LaunchPad")
				if pad and root then
					if root.Position.Z > 6 then
						-- do lasu wchodzi się WYŁĄCZNIE przez strefę startu
						root.CFrame = CFrame.new(pad.Position + Vector3.new(0, 3, 0))
					elseif math.abs(root.Position.X - pad.Position.X) < pad.Size.X / 2 + 1
						and math.abs(root.Position.Z - pad.Position.Z) < pad.Size.Z / 2 + 0.5 then
						-- stoisz na padzie po cooldownie → minigra rusza sama
						-- (Touched nie odpala się przy ciągłym kontakcie)
						startAiming(player, data.currentWorld, pad)
					end
				end
			end
			if root then
				s.lastZ = root.Position.Z
			end
			applySpeed(player)

			-- świeżość niesionych grzybów (event „Przymrozek" spowalnia psucie)
			local eventDecayMult = EventService.decayMult()
			for _, item in s.carried do
				item.freshness = math.max(0, item.freshness - decayPerSec(data, item) * eventDecayMult)
			end

			-- produkcja grządek: urobek odkłada się na zielonym polu grzyba
			-- (kasa wpada dopiero, gdy właściciel wejdzie na pole i zbierze)
			for index, item in data.shelf do
				item.earned = (item.earned or 0) + itemIncome(item, data)
				-- etykiety padów są kluczowane numerem GRZĄDKI (slot),
				-- nie pozycją w tablicy; wpis to { napis_płaski, napis_unoszący }
				local labels = s.plotLabels[item.slot or index]
				if labels then
					local text = "$" .. Config.fmtNumber(item.earned)
					for _, lbl in labels do
						lbl.Text = text
					end
				end
			end
			if s.baseIncomeLabel and s.baseIncomeLabel.Parent then
				s.baseIncomeLabel.Text = Config.fmtNumber(shelfIncomePerSec(data)) .. "$/s"
			end

			-- skrzynka czasowa (co 20 min online — GDD §7)
			if os.time() >= s.nextChestAt then
				s.nextChestAt = os.time() + Config.Chest.intervalSeconds
				local reward = math.max(
					Config.Chest.minReward,
					math.floor(shelfIncomePerSec(data) * Config.Chest.incomeSeconds)
				)
				data.cash += reward
				notifyRemote:FireClient(player, ("🎁 Skrzynka czasowa: +%s 💰!"):format(Config.fmtNumber(reward)))
			end

			-- combo wygasa po oknie bez ścięcia
			if s.comboCount > 0 and os.clock() - s.comboLastAt > Config.Combo.windowSeconds then
				s.comboCount = 0
			end

			-- auto-otwieranie jaj (pass): działa, gdy stoisz przy jajku
			if s.autoHatch and os.time() >= s.nextAutoHatchAt then
				s.nextAutoHatchAt = os.time() + Config.Pets.autoHatchIntervalSec
				local worldFolder = worldsFolder:FindFirstChild("World" .. data.currentWorld)
				local egg = worldFolder and worldFolder:FindFirstChild("WorldEgg")
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if egg and root and (egg.Position - root.Position).Magnitude <= 18 then
					if data.cash >= Config.Pets.eggCostByWorld[data.currentWorld] then
						hatchEgg(player, data.currentWorld, true)
					else
						s.autoHatch = false
						notifyRemote:FireClient(player, "🤖 Auto-otwieranie wyłączone — brak kasy na jajo.")
					end
				end
			end

			-- nowy dzień = nowe zadania (dla siedzących w grze przez północ UTC)
			ensureDaily(data)

			syncAttributes(player)
		end
	end
end)

-- ============================================================================
-- Wejście / wyjście gracza, offline, autozapis
-- ============================================================================

Players.PlayerAdded:Connect(function(player)
	local data, loadedOk = DataService.load(player.UserId)

	-- zarobek offline (GDD §8): 50% stawki, cap 2 h
	-- (bonus ×2 do wykupienia za Robux — patrz ProcessReceipt niżej)
	local offlineBonus = 0
	if data.lastSeen > 0 then
		local elapsed = math.min(os.time() - data.lastSeen, Config.Offline.capSeconds)
		if elapsed > 0 then
			local earned = shelfIncomePerSec(data) * Config.Offline.incomeFraction * elapsed
			data.cash += earned
			player:SetAttribute("OfflineEarned", math.floor(earned))
			offlineBonus = earned * (Config.DevProducts.OfflineDouble.effect.offlineMultiplier - 1)
		end
	end

	ensureDaily(data)

	-- migracja starych zapisów: grzyby z półki dostają numery grządek
	local usedSlots = {}
	for _, item in data.shelf do
		if item.slot then
			usedSlots[item.slot] = true
		end
	end
	local nextFreeSlot = 1
	for _, item in data.shelf do
		if not item.slot then
			while usedSlots[nextFreeSlot] do
				nextFreeSlot += 1
			end
			item.slot = nextFreeSlot
			usedSlots[nextFreeSlot] = true
		end
	end

	plotCounter += 1
	sessions[player] = {
		data = data,
		loadedOk = loadedOk,
		stamina = staminaMax(data),
		sprinting = false,
		exhausted = false,
		exhaustedUntil = 0,
		carried = {},
		tutorialStep = data.tutorialDone and 0 or 1,
		nextChestAt = os.time() + Config.Chest.intervalSeconds,
		plotIndex = (plotCounter - 1) % 5, -- 5 osobnych baz-decków na serwer
		plotLabels = {},
		pendingOfflineBonus = offlineBonus,
		comboCount = 0,
		comboLastAt = 0,
		passes = {},
		autoHatch = false,
		nextAutoHatchAt = 0,
		expedition = "base",
		runPhase = "out",
		fullToastAt = 0,
		lastZ = 0,
		launchStart = 0,
		launchMult = 1,
		launchUntil = 0,
		launchCooldownUntil = 0,
	}

	loadPasses(player, sessions[player])
	grantDailyStreak(player)

	-- leaderboard Roblox (lista graczy po prawej)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cashValue = Instance.new("IntValue")
	cashValue.Name = "Kasa"
	cashValue.Parent = leaderstats
	leaderstats.Parent = player
	task.spawn(function()
		while sessions[player] do
			cashValue.Value = math.floor(sessions[player].data.cash)
			task.wait(2)
		end
	end)

	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		-- po respawnie wracasz do bazy swojego świata (spawn stoi w Świecie 1)
		if sessions[player] and sessions[player].data.currentWorld > 1 then
			teleportToBase(player, sessions[player].data.currentWorld)
		end
		applySpeed(player)
		rebuildTools(player) -- grzyby z plecaka wracają do hotbara
	end)

	syncAttributes(player)
	respawnAllNodes(player)
	refreshShelfDisplay(player)
end)

Players.PlayerRemoving:Connect(function(player)
	local s = sessions[player]
	if s then
		-- nie nadpisuj danych, jeśli odczyt przy wejściu się nie udał!
		if s.loadedOk then
			DataService.save(player.UserId, s.data)
		end
		sessions[player] = nil
	end
	local folder = workspace:FindFirstChild("Mushrooms_" .. player.UserId)
	if folder then
		folder:Destroy()
	end
	local display = workspace:FindFirstChild("PlotArea_" .. player.UserId)
	if display then
		display:Destroy()
	end
end)

task.spawn(function()
	while true do
		task.wait(AUTOSAVE_INTERVAL)
		for player, s in sessions do
			if s.loadedOk then
				DataService.save(player.UserId, s.data)
			end
		end
	end
end)

game:BindToClose(function()
	for player, s in sessions do
		if s.loadedOk then
			DataService.save(player.UserId, s.data)
		end
	end
end)

-- ============================================================================
-- Zakupy za Robux (Developer Products) — fundament fazy 8
-- Po utworzeniu produktów w Creator Hub wpisz ich ID w GameConfig.DevProducts.
-- ============================================================================

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- gracz wyszedł — Roblox spróbuje ponownie przy następnym wejściu
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local s = sessions[player]
	if not s then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 🌙 Podwójny Zbiór Nocny: dopłata drugiej połowy zarobku offline
	if receiptInfo.ProductId == Config.DevProducts.OfflineDouble.id then
		if s.pendingOfflineBonus > 0 then
			s.data.cash += s.pendingOfflineBonus
			notifyRemote:FireClient(player, ("🌙 Podwójny Zbiór Nocny: +%s 💰!"):format(Config.fmtNumber(s.pendingOfflineBonus)))
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				floatingText(root.Position + Vector3.new(0, 2, 0),
					("+%s 💰"):format(Config.fmtNumber(s.pendingOfflineBonus)), Color3.fromRGB(255, 220, 120))
			end
			s.pendingOfflineBonus = 0
			syncAttributes(player)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	warn("[GameServer] Nieznany ProductId w ProcessReceipt: " .. receiptInfo.ProductId)
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

print("[GameServer] Pick a Shroom wystartował 🍄 (światów: " .. #Config.Worlds .. ")")
