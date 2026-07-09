-- MapBuilder: buduje CAŁĄ prototypową mapę ze skryptu — zero ręcznego modelowania.
-- Wklej jako Script do ServerScriptService (nazwa: MapBuilder).
--
-- Co powstaje:
--   * strefa bazy (zielony pas) ze SpawnLocation i "BasePad" (odkładanie grzybów)
--   * 5 pierścieni lasu (coraz ciemniejsze pasy) — długości wyliczone z GameConfig
--
-- To jest mapa-atrapa z fazy 4 planu: brzydka, ale o właściwych proporcjach.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))

-- Prototypowa mapa jest skrócona względem docelowej, żeby testy nie męczyły.
-- Przy strojeniu docelowych dystansów podnieś do 1.0.
local MAP_SCALE = 0.5

local MAP_WIDTH = 140 -- szerokość pasów (oś X)
local BASE_LENGTH = 40

-- kolory pierścieni: od jasnej polany po ciemną głuszę
local RING_COLORS = {
	Color3.fromRGB(124, 176, 88),
	Color3.fromRGB(96, 152, 74),
	Color3.fromRGB(72, 128, 64),
	Color3.fromRGB(52, 100, 54),
	Color3.fromRGB(34, 72, 44),
}

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Anchored = true
	part.Material = Enum.Material.Grass
	part.TopSurface = Enum.SurfaceType.Smooth
	part.Parent = workspace
	return part
end

-- === Strefa bazy (z = -BASE_LENGTH .. 0) ===
makePart(
	"BaseZone",
	Vector3.new(MAP_WIDTH, 1, BASE_LENGTH),
	CFrame.new(0, 0.5, -BASE_LENGTH / 2),
	Color3.fromRGB(170, 210, 120)
)

local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Size = Vector3.new(8, 1, 8)
spawnLocation.CFrame = CFrame.new(0, 1.1, -BASE_LENGTH + 10)
spawnLocation.Anchored = true
spawnLocation.Neutral = true
spawnLocation.Parent = workspace

-- BasePad: tu gracz odkłada grzyby na półki (ProximityPrompt obsługuje GameServer)
local basePad = makePart(
	"BasePad",
	Vector3.new(10, 1.2, 10),
	CFrame.new(0, 1.1, -12),
	Color3.fromRGB(140, 96, 60)
)
basePad.Material = Enum.Material.WoodPlanks

local padPrompt = Instance.new("ProximityPrompt")
padPrompt.ActionText = "Odłóż grzyby"
padPrompt.ObjectText = "Półki w bazie"
padPrompt.HoldDuration = 0.4
padPrompt.MaxActivationDistance = 12
padPrompt.RequiresLineOfSight = false
padPrompt.Parent = basePad

-- === Pierścienie lasu (z = 0 .. w głąb) ===
local ringsFolder = Instance.new("Folder")
ringsFolder.Name = "Rings"
ringsFolder.Parent = workspace

local shortcutsFolder = Instance.new("Folder")
shortcutsFolder.Name = "Shortcuts"
shortcutsFolder.Parent = workspace

local sprintSpeed = Config.Movement.sprintSpeed
local prevEndZ = 0

for ringIndex, ringConfig in Config.Rings do
	local endZ = ringConfig.sprintSecondsFromBase * sprintSpeed * MAP_SCALE
	local length = endZ - prevEndZ
	local ring = makePart(
		"Ring" .. ringIndex,
		Vector3.new(MAP_WIDTH, 1, length),
		CFrame.new(0, 0.5, prevEndZ + length / 2),
		RING_COLORS[ringIndex] or RING_COLORS[#RING_COLORS]
	)
	ring:SetAttribute("RingIndex", ringIndex)
	ring.Parent = ringsFolder

	-- tabliczka z numerem pierścienia na granicy (orientacja w terenie)
	local sign = makePart(
		"RingSign" .. ringIndex,
		Vector3.new(6, 4, 0.5),
		CFrame.new(-MAP_WIDTH / 2 + 6, 3, prevEndZ),
		Color3.fromRGB(230, 220, 180)
	)
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
	label.Text = "PIERŚCIEŃ " .. ringIndex
	label.Parent = gui

	-- świecący portal skrótu powrotnego na początku pierścienia (GDD §3)
	local shortcutConfig = Config.Shortcuts[ringIndex]
	if shortcutConfig then
		local portal = makePart(
			"ShortcutPortal" .. ringIndex,
			Vector3.new(5, 9, 1),
			CFrame.new(MAP_WIDTH / 2 - 12, 5, prevEndZ + 4),
			Color3.fromRGB(110, 190, 255)
		)
		portal.Material = Enum.Material.Neon
		portal.Transparency = 0.25
		portal:SetAttribute("RingIndex", ringIndex)
		portal.Parent = shortcutsFolder

		local portalPrompt = Instance.new("ProximityPrompt")
		portalPrompt.ActionText = "Skrót do bazy"
		portalPrompt.ObjectText = ("%s — %d 💰 (raz)"):format(shortcutConfig.name, shortcutConfig.cost)
		portalPrompt.HoldDuration = 0.4
		portalPrompt.MaxActivationDistance = 10
		portalPrompt.RequiresLineOfSight = false
		portalPrompt.Parent = portal
	end

	prevEndZ = endZ
end

print(("[MapBuilder] Mapa gotowa: baza + %d pierścieni, długość %d studów"):format(#Config.Rings, math.floor(prevEndZ)))
