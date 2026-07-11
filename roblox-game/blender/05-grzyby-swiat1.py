# Pick a Shroom — 10 GATUNKÓW ŚWIATA 1 (Las Liściasty), low-poly
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_Swiat1" z 10 grzybami obok siebie (co 4 j.).
#
# Kolejność = drabinka wartości z GameConfig (1 = najtańszy, 10 = najcenniejszy).
# Im wyżej w drabince, tym bardziej „odjechany" model: łuski, pierścienie,
# pomarszczenia, złote kropki, korona. Części są OSOBNYMI obiektami
# (w Roblox jeden MeshPart = jeden kolor) — nie łącz ich!

import bpy
import math
import random

COLLECTION_NAME = "PickAShroom_Swiat1"
random.seed(7)  # powtarzalne "losowe" detale

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


def make_material(name, rgb, roughness=0.9, emission=0.0):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        if emission > 0 and "Emission Strength" in bsdf.inputs:
            bsdf.inputs["Emission Strength"].default_value = emission
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


def join_as(objs, name, material):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    return finish(bpy.context.active_object, name, material)


def stem(x, height, r_bottom, r_top, name, material):
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r_bottom,
                                    radius2=r_top, depth=height,
                                    location=(x, 0, height / 2))
    return finish(bpy.context.active_object, name, material)


def dome(x, z, radius, squash, name, material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5,
                                         radius=radius, location=(x, 0, z))
    return finish(bpy.context.active_object, name, material,
                  scale=(1.0, 1.0, squash))


def dots_on_dome(x, cap_z, cap_r, squash, name, material, pattern, dot_squash=0.45):
    """Kropki/łuski na powierzchni kopuły, złączone w jeden obiekt."""
    parts = []
    for (angle_deg, dist_frac, size) in pattern:
        a = math.radians(angle_deg)
        d = cap_r * dist_frac
        dz = squash * math.sqrt(max(cap_r * cap_r - d * d, 0.0))
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=6, ring_count=4, radius=size,
            location=(x + math.cos(a) * d, math.sin(a) * d, cap_z + dz))
        p = bpy.context.active_object
        p.scale = (1.0, 1.0, dot_squash)
        parts.append(p)
    bpy.ops.object.select_all(action="DESELECT")
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.join()
    return finish(bpy.context.active_object, name, material)


def ring_on_cap(x, cap_z, cap_r, squash, ring_frac, name, material, minor=0.05):
    """Pierścień (torus) leżący na kopule — np. słoje Rydza."""
    d = cap_r * ring_frac
    dz = squash * math.sqrt(max(cap_r * cap_r - d * d, 0.0))
    bpy.ops.mesh.primitive_torus_add(major_radius=d, minor_radius=minor,
                                     major_segments=14, minor_segments=6,
                                     location=(x, 0, cap_z + dz))
    return finish(bpy.context.active_object, name, material)


# --- materiały (kolory robocze — finalnie i tak malujesz w Roblox) ---------
M_TRZON = make_material("S1_Trzon", (0.93, 0.89, 0.78))
M_TRZON_BIALY = make_material("S1_TrzonBialy", (0.96, 0.95, 0.92))
M_KURKA = make_material("S1_Kurka", (0.91, 0.66, 0.24))
M_PODGRZYBEK = make_material("S1_Podgrzybek", (0.43, 0.29, 0.18))
M_MASLAK = make_material("S1_Maslak", (0.69, 0.47, 0.19), roughness=0.2)  # śliski!
M_KANIA = make_material("S1_Kania", (0.79, 0.69, 0.54))
M_LUSKI = make_material("S1_Luski", (0.48, 0.36, 0.24))
M_GASKA = make_material("S1_Gaska", (0.66, 0.72, 0.29))
M_RYDZ = make_material("S1_Rydz", (0.85, 0.48, 0.18))
M_SLOJE = make_material("S1_Sloje", (0.70, 0.37, 0.12))
M_BOROWIK = make_material("S1_Borowik", (0.48, 0.29, 0.16))
M_KOZLARZ = make_material("S1_Kozlarz", (0.78, 0.29, 0.17))
M_SMARDZ = make_material("S1_Smardz", (0.85, 0.64, 0.25), emission=0.15)
M_CESARZ = make_material("S1_Cesarz", (0.69, 0.12, 0.16))
M_ZLOTO = make_material("S1_Zloto", (0.91, 0.76, 0.35), roughness=0.35)

