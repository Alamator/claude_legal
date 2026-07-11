# Pick a Shroom — 5 PETÓW ŚWIATA 1 (Las Liściasty), low-poly
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_PetySwiat1" z 5 petami obok siebie (co 4 j.).
#
# Kolejność = pozycja w puli jaja z GameConfig = rzadkość:
#   1. Grzybek Skoczek   (Rzadki 55%)       — prościutki i uroczy
#   2. Ślimak Zamszowy   (B. Rzadki 34%)    — fasetowana spiralna muszla
#   3. Jeżozwierzyk      (Epicki 7,5%)      — kolce + mini-grzybek na grzbiecie
#   4. Biedronix         (Legendarny 3,4%)  — złote akcenty, świecące czułki
#   5. Wiewiór Rudzik    (SEKRET 0,1%)      — lewitujący ogon, złoty żołądź,
#                                             aureolka i dryfujące iskry
#
# Pety lewitują przy graczu, więc są MAŁE (~1,5 j. wzrostu — 1 j. ≈ 1 stud).
# Animacje za darmo (FxClient, po nazwach): "…Warkocz…"/"…Drobiny…" dryfują,
# "…Pierscien…" wiruje, wszystko z "Glow" sypie iskrami (Material = Neon).
# Styl: klockowy, płaskie cieniowanie. Części OSOBNO — nie łącz ich!

import bpy
import math
import random

COLLECTION_NAME = "PickAShroom_PetySwiat1"
random.seed(16)

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


def eyes_and_cheeks(x, y_front, z, spread, name_prefix, eye_r=0.09,
                    cheeks=True, mat_eye=None, mat_cheek=None):
    """Para ślepek + (opcjonalnie) różowe policzki — wspólny urok wszystkich petów."""
    eyes = [bead(x - spread, y_front, z, eye_r), bead(x + spread, y_front, z, eye_r)]
    join_as(eyes, name_prefix + "_Oczy", mat_eye)
    if cheeks:
        ch = [bead(x - spread - 0.12, y_front - 0.02, z - 0.13, eye_r * 0.8),
              bead(x + spread + 0.12, y_front - 0.02, z - 0.13, eye_r * 0.8)]
        for c in ch:
            c.scale = (1.0, 0.5, 0.7)
        join_as(ch, name_prefix + "_Policzki", mat_cheek)


# --- materiały wspólne -------------------------------------------------------
M_OKO = make_material("PET_Oko", (0.06, 0.06, 0.07), roughness=0.3)
M_POLICZEK = make_material("PET_Policzek", (0.95, 0.55, 0.60))
M_BRZUCH = make_material("PET_Brzuszek", (0.96, 0.90, 0.78))

# ===========================================================================
# PET 1 — GRZYBEK SKOCZEK (Rzadki 55%) — chodzący grzybek na pulchnych nóżkach
# ===========================================================================
X = 0.0
M_S_KAP = make_material("P1S_Kapelusz", (0.86, 0.30, 0.26))
M_S_KROPKI = make_material("P1S_Kropki", (0.97, 0.94, 0.86))
M_S_CIALO = make_material("P1S_Cialo", (0.96, 0.90, 0.78))
M_S_NOGI = make_material("P1S_Nogi", (0.80, 0.66, 0.50))

finish(sphere(X, 0, 0.62, 0.42, squash=1.05), "P1_1_GrzybekSkoczek_Cialo", M_S_CIALO)
finish(sphere(X, 0, 1.05, 0.62, squash=0.62), "P1_1_GrzybekSkoczek_Kapelusz", M_S_KAP)
kropki = []
for (a_deg, d, s) in [(30, 0.32, 0.11), (150, 0.38, 0.09), (265, 0.30, 0.10), (90, 0.15, 0.08)]:
    a = math.radians(a_deg)
    kropki.append(bead(X + math.cos(a) * d, math.sin(a) * d, 1.30, s))
for k in kropki:
    k.scale = (1.0, 1.0, 0.5)
join_as(kropki, "P1_1_GrzybekSkoczek_Kropki", M_S_KROPKI)
nogi = [sphere(X - 0.2, 0, 0.12, 0.16, squash=0.75, segments=6, rings=4),
        sphere(X + 0.2, 0, 0.12, 0.16, squash=0.75, segments=6, rings=4)]
join_as(nogi, "P1_1_GrzybekSkoczek_Nozki", M_S_NOGI)
eyes_and_cheeks(X, 0.38, 0.68, 0.15, "P1_1_GrzybekSkoczek",
                mat_eye=M_OKO, mat_cheek=M_POLICZEK)

