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

local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))
local DataService = require(ServerScriptService:WaitForChild("DataService"))
local EventService = require(ServerScriptService:WaitForChild("EventService"))

local NODES_PER_PLAYER = 14    -- ile miejscówek grzybowych naraz ma gracz
local NODE_RESPAWN_DELAY = 5   -- sekundy do wyrośnięcia nowej miejscówki
local AUTOSAVE_INTERVAL = 120

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
	freshness: number,
}

local sessions: { [Player]: {
	data: any,
	loadedOk: boolean,
	stamina: number,
	sprinting: boolean,
	exhausted: boolean,
	carried: { Carried },
	tutorialStep: number, -- 1..3 = aktywny krok, 0 = ukończony
	nextChestAt: number,  -- os.time() następnej skrzynki czasowej
	plotIndex: number,    -- miejsce stojaka z półkami w bazie
} } = {}

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

local function itemIncome(item: Carried): number
	local world = Config.Worlds[item.worldIdx or 1]
	local species = world.species[item.speciesIdx]
	local rarity = Config.Rarities[item.rarityIdx]
	local mutationMult = item.mutationIdx > 0 and Config.Mutations[item.mutationIdx].incomeMult or 1
	return Config.shelfIncome(species.baseIncome, rarity.incomeMult, mutationMult, item.freshness, world.incomeMult)
end

local function shelfIncomePerSec(data): number
	local total = 0
	for _, item in data.shelf do
		total += itemIncome(item)
	end
	return total
end

