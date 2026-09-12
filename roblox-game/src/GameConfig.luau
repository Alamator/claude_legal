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
		-- pasek to BUDŻET wyprawy: odnawia się TYLKO w bazie — bez tego dałoby
		-- się biegać w nieskończoność metodą „sprint-odpoczynek-sprint"
		baseRegenPerSec = 25,   -- szybka regeneracja w strefie bazy
		fieldRegenPerSec = 0,   -- w lesie: zero (Energetyk = jedyny ratunek)
		exhaustedSeconds = 3,   -- „zadyszka" po wyzerowaniu paska
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

-- ===========================================================================
-- FORMATOWANIE KASY — simy Roblox żyją absurdalnymi sumami (10Qt, 100Sx…),
-- gracze je KOCHAJĄ. Wspólna drabinka sufiksów dla klienta i serwera;
-- ekonomia świadomie puchnie z każdym światem, żeby te liczby osiągać.
-- ===========================================================================

local NUMBER_SUFFIXES = { "K", "M", "B", "T", "Qa", "Qt", "Sx", "Sp", "Oc", "No", "Dc" }

function Config.fmtNumber(n: number): string
	n = math.floor(n)
	if n < 1000 then
		return tostring(n)
	end
	local value = n
	local index = 0
	while value >= 1000 and index < #NUMBER_SUFFIXES do
		value /= 1000
		index += 1
	end
	if value >= 100 then
		return string.format("%d%s", math.floor(value), NUMBER_SUFFIXES[index])
	elseif value >= 10 then
		return string.format("%.1f%s", value, NUMBER_SUFFIXES[index])
	end
	return string.format("%.2f%s", value, NUMBER_SUFFIXES[index])
end

-- ===========================================================================
-- "TEKSTURY" MODELI Z BLENDERA — materiały Roblox po nazwach części.
-- FBX przenosi kolory, a wbudowane materiały silnika (drewno, kamień,
-- szkło, lód, trawa...) dają teksturę powierzchni bez UV-mapowania.
-- Auto-podpięcie (GameServer/ClientMain/MapBuilder) woła Config.materialFor
-- dla każdej części klonowanego modelu. Kolejność ma znaczenie:
-- pierwsza pasująca reguła wygrywa ("Glow" sprawdzane jest wcześniej,
-- osobno — świecące części zawsze dostają Neon).
-- ===========================================================================

local MATERIAL_RULES: { { keys: { string }, material: Enum.Material } } = {
	{ keys = { "Lod", "Szron", "Mroz", "Sopel", "Snieg" }, material = Enum.Material.Ice },
	{ keys = { "Krysztal", "Ametyst", "Rubin", "Szmaragd", "Diament", "Kwarc",
		"Pryzmat", "Gem", "Klejnot", "Geoda", "Obsydian", "Lazur" }, material = Enum.Material.Glass },
	-- "Cesarz" przed regułą traw: złota korona Muchomora Cesarskiego to metal,
	-- reszta "Koron" w modelach to korony drzew (liście)
	{ keys = { "Zloto", "Metal", "Medalion", "Cesarz" }, material = Enum.Material.Foil },
	{ keys = { "Pien", "Drewno", "Galazk", "Konar", "Slup", "Kloda", "Deska",
		"Pniak", "Stragan" }, material = Enum.Material.WoodPlanks },
	{ keys = { "Kamien", "Glaz", "Skal", "Stalagmit", "Monolit", "Meteoryt",
		"Krater", "Podest" }, material = Enum.Material.Slate },
	{ keys = { "Mech", "Traw", "Lisc", "Igliwie", "Korona", "Wyscielenie",
		"Listek", "Paproc" }, material = Enum.Material.Grass },
	{ keys = { "Futro", "Piora", "Pusz", "Welna" }, material = Enum.Material.Fabric },
	{ keys = { "Blot", "Ziemia", "Kaluza", "Bagno" }, material = Enum.Material.Ground },
}

