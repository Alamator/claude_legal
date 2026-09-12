# Pick a Shroom — NATURA ŚWIATA 5 (Grzyboksiężyc): kosmiczny krajobraz
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_NaturaSwiat5" (elementy obok siebie co 7 j.).
#
# Klimat: księżycowa pustka z kosmiczną florą — grzybodrzewa zamiast drzew,
# kratery, lewitujące wyspy, meteoryt, świetlista trawa. Cuda są, ale
# dozowane: szare tło skał sprawia, że każdy glow gra podwójnie.
# Nazwy z "FloatingRock"/"Drobiny"/"Halo"/"Glow" łapie FxClient
# (lewitacja / obrót / iskry) — nie zmieniaj nazw przy imporcie!
# Styl: klockowy, płaskie cieniowanie. Części OSOBNO — nie łącz ich!

import bpy
import math
import random

COLLECTION_NAME = "PickAShroom_NaturaSwiat5"
random.seed(66)

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


def shard(x, y, z, height, r, tilt=(0, 0)):
    """Kryształowy odłamek: wydłużony, pochylony ośmiokątny słup."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=6, radius1=r, radius2=r * 0.15, depth=height,
        location=(x, y, z + height / 2),
        rotation=(math.radians(tilt[0]), math.radians(tilt[1]),
                  math.radians(random.uniform(0, 360))))
    return bpy.context.active_object


# --- materiały --------------------------------------------------------------
M_SKALA = make_material("N5_Skala", (0.56, 0.56, 0.62))
M_SKALA_C = make_material("N5_SkalaCiemna", (0.36, 0.36, 0.42))
M_REGOLIT = make_material("N5_Regolit", (0.46, 0.46, 0.52))
M_PIEN = make_material("N5_GrzybodrzewoPien", (0.78, 0.79, 0.86))
M_KORONA = make_material("N5_KoronaGlow", (0.55, 1.0, 0.72), glow=2.5)
M_KROPKI = make_material("N5_Kropki", (0.94, 0.97, 1.0))
M_KRYSZTAL = make_material("N5_KrysztalGlow", (0.70, 0.85, 1.0), glow=2.0)
M_FIOLET = make_material("N5_FioletGlow", (0.72, 0.55, 1.0), glow=1.8)
M_KWIAT = make_material("N5_GwiezdnyKwiatGlow", (1.0, 0.90, 0.55), glow=3.0)
M_LODYGA = make_material("N5_Lodyga", (0.60, 0.66, 0.62))
M_TRAWA = make_material("N5_Trawa", (0.62, 0.72, 0.70))
M_TRAWA_G = make_material("N5_TrawaKoncowkiGlow", (0.55, 1.0, 0.85), glow=4.0)
M_METEOR = make_material("N5_Meteor", (0.24, 0.22, 0.26))
M_ZAR = make_material("N5_ZarGlow", (1.0, 0.55, 0.25), glow=5.0)
M_SPALENIZNA = make_material("N5_Spalenizna", (0.20, 0.19, 0.22))
M_PYL = make_material("N5_PylGlow", (0.80, 0.90, 1.0), glow=3.0)

# ===========================================================================
# 1) GRZYBODRZEWO — „drzewo" Księżyca: wysoki blady pień, świecąca
#    grzybowa korona z kropkami (zamiast liści)
# ===========================================================================
X = 0
bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.5, radius2=0.3,
                                depth=4.6, location=(X, 0, 2.3))
finish(bpy.context.active_object, "N501_Grzybodrzewo_Pien", M_PIEN)
bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5, radius=2.0,
                                     location=(X, 0, 4.9))
korona = bpy.context.active_object
korona.scale = (1.0, 1.0, 0.55)
finish(korona, "N501_Grzybodrzewo_KoronaGlow", M_KORONA)
kropki = []
for (a_deg, d, r) in [(30, 0.5, 0.28), (140, 0.65, 0.24), (250, 0.45, 0.26), (330, 0.75, 0.2)]:
    a = math.radians(a_deg)
    dd = 2.0 * d
    dz = 0.55 * math.sqrt(max(4.0 - dd * dd, 0.0))
    kropki.append(mini_sphere(X + math.cos(a) * dd, math.sin(a) * dd,
                              4.9 + dz, r, squash=0.5))
join_as(kropki, "N501_Grzybodrzewo_Kropki", M_KROPKI)

# ===========================================================================
# 2) IGLICA KRYSZTAŁOWA — smukła wieżyczka z 3 odłamków (drugie „drzewo")
# ===========================================================================
X = 7
finish(shard(X, 0, 0, 4.2, 0.55), "N502_Iglica_Glowna", M_FIOLET)
finish(shard(X + 0.7, 0.3, 0, 2.4, 0.35, tilt=(8, -10)), "N502_Iglica_Bok1", M_FIOLET)
finish(shard(X - 0.6, -0.35, 0, 1.8, 0.3, tilt=(-9, 7)), "N502_Iglica_Bok2", M_KRYSZTAL)

# ===========================================================================
# 3) KRATER — pierścień wału z ciemnym dnem (charakter terenu Księżyca)
# ===========================================================================
X = 14
bpy.ops.mesh.primitive_torus_add(major_radius=2.0, minor_radius=0.55,
                                 major_segments=12, minor_segments=5,
                                 location=(X, 0, 0.25))
wal = bpy.context.active_object
wal.scale = (1.0, 1.0, 0.55)
finish(wal, "N503_Krater_Wal", M_REGOLIT)
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=1.7, depth=0.08,
                                    location=(X, 0, 0.1))
finish(bpy.context.active_object, "N503_Krater_Dno", M_SKALA_C)

# ===========================================================================
# 4) LEWITUJĄCA WYSPA — skała dryfująca w powietrzu (FloatingRock = sama
#    się unosi), z trawiastą czapą, kryształkami od spodu i pierścieniem
#    (Halo = sam wiruje). Sztandarowy landmark świata.
# ===========================================================================
X = 21
wyspa = blob(X, 0, 3.2, 1.4, squash=0.8)
finish(wyspa, "N504_Wyspa_FloatingRockSkala", M_SKALA)
czapa = blob(X, 0, 4.05, 1.25, squash=0.3)
finish(czapa, "N504_Wyspa_FloatingRockCzapa", M_KORONA)
sople = []
for (a_deg, d, h) in [(40, 0.6, 0.9), (170, 0.5, 0.7), (290, 0.65, 0.8)]:
    a = math.radians(a_deg)
    bpy.ops.mesh.primitive_cone_add(
        vertices=5, radius1=0.22, radius2=0.02, depth=h,
        location=(X + math.cos(a) * d, math.sin(a) * d, 2.4 - h / 2),
        rotation=(math.radians(180), 0, 0))
    sople.append(bpy.context.active_object)
join_as(sople, "N504_Wyspa_FloatingRockSople", M_KRYSZTAL)
bpy.ops.mesh.primitive_torus_add(major_radius=2.2, minor_radius=0.06,
                                 major_segments=16, minor_segments=5,
                                 location=(X, 0, 3.3),
                                 rotation=(math.radians(10), 0, 0))
finish(bpy.context.active_object, "N504_Wyspa_HaloGlow", M_PYL)

# ===========================================================================
# 5) ŁUK SKALNY — naturalna brama z trzech głazów (fajnie przebiegać pod nim)
# ===========================================================================
X = 28
for (dx, name) in [(-1.6, "N505_Luk_FilarLewy"), (1.6, "N505_Luk_FilarPrawy")]:
    bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=0.75, radius2=0.5,
                                    depth=3.4, location=(X + dx, 0, 1.7))
    finish(bpy.context.active_object, name, M_SKALA)
bpy.ops.mesh.primitive_cube_add(size=1, location=(X, 0, 3.6))
belka = bpy.context.active_object
belka.scale = (4.4, 1.0, 0.8)
join_as([belka], "N505_Luk_Belka", M_REGOLIT)

# ===========================================================================
# 6) KĘPA KRYSZTAŁÓW — trzy miętowe odłamki (świecący akcent poboczy)
# ===========================================================================
X = 35
finish(shard(X, 0, 0, 1.6, 0.3), "N506_Krysztaly_Duzy", M_KRYSZTAL)
finish(shard(X + 0.5, 0.25, 0, 1.0, 0.22, tilt=(10, -14)), "N506_Krysztaly_Sredni", M_KRYSZTAL)
finish(shard(X - 0.45, -0.2, 0, 0.7, 0.18, tilt=(-12, 9)), "N506_Krysztaly_Maly", M_FIOLET)

# ===========================================================================
# 7) GWIEZDNY KWIAT — pięcioramienna świecąca gwiazdka na łodyżce
# ===========================================================================
X = 39
bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.05, radius2=0.035,
                                depth=1.1, location=(X, 0, 0.55))
finish(bpy.context.active_object, "N507_Kwiat_Lodyga", M_LODYGA)
platki = []
for i in range(5):
    a = math.radians(i * 72)
    p = mini_sphere(X + math.cos(a) * 0.26, math.sin(a) * 0.26, 1.15, 0.14)
    p.scale = (1.5, 0.6, 0.35)
    bpy.context.view_layer.objects.active = p
    p.rotation_euler = (0, 0, a)
    platki.append(p)
join_as(platki, "N507_Kwiat_PlatkiGlow", M_KWIAT)
finish(mini_sphere(X, 0, 1.2, 0.12), "N507_Kwiat_SrodekGlow", M_KWIAT)

# ===========================================================================
# 8) METEORYT — na wpół wbity, przekrzywiony, z żarzącymi pęknięciami
#    i kręgiem spalenizny
# ===========================================================================
X = 43
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=1.5, depth=0.06,
                                    location=(X, 0, 0.08))
finish(bpy.context.active_object, "N508_Meteoryt_Spalenizna", M_SPALENIZNA)
meteor = blob(X, 0, 0.55, 0.95, squash=0.85)
meteor.rotation_euler = (math.radians(24), math.radians(12), 0)
finish(meteor, "N508_Meteoryt_Skala", M_METEOR)
zar = []
for (a_deg, d, z) in [(30, 0.6, 0.75), (150, 0.7, 0.55), (260, 0.5, 0.9)]:
    a = math.radians(a_deg)
    z_dot = mini_sphere(X + math.cos(a) * d, math.sin(a) * d, z, 0.12, squash=0.5)
    zar.append(z_dot)
join_as(zar, "N508_Meteoryt_ZarGlow", M_ZAR)

# ===========================================================================
# 9) KOSMICZNA TRAWA — kępka bladych źdźbeł ze świecącymi końcówkami
#    (jak światłowody)
# ===========================================================================
X = 47
zdzbla, koncowki = [], []
for i in range(6):
    a = math.radians(i * 60 + 15)
    tilt = math.radians(random.uniform(8, 20))
    dl = random.uniform(0.7, 1.05)
    bpy.ops.mesh.primitive_cone_add(
        vertices=4, radius1=0.045, radius2=0.01, depth=dl,
        location=(X + math.cos(a) * 0.14, math.sin(a) * 0.14, dl / 2),
        rotation=(math.sin(a) * tilt, -math.cos(a) * tilt, 0))
    zdzbla.append(bpy.context.active_object)
    tip_off = dl * 0.5 + 0.04
    koncowki.append(mini_sphere(
        X + math.cos(a) * 0.14 + math.sin(a) * math.sin(tilt) * dl * 0.5,
        math.sin(a) * 0.14 - math.cos(a) * math.sin(tilt) * dl * 0.5,
        dl * math.cos(tilt) * 0.98, 0.07))
join_as(zdzbla, "N509_Trawa_Zdzbla", M_TRAWA)
join_as(koncowki, "N509_Trawa_KoncowkiGlow", M_TRAWA_G)

# ===========================================================================
# 10) GEJZER PYŁU — mały stożek-komin, nad nim słup dryfujących drobin
#     (nazwa "Drobiny" = FxClient sam je kołysze — żywy element terenu)
# ===========================================================================
X = 51
bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.9, radius2=0.35,
                                depth=0.8, location=(X, 0, 0.4))
finish(bpy.context.active_object, "N510_Gejzer_Komin", M_REGOLIT)
drobiny = []
for (z, r, off) in [(1.2, 0.12, 0.05), (1.8, 0.10, -0.12), (2.4, 0.09, 0.1),
                    (3.0, 0.07, -0.06), (3.5, 0.06, 0.14)]:
    drobiny.append(mini_sphere(X + off, -off * 0.6, z, r))
join_as(drobiny, "N510_Gejzer_DrobinyGlow", M_PYL)

print("Gotowe! Kolekcja:", COLLECTION_NAME,
      "— 10 elementów natury Grzyboksiężyca. *Glow → Material=Neon;",
      "FloatingRock/Halo/Drobiny animuje FxClient.")
