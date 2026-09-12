# Pick a Shroom — 5 PETÓW ŚWIATA 5 (Grzyboksiężyc, endgame), low-poly
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_PetySwiat5" z 5 petami obok siebie (co 4 j.).
#
# Kolejność = pozycja w puli jaja z GameConfig = rzadkość:
#   1. Kosmiczny Grzybek (Rzadki 55%)      — grzybkowy ludek ze świecącymi
#                                            kraterkami i zarodnikami
#   2. Lunar Puf         (B. Rzadki 34%)   — senna kulka księżycowa z kraterami
#                                            i WŁASNYM krążącym księżycykiem
#   3. Meteorek          (Epicki 7,5%)     — skalny pędziwiatr z żarem w pęknięciach
#                                            i ognistym warkoczem
#   4. Gwiezdny Ślimak   (Legendarny 3,4%) — muszla-galaktyka ze spiralą gwiazd
#                                            i wirującym pierścieniem pyłu
#   5. Czarnodziurek     (SEKRET 0,1%)     — kieszonkowa czarna dziura: WIRUJĄCY
#                                            dysk akrecyjny, zagięte światło,
#                                            wciągana materia. Finał kolekcji.
#
# Pety lewitują przy graczu, więc są MAŁE (~1,5 j. wzrostu — 1 j. ≈ 1 stud).
# Animacje za darmo (FxClient, po nazwach): "…Warkocz…"/"…Drobiny…"/"…Materia…"/
# "…Ksiezyc…" dryfują, "…Pierscien…"/"…Dysk…" wirują, wszystko z "Glow" sypie
# iskrami (Material = Neon). Styl: klockowy, płaskie cieniowanie.
# Części OSOBNO — nie łącz ich!

import bpy
import math
import random

COLLECTION_NAME = "PickAShroom_PetySwiat5"
random.seed(20)

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


def sphere(x, y, z, r, squash=1.0, segments=8, rings=5):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings,
                                         radius=r, location=(x, y, z))
    obj = bpy.context.active_object
    if squash != 1.0:
        obj.scale = (1.0, 1.0, squash)
    return obj


def bead(x, y, z, r):
    """Małe kulki (oczy, kropki) — jeszcze mniej segmentów."""
    return sphere(x, y, z, r, segments=6, rings=4)


def cone(x, y, z, r, h, rot=(0, 0, 0), vertices=6):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r, radius2=0.0,
                                    depth=h, location=(x, y, z), rotation=rot)
    return bpy.context.active_object


# --- materiały wspólne -------------------------------------------------------
M_OKO = make_material("PET_Oko", (0.06, 0.06, 0.07), roughness=0.3)
M_POLICZEK = make_material("PET_Policzek", (0.95, 0.55, 0.60))

# ===========================================================================
# PET 1 — KOSMICZNY GRZYBEK (Rzadki 55%) — grzybkowy ludek z fioletowym
# kapeluszem, na którym świecą kraterki; wokół dryfują zarodniki-gwiazdki
# ===========================================================================
X = 0.0
M_KG_KAP = make_material("P5K_Kapelusz", (0.38, 0.26, 0.60))
M_KG_KRATERKI = make_material("P5K_KraterkiGlow", (0.55, 0.90, 0.95), glow=2.2)
M_KG_CIALO = make_material("P5K_Cialo", (0.82, 0.80, 0.92))
M_KG_ZARODNIKI = make_material("P5K_ZarodnikiGlow", (0.75, 0.95, 1.0), glow=3.0)

finish(sphere(X, 0, 0.55, 0.36, squash=1.05), "P5_1_KosmicznyGrzybek_Cialo", M_KG_CIALO)
finish(sphere(X, 0, 0.95, 0.56, squash=0.62), "P5_1_KosmicznyGrzybek_Kapelusz", M_KG_KAP)
# świecące kraterki na kapeluszu (spłaszczone pierścienie-kulki)
kraterki = []
for (a_deg, d, s) in [(40, 0.28, 0.10), (160, 0.34, 0.08), (255, 0.26, 0.09),
                      (330, 0.18, 0.07)]:
    a = math.radians(a_deg)
    k = bead(X + math.cos(a) * d, math.sin(a) * d, 1.16, s)
    k.scale = (1.0, 1.0, 0.4)
    kraterki.append(k)
join_as(kraterki, "P5_1_KosmicznyGrzybek_KraterkiGlow", M_KG_KRATERKI)
nozki = [sphere(X - 0.16, 0.05, 0.12, 0.12, squash=0.7, segments=6, rings=4),
         sphere(X + 0.16, 0.05, 0.12, 0.12, squash=0.7, segments=6, rings=4)]
