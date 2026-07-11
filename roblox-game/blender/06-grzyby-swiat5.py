# Pick a Shroom — 10 GATUNKÓW ŚWIATA 5 (Grzyboksiężyc) — wersje SPEKTAKULARNE
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_Swiat5" z 10 grzybami obok siebie (co 5 j.).
#
# Endgame = nagroda dla oczu. Każdy gatunek ma swój „patent":
# kratery, świetlisty halo, warkocz komety, gwiezdny pył, pierścienie
# orbitalne, plazmowy rdzeń, mgławica, antygrawitacyjny rozerwany trzon,
# eksplozja supernowej i czarna dziura z dyskiem akrecyjnym.
#
# Świecące części mają w Blenderze materiał z EMISSION — w Roblox po
# imporcie ustaw im Material = Neon (nazwy części z "Glow" = mają świecić).
# Części są OSOBNYMI obiektami — nie łącz ich!

import bpy
import math
import random

COLLECTION_NAME = "PickAShroom_Swiat5"
random.seed(55)

# ---------------------------------------------------------------------------
# Pomocnicze
# ---------------------------------------------------------------------------

def get_collection(name):
    coll = bpy.data.collections.get(name)
    if coll is None:
        coll = bpy.data.collections.new(name)
        bpy.context.scene.collection.children.link(coll)
    return coll


def move_to_collection(obj, coll):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    coll.objects.link(obj)


def make_material(name, rgb, roughness=0.85, glow=0.0):
    """glow > 0 = materiał świecący (emission); w Roblox → Material Neon."""
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        if glow > 0:
            # nazwa wejścia różni się między Blenderem 3.x a 4.x
            for input_name in ("Emission Color", "Emission"):
                if input_name in bsdf.inputs:
                    bsdf.inputs[input_name].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
                    break
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = glow
    return mat


coll = get_collection(COLLECTION_NAME)


def finish(obj, name, material, scale=None):
    obj.name = name
    if scale is not None:
        obj.scale = scale
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    # styl Roblox: płaskie cieniowanie — każda ścianka łapie światło osobno
    for poly in obj.data.polygons:
        poly.use_smooth = False
    obj.data.materials.clear()
    obj.data.materials.append(material)
    move_to_collection(obj, coll)
    return obj


def join_group(parts, name, material):
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.join()
    return finish(bpy.context.active_object, name, material)


def stem(x, height, r_bottom, r_top, name, material, z0=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r_bottom,
                                    radius2=r_top, depth=height,
                                    location=(x, 0, z0 + height / 2))
    return finish(bpy.context.active_object, name, material)


def dome(x, z, radius, squash, name, material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5,
                                         radius=radius, location=(x, 0, z))
    return finish(bpy.context.active_object, name, material,
                  scale=(1.0, 1.0, squash))


def sphere(x, y, z, r, segments=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=6,
                                         radius=r, location=(x, y, z))
    return bpy.context.active_object


def torus(x, z, major, minor, name, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor,
                                     major_segments=16, minor_segments=6,
                                     location=(x, 0, z),
                                     rotation=(math.radians(rot[0]),
                                               math.radians(rot[1]),
                                               math.radians(rot[2])))
    return finish(bpy.context.active_object, name, material)


def noisy(obj, amount):
    for v in obj.data.vertices:
        v.co.x += random.uniform(-amount, amount)
        v.co.y += random.uniform(-amount, amount)
        v.co.z += random.uniform(-amount, amount)
    return obj


