# Pick a Shroom — 10 GATUNKÓW ŚWIATA 4 (Kryształowa Grota), low-poly
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_Swiat4" z 10 grzybami obok siebie (co 4 j.).
#
# Klimat groty: każdy gatunek to inny MINERAŁ — kapelusze z klejnotów.
# Drabinka: 1 mleczny Kwarcownik → 10 Diamentowy Kapelusz (szlif brylantowy,
# wirująca iskra i dryfujące diamenciki). Kanciaste fasety low-poly grają
# tu podwójnie: klejnot MA być fasetowany.
# Nazwy z "Fala"/"Halo"/"Drobiny"/"Glow" łapie FxClient (obrót/lewitacja/iskry).
# Styl: klockowy, płaskie cieniowanie. Części OSOBNO — nie łącz ich!

import bpy
import math
import random

COLLECTION_NAME = "PickAShroom_Swiat4"
random.seed(77)

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


def mini_sphere(x, y, z, r, squash=1.0):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=6, ring_count=4, radius=r,
                                         location=(x, y, z))
    obj = bpy.context.active_object
    if squash != 1.0:
        obj.scale = (1.0, 1.0, squash)
    return obj


def dots_on_dome(x, cap_z, cap_r, squash, name, material, pattern):
    parts = []
    for (angle_deg, dist_frac, size) in pattern:
        a = math.radians(angle_deg)
        d = cap_r * dist_frac
        dz = squash * math.sqrt(max(cap_r * cap_r - d * d, 0.0))
        parts.append(mini_sphere(x + math.cos(a) * d, math.sin(a) * d,
                                 cap_z + dz, size, squash=0.5))
    return join_as(parts, name, material)


def shard(x, y, z, height, r, tilt=(0, 0)):
    bpy.ops.mesh.primitive_cone_add(
        vertices=6, radius1=r, radius2=r * 0.12, depth=height,
        location=(x, y, z + height / 2),
        rotation=(math.radians(tilt[0]), math.radians(tilt[1]),
                  math.radians(random.uniform(0, 360))))
    return bpy.context.active_object


# --- materiały --------------------------------------------------------------
M_TRZON = make_material("S4_TrzonSkalny", (0.55, 0.55, 0.62))
M_TRZON_C = make_material("S4_TrzonCiemny", (0.38, 0.38, 0.45))
M_KWARC = make_material("S4_Kwarc", (0.92, 0.92, 0.95), roughness=0.3)
M_GROTOLAZ = make_material("S4_Grotolaz", (0.46, 0.44, 0.48))
M_ECHO = make_material("S4_EchoGlow", (0.65, 0.80, 0.95), glow=1.5)
M_LAZURYT = make_material("S4_Lazuryt", (0.16, 0.28, 0.62), roughness=0.35)
M_PIRYT = make_material("S4_Piryt", (0.90, 0.75, 0.35), roughness=0.25)
M_RUBIN = make_material("S4_RubinGlow", (0.85, 0.10, 0.20), roughness=0.1, glow=1.5)
M_SZMARAGD = make_material("S4_SzmaragdGlow", (0.10, 0.75, 0.45), roughness=0.12, glow=1.2)
M_AMETYST = make_material("S4_AmetystGlow", (0.60, 0.35, 0.90), glow=2.0)
M_GEODA = make_material("S4_GeodaSkorupa", (0.42, 0.40, 0.46))
M_OBSYDIAN = make_material("S4_Obsydian", (0.05, 0.05, 0.07), roughness=0.05)
M_LAWA = make_material("S4_LawaGlow", (1.0, 0.50, 0.20), glow=4.0)
M_KRYSZTAL = make_material("S4_KrysztalGlow", (0.70, 0.90, 1.0), glow=2.5)
M_DIAMENT = make_material("S4_DiamentGlow", (0.95, 0.98, 1.0), roughness=0.05, glow=3.0)

# ===========================================================================
# 1) KWARCOWNIK (1) — mleczny kwarc: matowo-biała kopułka, dwa kwarcowe guzki
# ===========================================================================
X = 0
stem(X, 0.9, 0.32, 0.26, "C01_Kwarcownik_Trzon", M_TRZON)
dome(X, 0.95, 0.95, 0.5, "C01_Kwarcownik_Kapelusz", M_KWARC)
dots_on_dome(X, 0.95, 0.95, 0.5, "C01_Kwarcownik_Guzki", M_KWARC,
             [(50, 0.5, 0.16), (230, 0.55, 0.14)])

