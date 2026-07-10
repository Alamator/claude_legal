-- MapBuilder: buduje CAŁĄ prototypową mapę ze skryptu — zero ręcznego modelowania.
-- Wklej jako Script do ServerScriptService (nazwa: MapBuilder).
--
-- Wersja wieloświatowa (szkielet fazy 5): wszystkie światy z GameConfig
-- powstają obok siebie (przesunięte w osi X). Każdy świat ma:
--   * strefę bazy z "BasePad" (odkładanie grzybów) i portalami podróży,
--   * 5 pierścieni lasu z tabliczkami,
--   * świecące portale skrótów powrotnych (pierścienie 2-5).
-- SpawnLocation stoi tylko w Świecie 1 — dalej gracza przenosi GameServer.
--
-- Struktura w workspace (czyta ją GameServer):
--   Worlds/World<i> [attr WorldIndex]
--     ├─ BasePad [attr WorldIndex]
--     ├─ Rings/Ring<k> [attr RingIndex]
--     ├─ Shortcuts/ShortcutPortal<k> [attr WorldIndex, RingIndex]
--     ├─ PortalNext / PortalPrev [attr TargetWorld]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))

local MAP_SCALE = 0.5     -- prototyp jest 2× krótszy niż docelowe dystanse
local MAP_WIDTH = 140     -- szerokość pasów (oś X)
local BASE_LENGTH = 40
local WORLD_SPACING = 400 -- odstęp między światami w osi X