local function itemLabel(item: Carried): string
	local world = Config.Worlds[item.worldIdx or 1]
	local species = world.species[item.speciesIdx]
	local rarity = Config.Rarities[item.rarityIdx]
	local mutation = item.mutationIdx > 0 and (" [" .. Config.Mutations[item.mutationIdx].name .. "]") or ""
	return ("%s (%s)%s %d%%"):format(species.name, rarity.name, mutation, math.floor(item.freshness))
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
	player:SetAttribute("ShelvesOwned", data.shelvesOwned)
	player:SetAttribute("ShelfCount", #data.shelf)
	player:SetAttribute("IncomePerSec", math.floor(shelfIncomePerSec(data)))
	player:SetAttribute("Pity", data.pity)
	player:SetAttribute("WorldName", currentWorld(s).name)
	player:SetAttribute("CurrentWorld", data.currentWorld)

	local lines = {}
	for _, item in s.carried do
		table.insert(lines, itemLabel(item))
	end
	player:SetAttribute("CarriedSummary", table.concat(lines, "\n"))

	player:SetAttribute("TutorialStep", s.tutorialStep)
	player:SetAttribute("ChestIn", math.max(0, s.nextChestAt - os.time()))
	player:SetAttribute("JournalCount", journalCount(data))
	player:SetAttribute("JournalTotal", JOURNAL_TOTAL)
	player:SetAttribute("JournalText", journalText(data))
	player:SetAttribute("QuestsText", questsText(data))
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
	end
	if item.mutationIdx > 0 then
		local mutationId = Config.Mutations[item.mutationIdx].id
		if not data.mutationsSeen[mutationId] then
			data.mutationsSeen[mutationId] = true
			notifyRemote:FireClient(player, ("📖 Nowa mutacja w Dzienniku: %s!"):format(mutationId))
		end
	end
	if newEntry then
		local count = journalCount(data)
		for _, milestone in Config.Journal.milestones do
			if milestone.count == count then
				data.cash += milestone.reward
				notifyRemote:FireAllClients(("📖 %s ma już %d wpisów w Dzienniku Grzybiarza! (+%d 💰)")
					:format(player.DisplayName, count, milestone.reward))
			end
		end
	end
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
				notifyRemote:FireClient(player, ("✅ Zadanie wykonane: %s! Nagroda %d 💰")
					:format(template.text, template.reward))
			end
		end
	end
end

-- ============================================================================
-- Wizualne półki w bazie (GDD §6 — grzyby widoczne dla wszystkich)
-- ============================================================================

local function refreshShelfDisplay(player: Player)
	local s = sessions[player]
	if not s then return end

	local old = workspace:FindFirstChild("ShelfDisplay_" .. player.UserId)
	if old then old:Destroy() end

	local pad = basePads[s.data.currentWorld]
	if not pad then return end

	local origin = pad.Position + Vector3.new(-50 + s.plotIndex * 12, 0, -14)

	local model = Instance.new("Model")
	model.Name = "ShelfDisplay_" .. player.UserId

	local stand = Instance.new("Part")
	stand.Name = "Stand"
	stand.Size = Vector3.new(9, 1, 3)
	stand.CFrame = CFrame.new(origin + Vector3.new(0, 1.5, 0))
	stand.Color = Color3.fromRGB(120, 84, 50)
	stand.Material = Enum.Material.WoodPlanks
	stand.Anchored = true
	stand.Parent = model

	-- tabliczka z nickiem i dochodem
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.new(0, 160, 0, 40)
	tag.StudsOffset = Vector3.new(0, 6, 0)
	tag.AlwaysOnTop = false
	tag.Parent = stand
	local tagLabel = Instance.new("TextLabel")
	tagLabel.Size = UDim2.fromScale(1, 1)
	tagLabel.BackgroundTransparency = 0.4
	tagLabel.BackgroundColor3 = Color3.fromRGB(25, 30, 25)
	tagLabel.TextColor3 = Color3.new(1, 1, 1)
	tagLabel.Font = Enum.Font.FredokaOne
	tagLabel.TextScaled = true
	tagLabel.Text = ("🍄 %s  +%d/s"):format(player.DisplayName, math.floor(shelfIncomePerSec(s.data)))
	tagLabel.Parent = tag

	-- grzyby na stojaku: kolor = rzadkość, mutacje świecą
	for index, item in s.data.shelf do
		local column = (index - 1) % 4
		local row = (index - 1) // 4
		local ball = Instance.new("Part")
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(1.4, 1.4, 1.4)
		ball.CFrame = CFrame.new(origin + Vector3.new(column * 2.2 - 3.3, 2.8 + row * 1.8, 0))
		ball.Color = Config.Rarities[item.rarityIdx].color
		ball.Material = item.mutationIdx > 0 and Enum.Material.Neon or Enum.Material.SmoothPlastic
		ball.Anchored = true
		ball.CanCollide = false
		ball.Parent = model
	end

	model.Parent = workspace
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
-- Eventy podbijają szanse (Złoty Deszcz ×3, Tęcza otwiera Rainbow 1/150).
local function rollMutation(): number
	local eventMult = EventService.mutationChanceMult()
	for index = #Config.Mutations, 1, -1 do
		local mutation = Config.Mutations[index]
		local chance = eventMult / mutation.oneIn
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

local function cutNode(player: Player, node: Model, worldIdx: number, ringIndex: number)
	local s = sessions[player]
	if not s then return end
	node:Destroy()

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
	local item: Carried = {
		worldIdx = worldIdx,
		speciesIdx = math.random(#world.species),
		rarityIdx = rarityIdx,
		mutationIdx = rollMutation(),
		freshness = Config.Freshness.startPercent,
	}
	table.insert(s.carried, item)

	-- rzadkie trafienia ogłaszamy całemu serwerowi (GDD §4)
	if item.rarityIdx >= 5 or item.mutationIdx >= 4 then
		notifyRemote:FireAllClients(("🎉 %s znalazł: %s!"):format(player.DisplayName, itemLabel(item)))
	else
		notifyRemote:FireClient(player, "🍄 " .. itemLabel(item))
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
	local rings = ringPartsByWorld[worldIdx]
	local ringIndex = math.random(1, #rings)
	local ring = rings[ringIndex]

	local node = Instance.new("Model")
	node.Name = "MushroomNode"

	local stem = Instance.new("Part")
	stem.Shape = Enum.PartType.Cylinder
	stem.Size = Vector3.new(1.6, 0.8, 0.8)
	stem.Orientation = Vector3.new(0, 0, 90)
	stem.Color = Color3.fromRGB(235, 225, 200)
	stem.Anchored = true
	stem.Parent = node

	local cap = Instance.new("Part")
	cap.Shape = Enum.PartType.Ball
	cap.Size = Vector3.new(2, 1.4, 2)
	cap.Color = Color3.fromRGB(200, 60, 50)
	cap.Anchored = true
	cap.Parent = node

	local x = ring.Position.X + (math.random() - 0.5) * (ring.Size.X - 10)
	local z = ring.Position.Z + (math.random() - 0.5) * (ring.Size.Z - 10)
	local y = ring.Position.Y + ring.Size.Y / 2
	stem.CFrame = CFrame.new(x, y + 0.8, z)
	cap.CFrame = CFrame.new(x, y + 1.9, z)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Zetnij"
	prompt.ObjectText = "Grzyb (pierścień " .. ringIndex .. ")"
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = cap

	prompt.Triggered:Connect(function(who)
		if who == player then -- skrót prototypowy: tylko właściciel ścina swoje
			cutNode(player, node, worldIdx, ringIndex)
		end
	end)

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

local function deliver(player: Player)
	local s = sessions[player]
	if not s or #s.carried == 0 then return end

	local shelved, sold, soldValue = 0, 0, 0
	for _, item in s.carried do
		if #s.data.shelf < s.data.shelvesOwned then
			table.insert(s.data.shelf, item) -- świeżość zamrożona w chwili dostawy
			shelved += 1
		else
			-- brak miejsca: natychmiastowa sprzedaż (= 60 s dochodu, GDD §6)
			local value = itemIncome(item) * Config.Base.sellFromShelfMult
			s.data.cash += value
			sold += 1
			soldValue += value
		end
	end
	s.carried = {}

	local message = ("📦 Odłożono %d na półki"):format(shelved)
	if sold > 0 then
		message ..= (", sprzedano %d za %d 💰 (brak półek!)"):format(sold, math.floor(soldValue))
	end
	notifyRemote:FireClient(player, message)

	questProgress(player, "delivered", shelved + sold, false)
	questProgress(player, "shelfCount", #s.data.shelf, true)
	if s.tutorialStep == 2 then
		s.tutorialStep = 3
		notifyRemote:FireClient(player, "🎯 Świetnie! Kup teraz pierwsze ulepszenie (panel po lewej).")
	end
	refreshShelfDisplay(player)
	syncAttributes(player)
end

for _, pad in basePads do
	pad:FindFirstChildOfClass("ProximityPrompt").Triggered:Connect(deliver)
end

-- ============================================================================
-- Podróże między światami (GDD §5)
-- ============================================================================

local function teleportToBase(player: Player, worldIdx: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = baseReturnCFrames[worldIdx]
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
			notifyRemote:FireClient(player, ("❌ Portal do „%s" kosztuje %d 💰 — za mało kasy.")
				:format(world.name, world.portalCost))
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
				notifyRemote:FireClient(player, ("❌ %s kosztuje %d 💰 — za mało kasy."):format(shortcut.name, shortcut.cost))
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
		local income = itemIncome(item)
		if income < worstIncome then
			worstIdx, worstIncome = index, income
		end
	end

	local value = worstIncome * Config.Base.sellFromShelfMult
	table.remove(s.data.shelf, worstIdx)
	s.data.cash += value
	notifyRemote:FireClient(player, ("💸 Sprzedano najsłabszy grzyb za %d 💰 (slot wolny)."):format(math.floor(value)))
	refreshShelfDisplay(player)
	syncAttributes(player)
end)

-- ============================================================================
-- Ulepszenia (klient prosi, serwer decyduje)
-- ============================================================================

buyRemote.OnServerEvent:Connect(function(player, upgradeName)
	local s = sessions[player]
	if not s then return end
	local data = s.data

	local totalBefore = data.staminaLevel + data.thermosLevel + data.shelvesOwned

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
	elseif upgradeName == "Shelf" and data.shelvesOwned < Config.Base.maxShelves then
		cost = math.floor(Config.Base.shelfBaseCost * Config.Base.shelfCostGrowth ^ (data.shelvesOwned - Config.Base.startShelves))
		if data.cash >= cost then
			data.cash -= cost
			data.shelvesOwned += 1
		end
	end

	-- ostatni krok samouczka: pierwszy udany zakup
	if s.tutorialStep == 3 and data.staminaLevel + data.thermosLevel + data.shelvesOwned > totalBefore then
		s.tutorialStep = 0
		data.tutorialDone = true
		data.cash += Config.Tutorial.reward
		notifyRemote:FireClient(player, ("🎓 Samouczek ukończony! +%d 💰 — powodzenia, grzybiarzu!")
			:format(Config.Tutorial.reward))
	end
	syncAttributes(player)
end)

-- ============================================================================
-- Sprint i kondycja
-- ============================================================================

sprintRemote.OnServerEvent:Connect(function(player, wantsSprint)
	local s = sessions[player]
	if s then
		s.sprinting = wantsSprint == true
	end
end)

local function applySpeed(player: Player)
	local s = sessions[player]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not s or not humanoid then return end

	if s.exhausted then
		humanoid.WalkSpeed = Config.Movement.exhaustedSpeed
	elseif s.sprinting and s.stamina > 0 then
		humanoid.WalkSpeed = Config.Movement.sprintSpeed
	else
		humanoid.WalkSpeed = Config.Movement.walkSpeed
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

			-- kondycja
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local moving = humanoid and humanoid.MoveDirection.Magnitude > 0.1
			if s.sprinting and moving and not s.exhausted then
				s.stamina = math.max(0, s.stamina - Config.Stats.Stamina.sprintDrainPerSec)
				if s.stamina <= 0 then
					s.exhausted = true
					notifyRemote:FireClient(player, "😮‍💨 Wyczerpanie! Zwalniasz…")
				end
			else
				s.stamina = math.min(staminaMax(data), s.stamina + Config.Stats.Stamina.regenPerSec)
				if s.exhausted and s.stamina >= Config.Movement.exhaustedRecoverAt then
					s.exhausted = false
				end
			end
			applySpeed(player)

			-- świeżość niesionych grzybów (event „Przymrozek" spowalnia psucie)
			local eventDecayMult = EventService.decayMult()
			for _, item in s.carried do
				item.freshness = math.max(0, item.freshness - decayPerSec(data, item) * eventDecayMult)
			end

			-- dochód z półek
			data.cash += shelfIncomePerSec(data)

			-- skrzynka czasowa (co 20 min online — GDD §7)
			if os.time() >= s.nextChestAt then
				s.nextChestAt = os.time() + Config.Chest.intervalSeconds
				local reward = math.max(
					Config.Chest.minReward,
					math.floor(shelfIncomePerSec(data) * Config.Chest.incomeSeconds)
				)
				data.cash += reward
				notifyRemote:FireClient(player, ("🎁 Skrzynka czasowa: +%d 💰!"):format(reward))
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
	if data.lastSeen > 0 then
		local elapsed = math.min(os.time() - data.lastSeen, Config.Offline.capSeconds)
		if elapsed > 0 then
			local earned = shelfIncomePerSec(data) * Config.Offline.incomeFraction * elapsed
			data.cash += earned
			player:SetAttribute("OfflineEarned", math.floor(earned))
		end
	end

	ensureDaily(data)

	plotCounter += 1
	sessions[player] = {
		data = data,
		loadedOk = loadedOk,
		stamina = staminaMax(data),
		sprinting = false,
		exhausted = false,
		carried = {},
		tutorialStep = data.tutorialDone and 0 or 1,
		nextChestAt = os.time() + Config.Chest.intervalSeconds,
		plotIndex = (plotCounter - 1) % 9,
	}

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
	local display = workspace:FindFirstChild("ShelfDisplay_" .. player.UserId)
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

print("[GameServer] Pick a Shroom wystartował 🍄 (światów: " .. #Config.Worlds .. ")")
