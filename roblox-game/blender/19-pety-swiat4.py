# Pick a Shroom — 5 PETÓW ŚWIATA 4 (Kryształowa Grota), low-poly
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_PetySwiat4" z 5 petami obok siebie (co 4 j.).
#
# Kolejność = pozycja w puli jaja z GameConfig = rzadkość:
#   1. Kryształowy Żuk    (Rzadki 55%)      — pancerz z fasetowanych kryształków
#   2. Ametystowy Nietoperz (B. Rzadki 34%) — wielkie uszy, ametystowe skrzydła
#   3. Gemek              (Epicki 7,5%)     — żywy klejnot w szlifie brylantowym
#   4. Grotowy Golem      (Legendarny 3,4%) — świecące serce w piersi, kryształy
#                                             na barkach, LEWITUJĄCE skałki
#   5. Pryzmatek          (SEKRET 0,1%)     — duszek-pryzmat rozszczepiający
#                                             światło: 3 kolory dryfujących
#                                             odprysków, wirująca obręcz widma
#
# Pety lewitują przy graczu, więc są MAŁE (~1,5 j. wzrostu — 1 j. ≈ 1 stud).
# Animacje za darmo (FxClient, po nazwach): "…Skalki…"/"…Drobiny…" dryfują,
# "…Pierscien…" wiruje, wszystko z "Glow" sypie iskrami (Material = Neon).
# Styl: klockowy, płaskie cieniowanie. Części OSOBNO — nie łącz ich!

import bpy
import math
import random

COLLECTION_NAME = "PickAShroom_PetySwiat4"
random.seed(19)

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


def gem(x, y, z, r, h_top, h_bottom, vertices=7):
    """Klejnot w szlifie brylantowym: korona (ścięty stożek) + pawilon
    (odwrócony stożek). Zwraca listę [korona, pawilon] — złącz przez join_as."""
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r, radius2=r * 0.55,
                                    depth=h_top, location=(x, y, z + h_top / 2))
    korona = bpy.context.active_object
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=r, radius2=0.0,
                                    depth=h_bottom, location=(x, y, z - h_bottom / 2),
                                    rotation=(math.radians(180), 0, 0))
    pawilon = bpy.context.active_object
    return [korona, pawilon]


# --- materiały wspólne -------------------------------------------------------
M_OKO = make_material("PET_Oko", (0.06, 0.06, 0.07), roughness=0.3)
M_POLICZEK = make_material("PET_Policzek", (0.95, 0.55, 0.60))

# ===========================================================================
# PET 1 — KRYSZTAŁOWY ŻUK (Rzadki 55%) — poczciwy żuczek, którego pancerz
# porósł fasetowanymi kryształkami; kryształki delikatnie świecą
# ===========================================================================
X = 0.0
M_ZU_CIALO = make_material("P4Z_Cialo", (0.30, 0.32, 0.42))
M_ZU_GLOWA = make_material("P4Z_Glowa", (0.38, 0.40, 0.52))
M_ZU_KRYSZTAL = make_material("P4Z_KrysztalGlow", (0.55, 0.80, 1.0), roughness=0.3, glow=1.8)

pancerz = sphere(X, -0.05, 0.40, 0.40, squash=0.75)
pancerz.scale = (0.95, 1.15, 0.75)
finish(pancerz, "P4_1_KrysztalowyZuk_Pancerz", M_ZU_CIALO)
finish(sphere(X, 0.34, 0.38, 0.22), "P4_1_KrysztalowyZuk_Glowa", M_ZU_GLOWA)
# kryształki wyrastające z pancerza (różne wysokości i pochylenia)
krysztaly = []
for (dx, dy, h, tilt_x, tilt_y) in [(0.0, -0.10, 0.42, -8, 0), (-0.18, 0.02, 0.30, 0, -16),
                                    (0.18, 0.00, 0.32, 0, 16), (-0.10, -0.28, 0.26, 12, -8),
                                    (0.12, -0.26, 0.28, 12, 8)]:
    krysztaly.append(cone(X + dx, dy, 0.62 + h * 0.30, 0.08, h,
                          rot=(math.radians(tilt_x), math.radians(tilt_y), 0),
                          vertices=5))