# ===========================================================================
# 2) GROTOŁAZ (2) — skalny szarak z mini-stalagmitami na kapeluszu
# ===========================================================================
X = 4
stem(X, 0.85, 0.34, 0.28, "C02_Grotolaz_Trzon", M_TRZON_C)
dome(X, 0.9, 1.0, 0.5, "C02_Grotolaz_Kapelusz", M_GROTOLAZ)
stalagmity = []
for (a_deg, d, h) in [(30, 0.45, 0.4), (150, 0.3, 0.5), (270, 0.5, 0.35)]:
    a = math.radians(a_deg)
    dd = 1.0 * d
    dz = 0.5 * math.sqrt(max(1.0 - dd * dd, 0.0))
    bpy.ops.mesh.primitive_cone_add(
        vertices=5, radius1=0.12, radius2=0.015, depth=h,
        location=(X + math.cos(a) * dd, math.sin(a) * dd, 0.9 + dz + h / 2))
    stalagmity.append(bpy.context.active_object)
join_as(stalagmity, "C02_Grotolaz_Stalagmity", M_GROTOLAZ)

# ===========================================================================
# 3) ECHOWIEC (3) — grzyb-echo: nad kapeluszem unoszą się dwa kręgi fal
#    dźwięku (nazwa "Fala" = FxClient je obraca)
# ===========================================================================
X = 8
stem(X, 1.0, 0.28, 0.22, "C03_Echowiec_Trzon", M_TRZON)
dome(X, 1.05, 0.9, 0.55, "C03_Echowiec_Kapelusz", M_GROTOLAZ)
bpy.ops.mesh.primitive_torus_add(major_radius=0.65, minor_radius=0.05,
                                 major_segments=12, minor_segments=5,
                                 location=(X, 0, 1.85))
finish(bpy.context.active_object, "C03_Echowiec_FalaMalaGlow", M_ECHO)
bpy.ops.mesh.primitive_torus_add(major_radius=1.05, minor_radius=0.04,
                                 major_segments=14, minor_segments=5,
                                 location=(X, 0, 2.2))
finish(bpy.context.active_object, "C03_Echowiec_FalaDuzaGlow", M_ECHO)

# ===========================================================================
# 4) LAZURYT (4) — lapis lazuli: granatowy kapelusz w ZŁOTE cętki pirytu
# ===========================================================================
X = 12
stem(X, 0.95, 0.3, 0.24, "C04_Lazuryt_Trzon", M_TRZON)
dome(X, 1.0, 1.05, 0.5, "C04_Lazuryt_Kapelusz", M_LAZURYT)
dots_on_dome(X, 1.0, 1.05, 0.5, "C04_Lazuryt_Piryt", M_PIRYT,
             [(20, 0.55, 0.1), (100, 0.35, 0.09), (180, 0.6, 0.1),
              (260, 0.45, 0.08), (330, 0.7, 0.09)])

# ===========================================================================
# 5) RUBINEK (6) — fasetowany rubin zamiast kapelusza (ikosfera = szlif)
# ===========================================================================
X = 16
stem(X, 1.0, 0.3, 0.24, "C05_Rubinek_Trzon", M_TRZON)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.85,
                                      location=(X, 0, 1.35))
rubin = bpy.context.active_object
rubin.scale = (1.0, 1.0, 0.75)
finish(rubin, "C05_Rubinek_KapeluszGlow", M_RUBIN)

# ===========================================================================
# 6) SZMARAGDZIAK (8) — kapelusz z wiązki zielonych kryształów
# ===========================================================================
X = 20
stem(X, 1.0, 0.32, 0.26, "C06_Szmaragdziak_Trzon", M_TRZON)
szmaragdy = []
szmaragdy.append(shard(X, 0, 1.0, 1.3, 0.4))
szmaragdy.append(shard(X + 0.4, 0.2, 1.0, 0.9, 0.28, tilt=(12, -18)))
szmaragdy.append(shard(X - 0.38, -0.15, 1.0, 0.8, 0.26, tilt=(-14, 12)))
szmaragdy.append(shard(X + 0.1, -0.35, 1.0, 0.6, 0.2, tilt=(18, 6)))
join_as(szmaragdy, "C06_Szmaragdziak_KrysztalyGlow", M_SZMARAGD)

# ===========================================================================
# 7) AMETYSTÓWKA (11) — otwarta GEODA: skalna czasza, a w niej wieniec
#    fioletowych kryształów
# ===========================================================================
X = 24
stem(X, 1.1, 0.36, 0.3, "C07_Ametystowka_Trzon", M_TRZON_C)
bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5, radius=1.05,
                                     location=(X, 0, 1.2))