# ===========================================================================
# PET 2 — ŚLIMAK ZAMSZOWY (B. Rzadki 34%) — zamszowe ciałko, fasetowana
# spiralna muszla z malejących kul, oczka na słupkach
# ===========================================================================
X = 4.0
M_L_CIALO = make_material("P1L_Cialo", (0.72, 0.52, 0.72))
M_L_MUSZLA = make_material("P1L_Muszla", (0.42, 0.60, 0.86), roughness=0.5)
M_L_MUSZLA2 = make_material("P1L_MuszlaJasna", (0.60, 0.76, 0.95), roughness=0.5)

cialo = sphere(X, 0.15, 0.28, 0.42, squash=0.55)
cialo.scale = (0.75, 1.4, 0.55)
finish(cialo, "P1_2_SlimakZamszowy_Cialo", M_L_CIALO)
glowka = finish(sphere(X, 0.62, 0.42, 0.24), "P1_2_SlimakZamszowy_Glowka", M_L_CIALO)
# spirala muszli: coraz mniejsze kule wspinające się ślimakiem
muszla, muszla2 = [], []
for i, (a_deg, d, z, r) in enumerate([(0, 0.0, 0.85, 0.42), (140, 0.18, 1.05, 0.30),
                                      (260, 0.28, 1.18, 0.20), (20, 0.33, 1.27, 0.12)]):
    a = math.radians(a_deg)
    b = sphere(X + math.cos(a) * d * 0.4, -0.15 + math.sin(a) * d * 0.4, z, r,
               segments=7, rings=5)
    (muszla if i % 2 == 0 else muszla2).append(b)
join_as(muszla, "P1_2_SlimakZamszowy_Muszla", M_L_MUSZLA)
join_as(muszla2, "P1_2_SlimakZamszowy_MuszlaSkret", M_L_MUSZLA2)
slupki = []
for side in (-1, 1):
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.045, depth=0.35,
                                        location=(X + side * 0.12, 0.68, 0.72),
                                        rotation=(math.radians(-15), 0, 0))
    slupki.append(bpy.context.active_object)
join_as(slupki, "P1_2_SlimakZamszowy_Slupki", M_L_CIALO)
oczka = [bead(X - 0.12, 0.73, 0.92, 0.09), bead(X + 0.12, 0.73, 0.92, 0.09)]
join_as(oczka, "P1_2_SlimakZamszowy_Oczy", M_OKO)

# ===========================================================================
# PET 3 — JEŻOZWIERZYK (Epicki 7,5%) — kulka z wachlarzem kolców
# i mini-grzybkiem rosnącym między nimi
# ===========================================================================
X = 8.0
M_J_CIALO = make_material("P1J_Cialo", (0.58, 0.42, 0.30))
M_J_PYSK = make_material("P1J_Pysk", (0.88, 0.76, 0.60))
M_J_KOLCE = make_material("P1J_Kolce", (0.38, 0.26, 0.36))
M_J_KOLCE_F = make_material("P1J_KolceFiolet", (0.62, 0.36, 0.78))
M_J_GRZYBEK = make_material("P1J_MiniGrzybek", (0.86, 0.30, 0.26))

finish(sphere(X, 0, 0.5, 0.48, squash=0.9), "P1_3_Jezozwierzyk_Cialo", M_J_CIALO)
pysk = sphere(X, 0.4, 0.42, 0.2)
pysk.scale = (0.9, 1.2, 0.8)
finish(pysk, "P1_3_Jezozwierzyk_Pysk", M_J_PYSK)
finish(bead(X, 0.62, 0.46, 0.07), "P1_3_Jezozwierzyk_Nosek", M_OKO)
kolce, kolce_f = [], []
for i, (a_deg, tilt_deg) in enumerate([(90, 0), (60, 25), (120, 25), (35, 50),
                                       (145, 50), (75, -20), (105, -20), (90, 40)]):
    a = math.radians(a_deg)
    tilt = math.radians(tilt_deg)
    d = 0.30
    bpy.ops.mesh.primitive_cone_add(
        vertices=5, radius1=0.09, radius2=0.0, depth=0.55,
        location=(X + math.sin(tilt) * d, -0.35 * math.cos(a) - 0.05,
                  0.62 + math.cos(tilt) * d + 0.18),
        rotation=(math.radians(-20) * math.cos(a), tilt, 0))
    (kolce if i % 3 != 0 else kolce_f).append(bpy.context.active_object)