-- Materiał dla części o danej nazwie; nil = zostaw jak w imporcie
-- (SmoothPlastic). Części "*Glow" obsługuje auto-podpięcie osobno (Neon).
function Config.materialFor(partName: string): Enum.Material?
	for _, rule in MATERIAL_RULES do
		for _, key in rule.keys do
			if string.find(partName, key, 1, true) then
				return rule.material
			end
		end
	end
	return nil
end

-- Prędkości poruszania (używane przez serwer — klient ich nie ustawia!)
Config.Movement = {
	walkSpeed = 16,
	sprintSpeed = 26,
	exhaustedSpeed = 9,      -- „wleczenie się" podczas zadyszki
}

-- ===========================================================================
-- KOSZYK — mało miejsc: do bazy niesiesz tylko najlepsze okazy.
-- Ścinasz bez limitu (combo/XP/pity działają), ale koszyk trzyma tylko
-- najcenniejsze: słabszy roll sprzedaje się na miejscu za grosze,
-- lepszy wypycha najsłabszego z koszyka.
-- ===========================================================================

Config.Carry = {
	-- JEDEN grzyb na wyprawę (pass „Głęboki Koszyk" +2). Rdzeń pętli:
	-- wbiegnij → zetnij → UCIEKNIJ przed wilkiem → zasadź → ulepsz → głębiej.
	baseSlots = 1,
}

-- ===========================================================================
-- MINIGRA STARTU WYPRAWY — strefa przed lasem: pionowy pasek (zielony dół →
-- czerwony góra), wskaźnik lata góra-dół (im wyżej, tym szybciej), klik
-- zatrzymuje. Trafienie wyżej = mocniejszy „head start" (bonus prędkości
-- na kilka sekund). Serwer liczy pozycję z tej samej krzywej co klient
-- (wspólny zegar GetServerTimeNow), więc nie da się oszukać.
-- ===========================================================================

Config.Launch = {
	periodSeconds = 1.7,  -- pełny cykl wskaźnika dół→góra→dół
	curveExponent = 1.6,  -- >1 = przy czerwonym wskaźnik lata najszybciej
	tiers = {             -- od najlepszego; min = pozycja wskaźnika [0..1]
		{ min = 0.92, mult = 1.45, seconds = 5, label = "🔥🔥 IDEALNY START!!!", shake = 3 },
		{ min = 0.72, mult = 1.30, seconds = 4, label = "🔥 Świetny start!",     shake = 2 },
		{ min = 0.45, mult = 1.16, seconds = 3, label = "👍 Niezły start!",      shake = 1 },
		{ min = 0,    mult = 1.07, seconds = 2, label = "Start!",                shake = 0 },
	},
}

-- Wspólna krzywa wskaźnika (serwer i klient liczą to samo z czasu serwera).
function Config.launchPosition(startTime: number, now: number): number
	local phase = ((now - startTime) / Config.Launch.periodSeconds) % 2
	local tri = phase < 1 and phase or 2 - phase
	return tri ^ Config.Launch.curveExponent
end

-- ===========================================================================
-- WILK — po ścięciu grzyba budzi się drapieżnik świata i GONI do samej bazy.
-- Prędkość = sprint gracza × (baza + bonus za pierścień ścięcia + świat):
-- pierścień 1 ucieka się spacerkiem, 4–5 to wyścig o życie (skróty ratują!).
-- Dogonienie = powrót do bazy BEZ łupu. Ucieczka = fanfara zdobyczy.
-- ===========================================================================

Config.Wolves = {
	cutsceneSeconds = 2.6, -- reveal wilka: kamera najeżdża, wszyscy stoją
	speedBase = 0.97,      -- × prędkość sprintu gracza
	speedPerRing = 0.02,   -- + za pierścień, w którym ścięto
	speedPerWorld = 0.005, -- + za świat
	spawnGap = 40,         -- pojawia się tyle studów ZA graczem (w głębi)
	catchDistance = 5,     -- bliżej = złapał
	byWorld = {
		{ name = "Wilk Szary",       body = Color3.fromRGB(105, 105, 118), accent = Color3.fromRGB(70, 70, 82),    eyes = Color3.fromRGB(255, 70, 40) },
		{ name = "Wilk Śnieżny",     body = Color3.fromRGB(225, 232, 240), accent = Color3.fromRGB(170, 185, 205), eyes = Color3.fromRGB(80, 190, 255) },
		{ name = "Bagienny Waran",   body = Color3.fromRGB(80, 110, 60),   accent = Color3.fromRGB(52, 76, 40),    eyes = Color3.fromRGB(255, 230, 60) },
		{ name = "Kryształowy Wilk", body = Color3.fromRGB(140, 170, 220), accent = Color3.fromRGB(100, 120, 190), eyes = Color3.fromRGB(200, 240, 255) },
		{ name = "Wilk Pustki",      body = Color3.fromRGB(40, 34, 60),    accent = Color3.fromRGB(24, 20, 40),    eyes = Color3.fromRGB(255, 90, 200) },
	},
}

