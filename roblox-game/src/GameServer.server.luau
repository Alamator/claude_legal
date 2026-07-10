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
local rebirthRemote = makeRemote("Rebirth")     -- klient → serwer: prośba o rebirth

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
	pendingOfflineBonus: number, -- druga połowa zarobku offline (×2 za Robux)
	comboCount: number,   -- aktualna seria ścięć
	comboLastAt: number,  -- os.clock() ostatniego ścięcia
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

-- trwały mnożnik dochodu z rebirthów (GDD: silnik długiego progresu)
local function rebirthMult(data): number
	return 1 + (data.rebirths or 0) * Config.Rebirth.incomeBonusPerRebirth
end

local function itemIncome(item: Carried, data): number
	local world = Config.Worlds[item.worldIdx or 1]
	local species = world.species[item.speciesIdx]
	local rarity = Config.Rarities[item.rarityIdx]
	local mutationMult = item.mutationIdx > 0 and Config.Mutations[item.mutationIdx].incomeMult or 1
	local mutation2Idx = item.mutationIdx2 or 0
	if mutation2Idx > 0 then
		mutationMult *= Config.Mutations[mutation2Idx].incomeMult
	end
	return Config.shelfIncome(species.baseIncome, rarity.incomeMult, mutationMult, item.freshness, world.incomeMult)
		* rebirthMult(data)
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
	return ("%s (%s)%s %d%%"):format(species.name, rarity.name, mutation, math.floor(item.freshness))
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
				notifyRemote:FireAllClients(("📖 %s ma już %d wpisów w Dzienniku Grzybiarza! (+%d 💰)")
					:format(player.DisplayName, count, milestone.reward))
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

		notifyRemote:FireClient(player, ("⬆️ POZIOM %d! Nagroda: %d 💰%s"):format(
			data.level, math.floor(reward),
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
	notifyRemote:FireClient(player, ("🔥 Seria dzienna: dzień %d — +%d 💰! Wróć jutro po więcej.")
		:format(data.streakDay, reward))
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

	-- najlepszy okaz dostaje piedestał i iskierki (flex!)
	local bestIdx, bestIncome = 0, -1
	for index, item in s.data.shelf do
		local income = itemIncome(item, s.data)
		if income > bestIncome then
			bestIdx, bestIncome = index, income
		end
	end

	-- grzyby na stojaku jako mini-grzybki: kapelusz = kolor rzadkości, mutacje świecą
	for index, item in s.data.shelf do
		local column = (index - 1) % 4
		local row = (index - 1) // 4
		local isBest = index == bestIdx
		local scale = isBest and 1.5 or 1
		local position = origin + Vector3.new(column * 2.2 - 3.3, 2.5 + row * 2, 0)

		local miniStem = Instance.new("Part")
		miniStem.Shape = Enum.PartType.Cylinder
		miniStem.Size = Vector3.new(0.9, 0.45, 0.45) * scale
		miniStem.Color = Color3.fromRGB(240, 232, 210)
		miniStem.Material = Enum.Material.SmoothPlastic
		miniStem.Anchored = true
		miniStem.CanCollide = false
		miniStem.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
		miniStem.Parent = model

		local miniCap = Instance.new("Part")
		miniCap.Shape = Enum.PartType.Ball
		miniCap.Size = Vector3.new(1.3, 0.9, 1.3) * scale
		miniCap.Color = Config.Rarities[item.rarityIdx].color
		miniCap.Material = (item.mutationIdx > 0 or (item.mutationIdx2 or 0) > 0)
			and Enum.Material.Neon or Enum.Material.SmoothPlastic
		miniCap.Anchored = true
		miniCap.CanCollide = false
		miniCap.CFrame = CFrame.new(position + Vector3.new(0, 0.55 * scale, 0))
		miniCap.Parent = model

		if isBest and bestIncome > 0 then
			addSparkle(miniCap, Color3.fromRGB(255, 220, 120), 3)
		end
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
-- Eventy podbijają szanse (Złoty Deszcz ×3, Tęcza otwiera Rainbow 1/150);
-- poziomy (+0,5%/poz.) i rebirthy (+2%/szt.) dają trwałe szczęście.
local function rollMutation(data, chanceMult: number?): number
	local luckMult = EventService.mutationChanceMult()
		* (1 + data.level * Config.XP.luckPerLevel + (data.rebirths or 0) * Config.Rebirth.luckPerRebirth)
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

local function cutNode(player: Player, node: Model, worldIdx: number, ringIndex: number)
	local s = sessions[player]
	if not s then return end

	-- rozbryzg w kolorze kapelusza w miejscu ścięcia
	local cap = node:FindFirstChild("Cap")
	local cutPosition = cap and cap.Position or nil
	local cutColor = cap and cap.Color or Color3.fromRGB(220, 220, 220)
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
		speciesIdx = math.random(#world.species),
		rarityIdx = rarityIdx,
		mutationIdx = mutationIdx,
		mutationIdx2 = mutationIdx2,
		freshness = Config.Freshness.startPercent,
	}
	table.insert(s.carried, item)

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
		notifyRemote:FireClient(player, ("🔥 COMBO ×%d! Bonus: %d 💰"):format(s.comboCount, bonus))
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

	-- rzadkie trafienia ogłaszamy całemu serwerowi (GDD §4)
	-- podwójna mutacja to zawsze widowisko — ogłaszamy każdą
	if item.rarityIdx >= 5 or item.mutationIdx >= 4 or item.mutationIdx2 > 0 then
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
	local world = Config.Worlds[worldIdx]
	local rings = ringPartsByWorld[worldIdx]
	local ringIndex = math.random(1, #rings)
	local ring = rings[ringIndex]

	local node = Instance.new("Model")
	node.Name = "MushroomNode"

	-- każdy grzyb wygląda inaczej: kolor z palety świata, losowy rozmiar
	local scale = 0.8 + math.random() * 0.5
	local capColor = world.theme.caps[math.random(#world.theme.caps)]

	local x = ring.Position.X + (math.random() - 0.5) * (ring.Size.X - 10)
	local z = ring.Position.Z + (math.random() - 0.5) * (ring.Size.Z - 10)
	local y = ring.Position.Y + ring.Size.Y / 2

	local stem = Instance.new("Part")
	stem.Name = "Stem"
	stem.Shape = Enum.PartType.Cylinder
	stem.Size = Vector3.new(1.6, 0.8, 0.8) * scale
	stem.Color = Color3.fromRGB(240, 232, 210)
	stem.Material = Enum.Material.SmoothPlastic
	stem.Anchored = true
	stem.CFrame = CFrame.new(x, y + 0.8 * scale, z) * CFrame.Angles(0, 0, math.rad(90))
	stem.Parent = node

	local cap = Instance.new("Part")
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

	-- delikatne iskierki przyciągają wzrok; w głębi (pierścienie 4-5) grzyby świecą
	addSparkle(cap, capColor:Lerp(Color3.new(1, 1, 1), 0.5), 1.5)
	if ringIndex >= 4 then
		local light = Instance.new("PointLight")
		light.Color = capColor
		light.Range = 8
		light.Brightness = 1.2
		light.Parent = cap
	end

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
			local value = itemIncome(item, s.data) * Config.Base.sellFromShelfMult
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

	-- wyskakująca nagroda nad graczem
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root then
		local rewardText = sold > 0
			and ("+%d 🍄  +%d 💰"):format(shelved, math.floor(soldValue))
			or ("+%d 🍄"):format(shelved)
		floatingText(root.Position + Vector3.new(0, 2, 0), rewardText, Color3.fromRGB(140, 235, 140))
	end

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
		local income = itemIncome(item, s.data)
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
		notifyRemote:FireClient(player, ("❌ Rebirth kosztuje %d 💰 — za mało kasy."):format(cost))
		return
	end

	data.rebirths += 1
	data.cash = 0
	data.staminaLevel = 0
	data.thermosLevel = 0
	data.shelvesOwned = Config.Base.startShelves
	data.shelf = {}
	data.shortcuts = {}
	data.currentWorld = 1
	data.worldsUnlocked = { ["1"] = true }
	data.pity = 0
	s.carried = {}
	s.stamina = staminaMax(data)
	s.exhausted = false
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

			-- combo wygasa po oknie bez ścięcia
			if s.comboCount > 0 and os.clock() - s.comboLastAt > Config.Combo.windowSeconds then
				s.comboCount = 0
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
		pendingOfflineBonus = offlineBonus,
		comboCount = 0,
		comboLastAt = 0,
	}

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
			notifyRemote:FireClient(player, ("🌙 Podwójny Zbiór Nocny: +%d 💰!"):format(math.floor(s.pendingOfflineBonus)))
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				floatingText(root.Position + Vector3.new(0, 2, 0),
					("+%d 💰"):format(math.floor(s.pendingOfflineBonus)), Color3.fromRGB(255, 220, 120))
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
