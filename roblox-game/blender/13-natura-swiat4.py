# Pick a Shroom — NATURA ŚWIATA 4 (Kryształowa Grota): jaskiniowy krajobraz
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_NaturaSwiat4" (elementy obok siebie co 7 j.).
#
# Klimat: podziemna grota — ciemne skały jako tło, kryształy jako światło.
# Zasada: kamień jest matowy i ciemny, żeby każda żyła ametystu grała.
# Nazwy z "Halo"/"Drobiny"/"Glow" łapie FxClient (obrót/lewitacja/iskry).
# Styl: klockowy, płaskie cieniowanie. Części OSOBNO — nie łącz ich!

import bpy
import math
import random

COLLECTION_NAME = "PickAShroom_NaturaSwiat4"
random.seed(88)

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


def blob(x, y, z, r, squash=0.9):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r,
                                          location=(x, y, z))
    obj = bpy.context.active_object
    obj.scale = (1.0, 1.0, squash)
    return obj


def mini_sphere(x, y, z, r, squash=1.0):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=6, ring_count=4, radius=r,
                                         location=(x, y, z))
    obj = bpy.context.active_object
    if squash != 1.0:
        obj.scale = (1.0, 1.0, squash)
    return obj


def spike(x, y, z, height, r, vertices=6, tilt=(0, 0), upside_down=False):
    """Stalagmit/kryształ: zbieżny słup."""
    rot_x = math.radians(180) if upside_down else 0
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices, radius1=r, radius2=r * 0.1, depth=height,
        location=(x, y, z + (-height / 2 if upside_down else height / 2)),
        rotation=(rot_x + math.radians(tilt[0]), math.radians(tilt[1]),
                  math.radians(random.uniform(0, 360))))
    return bpy.context.active_object


# --- materiały --------------------------------------------------------------
M_SKALA = make_material("N4_Skala", (0.30, 0.30, 0.37))
M_SKALA_J = make_material("N4_SkalaJasna", (0.44, 0.43, 0.50))
M_NACIEK = make_material("N4_Naciek", (0.56, 0.52, 0.48))
M_AMETYST = make_material("N4_AmetystGlow", (0.62, 0.38, 0.92), glow=2.0)
M_CYJAN = make_material("N4_CyjanGlow", (0.40, 0.85, 0.95), glow=2.2)
M_ROZ = make_material("N4_RozGlow", (0.95, 0.55, 0.80), glow=1.8)
M_WODA = make_material("N4_Woda", (0.10, 0.22, 0.32), roughness=0.03)
M_MECH_SW = make_material("N4_MechSwietlnyGlow", (0.55, 0.95, 0.65), glow=3.0)
M_ZLOTO = make_material("N4_ZylkaZlota", (0.88, 0.72, 0.34), roughness=0.3)

# ===========================================================================
# 1) KOLUMNA JASKINIOWA — „drzewo" groty: gruby naciek od ziemi w górę,
#    z przewężeniem w talii (jak klepsydra) i kryształkami u podstawy
# ===========================================================================
X = 0
bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=1.1, radius2=0.45,
                                depth=2.6, location=(X, 0, 1.3))
finish(bpy.context.active_object, "N401_Kolumna_Dol", M_NACIEK)
bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.45, radius2=1.0,
                                depth=2.4, location=(X, 0, 3.8))
finish(bpy.context.active_object, "N401_Kolumna_Gora", M_NACIEK)
podstawa = []
for (a_deg, d, h) in [(30, 1.1, 0.7), (140, 1.25, 0.5), (260, 1.05, 0.6)]:
    a = math.radians(a_deg)
    podstawa.append(spike(X + math.cos(a) * d, math.sin(a) * d, 0, h, 0.2))
join_as(podstawa, "N401_Kolumna_KrysztalkiGlow", M_AMETYST)

# ===========================================================================
# 2) STALAGMIT DUŻY — samotny, gruby, lekko pochylony
# ===========================================================================
X = 7
finish(spike(X, 0, 0, 3.4, 0.85, vertices=7, tilt=(4, -3)),
       "N402_Stalagmit_Duzy", M_SKALA_J)

# ===========================================================================
# 3) GRUPKA STALAGMITÓW — trzy „zęby" różnej wysokości (wypełniacz poboczy)
# ===========================================================================
X = 12
zeby = [spike(X, 0, 0, 1.8, 0.45), spike(X + 0.8, 0.35, 0, 1.1, 0.32, tilt=(6, 8)),
        spike(X - 0.7, -0.3, 0, 0.8, 0.28, tilt=(-7, 4))]
join_as(zeby, "N403_Stalagmity_Zeby", M_SKALA_J)

# ===========================================================================
# 4) WIELKI KRYSZTAŁ — landmark: monolit z ametystu wyrastający z rumowiska,
#    otoczony wirującym pierścieniem drobin (Halo = FxClient go kręci)
# ===========================================================================
X = 18
finish(spike(X, 0, 0, 4.6, 1.0, tilt=(3, -5)), "N404_Monolit_KrysztalGlow", M_AMETYST)
rumowisko = [blob(X + 0.9, 0.4, 0.4, 0.6, squash=0.7),
             blob(X - 0.8, -0.3, 0.35, 0.55, squash=0.65),
             blob(X + 0.1, -0.85, 0.3, 0.45, squash=0.6)]
