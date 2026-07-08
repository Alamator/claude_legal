-- GameServer: cała logika prototypu — spawny grzybów, ścinanie (losowanie),
-- świeżość, kondycja/sprint, dostawa na półki, dochód, ulepszenia, zapis.
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

local WORLD = Config.Worlds[1] -- prototyp: tylko Las Liściasty
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

-- ============================================================================
-- Stan sesji graczy
-- ============================================================================

type Carried = { speciesIdx: number, rarityIdx: number, mutationIdx: number, freshness: number }

local sessions: { [Player]: {
	data: any,
	loadedOk: boolean,
	stamina: number,
	sprinting: boolean,
	exhausted: boolean,
	carried: { Carried },
} } = {}

local function staminaMax(data): number
	return Config.Stats.Stamina.baseBar + Config.Stats.Stamina.perLevel * data.staminaLevel
end

local function decayPerSec(data, rarityIdx: number): number
	return Config.decayPerSec(WORLD.freshnessDecayPerSec, data.thermosLevel, false, rarityIdx)
end

local function itemIncome(item: Carried): number
	local species = WORLD.species[item.speciesIdx]
	local rarity = Config.Rarities[item.rarityIdx]
	local mutationMult = item.mutationIdx > 0 and Config.Mutations[item.mutationIdx].incomeMult or 1
	return Config.shelfIncome(species.baseIncome, rarity.incomeMult, mutationMult, item.freshness, WORLD.incomeMult)
end

local function shelfIncomePerSec(data): number
	local total = 0
	for _, item in data.shelf do
		total += itemIncome(item)
	end
	return total
end

local function itemLabel(item: Carried): string
	local species = WORLD.species[item.speciesIdx]
	local rarity = Config.Rarities[item.rarityIdx]
	local mutation = item.mutationIdx > 0 and (" [" .. Config.Mutations[item.mutationIdx].name .. "]") or ""
	return ("%s (%s)%s %d%%"):format(species.name, rarity.name, mutation, math.floor(item.freshness))
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

	local lines = {}
	for _, item in s.carried do
		table.insert(lines, itemLabel(item))
	end
	player:SetAttribute("CarriedSummary", table.concat(lines, "\n"))
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
local function rollMutation(): number
	for index = #Config.Mutations, 1, -1 do
		if math.random(Config.Mutations[index].oneIn) == 1 then
			return index
		end
	end
	return 0
end

-- ============================================================================
-- Miejscówki grzybowe (spawny per-gracz)
-- ============================================================================

local ringsFolder = workspace:WaitForChild("Rings")
local ringParts: { Part } = {}
for _, part in ringsFolder:GetChildren() do
	local index = part:GetAttribute("RingIndex")
	if index then
		ringParts[index] = part
	end
end

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

local function cutNode(player: Player, node: Model, ringIndex: number)
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

	local item: Carried = {
		speciesIdx = math.random(#WORLD.species),
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

	syncAttributes(player)
	task.delay(NODE_RESPAWN_DELAY, function()
		if sessions[player] then
			spawnNode(player)
		end
	end)
end

spawnNode = function(player: Player)
	local ringIndex = math.random(1, #ringParts)
	local ring = ringParts[ringIndex]

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
			cutNode(player, node, ringIndex)
		end
	end)

	node.Parent = playerFolder(player)
end

-- ============================================================================
-- Dostawa do bazy (BasePad z MapBuildera)
-- ============================================================================

local basePad = workspace:WaitForChild("BasePad")
local basePrompt = basePad:WaitForChild("ProximityPrompt")

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
	syncAttributes(player)
end

basePrompt.Triggered:Connect(deliver)

-- ============================================================================
-- Ulepszenia (klient prosi, serwer decyduje)
-- ============================================================================

buyRemote.OnServerEvent:Connect(function(player, upgradeName)
	local s = sessions[player]
	if not s then return end
	local data = s.data

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
-- Pętla gry: 1 tyknięcie na sekundę (kondycja, świeżość, dochód)
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

			-- świeżość niesionych grzybów
			for _, item in s.carried do
				item.freshness = math.max(0, item.freshness - decayPerSec(data, item.rarityIdx))
			end

			-- dochód z półek
			data.cash += shelfIncomePerSec(data)

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
			-- (shelfIncomePerSec używa WORLD z zewnątrz — dla świata 1 OK w prototypie)
			data.cash += earned
			player:SetAttribute("OfflineEarned", math.floor(earned))
		end
	end

	sessions[player] = {
		data = data,
		loadedOk = loadedOk,
		stamina = staminaMax(data),
		sprinting = false,
		exhausted = false,
		carried = {},
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
		applySpeed(player)
	end)

	syncAttributes(player)
	for _ = 1, NODES_PER_PLAYER do
		spawnNode(player)
	end
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

print("[GameServer] Prototyp Pick a Shroom wystartował 🍄")
