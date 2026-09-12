# Pick a Shroom — 10 GATUNKÓW ŚWIATA 2 (Bór Iglasty), low-poly
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_Swiat2" z 10 grzybami obok siebie (co 4 j.).
#
# Klimat boru: chłód, mgła, igliwie, żywica, szron. Drabinka wartości
# rośnie w detal spokojniej niż na Grzyboksiężycu (to wczesny świat):
# 1 Rydz Borowy → 10 Widmowy Muchomor (duch: świeci, kropki LEWITUJĄ —
# nazwy z "Drobiny"/"Glow" łapie FxClient). Styl: klockowy, flat shading.
# Części są OSOBNYMI obiektami — nie łącz ich!

import bpy
import math
import random

COLLECTION_NAME = "PickAShroom_Swiat2"
random.seed(22)

# ---------------------------------------------------------------------------
# Pomocnicze (styl: mało segmentów + płaskie cieniowanie)
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


def make_material(name, rgb, roughness=0.9, glow=0.0):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        if glow > 0:
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
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.join()
    return finish(bpy.context.active_object, name, material)


def stem(x, height, r_bottom, r_top, name, material, tilt=(0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r_bottom,
                                    radius2=r_top, depth=height,
                                    location=(x, 0, height / 2),
                                    rotation=(math.radians(tilt[0]),
                                              math.radians(tilt[1]), 0))
    return finish(bpy.context.active_object, name, material)


def dome(x, z, radius, squash, name, material, y=0.0):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5,
                                         radius=radius, location=(x, y, z))
    return finish(bpy.context.active_object, name, material,
                  scale=(1.0, 1.0, squash))


def mini_sphere(x, y, z, r, squash=1.0):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=6, ring_count=4, radius=r,
                                         location=(x, y, z))
    obj = bpy.context.active_object
    if squash != 1.0:
        obj.scale = (1.0, 1.0, squash)
    return obj


# --- materiały --------------------------------------------------------------
M_TRZON = make_material("S2_Trzon", (0.90, 0.86, 0.75))
M_RYDZ_B = make_material("S2_RydzBorowy", (0.82, 0.45, 0.16))
M_MASLAK_S = make_material("S2_MaslakSosnowy", (0.62, 0.40, 0.16), roughness=0.15)
M_SLUZ = make_material("S2_Sluz", (0.80, 0.62, 0.30), roughness=0.1)
M_OPIENKA = make_material("S2_Opienka", (0.76, 0.58, 0.32))
M_ZIELENIATKA = make_material("S2_Zieleniatka", (0.58, 0.64, 0.30))
M_IGLA = make_material("S2_Igla", (0.35, 0.26, 0.16))
M_SZYSZKA = make_material("S2_Szyszka", (0.52, 0.36, 0.20))
M_SZYSZKA_J = make_material("S2_SzyszkaJasna", (0.68, 0.50, 0.30))
M_MROZNIK = make_material("S2_Mroznik", (0.72, 0.85, 0.92), roughness=0.25)
M_SZRON = make_material("S2_Szron", (0.95, 0.98, 1.0), roughness=0.2)
M_IGLOWIEC = make_material("S2_Iglowiec", (0.30, 0.45, 0.32))
M_KOLCE = make_material("S2_Kolce", (0.18, 0.34, 0.24))
M_SMOLAK = make_material("S2_Smolak", (0.10, 0.09, 0.10), roughness=0.08)
M_SMOLA = make_material("S2_Smola", (0.06, 0.05, 0.07), roughness=0.05)
M_KROL = make_material("S2_Krol", (0.44, 0.26, 0.14))
M_ZLOTO = make_material("S2_ZlotoGlow", (0.93, 0.76, 0.32), roughness=0.3, glow=1.0)
M_WIDMO = make_material("S2_WidmoGlow", (0.75, 0.90, 1.0), glow=2.5)
M_WIDMO_T = make_material("S2_WidmoTrzonGlow", (0.85, 0.95, 1.0), glow=1.5)

# ===========================================================================
# 1) RYDZ BOROWY (1) — przysadzista pomarańczowa kopułka, prosty otwieracz
# ===========================================================================
X = 0
stem(X, 0.8, 0.32, 0.26, "B01_RydzBorowy_Trzon", M_TRZON)
dome(X, 0.85, 0.95, 0.45, "B01_RydzBorowy_Kapelusz", M_RYDZ_B)

