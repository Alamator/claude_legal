--!strict
-- GameConfig: JEDYNE miejsce z liczbami balansu gry „Pick a Shroom".
-- Wklej jako ModuleScript do ReplicatedStorage (nazwa: GameConfig).
-- Logika gry (inne skrypty) tylko CZYTA te wartości — nigdy ich nie duplikuj.
--
-- Użycie w innym skrypcie:
--   local Config = require(game.ReplicatedStorage.GameConfig)
--   print(Config.Rarities.Rare.incomeMult) --> 10

local Config = {}

-- ===========================================================================
-- STATYSTYKI (2 ulepszane wielokrotnie)
-- ===========================================================================

Config.Stats = {
	-- 🏃 Kondycja: dłuższy pasek sprintu = dalej w głąb lasu
	Stamina = {
		baseBar = 100,          -- punkty paska na starcie
		perLevel = 8,           -- +punkty paska za każdy poziom
		maxLevel = 60,
		sprintDrainPerSec = 10, -- zużycie punktów/s podczas sprintu
		returnDrainMult = 0.5,  -- powrót zużywa 50% (otwarte pytanie GDD §12.2)
		regenPerSec = 6,        -- odnawianie, gdy nie sprintujesz
		baseCost = 40,          -- cena poziomu 1
		costGrowth = 1.35,      -- cena = baseCost * costGrowth^poziom
	},
	-- ❄️ Termos: grzyby wolniej tracą świeżość
	Thermos = {
		decayMultPerLevel = 0.975, -- tempo psucia mnożone przez to za każdy poziom
		maxLevel = 40,
		minDecayFraction = 0.30,   -- TWARDE DNO: nigdy poniżej 30% tempa świata
		baseCost = 60,
		costGrowth = 1.35,
	},
}

-- Prędkości poruszania (używane przez serwer — klient ich nie ustawia!)
Config.Movement = {
	walkSpeed = 16,
	sprintSpeed = 26,
	exhaustedSpeed = 9,      -- „wleczenie się" po wyczerpaniu kondycji
	exhaustedRecoverAt = 20, -- tyle punktów paska musi się odnowić, by wstać
}

-- ===========================================================================
-- ŚWIEŻOŚĆ (GDD §4)
-- ===========================================================================

Config.Freshness = {
	startPercent = 100,
	wiltedThreshold = 20,   -- poniżej tego: grzyb „zwiędnięty"
	wiltedValueMult = 0.2,  -- wartość zwiędniętego (w v1 nie przepada nigdy)
	rarityDecayMult = 1.1,  -- każdy stopień rzadkości psuje się o 10% szybciej
}

-- ===========================================================================
-- RZADKOŚCI (GDD §4) — wagi losowania per pierścień są w Config.Rings
-- ===========================================================================

Config.Rarities = {
	-- kolejność = stopień (używany do mnożnika psucia)
	{ id = "Common",    name = "Zwykły",     incomeMult = 1,    color = Color3.fromRGB(180, 180, 180) },
	{ id = "Uncommon",  name = "Niezwykły",  incomeMult = 3,    color = Color3.fromRGB(96, 200, 96) },
	{ id = "Rare",      name = "Rzadki",     incomeMult = 10,   color = Color3.fromRGB(80, 140, 255) },
	{ id = "Epic",      name = "Epicki",     incomeMult = 35,   color = Color3.fromRGB(180, 80, 255) },
	{ id = "Legendary", name = "Legendarny", incomeMult = 120,  color = Color3.fromRGB(255, 170, 0) },
	{ id = "Mythic",    name = "Mityczny",   incomeMult = 500,  color = Color3.fromRGB(255, 60, 60) },
	{ id = "Secret",    name = "Sekretny",   incomeMult = 2500, color = Color3.fromRGB(20, 20, 20) },
}

-- Pity: gwarantowany Rzadki+ co N ścięć (GDD §2)
Config.Pity = { cutsForGuaranteedRare = 15 }

-- ===========================================================================
-- MUTACJE (GDD §4) — chance = 1/x; losowana maks. JEDNA na grzyba
-- ===========================================================================