join_as(nozki, "P5_1_KosmicznyGrzybek_Nozki", M_KG_KAP)
# dryfujące zarodniki-gwiazdki ("Drobiny" = same się kołyszą)
zarodniki = []
for (a_deg, d, z) in [(60, 0.55, 0.95), (200, 0.58, 0.55), (315, 0.52, 1.10)]:
    a = math.radians(a_deg)
    zarodniki.append(bead(X + math.cos(a) * d, math.sin(a) * d, z, 0.05))
join_as(zarodniki, "P5_1_KosmicznyGrzybek_DrobinyZarodnikiGlow", M_KG_ZARODNIKI)
oczy = [bead(X - 0.13, 0.32, 0.60, 0.08), bead(X + 0.13, 0.32, 0.60, 0.08)]
join_as(oczy, "P5_1_KosmicznyGrzybek_Oczy", M_OKO)
policzki = [bead(X - 0.25, 0.28, 0.48, 0.055), bead(X + 0.25, 0.28, 0.48, 0.055)]
for p in policzki:
    p.scale = (1.0, 0.5, 0.7)
join_as(policzki, "P5_1_KosmicznyGrzybek_Policzki", M_POLICZEK)

# ===========================================================================
# PET 2 — LUNAR PUF (B. Rzadki 34%) — senna księżycowa kulka z kraterami,
# nocną czapeczką i WŁASNYM małym księżycem na orbicie ("Ksiezyc" = krąży)
# ===========================================================================
X = 4.0
M_LP_CIALO = make_material("P5L_CialoGlow", (0.88, 0.90, 0.96), roughness=0.6, glow=0.9)
M_LP_KRATERY = make_material("P5L_Kratery", (0.66, 0.70, 0.82))
M_LP_CZAPKA = make_material("P5L_Czapka", (0.24, 0.28, 0.52))
M_LP_KSIEZYC = make_material("P5L_KsiezycGlow", (1.0, 0.92, 0.60), glow=3.0)

finish(sphere(X, 0, 0.60, 0.46), "P5_2_LunarPuf_Cialo", M_LP_CIALO)
# kratery-wgłębienia (płaskie kulki w odcieniu cienia)
kratery = []
for (a_deg, z, s) in [(30, 0.45, 0.11), (150, 0.72, 0.09), (250, 0.52, 0.10),
                      (95, 0.88, 0.08), (330, 0.80, 0.07)]:
    a = math.radians(a_deg)
    k = bead(X + math.cos(a) * 0.40, math.sin(a) * 0.40, z, s)
    k.scale = (1.0, 1.0, 0.35)
    kratery.append(k)
join_as(kratery, "P5_2_LunarPuf_Kratery", M_LP_KRATERY)
# nocna czapeczka z pomponem (przekrzywiona)
czapka = cone(X + 0.14, 0, 1.12, 0.24, 0.42, rot=(0, math.radians(22), 0), vertices=7)
finish(czapka, "P5_2_LunarPuf_Czapeczka", M_LP_CZAPKA)
finish(bead(X + 0.30, 0, 1.28, 0.08), "P5_2_LunarPuf_Pompon", M_LP_KSIEZYC)
# własny księżyc na orbicie ("Ksiezyc" = FxClient sam go kołysze po orbicie)
finish(bead(X + 0.62, -0.25, 0.85, 0.10), "P5_2_LunarPuf_KsiezycMiniGlow", M_LP_KSIEZYC)
# senne zamknięte oczka (kreski) + ziewający dzióbek
oczka = []
for side in (-1, 1):
    o = bead(X + side * 0.15, 0.42, 0.66, 0.06)
    o.scale = (1.5, 0.4, 0.35)
    oczka.append(o)
join_as(oczka, "P5_2_LunarPuf_OczkaSpiace", M_OKO)
finish(bead(X, 0.46, 0.52, 0.05), "P5_2_LunarPuf_Buzia", M_LP_KRATERY)
policzki = [bead(X - 0.28, 0.36, 0.55, 0.05), bead(X + 0.28, 0.36, 0.55, 0.05)]
for p in policzki:
    p.scale = (1.0, 0.5, 0.7)
join_as(policzki, "P5_2_LunarPuf_Policzki", M_POLICZEK)