join_as(krysztaly, "P4_1_KrysztalowyZuk_KrysztalyGlow", M_ZU_KRYSZTAL)
# nóżki (3 pary kulek) i czułki
nozki = []
for dy in (0.16, -0.04, -0.24):
    for side in (-1, 1):
        nozki.append(sphere(X + side * 0.34, dy, 0.10, 0.08, squash=0.7,
                            segments=6, rings=4))
join_as(nozki, "P4_1_KrysztalowyZuk_Nozki", M_ZU_GLOWA)
czulki = []
for side in (-1, 1):
    bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=0.025, depth=0.22,
                                        location=(X + side * 0.09, 0.50, 0.54),
                                        rotation=(math.radians(-35), side * math.radians(15), 0))
    czulki.append(bpy.context.active_object)
    czulki.append(bead(X + side * 0.14, 0.56, 0.63, 0.045))
join_as(czulki, "P4_1_KrysztalowyZuk_Czulki", M_ZU_GLOWA)
oczy = [bead(X - 0.10, 0.52, 0.42, 0.07), bead(X + 0.10, 0.52, 0.42, 0.07)]
join_as(oczy, "P4_1_KrysztalowyZuk_Oczy", M_OKO)

# ===========================================================================
# PET 2 — AMETYSTOWY NIETOPERZ (B. Rzadki 34%) — fioletowy pyzaty nietoperz,
# wielkie uszy, rozpostarte kanciaste skrzydła z ametystowymi błonami
# ===========================================================================
X = 4.0
M_N_FUTRO = make_material("P4N_Futro", (0.42, 0.30, 0.58))
M_N_BRZUCH = make_material("P4N_Brzuch", (0.62, 0.50, 0.78))
M_N_BLONA = make_material("P4N_BlonaGlow", (0.70, 0.42, 0.95), roughness=0.4, glow=1.6)
M_N_USZY = make_material("P4N_UszySrodek", (0.85, 0.60, 0.95))

finish(sphere(X, 0, 0.72, 0.36), "P4_2_AmetystowyNietoperz_Cialo", M_N_FUTRO)
brzuch = sphere(X, 0.22, 0.62, 0.22, squash=1.1)
brzuch.scale = (0.85, 0.55, 1.0)
finish(brzuch, "P4_2_AmetystowyNietoperz_Brzuszek", M_N_BRZUCH)
# wielkie uszy + różowe wnętrza
uszy, wnetrza = [], []
for side in (-1, 1):
    uszy.append(cone(X + side * 0.22, 0, 1.16, 0.15, 0.38,
                     rot=(0, side * math.radians(16), 0), vertices=5))
    wnetrza.append(cone(X + side * 0.22, 0.05, 1.12, 0.08, 0.22,
                        rot=(0, side * math.radians(16), 0), vertices=5))
join_as(uszy, "P4_2_AmetystowyNietoperz_Uszy", M_N_FUTRO)
join_as(wnetrza, "P4_2_AmetystowyNietoperz_UszySrodek", M_N_USZY)
# rozpostarte skrzydła: ramię + kanciasta błona (spłaszczone stożki)
ramiona, blony = [], []
for side in (-1, 1):
    bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=0.05, depth=0.5,
                                        location=(X + side * 0.48, 0, 0.82),
                                        rotation=(0, side * math.radians(65), 0))
    ramiona.append(bpy.context.active_object)
    for (dd, dz, s) in [(0.62, 0.62, 0.26), (0.86, 0.70, 0.20)]:
        b = cone(X + side * dd, -0.02, dz, s, 0.42,
                 rot=(math.radians(180), side * math.radians(-22), 0), vertices=4)
        b.scale = (1.0, 0.25, 1.0)
        blony.append(b)
join_as(ramiona, "P4_2_AmetystowyNietoperz_SkrzydlaRamiona", M_N_FUTRO)
join_as(blony, "P4_2_AmetystowyNietoperz_SkrzydlaBlonyGlow", M_N_BLONA)
# ametystowy kryształek na czubku głowy między uszami
finish(cone(X, -0.05, 1.14, 0.07, 0.22, vertices=5),
       "P4_2_AmetystowyNietoperz_KrysztalekGlow", M_N_BLONA)
