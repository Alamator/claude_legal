# Pick a Shroom — STANOWISKO Z JAJEM PETÓW (gacha-ołtarzyk), low-poly
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_GniazdoJajo".
#
# Jeden uniwersalny model dla wszystkich światów — części akcentowe
# (Cetki, Krag, Drobiny, kule latarni) przemalowujesz w Roblox na kolor
# akcentu świata (theme.accent z GameConfig). Skorupka zostaje kremowa.
#
# Animacje za darmo (FxClient, po nazwach): "…KragHaloGlow" WIRUJE wokół
# podestu (magiczny krąg gachy), "…DrobinyGlow" dryfują wokół jaja,
# wszystko z "Glow" sypie iskrami. W Roblox: części *Glow → Material=Neon.
# Styl: klockowy, płaskie cieniowanie. Części OSOBNO — nie łącz ich!

import bpy
import math
import random

COLLECTION_NAME = "PickAShroom_GniazdoJajo"
random.seed(15)

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


def cylinder(x, y, z, r, h, vertices=10):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=r, depth=h,
                                        location=(x, y, z))
    return bpy.context.active_object


def mini_sphere(x, y, z, r, squash=1.0, segments=6):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=4,
                                         radius=r, location=(x, y, z))
    obj = bpy.context.active_object
    if squash != 1.0:
        obj.scale = (1.0, 1.0, squash)
    return obj


# --- materiały --------------------------------------------------------------
M_KAMIEN = make_material("GJ_Kamien", (0.52, 0.51, 0.56))
M_KAMIEN_J = make_material("GJ_KamienJasny", (0.66, 0.64, 0.68))
M_GALAZKI = make_material("GJ_Galazki", (0.42, 0.29, 0.17))
M_WYSCIELENIE = make_material("GJ_Wyscielenie", (0.42, 0.58, 0.28))
M_SKORUPKA = make_material("GJ_Skorupka", (0.97, 0.94, 0.86), roughness=0.35)
M_CETKI = make_material("GJ_Cetki", (0.45, 0.85, 0.65))          # kolor akcentu świata
M_DREWNO = make_material("GJ_Drewno", (0.55, 0.38, 0.22))
M_KRAG = make_material("GJ_KragGlow", (0.45, 0.95, 0.70), glow=3.0)
M_LATARNIA = make_material("GJ_LatarniaGlow", (1.0, 0.85, 0.45), glow=4.0)
M_DROBINY = make_material("GJ_DrobinyGlow", (0.75, 1.0, 0.85), glow=4.0)

# ===========================================================================
# PODEST — dwa kamienne stopnie (okrągłe, fasetowane)
# ===========================================================================
finish(cylinder(0, 0, 0.25, 2.6, 0.5, vertices=10), "GJ_Podest_StopienDolny", M_KAMIEN)
finish(cylinder(0, 0, 0.7, 1.9, 0.4, vertices=10), "GJ_Podest_StopienGorny", M_KAMIEN_J)

# ===========================================================================
# GNIAZDO — wieniec z gałązek (przekrzywione walce po okręgu) + zielone
# wyścielenie z mchu w środku
# ===========================================================================
galazki = []
for i in range(9):
    a = math.radians(i * 40)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=6, radius=0.11, depth=1.5,
        location=(math.cos(a) * 1.05, math.sin(a) * 1.05, 1.05),
        rotation=(math.radians(90 + random.uniform(-14, 14)), 0,
                  a + math.radians(90 + random.uniform(-18, 18))))
    galazki.append(bpy.context.active_object)
join_as(galazki, "GJ_Gniazdo_Galazki", M_GALAZKI)

wyscielenie = mini_sphere(0, 0, 1.0, 1.0, squash=0.28, segments=8)
finish(wyscielenie, "GJ_Gniazdo_Wyscielenie", M_WYSCIELENIE)

# ===========================================================================
# JAJO — duży fasetowany owal w cętki (cętki przemalujesz per świat)
# ===========================================================================
bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=6, radius=0.95,
                                     location=(0, 0, 2.15))
jajo = bpy.context.active_object
jajo.scale = (1.0, 1.0, 1.3)
finish(jajo, "GJ_Jajo_Skorupka", M_SKORUPKA)

cetki = []
for (a_deg, h_frac, size) in [(20, 0.35, 0.22), (110, 0.1, 0.18), (200, 0.45, 0.2),
                              (290, -0.05, 0.17), (65, -0.35, 0.19), (245, -0.3, 0.16)]:
    a = math.radians(a_deg)
    z_off = h_frac * 1.15
    r_at = 0.95 * math.sqrt(max(1 - (h_frac ** 2), 0.15))
    c = mini_sphere(math.cos(a) * r_at, math.sin(a) * r_at, 2.15 + z_off, size, squash=0.5)
    cetki.append(c)
join_as(cetki, "GJ_Jajo_Cetki", M_CETKI)

# ===========================================================================
# MAGICZNY KRĄG — świecący pierścień wokół podestu ("Halo" = sam WIRUJE)
# + 4 kamyki-runy na obwodzie
# ===========================================================================
bpy.ops.mesh.primitive_torus_add(major_radius=3.1, minor_radius=0.09,
                                 major_segments=16, minor_segments=5,
                                 location=(0, 0, 0.15))
finish(bpy.context.active_object, "GJ_KragHaloGlow", M_KRAG)
runy = []
for i in range(4):
    a = math.radians(i * 90 + 45)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(math.cos(a) * 3.1,
                                                      math.sin(a) * 3.1, 0.35))
    runa = bpy.context.active_object
    runa.scale = (0.35, 0.35, 0.55)
    runa.rotation_euler = (0, 0, a)
    runy.append(runa)
join_as(runy, "GJ_KragRunyGlow", M_KRAG)

# ===========================================================================
# LATARNIE — dwa drewniane słupki z wiszącymi kulami światła po bokach
# ===========================================================================
sloupki = []
kule = []
for side in (-1, 1):
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.14, depth=3.4,
                                        location=(side * 2.4, -2.2, 1.7))
    sloupki.append(bpy.context.active_object)
    bpy.ops.mesh.primitive_cube_add(size=1, location=(side * 2.4, -2.2, 3.5))
    ramie = bpy.context.active_object
    ramie.scale = (0.15, 0.7, 0.15)
    sloupki.append(ramie)
    kule.append(mini_sphere(side * 2.4, -2.75, 3.2, 0.3, segments=8))
join_as(sloupki, "GJ_Latarnie_Slupki", M_DREWNO)
join_as(kule, "GJ_Latarnie_KuleGlow", M_LATARNIA)

# ===========================================================================
# DROBINY — trzy iskry dryfujące wokół jaja ("Drobiny" = same się kołyszą)
# ===========================================================================
drobiny = []
for (a_deg, d, z) in [(30, 1.6, 2.6), (160, 1.8, 2.1), (280, 1.5, 3.0)]:
    a = math.radians(a_deg)
    drobiny.append(mini_sphere(math.cos(a) * d, math.sin(a) * d, z, 0.11))
join_as(drobiny, "GJ_DrobinyGlow", M_DROBINY)

print("Gotowe! Kolekcja:", COLLECTION_NAME,
      "— stanowisko z jajem. Cetki/Krag/Drobiny/Kule przemaluj na akcent",
      "świata; *Glow → Material=Neon. Krąg wiruje, drobiny dryfują (FxClient).")