Config.Mutations = {
	{ id = "Gold",    name = "Gold",    oneIn = 20,    incomeMult = 3 },
	{ id = "Diamond", name = "Diamond", oneIn = 100,   incomeMult = 8 },
	{ id = "Candy",   name = "Candy",   oneIn = 250,   incomeMult = 15 },
	{ id = "Neon",    name = "Neon",    oneIn = 500,   incomeMult = 25 },
	{ id = "Glitch",  name = "Glitch",  oneIn = 2000,  incomeMult = 75 },
	{ id = "Rainbow", name = "Rainbow", oneIn = 10000, incomeMult = 150 },
}

-- ===========================================================================
-- PIERŚCIENIE LASU — wagi rzadkości per pierścień (GDD §4)
-- sprintSecondsFromBase: ile sekund CIĄGŁEGO sprintu od bazy (projekt mapy!)
-- ===========================================================================

Config.Rings = {
	[1] = { sprintSecondsFromBase = 10, weights = { Common = 70,  Uncommon = 24, Rare = 5,  Epic = 0.9, Legendary = 0.1, Mythic = 0,   Secret = 0 } },
	[2] = { sprintSecondsFromBase = 22, weights = { Common = 55,  Uncommon = 30, Rare = 11, Epic = 3,   Legendary = 0.9, Mythic = 0.1, Secret = 0 } },
	[3] = { sprintSecondsFromBase = 38, weights = { Common = 45,  Uncommon = 33, Rare = 15, Epic = 5,   Legendary = 1.8, Mythic = 0.2, Secret = 0 } },
	[4] = { sprintSecondsFromBase = 60, weights = { Common = 37,  Uncommon = 34, Rare = 18, Epic = 7,   Legendary = 3,   Mythic = 0.5, Secret = 0.03 } },
	[5] = { sprintSecondsFromBase = 90, weights = { Common = 30,  Uncommon = 34, Rare = 22, Epic = 9,   Legendary = 4,   Mythic = 0.9, Secret = 0.1 } },
}

-- ===========================================================================
-- ŚWIATY (GDD §5) — v1.0: pełna pula gatunków dla Świata 1;
-- światy 2–5 mają szkic puli (uzupełnimy w fazie produkcji MVP)
-- ===========================================================================

Config.Worlds = {
	{
		id = "Deciduous",
		name = "Las Liściasty",
		incomeMult = 1,
		freshnessDecayPerSec = 1.2, -- % świeżości na sekundę (baza, przed Termosem)
		portalCost = 0,             -- świat startowy
		species = {
			-- baseIncome = kasa/s grzyba Zwykłego, 100% świeżości, bez mutacji
			{ id = "Kurka",       name = "Kurka",              baseIncome = 1 },
			{ id = "Podgrzybek",  name = "Podgrzybek",         baseIncome = 2 },
			{ id = "Maslak",      name = "Maślak Zwyczajny",   baseIncome = 3 },
			{ id = "Kania",       name = "Kania",              baseIncome = 4 },
			{ id = "Gaska",       name = "Gąska Zielona",      baseIncome = 6 },
			{ id = "Rydz",        name = "Rydz Młody",         baseIncome = 8 },
			{ id = "Borowik",     name = "Borowik Szlachetny", baseIncome = 11 },
			{ id = "Kozlarz",     name = "Koźlarz Czerwony",   baseIncome = 15 },
			{ id = "Smardz",      name = "Smardz Złocisty",    baseIncome = 20 },
			{ id = "CesarskiMuchomor", name = "Muchomor Cesarski", baseIncome = 28 },
		},
	},
	{
		id = "Coniferous",
		name = "Bór Iglasty",
		incomeMult = 8,
		freshnessDecayPerSec = 1.6,
		portalCost = 25_000, -- cel: osiągalny po ~2-3 h gry (GDD §8)
		species = {}, -- TODO: 10 gatunków w fazie produkcji
	},
	{
		id = "Swamp",
		name = "Mokradła",
		incomeMult = 50,
		freshnessDecayPerSec = 2.2,
		portalCost = 400_000,
		species = {},
	},
	{
		id = "CrystalCave",
		name = "Kryształowa Grota",
		incomeMult = 300,
		freshnessDecayPerSec = 3.0,
		portalCost = 6_000_000,
		species = {},
	},
	{
		id = "Mushmoon",
		name = "Grzyboksiężyc",
		incomeMult = 2000,
		freshnessDecayPerSec = 4.0,
		portalCost = 90_000_000,
		species = {},
		lowGravity = true, -- dłuższe skoki: JumpPower/gravity override na mapie
	},
}

