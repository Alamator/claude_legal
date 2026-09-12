# Pick a Shroom — 5 PETÓW ŚWIATA 3 (Mokradła), low-poly
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_PetySwiat3" z 5 petami obok siebie (co 4 j.).
#
# Kolejność = pozycja w puli jaja z GameConfig = rzadkość:
#   1. Bagienny Glut   (Rzadki 55%)      — uroczy glut błotny z kapkami
#   2. Świetlik Bzyk   (B. Rzadki 34%)   — świecący odwłok, skrzydełka, czułki
#   3. Neonowy Żabol   (Epicki 7,5%)     — żabka w neonowe pasy, oczy na czubku
#   4. Ropuch Królewski(Legendarny 3,4%) — brodawki, ZŁOTA korona, wirujący
#                                          królewski pierścień
#   5. Mglisty Duszek  (SEKRET 0,1%)     — cały świeci: mgielny welon-warkocz,
#                                          wirująca aureolka, dryfujące kule mgły
#
# Pety lewitują przy graczu, więc są MAŁE (~1,5 j. wzrostu — 1 j. ≈ 1 stud).
# Animacje za darmo (FxClient, po nazwach): "…Warkocz…"/"…Drobiny…" dryfują,
# "…Pierscien…" wiruje, wszystko z "Glow" sypie iskrami (Material = Neon).
# Styl: klockowy, płaskie cieniowanie. Części OSOBNO — nie łącz ich!

import bpy
import math
import random

COLLECTION_NAME = "PickAShroom_PetySwiat3"
random.seed(18)

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
# PET 1 — BAGIENNY GLUT (Rzadki 55%) — rozlany zielony glut, kapki błota
# ściekają po bokach, na czubku bulgocząca bańka
# ===========================================================================
X = 0.0
M_G_CIALO = make_material("P3G_Cialo", (0.46, 0.66, 0.28), roughness=0.45)
M_G_CIEMNE = make_material("P3G_Ciemne", (0.34, 0.50, 0.20), roughness=0.45)
M_G_BANKA = make_material("P3G_Banka", (0.62, 0.82, 0.42), roughness=0.35)

glut = sphere(X, 0, 0.42, 0.46, squash=0.8)
finish(glut, "P3_1_BagiennyGlut_Cialo", M_G_CIALO)
# rozlana "kałuża" u podstawy
podstawa = sphere(X, 0, 0.10, 0.52, squash=0.28)
finish(podstawa, "P3_1_BagiennyGlut_Kaluza", M_G_CIEMNE)
# kapki ściekające po bokach
kapki = []
for (a_deg, z, r) in [(35, 0.45, 0.11), (150, 0.52, 0.10), (250, 0.40, 0.12),
                      (320, 0.55, 0.09)]:
    a = math.radians(a_deg)
    k = sphere(X + math.cos(a) * 0.40, math.sin(a) * 0.40, z, r,
               segments=6, rings=4)
    k.scale = (1.0, 1.0, 1.5)
    kapki.append(k)
join_as(kapki, "P3_1_BagiennyGlut_Kapki", M_G_CIEMNE)
# bulgocząca bańka na czubku
finish(bead(X + 0.10, -0.05, 0.85, 0.12), "P3_1_BagiennyGlut_Banka", M_G_BANKA)
oczy = [bead(X - 0.15, 0.40, 0.50, 0.09), bead(X + 0.15, 0.40, 0.50, 0.09)]
join_as(oczy, "P3_1_BagiennyGlut_Oczy", M_OKO)
# szeroki uśmiech-kreska
usmiech = sphere(X, 0.44, 0.32, 0.10, segments=6, rings=4)
usmiech.scale = (1.6, 0.4, 0.4)
finish(usmiech, "P3_1_BagiennyGlut_Usmiech", M_G_CIEMNE)