join_as(rumowisko, "N404_Monolit_Rumowisko", M_SKALA)
bpy.ops.mesh.primitive_torus_add(major_radius=1.9, minor_radius=0.05,
                                 major_segments=16, minor_segments=5,
                                 location=(X, 0, 2.6),
                                 rotation=(math.radians(14), 0, 0))
finish(bpy.context.active_object, "N404_Monolit_HaloGlow", M_CYJAN)

# ===========================================================================
# 5) BRAMA KRYSTALICZNA — dwa kryształy pochylone ku sobie tworzą przejście
#    (postaw nad ścieżką — przebieganie pod nią to darmowa frajda)
# ===========================================================================
X = 25
finish(spike(X - 1.7, 0, 0, 4.4, 0.7, tilt=(0, 22)), "N405_Brama_Lewy", M_CYJAN)
finish(spike(X + 1.7, 0, 0, 4.4, 0.7, tilt=(0, -22)), "N405_Brama_Prawy", M_CYJAN)

# ===========================================================================
# 6) ŻYŁA KRYSZTAŁOWA — niski grzbiet skalny z rządkiem małych kryształków
#    (akcent wzdłuż poboczy ścieżki)
# ===========================================================================
X = 31
grzbiet = [blob(X - 1.0, 0, 0.3, 0.55, squash=0.5), blob(X, 0.1, 0.35, 0.6, squash=0.55),
           blob(X + 1.0, -0.05, 0.3, 0.5, squash=0.5)]
join_as(grzbiet, "N406_Zyla_Grzbiet", M_SKALA)
zylki = []
for i in range(5):
    zylki.append(spike(X - 1.1 + i * 0.55, random.uniform(-0.15, 0.15), 0.4,
                       random.uniform(0.4, 0.75), 0.14))
join_as(zylki, "N406_Zyla_KrysztalkiGlow", M_ROZ)

# ===========================================================================
# 7) JEZIORKO PODZIEMNE — lustrzana tafla z kryształkami na brzegu
# ===========================================================================
X = 37
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=1.9, depth=0.06,
                                    location=(X, 0, 0.06))
finish(bpy.context.active_object, "N407_Jeziorko_Tafla", M_WODA)
brzeg = []
for (a_deg, h) in [(20, 0.5), (95, 0.35), (200, 0.6), (300, 0.4)]:
    a = math.radians(a_deg)
    brzeg.append(spike(X + math.cos(a) * 1.85, math.sin(a) * 1.85, 0, h, 0.16))
join_as(brzeg, "N407_Jeziorko_BrzegGlow", M_CYJAN)

# ===========================================================================
# 8) RUMOWISKO GŁAZÓW — kupa ciemnych brył ze złotą żyłką (mineralna nutka)
# ===========================================================================
X = 43
glazy = [blob(X, 0, 0.6, 0.9, squash=0.8), blob(X + 0.9, 0.4, 0.4, 0.6, squash=0.7),
         blob(X - 0.8, -0.35, 0.35, 0.55, squash=0.65), blob(X + 0.2, -0.8, 0.3, 0.4, squash=0.6)]
join_as(glazy, "N408_Rumowisko_Glazy", M_SKALA)
zlote = [mini_sphere(X + 0.3, 0.2, 1.15, 0.1, squash=0.5),
         mini_sphere(X - 0.4, 0.1, 0.95, 0.08, squash=0.5),
         mini_sphere(X + 0.75, -0.2, 0.75, 0.09, squash=0.5)]
join_as(zlote, "N408_Rumowisko_ZlotaZylka", M_ZLOTO)

# ===========================================================================
# 9) MECH ŚWIETLNY — płat jarzącego się mchu na płaskiej skale
#    (jaskiniowa „lampka" przy ścieżce)
# ===========================================================================
X = 48
finish(blob(X, 0, 0.25, 0.85, squash=0.35), "N409_MechSwietlny_Skala", M_SKALA_J)
plamki = []
for i in range(7):
    a = math.radians(random.uniform(0, 360))
    d = random.uniform(0.1, 0.6)
    plamki.append(mini_sphere(X + math.cos(a) * d, math.sin(a) * d,
                              0.48 + random.uniform(0, 0.06),
                              random.uniform(0.08, 0.15), squash=0.4))
join_as(plamki, "N409_MechSwietlny_PlamkiGlow", M_MECH_SW)

# ===========================================================================
# 10) KWIAT GEODOWY — „kwiat" groty: skalna czasza z wieńcem różowych
#     kryształków (niski akcent jak kwiatek w Lesie, tylko kamienny)
# ===========================================================================
X = 52
bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5, radius=0.55,
                                     location=(X, 0, 0.3))
czasza = bpy.context.active_object
czasza.scale = (1.0, 1.0, 0.45)
finish(czasza, "N410_KwiatGeodowy_Czasza", M_SKALA)
platki = []
for i in range(6):
    a = math.radians(i * 60)
    platki.append(spike(X + math.cos(a) * 0.32, math.sin(a) * 0.32, 0.42,
                        0.38, 0.1, tilt=(math.sin(a) * 14, -math.cos(a) * 14)))
platki.append(spike(X, 0, 0.45, 0.45, 0.11))
join_as(platki, "N410_KwiatGeodowy_PlatkiGlow", M_ROZ)

print("Gotowe! Kolekcja:", COLLECTION_NAME,
      "— 10 elementów natury Kryształowej Groty. *Glow → Material=Neon;",
      "tafla jeziorka ładna z Reflectance/SmoothPlastic.")