# kły, oczy, nosek
kly = [cone(X - 0.08, 0.32, 0.56, 0.035, 0.10, rot=(math.radians(180), 0, 0), vertices=4),
       cone(X + 0.08, 0.32, 0.56, 0.035, 0.10, rot=(math.radians(180), 0, 0), vertices=4)]
join_as(kly, "P4_2_AmetystowyNietoperz_Kly", make_material("P4N_Kly", (0.95, 0.94, 0.90)))
oczy = [bead(X - 0.13, 0.30, 0.78, 0.08), bead(X + 0.13, 0.30, 0.78, 0.08)]
join_as(oczy, "P4_2_AmetystowyNietoperz_Oczy", M_OKO)
finish(bead(X, 0.35, 0.68, 0.05), "P4_2_AmetystowyNietoperz_Nosek", M_OKO)

# ===========================================================================
# PET 3 — GEMEK (Epicki 7,5%) — żywy klejnot w szlifie brylantowym,
# lewitujący nad świecącym cokolikiem-iskrą; rączki z kryształków
# ===========================================================================
X = 8.0
M_GE_KLEJNOT = make_material("P4G_Klejnot", (0.30, 0.85, 0.75), roughness=0.25)
M_GE_KLEJNOT_G = make_material("P4G_KlejnotGlow", (0.45, 1.0, 0.88), roughness=0.25, glow=2.2)
M_GE_ISKRA = make_material("P4G_IskraGlow", (0.85, 1.0, 0.95), glow=3.5)

# korpus-klejnot (korona + pawilon)
czesci = gem(X, 0, 0.72, 0.42, 0.30, 0.46, vertices=7)
join_as(czesci, "P4_3_Gemek_Klejnot", M_GE_KLEJNOT)
# świecący pas rundystu (obwódka w talii klejnotu)
bpy.ops.mesh.primitive_torus_add(major_radius=0.42, minor_radius=0.04,
                                 major_segments=14, minor_segments=5,
                                 location=(X, 0, 0.72))
finish(bpy.context.active_object, "P4_3_Gemek_RundystGlow", M_GE_KLEJNOT_G)
# blat korony (świecąca "czapeczka" ośmiokąt)
bpy.ops.mesh.primitive_cylinder_add(vertices=7, radius=0.24, depth=0.05,
                                    location=(X, 0, 1.04))
finish(bpy.context.active_object, "P4_3_Gemek_BlatGlow", M_GE_KLEJNOT_G)
# rączki-kryształki rozłożone jak do przytulenia
raczki = []
for side in (-1, 1):
    raczki.append(cone(X + side * 0.52, 0.08, 0.70, 0.07, 0.24,
                       rot=(0, side * math.radians(105), 0), vertices=5))
join_as(raczki, "P4_3_Gemek_Raczki", M_GE_KLEJNOT)
# iskra pod szpicem (Gemek na niej "lewituje") + dryfujące odpryski
finish(bead(X, 0, 0.30, 0.08), "P4_3_Gemek_IskraGlow", M_GE_ISKRA)
odpryski = []
for (a_deg, d, z) in [(45, 0.60, 0.95), (180, 0.64, 0.60), (300, 0.58, 1.05)]:
    a = math.radians(a_deg)
    odpryski.append(bead(X + math.cos(a) * d, math.sin(a) * d, z, 0.05))
join_as(odpryski, "P4_3_Gemek_DrobinyOdpryskiGlow", M_GE_ISKRA)
# twarz na płaskiej ściance korony
oczy = [bead(X - 0.13, 0.38, 0.80, 0.07), bead(X + 0.13, 0.38, 0.80, 0.07)]
join_as(oczy, "P4_3_Gemek_Oczy", M_OKO)
policzki = [bead(X - 0.25, 0.34, 0.70, 0.05), bead(X + 0.25, 0.34, 0.70, 0.05)]
for p in policzki:
    p.scale = (1.0, 0.5, 0.7)
join_as(policzki, "P4_3_Gemek_Policzki", M_POLICZEK)