# ===========================================================================
# PET 2 — ŚWIETLIK BZYK (B. Rzadki 34%) — nocny robaczek: ciemny tułów,
# ŚWIECĄCY odwłok-latarnia, skrzydełka i czułki z kulkami
# ===========================================================================
X = 4.0
M_S_TULOW = make_material("P3S_Tulow", (0.24, 0.20, 0.30))
M_S_ODWLOK = make_material("P3S_OdwlokGlow", (0.85, 1.0, 0.35), glow=4.0)
M_S_SKRZYDLA = make_material("P3S_Skrzydla", (0.75, 0.82, 0.90), roughness=0.3)
M_S_CZULKI = make_material("P3S_CzulkiGlow", (0.95, 1.0, 0.55), glow=3.0)

finish(sphere(X, 0.18, 0.62, 0.26), "P3_2_SwietlikBzyk_Glowa", M_S_TULOW)
finish(sphere(X, -0.10, 0.58, 0.30, squash=0.95), "P3_2_SwietlikBzyk_Tulow", M_S_TULOW)
# świecący odwłok (latarnia świetlika)
odwlok = sphere(X, -0.44, 0.52, 0.26)
odwlok.scale = (0.9, 1.15, 0.9)
finish(odwlok, "P3_2_SwietlikBzyk_OdwlokGlow", M_S_ODWLOK)
# skrzydełka uniesione do lotu
skrzydla = []
for side in (-1, 1):
    w = sphere(X + side * 0.26, -0.12, 0.88, 0.20, segments=6, rings=4)
    w.scale = (0.45, 1.1, 0.25)
    w.rotation_euler = (math.radians(-15), side * math.radians(35), 0)
    skrzydla.append(w)
join_as(skrzydla, "P3_2_SwietlikBzyk_Skrzydelka", M_S_SKRZYDLA)
czulki, kulki = [], []
for side in (-1, 1):
    bpy.ops.mesh.primitive_cylinder_add(vertices=5, radius=0.025, depth=0.3,
                                        location=(X + side * 0.10, 0.32, 0.86),
                                        rotation=(math.radians(-30), side * math.radians(20), 0))
    czulki.append(bpy.context.active_object)
    kulki.append(bead(X + side * 0.17, 0.40, 0.99, 0.055))
join_as(czulki, "P3_2_SwietlikBzyk_Czulki", M_S_TULOW)
join_as(kulki, "P3_2_SwietlikBzyk_CzulkiKulkiGlow", M_S_CZULKI)
# dryfujące ogniki wokół latarni ("Drobiny" = same się kołyszą)
ogniki = []
for (a_deg, d, z) in [(60, 0.45, 0.85), (200, 0.48, 0.45), (310, 0.42, 0.70)]:
    a = math.radians(a_deg)
    ogniki.append(bead(X + math.cos(a) * d, -0.35 + math.sin(a) * d, z, 0.05))
join_as(ogniki, "P3_2_SwietlikBzyk_DrobinyOgnikiGlow", M_S_ODWLOK)
oczy = [bead(X - 0.11, 0.40, 0.66, 0.08), bead(X + 0.11, 0.40, 0.66, 0.08)]
join_as(oczy, "P3_2_SwietlikBzyk_Oczy", M_OKO)

# ===========================================================================
# PET 3 — NEONOWY ŻABOL (Epicki 7,5%) — bagienna żabka w ŚWIECĄCE neonowe
# pasy, wyłupiaste oczy na czubku głowy, pulchne łapki
# ===========================================================================
X = 8.0
M_Z_SKORA = make_material("P3Z_Skora", (0.16, 0.38, 0.34))
M_Z_BRZUCH = make_material("P3Z_Brzuch", (0.70, 0.88, 0.58))
M_Z_NEON = make_material("P3Z_PasyGlow", (0.30, 1.0, 0.65), glow=3.0)
M_Z_OKO_B = make_material("P3Z_OkoBialko", (0.96, 0.95, 0.85), roughness=0.25)