# --- materiały --------------------------------------------------------------
M_SKALA = make_material("S5_Skala", (0.55, 0.55, 0.60))
M_SKALA_C = make_material("S5_SkalaCiemna", (0.32, 0.32, 0.38))
M_TRZON = make_material("S5_Trzon", (0.75, 0.76, 0.84))
M_LOD = make_material("S5_Lod", (0.62, 0.85, 0.95), roughness=0.25)
M_HALO = make_material("S5_HaloGlow", (0.78, 0.92, 1.0), glow=3.0)
M_KOMETA = make_material("S5_KometaGlow", (0.55, 0.85, 1.0), glow=4.0)
M_PYL = make_material("S5_PylGlow", (1.0, 0.92, 0.55), glow=5.0)
M_PLANETA = make_material("S5_Planeta", (0.80, 0.55, 0.35))
M_ORBITA = make_material("S5_OrbitaGlow", (0.95, 0.85, 0.55), glow=2.5)
M_PLAZMA = make_material("S5_PlazmaGlow", (0.95, 0.35, 0.85), glow=4.0)
M_PLAZMA_RDZEN = make_material("S5_PlazmaRdzenGlow", (0.65, 0.95, 1.0), glow=8.0)
M_MGLA_A = make_material("S5_MglawicaFiolet", (0.55, 0.35, 0.85), glow=1.5)
M_MGLA_B = make_material("S5_MglawicaTurkus", (0.30, 0.80, 0.80), glow=1.5)
M_ANTYGRAW = make_material("S5_AntygrawGlow", (0.45, 1.0, 0.65), glow=3.0)
M_NOVA = make_material("S5_NovaGlow", (1.0, 0.80, 0.35), glow=6.0)
M_NOVA_FALA = make_material("S5_NovaFalaGlow", (1.0, 0.55, 0.25), glow=3.0)
M_CZERN = make_material("S5_Czern", (0.01, 0.01, 0.02), roughness=0.15)
M_DYSK = make_material("S5_DyskGlow", (1.0, 0.65, 0.20), glow=7.0)

# ===========================================================================
# 1) KRATEREK (1) — księżycowa skała: szara kopuła z zapadniętymi kraterami
# ===========================================================================
X = 0
stem(X, 0.9, 0.32, 0.26, "K01_Kraterek_Trzon", M_TRZON)
dome(X, 0.95, 0.95, 0.55, "K01_Kraterek_Kapelusz", M_SKALA)
kratery = []
for (a_deg, dist, r) in [(20, 0.5, 0.2), (140, 0.55, 0.16), (260, 0.35, 0.18)]:
    a = math.radians(a_deg)
    d = 0.95 * dist
    dz = 0.55 * math.sqrt(max(0.95 ** 2 - d * d, 0.0)) - 0.06  # lekko ZAPADNIĘTE
    k = sphere(X + math.cos(a) * d, math.sin(a) * d, 0.95 + dz, r)
    k.scale = (1.0, 1.0, 0.3)
    kratery.append(k)
join_group(kratery, "K01_Kraterek_Kratery", M_SKALA_C)

# ===========================================================================
# 2) LUNARK (2) — blada kopuła z przechylonym ŚWIETLISTYM HALO (jak księżyc)
# ===========================================================================
X = 5
stem(X, 1.1, 0.3, 0.24, "K02_Lunark_Trzon", M_TRZON)
dome(X, 1.15, 0.9, 0.6, "K02_Lunark_Kapelusz", M_LOD)
torus(X, 1.35, 1.35, 0.05, "K02_Lunark_HaloGlow", M_HALO, rot=(18, 8, 0))

# ===========================================================================
# 3) KOMETKA (3) — przechylony lodowy grzyb z WARKOCZEM z malejących kul
# ===========================================================================
X = 10
bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.28, radius2=0.2,
                                depth=1.0, location=(X, 0, 0.5),
                                rotation=(0, math.radians(14), 0))
finish(bpy.context.active_object, "K03_Kometka_Trzon", M_TRZON)
bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5, radius=0.75,
                                     location=(X + 0.15, 0, 1.15))
kometa_kap = bpy.context.active_object
kometa_kap.scale = (1.0, 1.0, 0.62)
finish(kometa_kap, "K03_Kometka_Kapelusz", M_LOD)
warkocz = []
for i, (dx, dz, r) in enumerate([(-0.9, 0.5, 0.28), (-1.5, 0.95, 0.2), (-2.0, 1.35, 0.13)]):
    warkocz.append(sphere(X + dx, 0, 1.15 + dz, r))
join_group(warkocz, "K03_Kometka_WarkoczGlow", M_KOMETA)