join_as(kolce, "P1_3_Jezozwierzyk_Kolce", M_J_KOLCE)
join_as(kolce_f, "P1_3_Jezozwierzyk_KolceFiolet", M_J_KOLCE_F)
bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.05, depth=0.18,
                                    location=(X - 0.28, -0.15, 0.92))
finish(bpy.context.active_object, "P1_3_Jezozwierzyk_GrzybekTrzon", M_J_PYSK)
finish(sphere(X - 0.28, -0.15, 1.03, 0.12, squash=0.6, segments=6, rings=4),
       "P1_3_Jezozwierzyk_GrzybekKapelusz", M_J_GRZYBEK)
eyes_and_cheeks(X, 0.5, 0.58, 0.14, "P1_3_Jezozwierzyk",
                mat_eye=M_OKO, mat_cheek=M_POLICZEK)

# ===========================================================================
# PET 4 — BIEDRONIX (Legendarny 3,4%) — lakierowany pancerzyk w czarne grochy
# ze ZŁOTĄ obwódką i świecącymi czułkami
# ===========================================================================
X = 12.0
M_B_PANCERZ = make_material("P1B_Pancerz", (0.90, 0.18, 0.16), roughness=0.35)
M_B_GROCHY = make_material("P1B_Grochy", (0.10, 0.09, 0.10))
M_B_GLOWA = make_material("P1B_Glowa", (0.14, 0.12, 0.14))
M_B_ZLOTO = make_material("P1B_ZlotoGlow", (1.0, 0.72, 0.20), roughness=0.4, glow=2.5)

finish(sphere(X, 0, 0.42, 0.5, squash=0.62), "P1_4_Biedronix_Pancerz", M_B_PANCERZ)
grochy = []
for (a_deg, d, s) in [(40, 0.28, 0.10), (140, 0.30, 0.11), (215, 0.26, 0.09),
                      (320, 0.29, 0.10), (90, 0.10, 0.08)]:
    a = math.radians(a_deg)
    g = bead(X + math.cos(a) * d, math.sin(a) * d, 0.68, s)
    g.scale = (1.0, 1.0, 0.45)
    grochy.append(g)
join_as(grochy, "P1_4_Biedronix_Grochy", M_B_GROCHY)
# złota listwa rozdzielająca skrzydełka + złota obwódka pancerza
bpy.ops.mesh.primitive_cube_add(size=1, location=(X, -0.05, 0.62))
listwa = bpy.context.active_object
listwa.scale = (0.035, 0.42, 0.10)
finish(listwa, "P1_4_Biedronix_ListwaGlow", M_B_ZLOTO)
bpy.ops.mesh.primitive_torus_add(major_radius=0.46, minor_radius=0.045,
                                 major_segments=12, minor_segments=5,
                                 location=(X, 0, 0.32))
finish(bpy.context.active_object, "P1_4_Biedronix_ObwodkaGlow", M_B_ZLOTO)
finish(sphere(X, 0.42, 0.38, 0.26), "P1_4_Biedronix_Glowa", M_B_GLOWA)
czulki, kulki = [], []
for side in (-1, 1):
    bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=0.03, depth=0.3,
                                        location=(X + side * 0.12, 0.55, 0.66),
                                        rotation=(math.radians(-25), side * math.radians(18), 0))
    czulki.append(bpy.context.active_object)
    kulki.append(bead(X + side * 0.19, 0.62, 0.80, 0.07))
join_as(czulki, "P1_4_Biedronix_Czulki", M_B_GLOWA)
join_as(kulki, "P1_4_Biedronix_CzulkiKulkiGlow", M_B_ZLOTO)
oczy = [bead(X - 0.10, 0.64, 0.42, 0.08), bead(X + 0.10, 0.64, 0.42, 0.08)]
join_as(oczy, "P1_4_Biedronix_Oczy", make_material("P1B_Oko", (0.95, 0.95, 0.98), roughness=0.2))

# ===========================================================================
# PET 5 — WIEWIÓR RUDZIK (SEKRET 0,1%) — rudy wiewiór z LEWITUJĄCYM ogonem
# z segmentów ("Warkocz" = same dryfują + sypią iskrami), złotym żołędziem,
# wirującą aureolką i dryfującymi iskrami. Ma robić WOW.
# ===========================================================================
X = 16.0
M_W_FUTRO = make_material("P1W_Futro", (0.82, 0.38, 0.16))
M_W_BRZUCH = make_material("P1W_Brzuch", (0.97, 0.88, 0.72))
M_W_OGON = make_material("P1W_OgonGlow", (1.0, 0.52, 0.24), glow=2.0)
M_W_OGON2 = make_material("P1W_OgonJasnyGlow", (1.0, 0.76, 0.40), glow=2.5)
M_W_ZOLADZ = make_material("P1W_ZoladzGlow", (1.0, 0.82, 0.28), roughness=0.35, glow=3.5)
M_W_AURA = make_material("P1W_AuraGlow", (0.70, 0.95, 1.0), glow=3.0)

