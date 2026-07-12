-- FxClient: ożywia dekoracje na podstawie NAZW części — zero konfiguracji.
-- Wklej jako LocalScript do StarterPlayer → StarterPlayerScripts (nazwa: FxClient).
--
-- Konwencja nazw (celowo zgodna z modelami z blender/ i mapą proceduralną):
--   * zawiera Pierscien/Halo/Dysk/Orbita/Fala/Ring  → OBRACA SIĘ w swojej płaszczyźnie
--   * zawiera TrzonSeg/Skalki/FloatingRock/Drobiny/Materia/Ksiezyc/Warkocz
--                                                   → LEWITUJE (faluje góra-dół)
--   * zaczyna się od PortalNext/PortalPrev/ShortcutPortal → PULSUJE przezroczystością
--   * zawiera Glow                                  → dostaje ISKRY w kolorze części
--     (Rdzen w nazwie = iskier więcej)
--
-- Wszystko liczone lokalnie na kliencie (zero ruchu sieciowego) z LOD:
-- animowane są tylko części w pobliżu kamery.

local RunService = game:GetService("RunService")

local SPIN_KEYS = { "Pierscien", "Halo", "Dysk", "Orbita", "Fala", "Ring" }
local BOB_KEYS = { "TrzonSeg", "Skalki", "FloatingRock", "Drobiny", "Materia", "Ksiezyc", "Warkocz" }
local PULSE_KEYS = { "PortalNext", "PortalPrev", "ShortcutPortal" }

local SPIN_SPEED = 1.2      -- rad/s
local BOB_AMPLITUDE = 0.45  -- study
local BOB_SPEED = 1.6
local PULSE_AMPLITUDE = 0.12
local ACTIVE_DISTANCE = 220 -- LOD: dalej niż to = nie animujemy
local MAX_ACTIVE = 400

type Fx = {
	part: BasePart,
	base: CFrame,
	kind: string, -- "spin" | "bob" | "pulse"
	seed: number,
	baseTransparency: number,
}

local registered: { Fx } = {}
local active: { Fx } = {}

local function nameMatches(name: string, keys: { string }): boolean
	for _, key in keys do
		if string.find(name, key, 1, true) then
			return true
		end
	end
	return false
end

local function addSparkle(part: BasePart, rate: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(part.Color:Lerp(Color3.new(1, 1, 1), 0.35))
	emitter.LightEmission = 1
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(0.8, 1.8)
	emitter.Speed = NumberRange.new(0.4, 1.2)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = part
end

local seedCounter = 0

local function register(part: BasePart)
	local name = part.Name

	-- iskry na wszystkim, co świeci (modele z Blendera: *Glow)
	if string.find(name, "Glow", 1, true) and not part:FindFirstChildOfClass("ParticleEmitter") then
		addSparkle(part, string.find(name, "Rdzen", 1, true) and 6 or 2)
	end

	-- pety lewitujące przy graczach animuje ClientMain (są w ciągłym ruchu,
	-- a my kotwiczymy animację w miejscu spawnu) — iskry zostają, ruch nie
	if part:FindFirstAncestor("PetModels") then
		return
	end

	local kind: string? = nil
	if nameMatches(name, SPIN_KEYS) then
		kind = "spin"
	elseif nameMatches(name, BOB_KEYS) then
		kind = "bob"
	elseif nameMatches(name, PULSE_KEYS) then
		kind = "pulse"
	end
	if not kind then
		return
	end

	seedCounter += 1
	local fx: Fx = {
		part = part,
		base = part.CFrame,
		kind = kind,
		seed = (seedCounter % 23) * 0.41,
		baseTransparency = part.Transparency,
	}
	-- mapa/model mogły jeszcze nie stanąć na miejscu — dociśnij bazę po chwili
	task.delay(0.5, function()
		if part.Parent then
			fx.base = part.CFrame
		end
	end)
	table.insert(registered, fx)
end

for _, descendant in workspace:GetDescendants() do
	if descendant:IsA("BasePart") then
		register(descendant)
	end
end
workspace.DescendantAdded:Connect(function(descendant)
	if descendant:IsA("BasePart") then
		task.defer(register, descendant)
	end
end)

-- LOD: co pół sekundy wybierz części blisko kamery (i wyrzuć zniszczone)
task.spawn(function()
	while true do
		local camera = workspace.CurrentCamera
		local origin = camera and camera.CFrame.Position
		local fresh: { Fx } = {}
		for index = #registered, 1, -1 do
			local fx = registered[index]
			if not fx.part.Parent then
				table.remove(registered, index)
			elseif origin and #fresh < MAX_ACTIVE
				and (fx.part.Position - origin).Magnitude <= ACTIVE_DISTANCE then
				table.insert(fresh, fx)
			end
		end
		active = fresh
		task.wait(0.5)
	end
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for _, fx in active do
		if fx.kind == "spin" then
			-- obrót wokół własnej osi (przechylone halo wiruje w swojej płaszczyźnie)
			fx.part.CFrame = fx.base * CFrame.Angles(0, (now + fx.seed) * SPIN_SPEED, 0)
		elseif fx.kind == "bob" then
			fx.part.CFrame = fx.base
				* CFrame.new(0, math.sin((now + fx.seed * 10) * BOB_SPEED) * BOB_AMPLITUDE, 0)
		elseif fx.kind == "pulse" then
			fx.part.Transparency = fx.baseTransparency
				+ math.sin((now + fx.seed) * 2) * PULSE_AMPLITUDE
		end
	end
end)