# ===========================================================================
# 4) GWIEZDNY PYŁ (4) — ciemna kopuła obsypana DZIESIĄTKAMI świecących drobin,
#    część dryfuje NAD kapeluszem
# ===========================================================================
X = 15
stem(X, 1.0, 0.3, 0.24, "K04_Pyl_Trzon", M_TRZON)
dome(X, 1.05, 1.0, 0.5, "K04_Pyl_Kapelusz", M_SKALA_C)
drobiny = []
for i in range(14):
    a = math.radians(random.uniform(0, 360))
    d = 1.0 * random.uniform(0.15, 0.85)
    dz = 0.5 * math.sqrt(max(1.0 - d * d, 0.0))
    lift = random.choice([0.03, 0.05, 0.3, 0.55])  # część unosi się nad czapą
    drobiny.append(sphere(X + math.cos(a) * d, math.sin(a) * d,
                          1.05 + dz + lift, random.uniform(0.05, 0.1), segments=6))
join_group(drobiny, "K04_Pyl_DrobinyGlow", M_PYL)

# ===========================================================================
# 5) ORBITALNY BOROWIK (6) — planeta: gruby borowik z DWOMA pierścieniami
#    jak Saturn i małym księżycem na orbicie
# ===========================================================================
X = 20
stem(X, 1.4, 0.55, 0.38, "K05_Orbitalny_Trzon", M_TRZON)
dome(X, 1.5, 1.15, 0.7, "K05_Orbitalny_Kapelusz", M_PLANETA)
torus(X, 1.55, 1.6, 0.06, "K05_Orbitalny_Pierscien1Glow", M_ORBITA, rot=(24, 0, 0))
torus(X, 1.55, 1.95, 0.045, "K05_Orbitalny_Pierscien2Glow", M_ORBITA, rot=(24, 0, 0))
ksiezyc = sphere(X + 1.95 * math.cos(math.radians(30)),
                 1.95 * math.sin(math.radians(30)) * math.cos(math.radians(24)),
                 1.55 + 1.95 * math.sin(math.radians(30)) * math.sin(math.radians(24)),
                 0.16)
finish(ksiezyc, "K05_Orbitalny_Ksiezyc", M_SKALA)

# ===========================================================================
# 6) PLAZMIAK (8) — falująca plazmowa kula (mocny szum) z jaśniejszym RDZENIEM
#    prześwitującym przez szczyt
# ===========================================================================
X = 25
stem(X, 0.9, 0.34, 0.28, "K06_Plazmiak_Trzon", M_SKALA_C)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.95,
                                      location=(X, 0, 1.35))
plazma = bpy.context.active_object
plazma.scale = (1.0, 1.0, 0.8)
bpy.context.view_layer.objects.active = plazma
bpy.ops.object.select_all(action="DESELECT")
plazma.select_set(True)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
noisy(plazma, 0.11)
finish(plazma, "K06_Plazmiak_KapeluszGlow", M_PLAZMA)
rdzen = sphere(X, 0, 1.75, 0.42)
finish(rdzen, "K06_Plazmiak_RdzenGlow", M_PLAZMA_RDZEN)

# ===========================================================================
# 7) NEBULON (11) — mgławica: chmura z fioletowych i turkusowych obłoków
#    zamiast kapelusza + gwiazdki w środku
# ===========================================================================
X = 30
stem(X, 1.3, 0.26, 0.2, "K07_Nebulon_Trzon", M_TRZON)
fiolet, turkus = [], []
for i in range(6):
    a = math.radians(i * 60 + 15)
    d = 0.55 + (i % 2) * 0.25
    b = sphere(X + math.cos(a) * d, math.sin(a) * d,
               1.65 + random.uniform(-0.15, 0.3), random.uniform(0.4, 0.6))
    b.scale = (1.0, 1.0, 0.75)
    (fiolet if i % 2 == 0 else turkus).append(b)
srodek = sphere(X, 0, 1.75, 0.55)
srodek.scale = (1.0, 1.0, 0.8)
fiolet.append(srodek)
join_group(fiolet, "K07_Nebulon_ChmuraFioletGlow", M_MGLA_A)
join_group(turkus, "K07_Nebulon_ChmuraTurkusGlow", M_MGLA_B)
gwiazdki = [sphere(X + random.uniform(-0.7, 0.7), random.uniform(-0.7, 0.7),
                   1.75 + random.uniform(-0.2, 0.45), 0.06, segments=6)
            for _ in range(6)]
join_group(gwiazdki, "K07_Nebulon_GwiazdkiGlow", M_PYL)