finish(sphere(X, 0, 0.52, 0.38, squash=1.1), "P1_5_WiewiorRudzik_Cialo", M_W_FUTRO)
brzuch = sphere(X, 0.22, 0.48, 0.24, squash=1.2)
brzuch.scale = (0.85, 0.6, 1.0)
finish(brzuch, "P1_5_WiewiorRudzik_Brzuszek", M_W_BRZUCH)
finish(sphere(X, 0.05, 1.02, 0.30), "P1_5_WiewiorRudzik_Glowa", M_W_FUTRO)
uszy = []
for side in (-1, 1):
    bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.10, radius2=0.0, depth=0.24,
                                    location=(X + side * 0.18, 0.02, 1.32),
                                    rotation=(0, side * math.radians(12), 0))
    uszy.append(bpy.context.active_object)
join_as(uszy, "P1_5_WiewiorRudzik_Uszy", M_W_FUTRO)
lapki = [sphere(X - 0.16, 0.28, 0.66, 0.09, segments=6, rings=4),
         sphere(X + 0.16, 0.28, 0.66, 0.09, segments=6, rings=4)]
join_as(lapki, "P1_5_WiewiorRudzik_Lapki", M_W_FUTRO)
# złoty żołądź w łapkach (fasetowany, świeci)
zoladz = sphere(X, 0.36, 0.60, 0.13, segments=7, rings=5)
zoladz.scale = (1.0, 1.0, 1.25)
finish(zoladz, "P1_5_WiewiorRudzik_ZoladzGlow", M_W_ZOLADZ)
finish(sphere(X, 0.36, 0.74, 0.10, squash=0.5, segments=6, rings=4),
       "P1_5_WiewiorRudzik_ZoladzCzapeczka", M_W_FUTRO)
# LEWITUJĄCY ogon: łuk z 5 kul za plecami — "Warkocz" w nazwie = FxClient
# sam je kołysze i (Glow) sypie iskrami; dwa odcienie = gradient
ogon, ogon2 = [], []
for i, (dy, dz, r) in enumerate([(-0.42, 0.35, 0.16), (-0.58, 0.62, 0.20),
                                 (-0.62, 0.95, 0.23), (-0.52, 1.28, 0.20),
                                 (-0.32, 1.50, 0.15)]):
    b = sphere(X, dy, dz, r, segments=7, rings=5)
    (ogon if i % 2 == 0 else ogon2).append(b)
join_as(ogon, "P1_5_WiewiorRudzik_OgonWarkoczGlow", M_W_OGON)
join_as(ogon2, "P1_5_WiewiorRudzik_OgonWarkoczJasnyGlow", M_W_OGON2)
# aureolka nad głową ("Pierscien" = sama WIRUJE)
bpy.ops.mesh.primitive_torus_add(major_radius=0.22, minor_radius=0.035,
                                 major_segments=10, minor_segments=5,
                                 location=(X, 0.05, 1.52))
finish(bpy.context.active_object, "P1_5_WiewiorRudzik_PierscienAuraGlow", M_W_AURA)
# dryfujące iskry wokół ("Drobiny" = same się kołyszą)
drobiny = []
for (a_deg, d, z) in [(35, 0.55, 1.15), (170, 0.60, 0.75), (290, 0.52, 1.35)]:
    a = math.radians(a_deg)
    drobiny.append(bead(X + math.cos(a) * d, 0.05 + math.sin(a) * d, z, 0.06))
join_as(drobiny, "P1_5_WiewiorRudzik_DrobinyGlow", M_W_AURA)
eyes_and_cheeks(X, 0.30, 1.08, 0.12, "P1_5_WiewiorRudzik",
                mat_eye=M_OKO, mat_cheek=M_POLICZEK)

print("Gotowe! Kolekcja:", COLLECTION_NAME, "— 5 petów Świata 1.",
      "Części *Glow → Material=Neon. Ogon Wiewióra dryfuje, aureolka wiruje,",
      "iskry sypią się same (FxClient po nazwach).")