# ===========================================================================
# PET 4 — GROTOWY GOLEM (Legendarny 3,4%) — krępy strażnik groty: kamienne
# ciało, ŚWIECĄCE serce w piersi i oczy, kryształy na barkach,
# LEWITUJĄCE skałki krążące wokół ("Skalki" = same dryfują)
# ===========================================================================
X = 12.0
M_GO_KAMIEN = make_material("P4O_Kamien", (0.44, 0.42, 0.48))
M_GO_KAMIEN_C = make_material("P4O_KamienCiemny", (0.32, 0.30, 0.36))
M_GO_SERCE = make_material("P4O_SerceGlow", (1.0, 0.55, 0.20), glow=3.5)
M_GO_KRYSZTAL = make_material("P4O_KrysztalGlow", (0.55, 0.80, 1.0), roughness=0.3, glow=2.2)

# krępy korpus + głowa-głaz
korpus = sphere(X, 0, 0.55, 0.42, squash=1.0, segments=7, rings=5)
korpus.scale = (1.1, 0.9, 1.0)
finish(korpus, "P4_4_GrotowyGolem_Korpus", M_GO_KAMIEN)
glowa = sphere(X, 0.02, 1.10, 0.26, segments=7, rings=5)
glowa.scale = (1.1, 1.0, 0.85)
finish(glowa, "P4_4_GrotowyGolem_Glowa", M_GO_KAMIEN_C)
# świecące serce w piersi (fasetowany ośmiokąt w "dziupli")
bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.14, depth=0.10,
                                    location=(X, 0.36, 0.62),
                                    rotation=(math.radians(90), 0, 0))
finish(bpy.context.active_object, "P4_4_GrotowyGolem_SerceGlow", M_GO_SERCE)
# barki-głazy + kryształy wyrastające z barków
barki = [sphere(X - 0.48, 0, 0.86, 0.20, segments=6, rings=4),
         sphere(X + 0.48, 0, 0.86, 0.20, segments=6, rings=4)]
join_as(barki, "P4_4_GrotowyGolem_Barki", M_GO_KAMIEN_C)
krysztaly = []
for side in (-1, 1):
    krysztaly.append(cone(X + side * 0.50, 0, 1.14, 0.08, 0.30,
                          rot=(0, side * math.radians(14), 0), vertices=5))
    krysztaly.append(cone(X + side * 0.60, -0.06, 1.04, 0.05, 0.18,
                          rot=(0, side * math.radians(35), 0), vertices=5))
join_as(krysztaly, "P4_4_GrotowyGolem_KrysztalyGlow", M_GO_KRYSZTAL)
# pięści przy ziemi (golem-goryl) i nóżki
piesci = [sphere(X - 0.52, 0.16, 0.16, 0.15, segments=6, rings=4),
          sphere(X + 0.52, 0.16, 0.16, 0.15, segments=6, rings=4)]
join_as(piesci, "P4_4_GrotowyGolem_Piesci", M_GO_KAMIEN)
nogi = [sphere(X - 0.20, -0.05, 0.10, 0.14, squash=0.7, segments=6, rings=4),
        sphere(X + 0.20, -0.05, 0.10, 0.14, squash=0.7, segments=6, rings=4)]
join_as(nogi, "P4_4_GrotowyGolem_Nogi", M_GO_KAMIEN_C)
# LEWITUJĄCE skałki krążące wokół golema ("Skalki" = same dryfują)
skalki = []
for (a_deg, d, z, r) in [(30, 0.72, 0.95, 0.09), (150, 0.76, 0.70, 0.11),
                         (270, 0.70, 1.10, 0.08)]:
    a = math.radians(a_deg)
    skalki.append(sphere(X + math.cos(a) * d, math.sin(a) * d, z, r,
                         segments=6, rings=4))
join_as(skalki, "P4_4_GrotowyGolem_SkalkiLewitujace", M_GO_KAMIEN)
# świecące oczy-szparki
oczy = []
for side in (-1, 1):
    o = bead(X + side * 0.11, 0.24, 1.12, 0.055)
    o.scale = (1.4, 0.6, 0.8)
    oczy.append(o)
join_as(oczy, "P4_4_GrotowyGolem_OczyGlow", M_GO_SERCE)