-- ===========================================================================
-- POZIOMY GRZYBÓW — każdy zasadzony grzyb ulepszasz lvl 1→100.
-- Matematyka: dochód ×1,05/poziom (lvl 100 ≈ ×125), koszt ×1,10/poziom —
-- zwrot ulepszenia wydłuża się z ~60 s (lvl 1) do ~1,5 h (lvl 99→100),
-- więc początek to czysta dopamina, a setka to prestiżowy zlew na kasę.
-- Koszt skaluje się z wartością WŁASNĄ grzyba (bez rebirtha/petów).
-- Grzyb rośnie z poziomem — na lvl 100 jest ~3× większy (OGROMNY).
-- ===========================================================================

Config.MushroomLevels = {
	maxLevel = 100,
	incomeMultPerLevel = 1.05,
	costBaseSeconds = 3,   -- koszt lvl 1→2 = 3 s bazowego dochodu grzyba
	costGrowth = 1.10,
	sizePerLevel = 0.055,  -- skala modelu: lvl 100 ≈ ×6,5 — KOLOS-drzewo,
	                       -- pod którego kapeluszem się przechodzi
}

function Config.mushroomLevelMult(lvl: number?): number
	return Config.MushroomLevels.incomeMultPerLevel ^ ((lvl or 1) - 1)
end

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
	-- kolejność: od najczęstszej do najrzadszej (rollMutation iteruje od końca)
	{ id = "Gold",    name = "Gold",    oneIn = 20,     incomeMult = 3 },
	{ id = "Diamond", name = "Diamond", oneIn = 100,    incomeMult = 8 },
	{ id = "Candy",   name = "Candy",   oneIn = 250,    incomeMult = 15 },
	{ id = "Neon",    name = "Neon",    oneIn = 500,    incomeMult = 25 },
	{ id = "Frost",   name = "Frost",   oneIn = 1_200,  incomeMult = 40 },
	{ id = "Magma",   name = "Magma",   oneIn = 2_500,  incomeMult = 60 },
	{ id = "Glitch",  name = "Glitch",  oneIn = 4_000,  incomeMult = 80 },
	{ id = "Void",    name = "Void",    oneIn = 8_000,  incomeMult = 120 },
	{ id = "Rainbow", name = "Rainbow", oneIn = 10_000, incomeMult = 150 }, -- event Tęcza: 1/150
	{ id = "Galaxy",  name = "Galaxy",  oneIn = 25_000, incomeMult = 400 },
}