-- ===========================================================================
-- BAZA I ZAKUPY JEDNORAZOWE (GDD §3, §6)
-- ===========================================================================

Config.Base = {
	startShelves = 4,
	maxShelves = 16,
	shelfBaseCost = 500,
	shelfCostGrowth = 2.2, -- cena = shelfBaseCost * shelfCostGrowth^(kupione)
	sellFromShelfMult = 60, -- sprzedaż z półki = 60 s dochodu jednorazowo
}

Config.Shortcuts = {
	-- po jednym na pierścień 2-5; returnSeconds = czas powrotu skrótem
	[2] = { name = "Zjeżdżalnia",  cost = 2_000,   returnSeconds = 6 },
	[3] = { name = "Trampolina",   cost = 12_000,  returnSeconds = 8 },
	[4] = { name = "Tyrolka",      cost = 80_000,  returnSeconds = 10 },
	[5] = { name = "Wielka Tyrolka", cost = 500_000, returnSeconds = 12 },
}

-- ===========================================================================
-- DZIENNIK GRZYBIARZA (GDD §6) — nagrody za liczbę odkrytych wpisów
-- (wpis = gatunek × rzadkość; mutacje liczone osobno jako odznaki)
-- ===========================================================================

Config.Journal = {
	milestones = {
		{ count = 10, reward = 500 },
		{ count = 25, reward = 2_500 },
		{ count = 50, reward = 15_000 },
		{ count = 70, reward = 50_000 }, -- komplet dla Świata 1
	},
}

-- ===========================================================================
-- DZIENNE ZADANIA + SKRZYNKA CZASOWA (GDD §7)
-- ===========================================================================

Config.Daily = {
	questCount = 3, -- tyle zadań losujemy każdego dnia (UTC)
	templates = {
		{ id = "Cut20",     text = "Zetnij 20 grzybów",             target = 20, reward = 400, stat = "cuts" },
		{ id = "Rare5",     text = "Zetnij 5 Rzadkich lub lepszych", target = 5,  reward = 600, stat = "rareCuts" },
		{ id = "Deliver15", text = "Dostarcz 15 grzybów do bazy",    target = 15, reward = 500, stat = "delivered" },
		{ id = "Deep3",     text = "Zetnij grzyba w pierścieniu 3+", target = 1,  reward = 300, stat = "deepCut" },
		{ id = "Shelf8",    text = "Miej 8 grzybów na półkach",      target = 8,  reward = 500, stat = "shelfCount" },
	},
}

Config.Chest = {
	intervalSeconds = 20 * 60, -- skrzynka za czas online
	minReward = 100,
	incomeSeconds = 120,       -- nagroda = max(minReward, dochód/s × tyle sekund)
}

-- ===========================================================================
-- SAMOUCZEK (onboarding pierwszych 60 sekund — GDD §5 planu MVP)
-- ===========================================================================

Config.Tutorial = {
	reward = 150, -- kasa za ukończenie 3 kroków
}

-- ===========================================================================
-- OFFLINE (GDD §8)
-- ===========================================================================

Config.Offline = {
	incomeFraction = 0.5, -- 50% stawki
	capSeconds = 2 * 3600,
	-- z Game Passem „Nocny Marek":
	passIncomeFraction = 1.0,
	passCapSeconds = 8 * 3600,
}

-- ===========================================================================
-- EVENTY SERWEROWE (GDD §7) — rotacja co intervalMin-intervalMax sekund
-- ===========================================================================