# ===========================================================================
# PET 3 — METEOREK (Epicki 7,5%) — skalny pędziwiatr: ciemny głaz z żarem
# w pęknięciach, ognisty WARKOCZ lotu i dryfujące iskry żaru
# ===========================================================================
X = 8.0
M_M_SKALA = make_material("P5M_Skala", (0.30, 0.26, 0.28))
M_M_ZAR = make_material("P5M_ZarGlow", (1.0, 0.45, 0.15), glow=3.5)
M_M_PLOMIEN = make_material("P5M_PlomienGlow", (1.0, 0.65, 0.20), glow=2.8)
M_M_PLOMIEN2 = make_material("P5M_PlomienJasnyGlow", (1.0, 0.85, 0.35), glow=3.5)

# głaz pochylony do lotu
glaz = sphere(X, 0.05, 0.62, 0.40, segments=7, rings=5)
glaz.scale = (0.95, 1.1, 0.9)
glaz.rotation_euler = (math.radians(-12), 0, 0)
finish(glaz, "P5_3_Meteorek_Glaz", M_M_SKALA)
# żar w pęknięciach: pas świecących kulek wzdłuż "szwu" głazu
zar = []
for (a_deg, z, s) in [(15, 0.52, 0.07), (75, 0.70, 0.08), (140, 0.60, 0.06),
                      (210, 0.48, 0.07), (290, 0.66, 0.08)]:
    a = math.radians(a_deg)
    g = bead(X + math.cos(a) * 0.36, 0.05 + math.sin(a) * 0.36, z, s)
    g.scale = (1.3, 0.5, 0.8)
    zar.append(g)
join_as(zar, "P5_3_Meteorek_PekniecaZarGlow", M_M_ZAR)
# guzy skalne (meteor nie jest gładki)
guzy = []
for (a_deg, z, s) in [(50, 0.85, 0.10), (185, 0.75, 0.11), (300, 0.90, 0.08)]:
    a = math.radians(a_deg)
    guzy.append(bead(X + math.cos(a) * 0.30, 0.05 + math.sin(a) * 0.30, z, s))
join_as(guzy, "P5_3_Meteorek_Guzy", M_M_SKALA)
# ognisty warkocz lotu za meteorkiem ("Warkocz" = dryfuje) — dwa odcienie
plomien, plomien2 = [], []
for i, (dy, dz, r) in enumerate([(-0.40, 0.50, 0.16), (-0.60, 0.42, 0.13),
                                 (-0.78, 0.36, 0.10), (-0.94, 0.32, 0.07),
                                 (-1.06, 0.30, 0.05)]):
    b = sphere(X, dy, dz, r, segments=6, rings=4)
    (plomien if i % 2 == 0 else plomien2).append(b)
join_as(plomien, "P5_3_Meteorek_OgonWarkoczGlow", M_M_PLOMIEN)
join_as(plomien2, "P5_3_Meteorek_OgonWarkoczJasnyGlow", M_M_PLOMIEN2)
# dryfujące iskry żaru ("Drobiny")
iskry = []
for (a_deg, d, z) in [(70, 0.55, 1.00), (210, 0.60, 0.75), (340, 0.52, 1.05)]:
    a = math.radians(a_deg)
    iskry.append(bead(X + math.cos(a) * d, math.sin(a) * d, z, 0.045))
join_as(iskry, "P5_3_Meteorek_DrobinyIskryGlow", M_M_ZAR)
# zdeterminowane oczy pędziwiatra
oczy = [bead(X - 0.13, 0.42, 0.70, 0.075), bead(X + 0.13, 0.42, 0.70, 0.075)]
join_as(oczy, "P5_3_Meteorek_Oczy", M_OKO)

# ===========================================================================
# PET 4 — GWIEZDNY ŚLIMAK (Legendarny 3,4%) — ślimak, którego muszla to
# GALAKTYKA: spiralne ramię świecących gwiazd, wirujący pierścień pyłu
# i gwiazda na szczycie
# ===========================================================================
X = 12.0
M_GS_CIALO = make_material("P5S_Cialo", (0.30, 0.35, 0.65))
M_GS_MUSZLA = make_material("P5S_Muszla", (0.14, 0.12, 0.30))
M_GS_GWIAZDY = make_material("P5S_GwiazdyGlow", (0.85, 0.90, 1.0), glow=3.0)
M_GS_PYL = make_material("P5S_PylGlow", (0.65, 0.55, 1.0), glow=2.5)
M_GS_GWIAZDA = make_material("P5S_GwiazdaGlow", (1.0, 0.90, 0.45), glow=4.0)