-- Podwójne mutacje: WYŁĄCZONE na premierę, włączane jednym `true` na event
-- weekendowy („Weekend Podwójnych Mutacji!"). Druga mutacja losuje się
-- z ułamkiem normalnych szans i musi być inna niż pierwsza; mnożniki się mnożą.
Config.DoubleMutations = {
	enabled = false,
	secondRollChanceMult = 0.25, -- 25% normalnych szans na drugą mutację
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
		-- paleta wizualna (MapBuilder: drzewa/dekoracje; GameServer: kapelusze)
		theme = {
			style = "ball", -- drzewa liściaste (kule)
			trunk = Color3.fromRGB(110, 76, 48),
			canopy = { Color3.fromRGB(88, 160, 66), Color3.fromRGB(122, 190, 80), Color3.fromRGB(160, 200, 70) },
			caps = { Color3.fromRGB(205, 62, 50), Color3.fromRGB(235, 140, 50), Color3.fromRGB(205, 175, 95), Color3.fromRGB(195, 95, 145) },
			accent = Color3.fromRGB(255, 205, 95),
			fireflies = false,
		},
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
		incomeMult = 12,
		freshnessDecayPerSec = 1.6,
		portalCost = 25_000, -- cel: osiągalny po ~2-3 h gry (GDD §8)
		theme = {
			style = "pine", -- świerki (stożki z dysków)
			trunk = Color3.fromRGB(86, 62, 44),
			canopy = { Color3.fromRGB(40, 112, 92), Color3.fromRGB(52, 132, 102) },
			caps = { Color3.fromRGB(152, 82, 42), Color3.fromRGB(92, 62, 38), Color3.fromRGB(192, 152, 62), Color3.fromRGB(122, 132, 142) },
			accent = Color3.fromRGB(140, 220, 255),
			fireflies = false,
		},
		species = {
			{ id = "RydzBorowy",   name = "Rydz Borowy",        baseIncome = 1 },
			{ id = "MaslakSosnowy", name = "Maślak Sosnowy",    baseIncome = 2 },
			{ id = "OpienkaMglista", name = "Opieńka Mglista",  baseIncome = 3 },
			{ id = "Zieleniatka",  name = "Zieleniatka",        baseIncome = 4 },
			{ id = "Szyszkowka",   name = "Szyszkówka",         baseIncome = 6 },
			{ id = "Mroznik",      name = "Mroźnik",            baseIncome = 8 },
			{ id = "Iglowiec",     name = "Igłowiec",           baseIncome = 11 },
			{ id = "Smolak",       name = "Smolak",             baseIncome = 15 },
			{ id = "BorowikKrolewski", name = "Borowik Królewski", baseIncome = 20 },
			{ id = "WidmowyMuchomor", name = "Widmowy Muchomor", baseIncome = 28 },
		},
	},
	{
		id = "Swamp",
		name = "Mokradła",
		incomeMult = 250,
		freshnessDecayPerSec = 2.2,
		portalCost = 3_000_000,
		theme = {
			style = "swamp", -- karłowate drzewa + świecące kałuże
			trunk = Color3.fromRGB(72, 82, 56),
			canopy = { Color3.fromRGB(92, 122, 62), Color3.fromRGB(72, 102, 52) },
			caps = { Color3.fromRGB(92, 202, 162), Color3.fromRGB(142, 222, 92), Color3.fromRGB(62, 162, 202), Color3.fromRGB(182, 122, 222) },
			accent = Color3.fromRGB(120, 255, 200),
			fireflies = true,
		},
		species = {
			{ id = "Blotnik",      name = "Błotnik",            baseIncome = 1 },
			{ id = "Zgnilek",      name = "Zgniłek",            baseIncome = 2 },
			{ id = "TrzesakBagienny", name = "Trzęsak Bagienny", baseIncome = 3 },
			{ id = "Mszarnik",     name = "Mszarnik",           baseIncome = 4 },
			{ id = "BagiennaKurka", name = "Bagienna Kurka",    baseIncome = 6 },
			{ id = "Fosforek",     name = "Fosforek",           baseIncome = 8 },
			{ id = "SwietlikBagienny", name = "Świetlik Bagienny", baseIncome = 11 },
			{ id = "Topielec",     name = "Topielec",           baseIncome = 15 },
			{ id = "Mglak",        name = "Mglak",              baseIncome = 20 },
			{ id = "KrolMokradel", name = "Król Mokradeł",      baseIncome = 28 },
		},
	},
	{
		id = "CrystalCave",
		name = "Kryształowa Grota",
		incomeMult = 6_000,
		freshnessDecayPerSec = 3.0,
		portalCost = 250_000_000,
		theme = {
			style = "crystal", -- świecące kryształy zamiast drzew
			trunk = Color3.fromRGB(70, 70, 90),
			canopy = {},
			caps = { Color3.fromRGB(152, 122, 255), Color3.fromRGB(92, 202, 255), Color3.fromRGB(255, 122, 202), Color3.fromRGB(122, 255, 222) },
			accent = Color3.fromRGB(170, 140, 255),
			fireflies = true, -- świecące drobinki groty
		},
		species = {
			{ id = "Kwarcownik",   name = "Kwarcownik",         baseIncome = 1 },
			{ id = "Grotolaz",     name = "Grotołaz",           baseIncome = 2 },
			{ id = "Echowiec",     name = "Echowiec",           baseIncome = 3 },
			{ id = "Lazuryt",      name = "Lazuryt",            baseIncome = 4 },
			{ id = "Rubinek",      name = "Rubinek",            baseIncome = 6 },
			{ id = "Szmaragdziak", name = "Szmaragdziak",       baseIncome = 8 },
			{ id = "Ametystowka",  name = "Ametystówka",        baseIncome = 11 },
			{ id = "Obsydianka",   name = "Obsydianka",         baseIncome = 15 },
			{ id = "Krysztalak",   name = "Kryształak",         baseIncome = 20 },
			{ id = "DiamentowyKapelusz", name = "Diamentowy Kapelusz", baseIncome = 28 },
		},
	},
	{
		id = "Mushmoon",
		name = "Grzyboksiężyc",
		incomeMult = 200_000,
		freshnessDecayPerSec = 4.0,
		portalCost = 25_000_000_000,
		theme = {
			style = "moon", -- kratery i lewitujące skały
			trunk = Color3.fromRGB(120, 120, 130),
			canopy = {},
			caps = { Color3.fromRGB(122, 255, 122), Color3.fromRGB(122, 202, 255), Color3.fromRGB(232, 232, 255), Color3.fromRGB(255, 122, 255) },
			accent = Color3.fromRGB(150, 255, 180),
			fireflies = true, -- kosmiczny pył
		},
		species = {
			{ id = "Kraterek",     name = "Kraterek",           baseIncome = 1 },
			{ id = "Lunark",       name = "Lunark",             baseIncome = 2 },
			{ id = "Kometka",      name = "Kometka",            baseIncome = 3 },
			{ id = "GwiezdnyPyl",  name = "Gwiezdny Pył",       baseIncome = 4 },
			{ id = "OrbitalnyBorowik", name = "Orbitalny Borowik", baseIncome = 6 },
			{ id = "Plazmiak",     name = "Plazmiak",           baseIncome = 8 },
			{ id = "Nebulon",      name = "Nebulon",            baseIncome = 11 },
			{ id = "Antygrawik",   name = "Antygrawik",         baseIncome = 15 },
			{ id = "Supernowik",   name = "Supernowik",         baseIncome = 20 },
			{ id = "CzarnaDziura", name = "Czarna Dziura",      baseIncome = 28 },
		},
		lowGravity = true, -- dłuższe skoki: JumpPower override po podróży
	},
}