geoda = bpy.context.active_object
geoda.scale = (1.0, 1.0, 0.45)
finish(geoda, "C07_Ametystowka_Geoda", M_GEODA)
wieniec = []
for i in range(7):
    a = math.radians(i * (360 / 7))
    d = 0.62
    bpy.ops.mesh.primitive_cone_add(
        vertices=5, radius1=0.16, radius2=0.02, depth=0.55,
        location=(X + math.cos(a) * d, math.sin(a) * d, 1.55),
        rotation=(math.sin(a) * math.radians(16), -math.cos(a) * math.radians(16), 0))
    wieniec.append(bpy.context.active_object)
wieniec.append(shard(X, 0, 1.35, 0.7, 0.2))
join_as(wieniec, "C07_Ametystowka_WieniecGlow", M_AMETYST)

# ===========================================================================
# 8) OBSYDIANKA (15) — wulkaniczne szkło: czarny ostry stożek z żarzącymi
#    pęknięciami lawy
# ===========================================================================
X = 28
stem(X, 1.0, 0.34, 0.26, "C08_Obsydianka_Trzon", M_TRZON_C)
bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=1.0, radius2=0.05,
                                depth=1.5, location=(X, 0, 1.75))
finish(bpy.context.active_object, "C08_Obsydianka_Kapelusz", M_OBSYDIAN)
dots_on_dome(X, 1.15, 0.9, 0.4, "C08_Obsydianka_LawaGlow", M_LAWA,
             [(40, 0.75, 0.1), (160, 0.8, 0.09), (280, 0.7, 0.1)])

# ===========================================================================
# 9) KRYSZTAŁAK (20) — cały z kryształu: lodowo świecący od stóp po kapelusz,
#    wokół dryfują odpryski (nazwa "Drobiny" = FxClient je lewituje)
# ===========================================================================
X = 32
stem(X, 1.3, 0.32, 0.24, "C09_Krysztalak_TrzonGlow", M_KRYSZTAL)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1.0,
                                      location=(X, 0, 1.7))
krysztal_kap = bpy.context.active_object
krysztal_kap.scale = (1.0, 1.0, 0.65)
finish(krysztal_kap, "C09_Krysztalak_KapeluszGlow", M_KRYSZTAL)
odpryski = []
for (a_deg, d, z, r) in [(30, 1.4, 1.9, 0.12), (140, 1.6, 1.4, 0.1),
                         (250, 1.45, 2.2, 0.11), (340, 1.3, 1.1, 0.09)]:
    a = math.radians(a_deg)
    o = mini_sphere(X + math.cos(a) * d, math.sin(a) * d, z, r, squash=0.7)
    odpryski.append(o)
join_as(odpryski, "C09_Krysztalak_DrobinyGlow", M_KRYSZTAL)

# ===========================================================================
# 10) DIAMENTOWY KAPELUSZ (28) — finał: kapelusz w SZLIFIE BRYLANTOWYM
#     (korona + pawilon), wirująca iskra (Halo) i dryfujące diamenciki
# ===========================================================================
X = 36
stem(X, 1.4, 0.4, 0.3, "C10_Diament_Trzon", M_TRZON)
# pawilon: odwrócony stożek (czubkiem w dół, styka się z trzonem)
bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=1.15, radius2=0.02,
                                depth=0.85, location=(X, 0, 1.85),
                                rotation=(math.radians(180), 0, 0))
finish(bpy.context.active_object, "C10_Diament_PawilonGlow", M_DIAMENT)
# korona: ścięty stożek z płaskim blatem
bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=1.15, radius2=0.6,
                                depth=0.5, location=(X, 0, 2.52))
finish(bpy.context.active_object, "C10_Diament_KoronaGlow", M_DIAMENT)
# wirująca iskra wokół talii brylantu
bpy.ops.mesh.primitive_torus_add(major_radius=1.45, minor_radius=0.05,
                                 major_segments=16, minor_segments=5,
                                 location=(X, 0, 2.27),
                                 rotation=(math.radians(12), 0, 0))
finish(bpy.context.active_object, "C10_Diament_IskraHaloGlow", M_DIAMENT)
diamenciki = []
for (a_deg, d, z) in [(20, 1.7, 2.9), (130, 1.9, 1.7), (240, 1.75, 2.5), (320, 2.0, 2.0)]:
    a = math.radians(a_deg)
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.13,
                                          location=(X + math.cos(a) * d,
                                                    math.sin(a) * d, z))
    diamenciki.append(bpy.context.active_object)
join_as(diamenciki, "C10_Diament_DrobinyGlow", M_DIAMENT)

print("Gotowe! Kolekcja:", COLLECTION_NAME,
      "— 10 gatunków Kryształowej Groty. *Glow → Material=Neon;",
      "Rubin/Szmaragd/Kryształak/Diament ładnie wyglądają też z Transparency ~0.15.")
