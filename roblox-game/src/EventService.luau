-- EventService: rotacja eventów serwerowych (GDD §7) — „musi się dużo dziać".
-- Wklej jako ModuleScript do ServerScriptService (nazwa: EventService).
--
-- Co robi: co 4–6 minut losuje event z GameConfig.Events, ogłasza go wszystkim
-- i przez czas trwania wystawia mnożniki, o które pyta GameServer
-- (szansa mutacji, tempo spawnów, tempo psucia, tryb tęczowy).
-- Stan eventu jest też w atrybutach workspace — stąd czyta go HUD klienta.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))

local EventService = {}

local currentEffect: { [string]: any } = {}

function EventService.mutationChanceMult(): number
	return currentEffect.mutationChanceMult or 1
end

function EventService.spawnRateMult(): number
	return currentEffect.spawnRateMult or 1
end

function EventService.decayMult(): number
	return currentEffect.freshnessDecayMult or 1
end

function EventService.rainbowActive(): boolean
	return currentEffect.rainbowEnabled == true
end

function EventService.rainbowOneIn(): number
	return currentEffect.rainbowOneIn or 150
end

function EventService.init(notifyRemote: RemoteEvent, worldId: string)
	-- pula eventów dostępnych w tym świecie (np. Deszcz meteorów tylko na Grzyboksiężycu)
	local pool = {}
	for _, event in Config.Events.list do
		if event.onlyWorld == nil or event.onlyWorld == worldId then
			table.insert(pool, event)
		end
	end
	if #pool == 0 then
		return
	end

	task.spawn(function()
		while true do
			task.wait(math.random(Config.Events.intervalMin, Config.Events.intervalMax))

			local event = pool[math.random(#pool)]
			currentEffect = event.effect
			workspace:SetAttribute("EventName", event.name)
			workspace:SetAttribute("EventEndsAt", os.time() + event.duration)
			notifyRemote:FireAllClients(("⚡ EVENT: %s! (%d s)"):format(event.name, event.duration))

			task.wait(event.duration)

			currentEffect = {}
			workspace:SetAttribute("EventName", nil)
			workspace:SetAttribute("EventEndsAt", nil)
			notifyRemote:FireAllClients(('⏹️ Event „%s" zakończony.'):format(event.name))
		end
	end)
end

return EventService
