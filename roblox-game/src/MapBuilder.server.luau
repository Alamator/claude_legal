-- MapBuilder: buduje CAŁĄ mapę ze skryptu — zero ręcznego modelowania.
-- Wklej jako Script do ServerScriptService (nazwa: MapBuilder).
--
-- Wersja „ładna": filmowe oświetlenie (Atmosphere, Bloom, korekcja kolorów),
-- dekoracje per biom (drzewa liściaste / świerki / bagno / kryształy /
-- księżyc), bazy jako obozowiska (stragan, ognisko, lampy, flaga) i portale
-- z łukiem, poświatą i cząsteczkami. Świecące kałuże, robaczki świętojańskie,
-- lewitujące skały. Palety kolorów per świat: GameConfig → theme.
--
-- Struktura w workspace (czyta ją GameServer):
--   Worlds/World<i> [attr WorldIndex]
--     ├─ BasePad [attr WorldIndex]
--     ├─ Rings/Ring<k> [attr RingIndex]
--     ├─ Shortcuts/ShortcutPortal<k> [attr WorldIndex, RingIndex]
--     ├─ PortalNext / PortalPrev [attr TargetWorld]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("GameConfig"))

local MAP_SCALE = 0.5     -- prototyp jest 2× krótszy niż docelowe dystanse
local MAP_WIDTH = 140     -- szerokość korytarza LASU (oś X)
local BASE_WIDTH = 760    -- strefa baz: 5 osobnych decków z dużymi odstępami
local BASE_LENGTH = 90    -- głęboka: rzędy grządek chodzą parami z alejkami
local WORLD_SPACING = 1100 -- odstęp między światami (bazy są szerokie — bez nachodzenia)

-- kolor podłoża świata (pierścienie ciemnieją w głąb przez Lerp do czerni)
local WORLD_GROUND = {
	Color3.fromRGB(124, 176, 88),  -- Las Liściasty
	Color3.fromRGB(64, 120, 104),  -- Bór Iglasty (mgła, chłód)
	Color3.fromRGB(96, 110, 60),   -- Mokradła
	Color3.fromRGB(96, 110, 160),  -- Kryształowa Grota
	Color3.fromRGB(150, 150, 160), -- Grzyboksiężyc
}

-- ============================================================================
-- Oświetlenie: ciepłe popołudnie + mgła + bloom = „przytulny low-poly"
-- ============================================================================

Lighting.ClockTime = 14.2
Lighting.Brightness = 3
Lighting.ExposureCompensation = 0.1
Lighting.ShadowSoftness = 0.35
Lighting.GlobalShadows = true
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 0.5

local atmosphere = Instance.new("Atmosphere")
atmosphere.Density = 0.3
atmosphere.Offset = 0.5
atmosphere.Color = Color3.fromRGB(206, 222, 245)
atmosphere.Decay = Color3.fromRGB(255, 180, 120)
atmosphere.Glare = 0.2
atmosphere.Haze = 1.6
atmosphere.Parent = Lighting

local bloom = Instance.new("BloomEffect")
bloom.Intensity = 0.5
bloom.Size = 24
bloom.Threshold = 1.4
bloom.Parent = Lighting

local colorCorrection = Instance.new("ColorCorrectionEffect")
colorCorrection.Saturation = 0.22
colorCorrection.Contrast = 0.08
colorCorrection.TintColor = Color3.fromRGB(255, 250, 240)
colorCorrection.Parent = Lighting

local sunRays = Instance.new("SunRaysEffect")
sunRays.Intensity = 0.09
sunRays.Spread = 0.6
sunRays.Parent = Lighting

-- ============================================================================
-- Pomocnicze klocki
-- ============================================================================

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Anchored = true
	-- czysty "klockowy" look Roblox: gładki plastik zamiast tekstury trawy
	part.Material = Enum.Material.SmoothPlastic
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

-- drewniana tabliczka na słupku, lekko przekrzywiona (urok ręcznej roboty)
local function makeSign(parent: Instance, text: string, cframe: CFrame)
	local tilt = CFrame.Angles(0, math.rad(math.random(-9, 9)), 0)
	local post = makePart("SignPost", Vector3.new(0.5, 4, 0.5), cframe * tilt * CFrame.new(0, -1, 0), Color3.fromRGB(110, 76, 48), parent)
	post.Material = Enum.Material.Wood
	local board = makePart("SignBoard", Vector3.new(7, 3, 0.5), cframe * tilt * CFrame.new(0, 1.6, 0), Color3.fromRGB(196, 152, 98), parent)
	board.Material = Enum.Material.WoodPlanks
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.fromRGB(60, 40, 25)
	label.Text = text
	label.Parent = gui

	-- WISZĄCA TABLICZKA wysoko nad znakiem — widoczna z daleka
	local floatBoard = Instance.new("BillboardGui")
	floatBoard.Size = UDim2.new(0, 280, 0, 52)
	floatBoard.StudsOffset = Vector3.new(0, 10, 0)
	floatBoard.MaxDistance = 240
	floatBoard.Parent = board
	local floatLabel = Instance.new("TextLabel")
	floatLabel.Size = UDim2.fromScale(1, 1)
	floatLabel.BackgroundTransparency = 1
	floatLabel.Font = Enum.Font.FredokaOne
	floatLabel.TextScaled = true
	floatLabel.TextColor3 = Color3.new(1, 1, 1)
	floatLabel.TextStrokeColor3 = Color3.fromRGB(30, 25, 20)
	floatLabel.TextStrokeTransparency = 0.1
	floatLabel.Text = text
	floatLabel.Parent = floatBoard