Config.Events = {
	intervalMin = 240,
	intervalMax = 360,
	list = {
		{ id = "GoldenRain",  name = "Złoty Deszcz",    duration = 90,  effect = { mutationChanceMult = 3 } },
		{ id = "Bloom",       name = "Wysyp",           duration = 60,  effect = { spawnRateMult = 3 } },
		{ id = "RainbowSky",  name = "Tęcza nad lasem", duration = 120, effect = { rainbowEnabled = true, rainbowOneIn = 150 } },
		{ id = "Frost",       name = "Przymrozek",      duration = 120, effect = { freshnessDecayMult = 0.5 } },
		{ id = "MeteorRain",  name = "Deszcz meteorów", duration = 90,  effect = { meteorShroom = true }, onlyWorld = "Mushmoon" },
	},
}

-- ===========================================================================
-- MONETYZACJA (GDD §9) — ID uzupełnimy po utworzeniu passów w Creator Hub
-- ===========================================================================

Config.GamePasses = {
	DoubleCash    = { name = "Podwójna Kasa",        priceRobux = 399, id = 0, effect = { incomeMult = 2 } },
	CoolerBox     = { name = "Lodówka Turystyczna",  priceRobux = 299, id = 0, effect = { freshnessDecayMult = 0.8 } },
	ExtraShelves  = { name = "Druga Ściana Półek",   priceRobux = 349, id = 0, effect = { extraShelves = 6 } },
	NightOwl      = { name = "Nocny Marek",          priceRobux = 249, id = 0, effect = { offlinePass = true } },
	RingTeleport  = { name = "Teleport do Pierścieni", priceRobux = 249, id = 0, effect = { ringTeleport = true } },
	VIP           = { name = "VIP",                  priceRobux = 449, id = 0, effect = { luckMult = 1.1, chatTag = "VIP" } },
}

Config.DevProducts = {
	LuckPotion   = { name = "Eliksir Szczęścia", id = 0, effect = { luckMult = 2, durationSec = 1200 } },
	ReturnTotem5 = { name = "Totem Powrotu x5",  id = 0, effect = { returnTotems = 5 } },
	Energy5      = { name = "Energetyk x5",      id = 0, effect = { staminaRefills = 5 } },
	MutationDie  = { name = "Kostka Mutacji",    id = 0, effect = { mutationReroll = 1 } },
	-- paczki kasy (4 progi):
	Cash1 = { name = "Sakiewka",  id = 0, effect = { cash = 5_000 } },
	Cash2 = { name = "Skrzynka",  id = 0, effect = { cash = 30_000 } },
	Cash3 = { name = "Kufer",     id = 0, effect = { cash = 200_000 } },
	Cash4 = { name = "Skarbiec",  id = 0, effect = { cash = 1_500_000 } },
}

-- ===========================================================================
-- FUNKCJE POMOCNICZE (czyste obliczenia na configu — wygodne i testowalne)
-- ===========================================================================

-- Koszt następnego poziomu statystyki
function Config.statCost(stat: { baseCost: number, costGrowth: number }, currentLevel: number): number
	return math.floor(stat.baseCost * stat.costGrowth ^ currentLevel)
end

-- Tempo psucia dla gracza: świat × Termos (z twardym dnem) × pass × rzadkość
function Config.decayPerSec(worldDecay: number, thermosLevel: number, hasCoolerPass: boolean, rarityIndex: number): number
	local thermosMult = math.max(
		Config.Stats.Thermos.decayMultPerLevel ^ thermosLevel,
		Config.Stats.Thermos.minDecayFraction
	)
	local passMult = hasCoolerPass and Config.GamePasses.CoolerBox.effect.freshnessDecayMult or 1
	local rarityMult = Config.Freshness.rarityDecayMult ^ (rarityIndex - 1)
	return worldDecay * thermosMult * passMult * rarityMult
end

-- Dochód grzyba/s na półce (GDD §8)
function Config.shelfIncome(baseIncome: number, rarityMult: number, mutationMult: number, freshnessAtDelivery: number, worldMult: number): number
	local freshness = freshnessAtDelivery / 100
	if freshnessAtDelivery < Config.Freshness.wiltedThreshold then
		freshness = Config.Freshness.wiltedValueMult
	end
	return baseIncome * rarityMult * mutationMult * freshness * worldMult
end

return Config
