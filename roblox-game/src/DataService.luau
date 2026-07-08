-- DataService: zapis i odczyt postępu gracza (DataStore).
-- Wklej jako ModuleScript do ServerScriptService (nazwa: DataService).
--
-- WAŻNE: żeby DataStore działał w Studio, włącz
-- Game Settings → Security → "Enable Studio Access to API Services"
-- (gra musi być opublikowana: File → Publish to Roblox).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- Zmień nazwę store'a, gdy struktura danych się zmieni niekompatybilnie.
local store = DataStoreService:GetDataStore("PickAShroom_Proto_v1")

local RETRIES = 3

local DataService = {}

function DataService.defaultData()
	return {
		cash = 0,
		staminaLevel = 0,
		thermosLevel = 0,
		shelvesOwned = Config.Base.startShelves,
		-- grzyby na półkach: { {speciesIdx, rarityIdx, mutationIdx, freshness}, ... }
		shelf = {},
		pity = 0,
		lastSeen = 0, -- os.time() ostatniego zapisu (do liczenia zarobku offline)
	}
end

local function key(userId: number): string
	return "player_" .. userId
end

-- Zwraca dane gracza (albo świeży default, gdy gra pierwszy raz).
-- Drugi wynik: czy odczyt na pewno się udał (false = graj ostrożnie, nie nadpisuj!).
function DataService.load(userId: number): (any, boolean)
	for attempt = 1, RETRIES do
		local ok, result = pcall(function()
			return store:GetAsync(key(userId))
		end)
		if ok then
			local data = DataService.defaultData()
			if type(result) == "table" then
				-- przepisz tylko znane pola (odporność na stare wersje zapisu)
				for field, value in result do
					if data[field] ~= nil then
						data[field] = value
					end
				end
			end
			return data, true
		end
		warn(("[DataService] load próba %d/%d nieudana: %s"):format(attempt, RETRIES, tostring(result)))
		task.wait(2 ^ attempt) -- 2s, 4s, 8s
	end
	return DataService.defaultData(), false
end

function DataService.save(userId: number, data: any): boolean
	data.lastSeen = os.time()
	for attempt = 1, RETRIES do
		local ok, err = pcall(function()
			store:SetAsync(key(userId), data)
		end)
		if ok then
			return true
		end
		warn(("[DataService] save próba %d/%d nieudana: %s"):format(attempt, RETRIES, tostring(err)))
		task.wait(2 ^ attempt)
	end
	return false
end

return DataService