# ===========================================================================
# 8) ANTYGRAWIK (15) — grzyb, który OLAŁ grawitację: trzon rozerwany na
#    3 lewitujące segmenty, kapelusz unosi się najwyżej, wokół dryfują skałki
# ===========================================================================
X = 35
for i, (h, gap) in enumerate([(0.5, 0.0), (0.45, 0.35), (0.4, 0.7)]):
    z0 = sum([0.5, 0.45][:i]) + gap + (0.35 * i)
    seg = stem(X + (i % 2) * 0.12 - 0.06, h, 0.3 - i * 0.03, 0.26 - i * 0.03,
               "K08_Antygrawik_TrzonSeg" + str(i + 1), M_TRZON, z0=z0)
dome(X, 2.75, 1.05, 0.55, "K08_Antygrawik_KapeluszGlow", M_ANTYGRAW)
skalki = []
for (a_deg, d, z, r) in [(30, 1.3, 1.2, 0.16), (150, 1.45, 2.0, 0.2),
                         (250, 1.25, 0.7, 0.13), (330, 1.5, 2.6, 0.11)]:
    a = math.radians(a_deg)
    skalki.append(sphere(X + math.cos(a) * d, math.sin(a) * d, z, r, segments=8))
join_group(skalki, "K08_Antygrawik_Skalki", M_SKALA)

# ===========================================================================
# 9) SUPERNOWIK (20) — eksplodująca gwiazda: oślepiający rdzeń, 8 promieni
#    na wszystkie strony i pierścień fali uderzeniowej
# ===========================================================================
X = 40
stem(X, 1.1, 0.36, 0.28, "K09_Supernowik_Trzon", M_SKALA_C)
rdzen = sphere(X, 0, 1.9, 0.62)
finish(rdzen, "K09_Supernowik_RdzenGlow", M_NOVA)
promienie = []
for i in range(8):
    a = math.radians(i * 45)
    tilt = math.radians(35 if i % 2 == 0 else 80)
    dx = math.cos(a) * math.sin(tilt)
    dy = math.sin(a) * math.sin(tilt)
    dz = math.cos(tilt)
    dist = 0.95
    bpy.ops.mesh.primitive_cone_add(
        vertices=6, radius1=0.13, radius2=0.01, depth=0.85,
        location=(X + dx * dist, dy * dist, 1.9 + dz * dist),
        rotation=(math.atan2(math.sqrt(dx * dx + dy * dy), dz), 0, math.atan2(dy, dx) + math.pi / 2))
    promienie.append(bpy.context.active_object)
join_group(promienie, "K09_Supernowik_PromienieGlow", M_NOVA)
torus(X, 1.9, 1.5, 0.05, "K09_Supernowik_FalaGlow", M_NOVA_FALA, rot=(12, 0, 0))

# ===========================================================================
# 10) CZARNA DZIURA (28) — sekret: idealnie czarna kula, płonący DYSK
#     AKRECYJNY, łuki zagiętego światła i wciągana materia
# ===========================================================================
X = 45
stem(X, 1.0, 0.4, 0.3, "K10_CzarnaDziura_Trzon", M_SKALA_C)
horyzont = sphere(X, 0, 2.0, 0.85, segments=16)
finish(horyzont, "K10_CzarnaDziura_Horyzont", M_CZERN)
torus(X, 2.0, 1.45, 0.11, "K10_CzarnaDziura_DyskGlow", M_DYSK, rot=(75, 0, 0))
torus(X, 2.0, 1.05, 0.045, "K10_CzarnaDziura_LukGornyGlow", M_HALO, rot=(0, 0, 0))
torus(X, 2.0, 1.0, 0.04, "K10_CzarnaDziura_LukBocznyGlow", M_HALO, rot=(90, 0, 0))
materia = []
for i, t in enumerate([0.0, 0.5, 1.0]):
    a = math.radians(200 + t * 130)
    d = 2.1 - t * 0.9
    materia.append(sphere(X + math.cos(a) * d, math.sin(a) * d * 0.35,
                          2.0 + 0.3 - t * 0.25, 0.14 - t * 0.03, segments=8))
join_group(materia, "K10_CzarnaDziura_MateriaGlow", M_DYSK)

print("Gotowe! Kolekcja:", COLLECTION_NAME,
      "— 10 gatunków Grzyboksiężyca. Części *Glow → w Roblox Material=Neon.")