# ===========================================================================
# 1) KURKA (wartość 1) — lejek jak trąbka, najprostsza sylwetka
# ===========================================================================
X = 0
stem(X, 0.7, 0.28, 0.22, "G01_Kurka_Trzon", M_KURKA)
bpy.ops.mesh.primitive_cone_add(vertices=9, radius1=0.22, radius2=0.95,
                                depth=0.8, location=(X, 0, 1.05))
finish(bpy.context.active_object, "G01_Kurka_Lejek", M_KURKA)

# ===========================================================================
# 2) PODGRZYBEK (2) — klasyczna brązowa kopułka, krępy trzonek
# ===========================================================================
X = 4
stem(X, 1.0, 0.34, 0.27, "G02_Podgrzybek_Trzon", M_TRZON)
dome(X, 1.0, 0.85, 0.55, "G02_Podgrzybek_Kapelusz", M_PODGRZYBEK)

# ===========================================================================
# 3) MAŚLAK (3) — płaski, LŚNIĄCY kapelusz (niska szorstkość materiału)
# ===========================================================================
X = 8
stem(X, 0.9, 0.32, 0.26, "G03_Maslak_Trzon", M_TRZON)
dome(X, 0.92, 1.05, 0.38, "G03_Maslak_Kapelusz", M_MASLAK)

# ===========================================================================
# 4) KANIA (4) — wysoka i smukła parasolka z łuskami i czubkiem
# ===========================================================================
X = 12
stem(X, 2.4, 0.22, 0.16, "G04_Kania_Trzon", M_TRZON)
dome(X, 2.38, 1.45, 0.32, "G04_Kania_Kapelusz", M_KANIA)
dots_on_dome(X, 2.38, 1.45, 0.32, "G04_Kania_Luski", M_LUSKI,
             [(15, 0.55, 0.14), (95, 0.7, 0.12), (170, 0.45, 0.13),
              (250, 0.65, 0.12), (320, 0.5, 0.11), (0, 0.0, 0.18)])

# ===========================================================================
# 5) GĄSKA ZIELONA (6) — przysadzista, zielonkawa, gruby trzon
# ===========================================================================
X = 16
stem(X, 0.85, 0.4, 0.33, "G05_Gaska_Trzon", M_TRZON)
dome(X, 0.9, 1.05, 0.48, "G05_Gaska_Kapelusz", M_GASKA)

# ===========================================================================
# 6) RYDZ (8) — pomarańczowy z ciemniejszymi SŁOJAMI (2 pierścienie)
# ===========================================================================
X = 20
stem(X, 0.9, 0.3, 0.25, "G06_Rydz_Trzon", M_RYDZ)
dome(X, 0.95, 1.1, 0.4, "G06_Rydz_Kapelusz", M_RYDZ)
r1 = ring_on_cap(X, 0.95, 1.1, 0.4, 0.5, "G06_Rydz_SlojWewn", M_SLOJE)
r2 = ring_on_cap(X, 0.95, 1.1, 0.4, 0.82, "G06_Rydz_SlojZewn", M_SLOJE)

# ===========================================================================
# 7) BOROWIK SZLACHETNY (11) — beczkowaty gruby trzon, dostojna kopuła
# ===========================================================================
X = 24
stem(X, 1.3, 0.62, 0.4, "G07_Borowik_Trzon", M_TRZON)
dome(X, 1.35, 1.2, 0.6, "G07_Borowik_Kapelusz", M_BOROWIK)