-- ===========================================================================
-- BAZA I ZAKUPY JEDNORAZOWE (GDD §3, §6)
-- ===========================================================================

-- GRZĄDKI: grzyby są ZASADZONE w ziemi na działce gracza. Start: 10 grządek
-- (2 rządki po 5, po 5 na stronę). Dokupowanie PO JEDNEJ do 20 (cena rośnie
-- wykładniczo — nie psuje ekonomii). Game Pass „+5 Grządek" → max 25.
-- Pod każdą grządką zielone pole zlicza urobek; wejście na nie zbiera kasę.
Config.Base = {
	basePlots = 10,
	maxPlotsBuyable = 20,   -- limit dokupowania za kasę
	-- 5 OSOBNYCH baz-decków na serwer (max 5 graczy); środki decków w osi X
	-- względem środka świata. DUŻE odstępy = przestrzeń, nie ścisk.
	-- Kolejność od środka: pierwsi gracze dostają decki bliżej wejścia lasu.
	deckCenters = { 0, -150, 150, -300, 300 },
	-- grządki są DROGIE (decyzja na godziny, nie minuty) i kupuje się je
	-- na FIZYCZNYM stanowisku obok ostatniej grządki, nie w menu
	plotBaseCost = 50_000,
	plotCostGrowth = 2.6,   -- cena = plotBaseCost * growth^(dokupione)
	sellFromShelfMult = 60, -- sprzedaż grzyba z grządki = 60 s jego dochodu
	collectSoundId = "rbxasset://sounds/electronicpingshort.wav",
}