# ===========================================================================
# PET 5 — PRYZMATEK (SEKRET 0,1%) — duszek-pryzmat rozszczepiający światło:
# biały świecący klejnot-serce, wokół WIRUJE obręcz widma, a w trzech
# kolorach dryfują odpryski światła ("Drobiny"). Ma robić WOW.
# ===========================================================================
X = 16.0
M_P_CIALO = make_material("P4P_CialoGlow", (0.94, 0.96, 1.0), roughness=0.25, glow=2.0)
M_P_OBRECZ = make_material("P4P_ObreczGlow", (1.0, 0.95, 0.70), glow=3.0)
M_P_CZERW = make_material("P4P_OdpryskCzerwGlow", (1.0, 0.35, 0.35), glow=3.5)
M_P_ZIEL = make_material("P4P_OdpryskZielGlow", (0.35, 1.0, 0.55), glow=3.5)
M_P_NIEB = make_material("P4P_OdpryskNiebGlow", (0.40, 0.60, 1.0), glow=3.5)
M_P_WARKOCZ = make_material("P4P_WarkoczGlow", (0.85, 0.92, 1.0), glow=2.5)

# ciało: smukły pryzmat w szlifie (korona + długi pawilon) — cały świeci
czesci = gem(X, 0, 0.95, 0.34, 0.26, 0.55, vertices=6)
join_as(czesci, "P4_5_Pryzmatek_CialoGlow", M_P_CIALO)
# czubek-iskierka
finish(cone(X, 0, 1.28, 0.10, 0.20, vertices=5), "P4_5_Pryzmatek_CzubekGlow", M_P_OBRECZ)
# WIRUJĄCA obręcz widma wokół talii ("Pierscien" = sama WIRUJE)
bpy.ops.mesh.primitive_torus_add(major_radius=0.58, minor_radius=0.04,
                                 major_segments=14, minor_segments=5,
                                 location=(X, 0, 0.95), rotation=(math.radians(12), 0, 0))
finish(bpy.context.active_object, "P4_5_Pryzmatek_PierscienWidmaGlow", M_P_OBRECZ)
# rozszczepione światło: odpryski w 3 kolorach ("Drobiny" = same dryfują;
# osobne obiekty = osobne kolory w Roblox)
finish(bead(X + 0.52, 0.20, 1.15, 0.07), "P4_5_Pryzmatek_DrobinyCzerwoneGlow", M_P_CZERW)
finish(bead(X - 0.55, 0.10, 0.85, 0.07), "P4_5_Pryzmatek_DrobinyZieloneGlow", M_P_ZIEL)
finish(bead(X + 0.10, -0.55, 1.30, 0.07), "P4_5_Pryzmatek_DrobinyNiebieskieGlow", M_P_NIEB)
# ogonek światła pod pryzmatem ("Warkocz" = dryfuje) — malejące kulki
warkocz = []
for i, (dz, r) in enumerate([(0.42, 0.10), (0.28, 0.075), (0.16, 0.05)]):
    warkocz.append(bead(X + (i % 2) * 0.06 - 0.03, -0.02 * i, dz, r))
join_as(warkocz, "P4_5_Pryzmatek_OgonekWarkoczGlow", M_P_WARKOCZ)
# twarz na przedniej ściance (oczy-migdałki + rumieńce)
oczy = []
for side in (-1, 1):
    o = bead(X + side * 0.11, 0.30, 1.02, 0.065)
    o.scale = (0.8, 0.6, 1.3)
    oczy.append(o)
join_as(oczy, "P4_5_Pryzmatek_Oczy", M_OKO)
policzki = [bead(X - 0.21, 0.26, 0.90, 0.045), bead(X + 0.21, 0.26, 0.90, 0.045)]
for p in policzki:
    p.scale = (1.0, 0.5, 0.7)
join_as(policzki, "P4_5_Pryzmatek_Policzki", M_POLICZEK)

print("Gotowe! Kolekcja:", COLLECTION_NAME, "— 5 petów Świata 4.",
      "Części *Glow → Material=Neon. Skałki Golema i ogonek Pryzmatka dryfują,",
      "obręcze wirują, iskry sypią się same (FxClient po nazwach).")