# ciało ślimaka
cialo = sphere(X, 0.15, 0.26, 0.40, squash=0.55)
cialo.scale = (0.75, 1.4, 0.55)
finish(cialo, "P5_4_GwiezdnySlimak_Cialo", M_GS_CIALO)
finish(sphere(X, 0.60, 0.40, 0.22), "P5_4_GwiezdnySlimak_Glowka", M_GS_CIALO)
# muszla-galaktyka: ciemna kula...
finish(sphere(X, -0.15, 0.85, 0.42, segments=8, rings=5),
       "P5_4_GwiezdnySlimak_Muszla", M_GS_MUSZLA)
# ...ze spiralnym ramieniem gwiazd owiniętym wokół
gwiazdy = []
for i in range(8):
    t = i / 7.0
    a = math.radians(t * 500)
    r_orb = 0.44 + t * 0.06
    z = 0.60 + t * 0.55
    gwiazdy.append(bead(X + math.cos(a) * r_orb * (1 - t * 0.55),
                        -0.15 + math.sin(a) * r_orb * (1 - t * 0.55), z,
                        0.055 + (1 - t) * 0.02))
join_as(gwiazdy, "P5_4_GwiezdnySlimak_SpiralaGwiazdGlow", M_GS_GWIAZDY)
# gwiazda na biegunie muszli (klasyczna 4-ramienna z dwóch spłaszczonych stożków)
gwiazda = []
for rot_z in (0, 90):
    g = cone(X, -0.15, 1.32, 0.13, 0.26, rot=(0, 0, math.radians(rot_z)), vertices=4)
    g.scale = (1.0, 0.35, 1.0)
    gwiazda.append(g)
join_as(gwiazda, "P5_4_GwiezdnySlimak_GwiazdaGlow", M_GS_GWIAZDA)
# wirujący pierścień pyłu gwiezdnego wokół muszli ("Pierscien" = sam WIRUJE)
bpy.ops.mesh.primitive_torus_add(major_radius=0.58, minor_radius=0.04,
                                 major_segments=14, minor_segments=5,
                                 location=(X, -0.15, 0.85),
                                 rotation=(math.radians(18), 0, 0))
finish(bpy.context.active_object, "P5_4_GwiezdnySlimak_PierscienPyluGlow", M_GS_PYL)
# czułki z gwiazdkami + dryfujący pył za ślimakiem ("Drobiny")
slupki = []
for side in (-1, 1):
    bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=0.04, depth=0.30,
                                        location=(X + side * 0.11, 0.66, 0.62),
                                        rotation=(math.radians(-12), 0, 0))
    slupki.append(bpy.context.active_object)
join_as(slupki, "P5_4_GwiezdnySlimak_Slupki", M_GS_CIALO)
kulki = [bead(X - 0.11, 0.70, 0.80, 0.06), bead(X + 0.11, 0.70, 0.80, 0.06)]
join_as(kulki, "P5_4_GwiezdnySlimak_CzulkiGwiazdkiGlow", M_GS_GWIAZDA)
pyl = []
for (dy, z, s) in [(-0.50, 0.30, 0.05), (-0.68, 0.42, 0.045), (-0.82, 0.30, 0.04)]:
    pyl.append(bead(X + (0.08 if s == 0.045 else -0.05), dy, z, s))
join_as(pyl, "P5_4_GwiezdnySlimak_DrobinyPyluGlow", M_GS_PYL)
oczy = [bead(X - 0.10, 0.72, 0.52, 0.07), bead(X + 0.10, 0.72, 0.52, 0.07)]
join_as(oczy, "P5_4_GwiezdnySlimak_Oczy", M_OKO)

# ===========================================================================
# PET 5 — CZARNODZIUREK (SEKRET 0,1%) — kieszonkowa czarna dziura, finał
# kolekcji: czarne serce z fioletowym horyzontem zdarzeń, WIRUJĄCY dysk
# akrecyjny w dwóch odcieniach, zagięty łuk światła i WCIĄGANA materia
# w trzech kolorach. Absolutne WOW — nikt inny go nie ma.
# ===========================================================================
X = 16.0
M_C_SERCE = make_material("P5C_Serce", (0.02, 0.02, 0.04), roughness=0.25)
M_C_HORYZONT = make_material("P5C_HoryzontGlow", (0.55, 0.30, 0.95), glow=2.5)
M_C_DYSK = make_material("P5C_DyskGlow", (1.0, 0.55, 0.20), glow=3.0)
M_C_DYSK2 = make_material("P5C_DyskJasnyGlow", (1.0, 0.85, 0.40), glow=3.8)
M_C_LUK = make_material("P5C_LukSwiatlaGlow", (0.80, 0.92, 1.0), glow=3.0)
M_C_MAT_R = make_material("P5C_MateriaRozGlow", (1.0, 0.45, 0.75), glow=3.2)
M_C_MAT_B = make_material("P5C_MateriaBlekitGlow", (0.45, 0.80, 1.0), glow=3.2)
M_C_MAT_Z = make_material("P5C_MateriaZlotoGlow", (1.0, 0.85, 0.35), glow=3.2)