Config.Shortcuts = {
	-- po jednym na pierścień 2-5; returnSeconds = czas powrotu skrótem
	[2] = { name = "Zjeżdżalnia",  cost = 2_000,   returnSeconds = 6 },
	[3] = { name = "Trampolina",   cost = 12_000,  returnSeconds = 8 },
	[4] = { name = "Tyrolka",      cost = 80_000,  returnSeconds = 10 },
	[5] = { name = "Wielka Tyrolka", cost = 500_000, returnSeconds = 12 },
}

-- ===========================================================================
-- POZIOMY GRACZA (XP) — pasek zawsze rośnie, nagroda co poziom,
-- każdy poziom daje stały bonus do szczęścia (progres nigdy nie jest pusty)
-- ===========================================================================

Config.XP = {
	perCutByRarity = { 5, 9, 16, 30, 60, 130, 320 }, -- XP za ścięcie wg rzadkości
	maxLevel = 100,
	cashRewardBase = 60,     -- nagroda za poziom = base × growth^poziom
	cashRewardGrowth = 1.22,
	milestoneEvery = 5,      -- co 5 poziomów nagroda ×milestoneMult
	milestoneMult = 5,
	luckPerLevel = 0.005,    -- +0,5% szansy mutacji za każdy poziom (trwałe!)
}

-- ===========================================================================
-- COMBO — seryjne ścinanie (okno kilku sekund) mnoży XP; kamienie milowe
-- sypią kasą. Rosnący licznik + rosnący pitch dźwięku = pętla uwagi
-- ===========================================================================

Config.Combo = {
	windowSeconds = 4,   -- tyle czasu na kolejne ścięcie, by podbić combo
	xpMultPerStack = 0.1, -- każdy stack = +10% XP
	maxMult = 3,
	-- combo → nagroda w sekundach dochodu z półek (min. 50 kasy)
	milestones = { [10] = 60, [25] = 180, [50] = 600 },
}

-- ===========================================================================
-- PETY — gacha z jaj: każdy świat ma gniazdo z jajem; wyklute pety dają
-- % do dochodu i szczęścia. Silnik kolekcjonowania i (docelowo) monetyzacji.
-- ===========================================================================

Config.Pets = {
	maxEquipped = 3,  -- 4. slot = przyszły Game Pass
	maxOwned = 50,
	eggCostByWorld = { 5_000, 400_000, 50_000_000, 8_000_000_000, 1_500_000_000_000 },
	-- pozycja w puli świata = rzadkość peta (WŁASNA drabinka, nie grzybowa):
	-- głównie lecą dwa pierwsze, Epicki/Legendarny dużo rzadziej,
	-- a SEKRET to twarde 0,1% — passy szczęścia GO NIE RUSZAJĄ
	hatchWeights = { 55, 34, 7.5, 3.4, 0.1 },
	luckAffectsFrom = 3,      -- passy mnożą wagi Epickiego i Legendarnego
	luckSkipsLast = true,     -- ...ale NIGDY Sekreta (zawsze 0,1%)
	autoHatchIntervalSec = 3, -- tempo auto-otwierania (pass)
	incomeBonusByRarity = { 0.08, 0.15, 0.30, 0.55, 1.50 }, -- SEKRET = potwór
	luckBonusByRarity = { 0.03, 0.06, 0.14, 0.25, 0.60 },
	-- rzadkości petów (SEKRET renderowany tęczowym, świecącym fontem w UI)
	rarities = {
		{ id = "Rare",      name = "Rzadki",        color = Color3.fromRGB(80, 140, 255) },
		{ id = "VeryRare",  name = "Bardzo Rzadki", color = Color3.fromRGB(96, 220, 200) },
		{ id = "Epic",      name = "Epicki",        color = Color3.fromRGB(180, 80, 255) },
		{ id = "Legendary", name = "Legendarny",    color = Color3.fromRGB(255, 170, 0) },
		{ id = "Secret",    name = "SEKRET",        color = Color3.fromRGB(255, 90, 200), secret = true },
	},
	poolsByWorld = {
		{ "Grzybek Skoczek", "Ślimak Zamszowy", "Jeżozwierzyk", "Biedronix", "Wiewiór Rudzik" },
		{ "Sowa Mgielna", "Szyszkostwór", "Lisek Borowy", "Mroźny Puszek", "Dzięciołek" },
		{ "Bagienny Glut", "Świetlik Bzyk", "Neonowy Żabol", "Ropuch Królewski", "Mglisty Duszek" },
		{ "Kryształowy Żuk", "Ametystowy Nietoperz", "Gemek", "Grotowy Golem", "Pryzmatek" },
		{ "Kosmiczny Grzybek", "Lunar Puf", "Meteorek", "Gwiezdny Ślimak", "Czarnodziurek" },
	},
}