-- kolor podłoża świata (pierścienie ciemnieją w głąb przez Lerp do czerni)
local WORLD_GROUND = {
	Color3.fromRGB(124, 176, 88),  -- Las Liściasty
	Color3.fromRGB(64, 120, 104),  -- Bór Iglasty (mgła, chłód)
	Color3.fromRGB(96, 110, 60),   -- Mokradła
	Color3.fromRGB(96, 110, 160),  -- Kryształowa Grota
	Color3.fromRGB(150, 150, 160), -- Grzyboksiężyc
}

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Anchored = true
	part.Material = Enum.Material.Grass
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function makePrompt(parent: Instance, actionText: string, objectText: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

local function makeSign(parent: Instance, text: string, cframe: CFrame)
	local sign = makePart("Sign", Vector3.new(6, 4, 0.5), cframe, Color3.fromRGB(230, 220, 180), parent)
	sign.Material = Enum.Material.SmoothPlastic
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.Parent = sign
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(40, 40, 40)
	label.Text = text
	label.Parent = gui
end

local worldsFolder = Instance.new("Folder")
worldsFolder.Name = "Worlds"
worldsFolder.Parent = workspace

local sprintSpeed = Config.Movement.sprintSpeed

for worldIdx, worldConfig in Config.Worlds do
	local offsetX = (worldIdx - 1) * WORLD_SPACING
	local ground = WORLD_GROUND[worldIdx] or WORLD_GROUND[#WORLD_GROUND]

	local worldFolder = Instance.new("Folder")
	worldFolder.Name = "World" .. worldIdx
	worldFolder:SetAttribute("WorldIndex", worldIdx)
	worldFolder.Parent = worldsFolder

	-- === Strefa bazy (z = -BASE_LENGTH .. 0) ===
	makePart(
		"BaseZone",
		Vector3.new(MAP_WIDTH, 1, BASE_LENGTH),
		CFrame.new(offsetX, 0.5, -BASE_LENGTH / 2),
		ground:Lerp(Color3.new(1, 1, 1), 0.25),
		worldFolder
	)
	makeSign(worldFolder, worldConfig.name, CFrame.new(offsetX, 3, -BASE_LENGTH + 4))

	if worldIdx == 1 then
		local spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Size = Vector3.new(8, 1, 8)
		spawnLocation.CFrame = CFrame.new(offsetX, 1.1, -BASE_LENGTH + 10)
		spawnLocation.Anchored = true
		spawnLocation.Neutral = true
		spawnLocation.Parent = worldFolder
	end

	local basePad = makePart(
		"BasePad",
		Vector3.new(10, 1.2, 10),
		CFrame.new(offsetX, 1.1, -12),
		Color3.fromRGB(140, 96, 60),
		worldFolder
	)
	basePad.Material = Enum.Material.WoodPlanks
	basePad:SetAttribute("WorldIndex", worldIdx)
	makePrompt(basePad, "Odłóż grzyby", "Półki w bazie")

	-- === Portale podróży między światami ===
	local nextWorld = Config.Worlds[worldIdx + 1]
	if nextWorld then
		local portal = makePart(
			"PortalNext",
			Vector3.new(1, 10, 6),
			CFrame.new(offsetX + MAP_WIDTH / 2 - 8, 5.5, -BASE_LENGTH / 2),
			Color3.fromRGB(180, 120, 255),
			worldFolder
		)
		portal.Material = Enum.Material.Neon
		portal.Transparency = 0.25
		portal:SetAttribute("TargetWorld", worldIdx + 1)
		makePrompt(portal, "Podróż", ("→ %s (odblokowanie: %d 💰)"):format(nextWorld.name, nextWorld.portalCost))
	end
	if worldIdx > 1 then
		local portal = makePart(
			"PortalPrev",
			Vector3.new(1, 10, 6),
			CFrame.new(offsetX - MAP_WIDTH / 2 + 8, 5.5, -BASE_LENGTH / 2),
			Color3.fromRGB(120, 255, 180),
			worldFolder
		)
		portal.Material = Enum.Material.Neon
		portal.Transparency = 0.25
		portal:SetAttribute("TargetWorld", worldIdx - 1)
		makePrompt(portal, "Podróż", ("← %s"):format(Config.Worlds[worldIdx - 1].name))
	end

	-- === Pierścienie lasu (z = 0 .. w głąb) ===
	local ringsFolder = Instance.new("Folder")
	ringsFolder.Name = "Rings"
	ringsFolder.Parent = worldFolder

	local shortcutsFolder = Instance.new("Folder")
	shortcutsFolder.Name = "Shortcuts"
	shortcutsFolder.Parent = worldFolder

	local prevEndZ = 0
	for ringIndex, ringConfig in Config.Rings do
		local endZ = ringConfig.sprintSecondsFromBase * sprintSpeed * MAP_SCALE
		local length = endZ - prevEndZ
		local ring = makePart(
			"Ring" .. ringIndex,
			Vector3.new(MAP_WIDTH, 1, length),
			CFrame.new(offsetX, 0.5, prevEndZ + length / 2),
			ground:Lerp(Color3.new(0, 0, 0), ringIndex * 0.12),
			ringsFolder
		)
		ring:SetAttribute("RingIndex", ringIndex)

		makeSign(worldFolder, "PIERŚCIEŃ " .. ringIndex,
			CFrame.new(offsetX - MAP_WIDTH / 2 + 6, 3, prevEndZ))

		-- świecący portal skrótu powrotnego (GDD §3)
		local shortcutConfig = Config.Shortcuts[ringIndex]
		if shortcutConfig then
			local portal = makePart(
				"ShortcutPortal" .. ringIndex,
				Vector3.new(5, 9, 1),
				CFrame.new(offsetX + MAP_WIDTH / 2 - 12, 5, prevEndZ + 4),
				Color3.fromRGB(110, 190, 255),
				shortcutsFolder
			)
			portal.Material = Enum.Material.Neon
			portal.Transparency = 0.25
			portal:SetAttribute("RingIndex", ringIndex)
			portal:SetAttribute("WorldIndex", worldIdx)
			makePrompt(portal, "Skrót do bazy",
				("%s — %d 💰 (raz)"):format(shortcutConfig.name, shortcutConfig.cost))
		end

		prevEndZ = endZ
	end
end

print(("[MapBuilder] Mapa gotowa: %d światów po %d pierścieni"):format(#Config.Worlds, #Config.Rings))