end

local function addSparkles(parent: BasePart, color: Color3, rate: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(1.5, 3)
	emitter.Speed = NumberRange.new(0.3, 0.8)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new(0.2)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = parent
	return emitter
end

-- ============================================================================
-- Dekoracje per biom
-- ============================================================================

local function makeBallTree(theme, position: Vector3, parent: Instance)
	local height = math.random(6, 9)
	local trunk = makePart("Trunk", Vector3.new(1.4, height, 1.4), CFrame.new(position + Vector3.new(0, height / 2, 0)), theme.trunk, parent)
	trunk.Material = Enum.Material.Wood
	local canopyColor = theme.canopy[math.random(#theme.canopy)]
	local size = math.random(6, 9)
	local ball = makePart("Canopy", Vector3.new(size, size * 0.9, size), CFrame.new(position + Vector3.new(0, height + size * 0.3, 0)), canopyColor, parent)
	ball.Shape = Enum.PartType.Ball
	ball.Material = Enum.Material.SmoothPlastic
	if math.random() < 0.5 then
		local size2 = size * 0.6
		local ball2 = makePart("Canopy", Vector3.new(size2, size2, size2),
			CFrame.new(position + Vector3.new(math.random(-2, 2), height + size * 0.7, math.random(-2, 2))),
			theme.canopy[math.random(#theme.canopy)], parent)
		ball2.Shape = Enum.PartType.Ball
		ball2.Material = Enum.Material.SmoothPlastic
	end
end

local function makePineTree(theme, position: Vector3, parent: Instance)
	local height = math.random(4, 6)
	local trunk = makePart("Trunk", Vector3.new(1.2, height, 1.2), CFrame.new(position + Vector3.new(0, height / 2, 0)), theme.trunk, parent)
	trunk.Material = Enum.Material.Wood
	local canopyColor = theme.canopy[math.random(#theme.canopy)]
	local radius = math.random(6, 8)
	for layer = 0, 2 do
		local layerRadius = radius * (1 - layer * 0.3)
		local disk = makePart("Canopy", Vector3.new(2.2, layerRadius, layerRadius),
			CFrame.new(position + Vector3.new(0, height + layer * 2.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			canopyColor, parent)
		disk.Shape = Enum.PartType.Cylinder
		disk.Material = Enum.Material.SmoothPlastic
	end
end

local function makeSwampTree(theme, position: Vector3, parent: Instance)
	local trunk = makePart("Trunk", Vector3.new(2, 4, 2),
		CFrame.new(position + Vector3.new(0, 2, 0)) * CFrame.Angles(math.rad(math.random(-12, 12)), 0, math.rad(math.random(-12, 12))),
		theme.trunk, parent)
	trunk.Material = Enum.Material.Wood
	local canopy = makePart("Canopy", Vector3.new(7, 3, 7), CFrame.new(position + Vector3.new(0, 5.5, 0)),
		theme.canopy[math.random(#theme.canopy)], parent)
	canopy.Shape = Enum.PartType.Ball
	canopy.Material = Enum.Material.SmoothPlastic
	-- świecąca kałuża u stóp
	local puddle = makePart("Puddle", Vector3.new(math.random(4, 7), 0.2, math.random(4, 7)),
		CFrame.new(position + Vector3.new(math.random(-3, 3), 0.12, math.random(-3, 3))), theme.accent, parent)
	puddle.Material = Enum.Material.Neon
	puddle.Transparency = 0.35
end

local function makeCrystal(theme, position: Vector3, parent: Instance)
	local height = math.random(5, 11)
	local crystal = makePart("Crystal", Vector3.new(math.random(2, 3), height, math.random(2, 3)),
		CFrame.new(position + Vector3.new(0, height / 2 - 0.5, 0))
			* CFrame.Angles(math.rad(math.random(-18, 18)), math.rad(math.random(0, 360)), math.rad(math.random(-18, 18))),
		theme.caps[math.random(#theme.caps)], parent)
	crystal.Material = Enum.Material.Neon
	crystal.Transparency = 0.15
	-- światło tylko na ~1/3 kryształów (setki PointLightów zabiłyby FPS)
	if math.random() < 0.35 then
		local light = Instance.new("PointLight")
		light.Color = crystal.Color
		light.Range = 14
		light.Brightness = 0.8
		light.Parent = crystal
	end
end

local function makeMoonDecor(theme, position: Vector3, parent: Instance)
	if math.random() < 0.5 then
		-- krater
		local radius = math.random(6, 12)
		local crater = makePart("Crater", Vector3.new(1.2, radius, radius),
			CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(105, 105, 118), parent)
		crater.Shape = Enum.PartType.Cylinder
		crater.Material = Enum.Material.Slate
	else
		-- lewitująca skała
		local size = math.random(3, 6)
		local rock = makePart("FloatingRock", Vector3.new(size, size * 0.8, size),
			CFrame.new(position + Vector3.new(0, math.random(8, 16), 0))
				* CFrame.Angles(math.rad(math.random(0, 360)), math.rad(math.random(0, 360)), 0),
			Color3.fromRGB(130, 130, 145), parent)
		rock.Material = Enum.Material.Slate
	end
end

local function makeFireflies(color: Color3, position: Vector3, parent: Instance)
	local anchor = makePart("Fireflies", Vector3.new(1, 1, 1), CFrame.new(position + Vector3.new(0, 4, 0)), color, parent)
	anchor.Transparency = 1
	anchor.CanCollide = false
	local emitter = addSparkles(anchor, color, 3)
	emitter.Speed = NumberRange.new(0.4, 1.2)
	emitter.Lifetime = NumberRange.new(3, 5)
end

local DECOR_BY_STYLE = {
	ball = makeBallTree,
	pine = makePineTree,
	swamp = makeSwampTree,
	crystal = makeCrystal,
	moon = makeMoonDecor,
}

-- drobny detal wypełniający świat: kępki trawy, świecące kwiatki, kamienie
local function makeSmallDecor(theme, position: Vector3, parent: Instance)
	local roll = math.random()
	if roll < 0.45 then
		local tuftColor = (theme.canopy[1] or theme.accent):Lerp(Color3.new(1, 1, 1), 0.15)
		local tuft = makePart("Tuft",
			Vector3.new(math.random(15, 25) / 10, 0.7, math.random(15, 25) / 10),
			CFrame.new(position + Vector3.new(0, 0.35, 0)), tuftColor, parent)
		tuft.Shape = Enum.PartType.Ball
		tuft.CanCollide = false
	elseif roll < 0.75 then
		local stem = makePart("FlowerStem", Vector3.new(0.15, 1.2, 0.15),
			CFrame.new(position + Vector3.new(0, 0.6, 0)), Color3.fromRGB(90, 140, 70), parent)
		stem.CanCollide = false
		local bloom = makePart("Flower", Vector3.new(0.5, 0.35, 0.5),
			CFrame.new(position + Vector3.new(0, 1.25, 0)), theme.accent, parent)
		bloom.Shape = Enum.PartType.Ball
		bloom.Material = Enum.Material.Neon
		bloom.CanCollide = false
	else
		local shade = math.random(115, 145)
		local rock = makePart("Rock",
			Vector3.new(math.random(8, 16) / 10, math.random(6, 12) / 10, math.random(8, 16) / 10),
			CFrame.new(position + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.rad(math.random(0, 360)), 0),
			Color3.fromRGB(shade, shade, shade + 8), parent)
		rock.Shape = Enum.PartType.Ball
		rock.Material = Enum.Material.Slate
		rock.CanCollide = false
	end
end

-- ============================================================================
-- NPC-sprzedawca przy straganie: klockowy ludzik w grzybowym kapeluszu,
-- macha ręką na powitanie i ma tabliczkę z imieniem
-- ============================================================================

local VENDOR_NAMES = { "Grzybór", "Szyszek", "Bagno-Bill", "Kryształt", "Astrogrzyb" }

local function makeVendor(worldFolder: Instance, theme, worldIdx: number, position: Vector3)
	local skin = Color3.fromRGB(245, 205, 160)

	local function bodyPart(name: string, size: Vector3, cframe: CFrame, color: Color3): Part
		local part = makePart(name, size, cframe, color, worldFolder)
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide = false
		return part
	end

	bodyPart("VendorLegs", Vector3.new(1.6, 1.6, 0.9), CFrame.new(position + Vector3.new(0, 0.8, 0)), Color3.fromRGB(70, 60, 55))
	bodyPart("VendorTorso", Vector3.new(1.8, 1.8, 1), CFrame.new(position + Vector3.new(0, 2.5, 0)), theme.accent)
	bodyPart("VendorArmL", Vector3.new(0.5, 1.6, 0.5), CFrame.new(position + Vector3.new(-1.25, 2.5, 0)), skin)
	local armR = bodyPart("VendorArmR", Vector3.new(0.5, 1.6, 0.5), CFrame.new(position + Vector3.new(1.25, 2.5, 0)), skin)

	local head = bodyPart("VendorHead", Vector3.new(1.3, 1.3, 1.3), CFrame.new(position + Vector3.new(0, 4, 0)), skin)
	head.Shape = Enum.PartType.Ball
	for _, side in { -0.28, 0.28 } do
		bodyPart("VendorEye", Vector3.new(0.18, 0.18, 0.18),
			CFrame.new(position + Vector3.new(side, 4.15, -0.55)), Color3.fromRGB(25, 25, 35))
	end
	bodyPart("VendorSmile", Vector3.new(0.5, 0.1, 0.12),
		CFrame.new(position + Vector3.new(0, 3.75, -0.6)), Color3.fromRGB(150, 70, 60))

	-- grzybowy kapelusz z kropkami
	local hat = bodyPart("VendorHat", Vector3.new(1.9, 1, 1.9), CFrame.new(position + Vector3.new(0, 4.75, 0)), theme.caps[1])
	hat.Shape = Enum.PartType.Ball
	for _, offset in { Vector3.new(0.45, 0.3, 0.2), Vector3.new(-0.35, 0.35, -0.25) } do
		local dot = bodyPart("VendorHatDot", Vector3.new(0.3, 0.2, 0.3),
			CFrame.new(position + Vector3.new(0, 4.75, 0) + offset), Color3.fromRGB(250, 248, 240))
		dot.Shape = Enum.PartType.Ball
	end

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.new(0, 180, 0, 40)
	tag.StudsOffset = Vector3.new(0, 2.2, 0)
	tag.Parent = head
	local tagLabel = Instance.new("TextLabel")
	tagLabel.Size = UDim2.fromScale(1, 1)
	tagLabel.BackgroundTransparency = 0.35
	tagLabel.BackgroundColor3 = Color3.fromRGB(25, 30, 25)
	tagLabel.TextColor3 = Color3.new(1, 1, 1)
	tagLabel.Font = Enum.Font.FredokaOne
	tagLabel.TextScaled = true
	tagLabel.Text = ("🍄 %s — skup grzybów"):format(VENDOR_NAMES[worldIdx] or "Grzybór")
	tagLabel.Parent = tag
	local tagCorner = Instance.new("UICorner")
	tagCorner.CornerRadius = UDim.new(0, 10)
	tagCorner.Parent = tagLabel

	-- powitalne machanie ręką (pętla tam-i-z-powrotem w nieskończoność)
	local raised = CFrame.new(position + Vector3.new(1.45, 3.4, 0)) * CFrame.Angles(0, 0, math.rad(-150))
	TweenService:Create(armR,
		TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ CFrame = raised }):Play()
end

-- ============================================================================
-- Baza-obozowisko: stragan nad BasePadem, ognisko, lampy, flaga
-- ============================================================================

local function buildBaseCamp(worldFolder: Instance, theme, offsetX: number)
	-- stragan-SKLEP w przerwie między deckami 1 i 2 (NPC za ladą)
	local stallX = offsetX - 225
	local stallZ = -25
	for _, corner in { { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } } do
		local post = makePart("StallPost", Vector3.new(0.6, 7, 0.6),
			CFrame.new(stallX + corner[1], 4, stallZ + corner[2]), Color3.fromRGB(150, 105, 65), worldFolder)
		post.Material = Enum.Material.Wood
	end
	local roof = makePart("StallRoof", Vector3.new(11, 0.6, 11), CFrame.new(stallX, 7.8, stallZ), Color3.fromRGB(210, 65, 60), worldFolder)
	roof.Material = Enum.Material.SmoothPlastic
	local roofTrim = makePart("StallRoofTrim", Vector3.new(11.6, 0.5, 11.6), CFrame.new(stallX, 7.4, stallZ), Color3.fromRGB(245, 240, 225), worldFolder)
	roofTrim.Material = Enum.Material.SmoothPlastic
	-- białe pasy na daszku (klasyczny stragan)
	for _, stripeZ in { -3.4, 0, 3.4 } do
		local stripe = makePart("StallRoofStripe", Vector3.new(11.2, 0.2, 1.5),
			CFrame.new(stallX, 8.15, stallZ + stripeZ), Color3.fromRGB(245, 240, 225), worldFolder)
		stripe.Material = Enum.Material.SmoothPlastic
	end

	-- lada od frontu i skrzynki z towarem
	local counter = makePart("StallCounter", Vector3.new(9, 1, 1.2), CFrame.new(stallX, 2.2, stallZ + 4.6), Color3.fromRGB(150, 105, 65), worldFolder)
	counter.Material = Enum.Material.WoodPlanks
	for _, crateX in { -6.5, 6.5 } do
		local crate = makePart("Crate", Vector3.new(2.2, 2.2, 2.2), CFrame.new(stallX + crateX, 2.1, stallZ + 2), Color3.fromRGB(170, 125, 80), worldFolder)
		crate.Material = Enum.Material.WoodPlanks
		-- mini-grzybek na skrzynce (towar na wystawie)
		local displayCap = makePart("CrateShroom", Vector3.new(1.1, 0.8, 1.1),
			CFrame.new(stallX + crateX, 3.6, stallZ + 2), theme.caps[math.random(#theme.caps)], worldFolder)
		displayCap.Shape = Enum.PartType.Ball
		displayCap.Material = Enum.Material.SmoothPlastic
		displayCap.CanCollide = false
	end

	-- === 5 OSOBNYCH DECKÓW-HAL (po jednym na gracza): jasna podłoga,
	-- wysokie stalowe filary, ciemny dach, panele LED, neonowe listwy ===
	local STEEL = Color3.fromRGB(45, 52, 66)
	local STEEL_DARK = Color3.fromRGB(36, 42, 54)
	for _, deckCenter in Config.Base.deckCenters do
		local deckX = offsetX + deckCenter
		local deckFloor = makePart("DeckFloor", Vector3.new(46, 0.32, 74),
			CFrame.new(deckX, 1.0, -47), Color3.fromRGB(206, 220, 234), worldFolder)
		deckFloor.Material = Enum.Material.SmoothPlastic
		for _, columnX in { -21, 21 } do
			for _, columnZ in { -11, -47, -83 } do
				local column = makePart("DeckColumn", Vector3.new(1.5, 22, 1.5),
					CFrame.new(deckX + columnX, 12, columnZ), STEEL, worldFolder)
				column.Material = Enum.Material.Metal
			end
		end
		local canopy = makePart("DeckRoof", Vector3.new(46, 1, 75),
			CFrame.new(deckX, 23.5, -47), STEEL_DARK, worldFolder)
		canopy.Material = Enum.Material.SmoothPlastic
		local panelIndex = 0
		for _, panelX in { -11, 11 } do
			for _, panelZ in { -18, -40, -62, -80 } do
				local panel = makePart("DeckLightPanel", Vector3.new(5, 0.3, 5),
					CFrame.new(deckX + panelX, 22.8, panelZ), Color3.fromRGB(255, 250, 235), worldFolder)
				panel.Material = Enum.Material.Neon
				panel.CanCollide = false
				panelIndex += 1
				if panelIndex % 4 == 1 then
					local light = Instance.new("PointLight")
					light.Color = Color3.fromRGB(255, 245, 220)
					light.Range = 30
					light.Brightness = 0.8
					light.Parent = panel
				end
			end
		end
		for _, trimZ in { -10.5, -83.5 } do
			local trim = makePart("DeckTrim", Vector3.new(46, 0.5, 0.5),
				CFrame.new(deckX, 22.7, trimZ), theme.accent, worldFolder)
			trim.Material = Enum.Material.Neon
			trim.CanCollide = false
		end
	end

	-- ognisko: skrzyżowane polana + ogień + ciepłe światło (prawy przód)
	local firePos = Vector3.new(offsetX + 350, 1, -6)
	for angle = 0, 120, 60 do
		local log = makePart("Log", Vector3.new(4, 0.9, 0.9),
			CFrame.new(firePos) * CFrame.Angles(0, math.rad(angle), math.rad(8)), Color3.fromRGB(96, 66, 40), worldFolder)
		log.Material = Enum.Material.Wood
	end
	local fireCore = makePart("FireCore", Vector3.new(1, 1, 1), CFrame.new(firePos + Vector3.new(0, 0.8, 0)), Color3.fromRGB(255, 150, 50), worldFolder)
	fireCore.Transparency = 1
	fireCore.CanCollide = false
	local fire = Instance.new("ParticleEmitter")
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(230, 80, 40))
	fire.LightEmission = 1
	fire.Rate = 22
	fire.Lifetime = NumberRange.new(0.5, 1)
	fire.Speed = NumberRange.new(2, 4)
	fire.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	fire.Parent = fireCore
	local fireLight = Instance.new("PointLight")
	fireLight.Color = Color3.fromRGB(255, 170, 90)
	fireLight.Range = 18
	fireLight.Brightness = 1.4
	fireLight.Parent = fireCore

	-- ławki-polana wokół ogniska (miejsce spotkań)
	for _, seat in { { -4.5, 0, 20 }, { 3, 3.5, -35 } } do
		local bench = makePart("Bench", Vector3.new(4.5, 1, 1),
			CFrame.new(firePos + Vector3.new(seat[1], 0.2, seat[2])) * CFrame.Angles(0, math.rad(seat[3]), 0),
			Color3.fromRGB(110, 78, 48), worldFolder)
		bench.Material = Enum.Material.Wood
	end

	-- lampy przy wejściu do lasu
	for _, side in { -1, 1 } do
		local pole = makePart("LampPole", Vector3.new(0.5, 6, 0.5), CFrame.new(offsetX + side * 12, 3.5, -2), Color3.fromRGB(70, 70, 80), worldFolder)
		pole.Material = Enum.Material.Metal
		local bulb = makePart("LampBulb", Vector3.new(1.6, 1.6, 1.6), CFrame.new(offsetX + side * 12, 7, -2), Color3.fromRGB(255, 225, 150), worldFolder)
		bulb.Shape = Enum.PartType.Ball
		bulb.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 225, 150)
		light.Range = 16
		light.Brightness = 0.9
		light.Parent = bulb
	end

	-- flaga w kolorze świata (prawy przód, za ogniskiem)
	local flagPole = makePart("FlagPole", Vector3.new(0.4, 12, 0.4), CFrame.new(offsetX + 365, 6.5, -8), Color3.fromRGB(200, 200, 210), worldFolder)
	flagPole.Material = Enum.Material.Metal
	local flag = makePart("Flag", Vector3.new(5, 3, 0.3), CFrame.new(offsetX + 367.9, 10.5, -8), theme.accent, worldFolder)
	flag.Material = Enum.Material.SmoothPlastic
end

-- portal z kamiennym łukiem, poświatą i cząsteczkami
local function buildTravelPortal(worldFolder: Instance, name: string, position: Vector3, color: Color3, targetWorld: number, promptObjectText: string)
	for _, side in { -1, 1 } do
		local pillar = makePart(name .. "Pillar", Vector3.new(2, 11, 2), CFrame.new(position + Vector3.new(0, 0.5, side * 4)), Color3.fromRGB(120, 118, 130), worldFolder)
		pillar.Material = Enum.Material.Slate
	end
	local beam = makePart(name .. "Beam", Vector3.new(2.4, 2, 10.5), CFrame.new(position + Vector3.new(0, 6.5, 0)), Color3.fromRGB(120, 118, 130), worldFolder)
	beam.Material = Enum.Material.Slate

	local glow = makePart(name, Vector3.new(0.8, 9, 6.5), CFrame.new(position + Vector3.new(0, 0.5, 0)), color, worldFolder)
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.35
	glow:SetAttribute("TargetWorld", targetWorld)
	addSparkles(glow, color, 6)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 16
	light.Brightness = 1.2
	light.Parent = glow
	makePrompt(glow, "Podróż", promptObjectText)
end

-- ============================================================================
-- Budowa światów
-- ============================================================================

local worldsFolder = Instance.new("Folder")
worldsFolder.Name = "Worlds"
worldsFolder.Parent = workspace

local sprintSpeed = Config.Movement.sprintSpeed

for worldIdx, worldConfig in Config.Worlds do
	local offsetX = (worldIdx - 1) * WORLD_SPACING
	local ground = WORLD_GROUND[worldIdx] or WORLD_GROUND[#WORLD_GROUND]
	local theme = worldConfig.theme

	local worldFolder = Instance.new("Folder")
	worldFolder.Name = "World" .. worldIdx
	worldFolder:SetAttribute("WorldIndex", worldIdx)
	worldFolder.Parent = worldsFolder

	-- === Strefa bazy (z = -ZONE_LENGTH .. 0): LEGO-płyta z "guzikami" ===
	-- ZONE = obszar decków (BASE_WIDTH) + szeroki margines trawy dookoła,
	-- żeby ściany stały DALEKO od baz (nie tuż przy grządkach)
	local ZONE_MARGIN = 90
	local ZONE_WIDTH = BASE_WIDTH + ZONE_MARGIN * 2
	local ZONE_LENGTH = BASE_LENGTH + ZONE_MARGIN
	makePart(
		"BaseZone",
		Vector3.new(ZONE_WIDTH, 1, ZONE_LENGTH),
		CFrame.new(offsetX, 0.5, -ZONE_LENGTH / 2),
		Color3.fromRGB(108, 188, 78),
		worldFolder
	)
	-- "guziki" klocka na terenie MIĘDZY deckami (modny lego-look);
	-- pod deckami graczy nie stawiamy
	local studColor = Color3.fromRGB(126, 205, 94)
	for studX = -ZONE_WIDTH / 2 + 10, ZONE_WIDTH / 2 - 10, 10 do
		for studZ = -ZONE_LENGTH + 4, -4, 10 do
			local onDeck = false
			if studZ < -8 then
				for _, center in Config.Base.deckCenters do
					if math.abs(studX - center) < 25 then
						onDeck = true
						break
					end
				end
			end
			if not onDeck then
				local stud = makePart("LegoStud", Vector3.new(0.35, 2.9, 2.9),
					CFrame.new(offsetX + studX, 1.16, studZ) * CFrame.Angles(0, 0, math.rad(90)),
					studColor, worldFolder)
				stud.Shape = Enum.PartType.Cylinder
				stud.Material = Enum.Material.SmoothPlastic
				stud.CanCollide = false
			end
		end
	end
	makeSign(worldFolder, "🍄 " .. worldConfig.name, CFrame.new(offsetX, 2, -BASE_LENGTH + 4))

	if worldIdx == 1 then
		local spawnLocation = Instance.new("SpawnLocation")
		spawnLocation.Size = Vector3.new(8, 1, 8)
		-- spawn przy straganie (lewy przód bazy)
		spawnLocation.CFrame = CFrame.new(offsetX - 225, 1.1, -14)
		spawnLocation.Anchored = true
		spawnLocation.Neutral = true
		spawnLocation.Parent = worldFolder
	end

	-- PAS DOSTAWY na całej szerokości wejścia: wbiegasz z lasu i grzyby
	-- oddają się SAME (Touched w GameServer — bez prompta)
	local basePad = makePart(
		"BasePad",
		Vector3.new(MAP_WIDTH - 4, 1.2, 5),
		CFrame.new(offsetX, 1.1, -3),
		Color3.fromRGB(140, 96, 60),
		worldFolder
	)
	basePad.Material = Enum.Material.WoodPlanks
	basePad:SetAttribute("WorldIndex", worldIdx)

	-- STREFA STARTU WYPRAWY: świecący pas na CAŁEJ szerokości wejścia do
	-- lasu — nie da się go ominąć; wejście odpala minigrę (GameServer/klient).
	local launchPad = makePart("LaunchPad", Vector3.new(MAP_WIDTH - 4, 0.35, 6),
		CFrame.new(offsetX, 1.15, 3), Color3.fromRGB(90, 235, 120), worldFolder)
	launchPad.Material = Enum.Material.Neon
	launchPad:SetAttribute("WorldIndex", worldIdx)
	addSparkles(launchPad, Color3.fromRGB(160, 255, 180), 2)
	local launchSign = Instance.new("BillboardGui")
	launchSign.Size = UDim2.new(0, 280, 0, 56)
	launchSign.StudsOffset = Vector3.new(0, 11, 0)
	launchSign.MaxDistance = 220
	launchSign.Parent = launchPad
	local launchLabel = Instance.new("TextLabel")
	launchLabel.Size = UDim2.fromScale(1, 1)
	launchLabel.BackgroundTransparency = 1
	launchLabel.Font = Enum.Font.FredokaOne
	launchLabel.TextScaled = true
	launchLabel.TextColor3 = Color3.fromRGB(190, 255, 205)
	launchLabel.TextStrokeTransparency = 0.4
	launchLabel.Text = "🚀 STREFA STARTU"
	launchLabel.Parent = launchSign

	buildBaseCamp(worldFolder, theme, offsetX)

	-- sprzedawca ZA LADĄ straganu (stragan = SKLEP z ulepszeniami)
	makeVendor(worldFolder, theme, worldIdx, Vector3.new(offsetX - 225, 1, -29))
	makeFireflies(Color3.fromRGB(255, 215, 240), Vector3.new(offsetX - 30, 1, -25), worldFolder)
	for _ = 1, 10 do
		makeSmallDecor(theme, Vector3.new(
			offsetX + (math.random() < 0.5 and -1 or 1) * math.random(12, MAP_WIDTH / 2 - 8),
			1, -math.random(4, BASE_LENGTH - 6)), worldFolder)
	end

	-- gniazdo z jajem petów (GDD: gacha per świat). Jeśli w ReplicatedStorage.
	-- Models leży model "GniazdoJajo" (skrypt blender/15), stawiamy JEGO klon
	-- z akcentami przemalowanymi na kolor świata; inaczej klocki jak dotąd.
	local nestModelsRoot = ReplicatedStorage:FindFirstChild("Models")
	local nestTemplate = nestModelsRoot and nestModelsRoot:FindFirstChild("GniazdoJajo")
	local egg
	if nestTemplate and nestTemplate:IsA("Model") then
		local station = nestTemplate:Clone()
		for _, part in station:GetDescendants() do
			if part:IsA("BasePart") then
				part.Anchored = true
				part.CanQuery = false
				if string.find(part.Name, "Glow", 1, true) then
					part.Material = Enum.Material.Neon
				else
					-- "tekstura" po nazwie: podest→kamień, gałązki→drewno itd.
					local material = Config.materialFor(part.Name)
					if material then
						part.Material = material
					end
				end
				-- akcenty gachy w kolorze świata (README modeli: Cetki/Krag/Drobiny/Kule)
				for _, accentKey in { "Cetki", "Krag", "Drobiny", "Kule" } do
					if string.find(part.Name, accentKey, 1, true) then
						part.Color = theme.accent
						break
					end
				end
			end
		end
		-- normalizacja rozmiaru (FBX bywa ogromny/malutki): stanowisko ~8 studów
		local _, preSize = station:GetBoundingBox()
		if preSize.Y > 0.01 then
			station:ScaleTo(station:GetScale() * 8 / preSize.Y)
		end
		local box, size = station:GetBoundingBox()
		local pivotToCenter = station:GetPivot():ToObjectSpace(box)
		station:PivotTo(CFrame.new(offsetX + 225, 0.7 + size.Y / 2, -25) * pivotToCenter:Inverse())
		station.Parent = worldFolder
		-- niewidzialne "WorldEgg" zostaje kotwicą prompta/logiki GameServera
		egg = makePart("WorldEgg", Vector3.new(2.4, 3, 2.4),
			CFrame.new(offsetX + 225, 3.2, -25), Color3.fromRGB(250, 245, 230), worldFolder)
		egg.Transparency = 1
		egg.CanCollide = false
	else
		local nest = makePart("Nest", Vector3.new(4.5, 1, 4.5), CFrame.new(offsetX + 225, 1.2, -25), Color3.fromRGB(150, 110, 70), worldFolder)
		nest.Material = Enum.Material.WoodPlanks
		egg = makePart("WorldEgg", Vector3.new(2.4, 3, 2.4), CFrame.new(offsetX + 225, 3.2, -25), Color3.fromRGB(250, 245, 230), worldFolder)
		egg.Shape = Enum.PartType.Ball
		egg.Material = Enum.Material.SmoothPlastic
		addSparkles(egg, theme.accent, 2)
	end
	egg:SetAttribute("WorldIndex", worldIdx)
	makePrompt(egg, "Wyklnij peta",
		("🥚 Jajo: %s — %s 💰"):format(worldConfig.name, Config.fmtNumber(Config.Pets.eggCostByWorld[worldIdx])))

	-- === Portale podróży między światami ===
	local nextWorld = Config.Worlds[worldIdx + 1]
	if nextWorld then
		buildTravelPortal(worldFolder, "PortalNext",
			Vector3.new(offsetX + MAP_WIDTH / 2 - 10, 5, -BASE_LENGTH / 2),
			Color3.fromRGB(180, 120, 255), worldIdx + 1,
			("→ %s (odblokowanie: %s 💰)"):format(nextWorld.name, Config.fmtNumber(nextWorld.portalCost)))
	end
	if worldIdx > 1 then
		buildTravelPortal(worldFolder, "PortalPrev",
			Vector3.new(offsetX - MAP_WIDTH / 2 + 10, 5, -BASE_LENGTH / 2),
			Color3.fromRGB(120, 255, 180), worldIdx - 1,
			("← %s"):format(Config.Worlds[worldIdx - 1].name))
	end

	-- === Pierścienie lasu (z = 0 .. w głąb) ===
	local ringsFolder = Instance.new("Folder")
	ringsFolder.Name = "Rings"
	ringsFolder.Parent = worldFolder

	local shortcutsFolder = Instance.new("Folder")
	shortcutsFolder.Name = "Shortcuts"
	shortcutsFolder.Parent = worldFolder

	local decorate = DECOR_BY_STYLE[theme.style]
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
			CFrame.new(offsetX - MAP_WIDTH / 2 + 8, 2, prevEndZ))

		-- ściany lasu po bokach (rama korytarza) + dekoracje w polu,
		-- środek (|x| < 18) zostaje wolny — to pas biegu
		local edgeCount = math.max(3, math.floor(length / 14))
		for _ = 1, edgeCount do
			for _, side in { -1, 1 } do
				decorate(theme,
					Vector3.new(
						offsetX + side * (MAP_WIDTH / 2 - math.random(3, 9)),
						1,
						prevEndZ + math.random() * length),
					worldFolder)
			end
		end
		local fieldCount = math.max(2, math.floor(length / 26))
		for _ = 1, fieldCount do
			local x = (math.random() < 0.5 and -1 or 1) * math.random(20, MAP_WIDTH / 2 - 14)
			decorate(theme, Vector3.new(offsetX + x, 1, prevEndZ + math.random() * length), worldFolder)
		end
		if theme.fireflies then
			makeFireflies(theme.accent,
				Vector3.new(offsetX + math.random(-40, 40), 1, prevEndZ + length / 2), worldFolder)
		end

		-- drobny detal (trawa/kwiatki/kamienie) — wypełnia pustkę między drzewami
		for _ = 1, math.floor(length / 7) do
			local x = (math.random() < 0.5 and -1 or 1) * math.random(6, MAP_WIDTH / 2 - 6)
			makeSmallDecor(theme, Vector3.new(offsetX + x, 1, prevEndZ + math.random() * length), worldFolder)
		end

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
			addSparkles(portal, Color3.fromRGB(150, 210, 255), 4)
			makePrompt(portal, "Skrót do bazy",
				("%s — %s 💰 (raz)"):format(shortcutConfig.name, Config.fmtNumber(shortcutConfig.cost)))
		end

		prevEndZ = endZ
	end

	-- piaskowa ścieżka przez środek: prowadzi wzrok (i stopy) w głąb lasu
	local path = makePart("Path", Vector3.new(8, 0.16, prevEndZ + BASE_LENGTH),
		CFrame.new(offsetX, 1.06, (prevEndZ - BASE_LENGTH) / 2),
		Color3.fromRGB(196, 172, 128), worldFolder)
	path.Material = Enum.Material.Sand
	path.CanCollide = false

	-- WIDOCZNE ŚCIANY GRANICZNE: zasłaniają widok dookoła (nie widać
	-- pustki ani sąsiednich światów); do innych światów prowadzi
	-- WYŁĄCZNIE (opłacony) portal. Kształt: szeroka baza + korytarz lasu.
	local wallHeight = 55
	local wallColor = ground:Lerp(Color3.new(0, 0, 0), 0.45)
	-- ściany na krawędzi STREFY (z marginesem od baz), nie tuż przy grządkach
	local baseHalf = ZONE_WIDTH / 2
	local forestHalf = MAP_WIDTH / 2
	local wallSpecs = {
		-- baza: boki i tył (na obrysie szerokiej strefy)
		{ Vector3.new(2, wallHeight, ZONE_LENGTH + 4),
			CFrame.new(offsetX - baseHalf - 1, wallHeight / 2, -ZONE_LENGTH / 2) },
		{ Vector3.new(2, wallHeight, ZONE_LENGTH + 4),
			CFrame.new(offsetX + baseHalf + 1, wallHeight / 2, -ZONE_LENGTH / 2) },
		{ Vector3.new(ZONE_WIDTH + 4, wallHeight, 2),
			CFrame.new(offsetX, wallHeight / 2, -ZONE_LENGTH - 1) },
		-- ramiona na linii wejścia do lasu (łączą szeroką bazę z korytarzem)
		{ Vector3.new(baseHalf - forestHalf + 2, wallHeight, 2),
			CFrame.new(offsetX - (forestHalf + baseHalf) / 2, wallHeight / 2, 1) },
		{ Vector3.new(baseHalf - forestHalf + 2, wallHeight, 2),
			CFrame.new(offsetX + (forestHalf + baseHalf) / 2, wallHeight / 2, 1) },
		-- las: boki i koniec
		{ Vector3.new(2, wallHeight, prevEndZ + 4),
			CFrame.new(offsetX - forestHalf - 1, wallHeight / 2, prevEndZ / 2) },
		{ Vector3.new(2, wallHeight, prevEndZ + 4),
			CFrame.new(offsetX + forestHalf + 1, wallHeight / 2, prevEndZ / 2) },
		{ Vector3.new(MAP_WIDTH + 4, wallHeight, 2),
			CFrame.new(offsetX, wallHeight / 2, prevEndZ + 1) },
	}
	for _, spec in wallSpecs do
		local wall = Instance.new("Part")
		wall.Name = "WorldWall"
		wall.Size = spec[1]
		wall.CFrame = spec[2]
		wall.Color = wallColor
		wall.Material = Enum.Material.Grass
		wall.Anchored = true
		wall.CanCollide = true
		wall.CanQuery = false
		wall.Parent = worldFolder
	end
end

print(("[MapBuilder] Mapa gotowa: %d światów po %d pierścieni"):format(#Config.Worlds, #Config.Rings))