# ===========================================================================
# 2) MAŚLAK SOSNOWY (2) — LŚNIĄCY karmelowy kapelusz + kropla żywicy
#    spływająca z ronda
# ===========================================================================
X = 4
stem(X, 0.9, 0.3, 0.24, "B02_MaslakSosnowy_Trzon", M_TRZON)
dome(X, 0.95, 1.0, 0.42, "B02_MaslakSosnowy_Kapelusz", M_MASLAK_S)
kropla = mini_sphere(X + 0.85, 0.2, 0.72, 0.12)
kropla.scale = (0.7, 0.7, 1.6)
join_as([kropla], "B02_MaslakSosnowy_Kropla", M_SLUZ)

# ===========================================================================
# 3) OPIEŃKA MGLISTA (3) — rośnie w KĘPIE: trzy grzybki z jednej kępki
# ===========================================================================
X = 8
trzony, kapelusze = [], []
for (dx, dy, h, tiltx, tilty, r) in [(-0.35, 0.1, 1.0, 0, -12, 0.5),
                                     (0.3, -0.15, 1.25, 5, 10, 0.55),
                                     (0.1, 0.3, 0.8, -10, 4, 0.42)]:
    bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=0.16, radius2=0.12,
                                    depth=h, location=(X + dx, dy, h / 2),
                                    rotation=(math.radians(tiltx),
                                              math.radians(tilty), 0))
    trzony.append(bpy.context.active_object)
    kapelusze.append(mini_sphere(X + dx - h * math.sin(math.radians(tilty)) * 0.5,
                                 dy + h * math.sin(math.radians(tiltx)) * 0.5,
                                 h + 0.05, r, squash=0.5))
join_as(trzony, "B03_Opienka_Trzony", M_TRZON)
join_as(kapelusze, "B03_Opienka_Kapelusze", M_OPIENKA)

# ===========================================================================
# 4) ZIELENIATKA (4) — oliwkowa, z opadłą IGŁĄ sosny leżącą na kapeluszu
# ===========================================================================
X = 12
stem(X, 0.85, 0.32, 0.26, "B04_Zieleniatka_Trzon", M_TRZON)
dome(X, 0.9, 1.05, 0.4, "B04_Zieleniatka_Kapelusz", M_ZIELENIATKA)
bpy.ops.mesh.primitive_cube_add(size=1, location=(X + 0.15, 0.1, 1.34),
                                rotation=(0, 0, math.radians(28)))
igla = bpy.context.active_object
igla.scale = (0.9, 0.045, 0.04)
join_as([igla], "B04_Zieleniatka_Igla", M_IGLA)

# ===========================================================================
# 5) SZYSZKÓWKA (6) — kapelusz jak SZYSZKA: stożek pokryty łuskami
# ===========================================================================
X = 16
stem(X, 0.9, 0.26, 0.2, "B05_Szyszkowka_Trzon", M_TRZON)
bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.72, radius2=0.08,
                                depth=1.3, location=(X, 0, 1.5))
finish(bpy.context.active_object, "B05_Szyszkowka_Rdzen", M_SZYSZKA)
luski = []
for (ring_h, ring_r, count) in [(1.05, 0.62, 6), (1.45, 0.45, 5), (1.85, 0.26, 4)]:
    for i in range(count):
        a = math.radians(i * (360 / count) + ring_h * 40)
        l = mini_sphere(X + math.cos(a) * ring_r, math.sin(a) * ring_r,
                        ring_h, 0.16, squash=0.5)
        l.scale = (1.0, 0.7, 0.45)
        luski.append(l)
join_as(luski, "B05_Szyszkowka_Luski", M_SZYSZKA_J)

# ===========================================================================
# 6) MROŹNIK (8) — lodowo-błękitny, z kryształkami SZRONU na rondzie
# ===========================================================================
X = 20
stem(X, 1.0, 0.3, 0.24, "B06_Mroznik_Trzon", M_TRZON)
dome(X, 1.05, 1.05, 0.5, "B06_Mroznik_Kapelusz", M_MROZNIK)
szron = []
for i in range(6):
    a = math.radians(i * 60 + 12)
    d = 1.05 * 0.85
    bpy.ops.mesh.primitive_cube_add(
        size=1, location=(X + math.cos(a) * d, math.sin(a) * d, 1.18),
        rotation=(math.radians(random.uniform(-25, 25)),
                  math.radians(random.uniform(-25, 25)), a))
    krysztal = bpy.context.active_object
    krysztal.scale = (0.1, 0.1, 0.3)
    szron.append(krysztal)