# ===========================================================================
# 8) KOŹLARZ CZERWONY (15) — wysoki biały trzon w ciemne łuski, ruda czapa
# ===========================================================================
X = 28
stem(X, 2.2, 0.3, 0.22, "G08_Kozlarz_Trzon", M_TRZON_BIALY)
luski = []
for i in range(7):
    a = math.radians(i * 51 + 10)
    h = 0.35 + (i % 4) * 0.5
    r_at_h = 0.3 - (h / 2.2) * 0.08
    bpy.ops.mesh.primitive_cube_add(size=1, location=(
        X + math.cos(a) * r_at_h, math.sin(a) * r_at_h, h))
    scale_cube = bpy.context.active_object
    scale_cube.scale = (0.1, 0.1, 0.22)
    luski.append(scale_cube)
bpy.ops.object.select_all(action="DESELECT")
for p in luski:
    p.select_set(True)
bpy.context.view_layer.objects.active = luski[0]
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bpy.ops.object.join()
finish(bpy.context.active_object, "G08_Kozlarz_Luski", M_LUSKI)
dome(X, 2.2, 1.0, 0.65, "G08_Kozlarz_Kapelusz", M_KOZLARZ)

# ===========================================================================
# 9) SMARDZ ZŁOCISTY (20) — POMARSZCZONY stożkowy kapelusz (szum wierzchołków)
#    + delikatna złota poświata (emission w materiale)
# ===========================================================================
X = 32
stem(X, 1.0, 0.34, 0.3, "G09_Smardz_Trzon", M_TRZON_BIALY)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.8,
                                      location=(X, 0, 1.75))
smardz = bpy.context.active_object
smardz.scale = (0.85, 0.85, 1.25)
bpy.context.view_layer.objects.active = smardz
bpy.ops.object.select_all(action="DESELECT")
smardz.select_set(True)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
# pomarszczenie: losowe przesunięcie każdego wierzchołka (plaster miodu w low-poly)
for v in smardz.data.vertices:
    v.co.x += random.uniform(-0.07, 0.07)
    v.co.y += random.uniform(-0.07, 0.07)
    v.co.z += random.uniform(-0.05, 0.05)
finish(smardz, "G09_Smardz_Kapelusz", M_SMARDZ)

# ===========================================================================
# 10) MUCHOMOR CESARSKI (28) — finał drabinki: wielka purpurowa kopuła,
#     ZŁOTE kropki, pierścień na trzonie i złota korona z 3 kolców
# ===========================================================================
X = 36
stem(X, 1.9, 0.4, 0.3, "G10_Cesarz_Trzon", M_TRZON_BIALY)
# pierścień (spódniczka) na trzonie
bpy.ops.mesh.primitive_torus_add(major_radius=0.42, minor_radius=0.09,
                                 major_segments=16, minor_segments=6,
                                 location=(X, 0, 1.15))
finish(bpy.context.active_object, "G10_Cesarz_Pierscien", M_TRZON_BIALY)
dome(X, 1.95, 1.45, 0.6, "G10_Cesarz_Kapelusz", M_CESARZ)
dots_on_dome(X, 1.95, 1.45, 0.6, "G10_Cesarz_ZloteKropki", M_ZLOTO,
             [(30, 0.55, 0.17), (105, 0.7, 0.13), (180, 0.4, 0.15),
              (255, 0.65, 0.14), (330, 0.5, 0.13)])
korona = []
for i in range(3):
    a = math.radians(i * 120)
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.14, radius2=0.01,
                                    depth=0.5,
                                    location=(X + math.cos(a) * 0.35,
                                              math.sin(a) * 0.35, 3.0))
    korona.append(bpy.context.active_object)
bpy.ops.object.select_all(action="DESELECT")
for p in korona:
    p.select_set(True)
bpy.context.view_layer.objects.active = korona[0]
bpy.ops.object.join()
finish(bpy.context.active_object, "G10_Cesarz_Korona", M_ZLOTO)

print("Gotowe! Kolekcja:", COLLECTION_NAME,
      "— 10 gatunków Świata 1 (eksport wg blender/README.md)")