cialo = sphere(X, 0, 0.42, 0.42, squash=0.85)
cialo.scale = (1.0, 1.1, 0.85)
finish(cialo, "P3_3_NeonowyZabol_Cialo", M_Z_SKORA)
brzuch = sphere(X, 0.24, 0.36, 0.28, squash=0.85)
brzuch.scale = (0.85, 0.6, 0.85)
finish(brzuch, "P3_3_NeonowyZabol_Brzuszek", M_Z_BRZUCH)
# neonowe pasy na grzbiecie (trzy łuki-kapsułki)
pasy = []
for (dy, s) in [(-0.10, 0.34), (-0.24, 0.28), (-0.36, 0.20)]:
    p = sphere(X, dy, 0.72, 0.08, segments=6, rings=4)
    p.scale = (s / 0.08, 1.0, 0.5)
    pasy.append(p)
join_as(pasy, "P3_3_NeonowyZabol_PasyGlow", M_Z_NEON)
# wyłupiaste oczy na czubku
bialka = [sphere(X - 0.20, 0.16, 0.82, 0.14, segments=6, rings=4),
          sphere(X + 0.20, 0.16, 0.82, 0.14, segments=6, rings=4)]
join_as(bialka, "P3_3_NeonowyZabol_OczyBialka", M_Z_OKO_B)
zrenice = [bead(X - 0.20, 0.26, 0.86, 0.07), bead(X + 0.20, 0.26, 0.86, 0.07)]
join_as(zrenice, "P3_3_NeonowyZabol_Oczy", M_OKO)
# łapki przednie + tylne udka
lapki = [sphere(X - 0.24, 0.30, 0.12, 0.11, squash=0.65, segments=6, rings=4),
         sphere(X + 0.24, 0.30, 0.12, 0.11, squash=0.65, segments=6, rings=4)]
join_as(lapki, "P3_3_NeonowyZabol_Lapki", M_Z_SKORA)
udka = []
for side in (-1, 1):
    u = sphere(X + side * 0.40, -0.18, 0.22, 0.16, segments=6, rings=4)
    u.scale = (0.8, 1.2, 0.9)
    udka.append(u)
join_as(udka, "P3_3_NeonowyZabol_Udka", M_Z_SKORA)
# neonowe kropki na udkach
kropki = [bead(X - 0.42, -0.10, 0.30, 0.05), bead(X + 0.42, -0.10, 0.30, 0.05),
          bead(X - 0.36, -0.28, 0.24, 0.045), bead(X + 0.36, -0.28, 0.24, 0.045)]
join_as(kropki, "P3_3_NeonowyZabol_KropkiGlow", M_Z_NEON)
usmiech = sphere(X, 0.40, 0.44, 0.09, segments=6, rings=4)
usmiech.scale = (1.8, 0.4, 0.35)
finish(usmiech, "P3_3_NeonowyZabol_Usmiech", M_OKO)

# ===========================================================================
# PET 4 — ROPUCH KRÓLEWSKI (Legendarny 3,4%) — dostojny ropuch z brodawkami,
# ZŁOTĄ świecącą koroną i WIRUJĄCYM królewskim pierścieniem
# ===========================================================================
X = 12.0
M_R_SKORA = make_material("P3R_Skora", (0.44, 0.40, 0.22))
M_R_BRZUCH = make_material("P3R_Brzuch", (0.80, 0.74, 0.52))
M_R_BRODAWKI = make_material("P3R_Brodawki", (0.56, 0.52, 0.30))
M_R_ZLOTO = make_material("P3R_ZlotoGlow", (1.0, 0.78, 0.22), roughness=0.35, glow=3.0)