# czarne serce (idealnie ciemna kula) + świecący horyzont zdarzeń tuż nad nią
finish(sphere(X, 0, 0.90, 0.34), "P5_5_Czarnodziurek_Serce", M_C_SERCE)
bpy.ops.mesh.primitive_torus_add(major_radius=0.36, minor_radius=0.035,
                                 major_segments=14, minor_segments=5,
                                 location=(X, 0, 0.90), rotation=(math.radians(90), 0, 0))
finish(bpy.context.active_object, "P5_5_Czarnodziurek_HoryzontGlow", M_C_HORYZONT)
# WIRUJĄCY dysk akrecyjny: dwa przekrzywione torusy w odcieniach żaru
# ("Dysk" = FxClient sam je obraca w ich płaszczyźnie)
bpy.ops.mesh.primitive_torus_add(major_radius=0.60, minor_radius=0.055,
                                 major_segments=16, minor_segments=5,
                                 location=(X, 0, 0.90), rotation=(math.radians(14), 0, 0))
finish(bpy.context.active_object, "P5_5_Czarnodziurek_DyskAkrecyjnyGlow", M_C_DYSK)
bpy.ops.mesh.primitive_torus_add(major_radius=0.76, minor_radius=0.035,
                                 major_segments=16, minor_segments=5,
                                 location=(X, 0, 0.90), rotation=(math.radians(14), 0, 0))
finish(bpy.context.active_object, "P5_5_Czarnodziurek_DyskZewnetrznyGlow", M_C_DYSK2)
# zagięty łuk światła nad biegunem (soczewkowanie grawitacyjne w wersji cute)
bpy.ops.mesh.primitive_torus_add(major_radius=0.30, minor_radius=0.03,
                                 major_segments=12, minor_segments=5,
                                 location=(X, 0, 1.38), rotation=(math.radians(65), 0, 0))
finish(bpy.context.active_object, "P5_5_Czarnodziurek_LukSwiatlaGlow", M_C_LUK)
# WCIĄGANA materia: trzy smugi kulek spiralnie wpadające do dziury
# ("Materia" = FxClient sam je kołysze; osobne obiekty = osobne kolory)
for (mat, a0_deg, name) in [(M_C_MAT_R, 0, "P5_5_Czarnodziurek_MateriaRozGlow"),
                            (M_C_MAT_B, 120, "P5_5_Czarnodziurek_MateriaBlekitGlow"),
                            (M_C_MAT_Z, 240, "P5_5_Czarnodziurek_MateriaZlotoGlow")]:
    smuga = []
    for i in range(3):
        t = i / 2.0
        a = math.radians(a0_deg + t * 70)
        d = 0.95 - t * 0.35
        z = 0.90 + (t - 0.5) * 0.28 * math.sin(math.radians(a0_deg + 40))
        smuga.append(bead(X + math.cos(a) * d, math.sin(a) * d, z, 0.075 - t * 0.03))
    join_as(smuga, name, mat)
# oczy-półksiężyce (świecące, bo czarna dziura nie ma "białek")
oczy = []
for side in (-1, 1):
    o = bead(X + side * 0.12, 0.30, 0.94, 0.06)
    o.scale = (1.0, 0.5, 1.3)
    oczy.append(o)
join_as(oczy, "P5_5_Czarnodziurek_OczyGlow", M_C_LUK)
usmiech = bead(X, 0.32, 0.80, 0.05)
usmiech.scale = (1.7, 0.5, 0.4)
finish(usmiech, "P5_5_Czarnodziurek_UsmiechGlow", M_C_HORYZONT)

print("Gotowe! Kolekcja:", COLLECTION_NAME, "— 5 petów Świata 5, KONIEC",
      "kolekcji (25 petów). Części *Glow → Material=Neon. Dyski Czarnodziurka",
      "wirują, materia i warkocze dryfują, iskry same (FxClient po nazwach).")