join_as(szron, "B06_Mroznik_Szron", M_SZRON)

# ===========================================================================
# 7) IGŁOWIEC (11) — kapelusz najeżony IGŁAMI jak jeż
# ===========================================================================
X = 24
stem(X, 1.0, 0.34, 0.28, "B07_Iglowiec_Trzon", M_TRZON)
dome(X, 1.1, 1.0, 0.55, "B07_Iglowiec_Kapelusz", M_IGLOWIEC)
kolce = []
for i in range(9):
    a = math.radians(i * 40 + 8)
    d = 1.0 * random.uniform(0.15, 0.7)
    dz = 0.55 * math.sqrt(max(1.0 - (d / 1.0) ** 2, 0.0))
    tilt = d / 1.0 * 0.9
    bpy.ops.mesh.primitive_cone_add(
        vertices=4, radius1=0.07, radius2=0.005, depth=0.55,
        location=(X + math.cos(a) * d, math.sin(a) * d, 1.1 + dz + 0.18),
        rotation=(math.sin(a) * tilt, -math.cos(a) * tilt, 0))
    kolce.append(bpy.context.active_object)
join_as(kolce, "B07_Iglowiec_Kolce", M_KOLCE)

# ===========================================================================
# 8) SMOLAK (15) — CZARNY jak smoła, lustrzany połysk, ciekące krople smoły
# ===========================================================================
X = 28
stem(X, 1.1, 0.34, 0.26, "B08_Smolak_Trzon", M_SMOLAK)
dome(X, 1.15, 1.1, 0.5, "B08_Smolak_Kapelusz", M_SMOLAK)
krople = []
for (a_deg, drop_z, drop_len) in [(30, 0.85, 0.5), (160, 0.95, 0.35), (270, 0.8, 0.6)]:
    a = math.radians(a_deg)
    k = mini_sphere(X + math.cos(a) * 0.95, math.sin(a) * 0.95, drop_z, 0.11)
    k.scale = (0.7, 0.7, drop_len / 0.22)
    krople.append(k)
join_as(krople, "B08_Smolak_Krople", M_SMOLA)

# ===========================================================================
# 9) BOROWIK KRÓLEWSKI (20) — dostojny olbrzym ze ZŁOTĄ OBRĘCZĄ
#    (torus z lekką poświatą; FxClient nada mu obrót — nazwa z "Pierscien")
# ===========================================================================
X = 32
stem(X, 1.5, 0.66, 0.42, "B09_Krol_Trzon", M_TRZON)
dome(X, 1.6, 1.35, 0.6, "B09_Krol_Kapelusz", M_KROL)
bpy.ops.mesh.primitive_torus_add(major_radius=1.15, minor_radius=0.07,
                                 major_segments=14, minor_segments=6,
                                 location=(X, 0, 1.72))
finish(bpy.context.active_object, "B09_Krol_PierscienGlow", M_ZLOTO)

# ===========================================================================
# 10) WIDMOWY MUCHOMOR (28) — DUCH boru: cały świeci błękitem, a jego
#     kropki ODERWAŁY SIĘ od kapelusza i dryfują wokół (nazwa "Drobiny"
#     = FxClient sam je lewituje). W Roblox: Material=Neon, Transparency≈0.2
# ===========================================================================
X = 36
stem(X, 1.6, 0.34, 0.26, "B10_Widmo_TrzonGlow", M_WIDMO_T)
dome(X, 1.7, 1.2, 0.58, "B10_Widmo_KapeluszGlow", M_WIDMO)
drobiny = []
for (a_deg, d, z, r) in [(20, 0.9, 2.6, 0.14), (110, 1.3, 2.2, 0.11),
                         (200, 1.05, 2.9, 0.12), (300, 1.4, 2.45, 0.1),
                         (65, 0.5, 3.1, 0.09)]:
    a = math.radians(a_deg)
    drobiny.append(mini_sphere(X + math.cos(a) * d, math.sin(a) * d, z, r,
                               squash=0.6))
join_as(drobiny, "B10_Widmo_DrobinyGlow", M_WIDMO)

print("Gotowe! Kolekcja:", COLLECTION_NAME,
      "— 10 gatunków Boru Iglastego. Części *Glow → w Roblox Material=Neon;",
      "Widmo dodatkowo Transparency ~0.2.")