cialo = sphere(X, 0, 0.48, 0.48, squash=0.85)
cialo.scale = (1.05, 1.1, 0.85)
finish(cialo, "P3_4_RopuchKrolewski_Cialo", M_R_SKORA)
brzuch = sphere(X, 0.28, 0.40, 0.32, squash=0.85)
brzuch.scale = (0.85, 0.55, 0.85)
finish(brzuch, "P3_4_RopuchKrolewski_Brzuch", M_R_BRZUCH)
# dostojny podbródek
podbrodek = sphere(X, 0.38, 0.28, 0.20, squash=0.7, segments=6, rings=4)
podbrodek.scale = (1.3, 0.8, 0.7)
finish(podbrodek, "P3_4_RopuchKrolewski_Podbrodek", M_R_BRZUCH)
# brodawki na grzbiecie
brodawki = []
for (a_deg, d, z, r) in [(40, 0.30, 0.78, 0.08), (140, 0.34, 0.76, 0.07),
                         (220, 0.30, 0.72, 0.08), (310, 0.36, 0.74, 0.06),
                         (90, 0.12, 0.86, 0.07)]:
    a = math.radians(a_deg)
    brodawki.append(bead(X + math.cos(a) * d, math.sin(a) * d - 0.05, z, r))
join_as(brodawki, "P3_4_RopuchKrolewski_Brodawki", M_R_BRODAWKI)
# oczy na wystających garbkach
garbki = [sphere(X - 0.20, 0.18, 0.86, 0.12, segments=6, rings=4),
          sphere(X + 0.20, 0.18, 0.86, 0.12, segments=6, rings=4)]
join_as(garbki, "P3_4_RopuchKrolewski_OczyGarbki", M_R_SKORA)
oczy = [bead(X - 0.20, 0.27, 0.90, 0.065), bead(X + 0.20, 0.27, 0.90, 0.065)]
join_as(oczy, "P3_4_RopuchKrolewski_Oczy", M_OKO)
# ZŁOTA KORONA — obręcz + 4 zęby + kulki (świeci)
bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.17, depth=0.10,
                                    location=(X, 0, 1.02))
korona = [bpy.context.active_object]
for i in range(4):
    a = math.radians(i * 90 + 45)
    korona.append(cone(X + math.cos(a) * 0.13, math.sin(a) * 0.13, 1.14,
                       0.05, 0.14, vertices=5))
    korona.append(bead(X + math.cos(a) * 0.13, math.sin(a) * 0.13, 1.22, 0.03))
join_as(korona, "P3_4_RopuchKrolewski_KoronaGlow", M_R_ZLOTO)
# WIRUJĄCY królewski pierścień wokół ropucha ("Pierscien" = sam WIRUJE)
bpy.ops.mesh.primitive_torus_add(major_radius=0.68, minor_radius=0.045,
                                 major_segments=12, minor_segments=5,
                                 location=(X, 0, 0.48))
finish(bpy.context.active_object, "P3_4_RopuchKrolewski_PierscienGlow", M_R_ZLOTO)
# dryfujące złote bąbelki dworu ("Drobiny")
babelki = []
for (a_deg, d, z) in [(70, 0.66, 0.92), (210, 0.70, 0.60), (330, 0.62, 1.02)]:
    a = math.radians(a_deg)
    babelki.append(bead(X + math.cos(a) * d, math.sin(a) * d, z, 0.05))
join_as(babelki, "P3_4_RopuchKrolewski_DrobinyGlow", M_R_ZLOTO)
lapy = [sphere(X - 0.30, 0.34, 0.12, 0.13, squash=0.6, segments=6, rings=4),
        sphere(X + 0.30, 0.34, 0.12, 0.13, squash=0.6, segments=6, rings=4)]
join_as(lapy, "P3_4_RopuchKrolewski_Lapy", M_R_SKORA)

# ===========================================================================
# PET 5 — MGLISTY DUSZEK (SEKRET 0,1%) — zjawa znad bagien: całe ciało
# lekko świeci, welon mgły ("Warkocz") dryfuje za nim, wirująca aureolka,
# dryfujące kule mgły i mini-koronka z mgiełki. Ma robić WOW.
# ===========================================================================
X = 16.0
M_D_CIALO = make_material("P3D_CialoGlow", (0.78, 0.92, 0.95), roughness=0.5, glow=1.2)
M_D_WELON = make_material("P3D_WelonGlow", (0.62, 0.85, 0.92), glow=2.0)
M_D_WELON2 = make_material("P3D_WelonJasnyGlow", (0.85, 0.97, 1.0), glow=2.8)
M_D_AURA = make_material("P3D_AuraGlow", (0.55, 0.95, 0.85), glow=3.0)
M_D_OKO = make_material("P3D_Oko", (0.10, 0.22, 0.30), roughness=0.3)