-- ===========================================================================
-- REBIRTH — zeruje kasę/ulepszenia/światy, daje TRWAŁY mnożnik dochodu
-- i szczęścia. Silnik długiego progresu: „jeszcze jeden reset…"
-- ===========================================================================

Config.Rebirth = {
	baseCost = 50_000,          -- pierwszy rebirth
	costGrowth = 6,             -- każdy kolejny ×6
	incomeBonusPerRebirth = 0.5, -- +50% dochodu za każdy rebirth (na stałe)
	luckPerRebirth = 0.02,      -- +2% szansy mutacji za każdy rebirth
	maxRebirths = 50,
}

function Config.rebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.baseCost * Config.Rebirth.costGrowth ^ rebirths)
end

-- ===========================================================================
-- SERIA DZIENNA (login streak) — dzień 1-7, potem powtarza dzień 7
-- ===========================================================================

Config.Streak = {
	baseRewards = { 150, 300, 600, 1200, 2500, 5000, 10000 },
	levelScale = 0.15, -- nagroda × (1 + poziom × to) — rośnie z graczem
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
		{ id = "Deliver15", text = "Dostarcz 8 grzybów do bazy",     target = 8,  reward = 500, stat = "delivered" },
		{ id = "Deep3",     text = "Zetnij grzyba w pierścieniu 3+", target = 1,  reward = 300, stat = "deepCut" },
		{ id = "Shelf8",    text = "Miej 8 grzybów na grządkach",    target = 8,  reward = 500, stat = "shelfCount" },
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
	ExtraPlots    = { name = "Grzybowa Grządka +5",  priceRobux = 199, id = 0, effect = { extraPlots = 5 } },
	NightOwl      = { name = "Nocny Marek",          priceRobux = 249, id = 0, effect = { offlinePass = true } },
	RingTeleport  = { name = "Teleport do Pierścieni", priceRobux = 249, id = 0, effect = { ringTeleport = true } },
	VIP           = { name = "VIP",                  priceRobux = 449, id = 0, effect = { luckMult = 1.1, chatTag = "VIP" } },
	CarrySlots    = { name = "Głęboki Koszyk +2",    priceRobux = 249, id = 0, effect = { extraCarry = 2 } },
	-- passy jaj/petów
	TripleHatch   = { name = "Otwórz ×3",            priceRobux = 199, id = 0, effect = { tripleHatch = true } },
	AutoHatch     = { name = "Auto-Otwieranie",      priceRobux = 99,  id = 0, effect = { autoHatch = true } },
	EggLuck3      = { name = "Szczęście Jaj ×3",     priceRobux = 199, id = 0, effect = { eggLuck = 3 } },
	EggLuck6      = { name = "Szczęście Jaj ×6",     priceRobux = 499, id = 0, effect = { eggLuck = 6 } },
}

Config.DevProducts = {
	-- „podwój zarobek offline" — kupowane z modala powitalnego (19 Robux)
	OfflineDouble = { name = "Podwójny Zbiór Nocny", priceRobux = 19, id = 0, effect = { offlineMultiplier = 2 } },
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

-- Ile XP potrzeba, żeby wejść z danego poziomu na następny
function Config.xpForLevel(level: number): number
	return math.floor(80 * 1.15 ^ level)
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