# ciało-łezka: kula + zwężający się "ogonek" ducha
finish(sphere(X, 0, 0.85, 0.36), "P3_5_MglistyDuszek_Glowa", M_D_CIALO)
tulow = cone(X, 0, 0.45, 0.30, 0.65, vertices=8)
tulow.rotation_euler = (math.radians(180), 0, 0)
finish(tulow, "P3_5_MglistyDuszek_Tulow", M_D_CIALO)
# falbanka u dołu (kulki jak rąbek prześcieradła)
falbanka = []
for i in range(5):
    a = math.radians(i * 72)
    falbanka.append(bead(X + math.cos(a) * 0.16, math.sin(a) * 0.16, 0.14, 0.09))
join_as(falbanka, "P3_5_MglistyDuszek_Falbanka", M_D_CIALO)
# rączki-skrzydełka
raczki = []
for side in (-1, 1):
    r = sphere(X + side * 0.38, 0.05, 0.72, 0.13, segments=6, rings=4)
    r.scale = (1.3, 0.6, 0.5)
    r.rotation_euler = (0, side * math.radians(-25), 0)
    raczki.append(r)
join_as(raczki, "P3_5_MglistyDuszek_Raczki", M_D_CIALO)
# WELON MGŁY: łuk kul za duszkiem ("Warkocz" = dryfuje + sypie iskrami)
welon, welon2 = [], []
for i, (dy, dz, r) in enumerate([(-0.34, 0.60, 0.14), (-0.52, 0.82, 0.17),
                                 (-0.62, 1.08, 0.15), (-0.58, 1.32, 0.12),
                                 (-0.44, 1.50, 0.09)]):
    b = sphere(X, dy, dz, r, segments=6, rings=4)
    (welon if i % 2 == 0 else welon2).append(b)
join_as(welon, "P3_5_MglistyDuszek_WelonWarkoczGlow", M_D_WELON)
join_as(welon2, "P3_5_MglistyDuszek_WelonWarkoczJasnyGlow", M_D_WELON2)
# wirująca aureolka ("Pierscien" = sama WIRUJE)
bpy.ops.mesh.primitive_torus_add(major_radius=0.24, minor_radius=0.035,
                                 major_segments=10, minor_segments=5,
                                 location=(X, 0, 1.36))
finish(bpy.context.active_object, "P3_5_MglistyDuszek_PierscienAuraGlow", M_D_AURA)
# dryfujące kule mgły wokół ("Drobiny" = same się kołyszą)
kule = []
for (a_deg, d, z) in [(30, 0.58, 1.05), (160, 0.62, 0.60), (275, 0.55, 1.25)]:
    a = math.radians(a_deg)
    kule.append(bead(X + math.cos(a) * d, math.sin(a) * d, z, 0.07))
join_as(kule, "P3_5_MglistyDuszek_DrobinyMglyGlow", M_D_AURA)
# oczy-migdałki i rumieńce (duszek ma być słodki, nie straszny)
oczy = []
for side in (-1, 1):
    o = bead(X + side * 0.13, 0.30, 0.90, 0.075)
    o.scale = (0.8, 0.6, 1.3)
    oczy.append(o)
join_as(oczy, "P3_5_MglistyDuszek_Oczy", M_D_OKO)
policzki = [bead(X - 0.24, 0.26, 0.76, 0.055), bead(X + 0.24, 0.26, 0.76, 0.055)]
for p in policzki:
    p.scale = (1.0, 0.5, 0.7)
join_as(policzki, "P3_5_MglistyDuszek_Policzki", M_POLICZEK)

print("Gotowe! Kolekcja:", COLLECTION_NAME, "— 5 petów Świata 3.",
      "Części *Glow → Material=Neon. Welon Duszka dryfuje, aureolka i pierścień",
      "Ropucha wirują, iskry sypią się same (FxClient po nazwach).")
