# Pick a Shroom — 5 PETÓW ŚWIATA 2 (Bór Iglasty), low-poly
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_PetySwiat2" z 5 petami obok siebie (co 4 j.).
#
# Kolejność = pozycja w puli jaja z GameConfig = rzadkość:
#   1. Sowa Mgielna    (Rzadki 55%)      — pulchna sówka z czubkami na uszach
#   2. Szyszkostwór    (B. Rzadki 34%)   — żywa szyszka na nóżkach, łuski piętrami
#   3. Lisek Borowy    (Epicki 7,5%)     — lisek z puszystym ogonem o świecącym końcu
#   4. Mroźny Puszek   (Legendarny 3,4%) — kula szronu z lodowymi kryształami
#                                          i wirującą obręczą mrozu
#   5. Dzięciołek      (SEKRET 0,1%)     — złoty dziób, LEWITUJĄCY czub z piór,
#                                          wirująca aureolka i dryfujące iskry
#
# Pety lewitują przy graczu, więc są MAŁE (~1,5 j. wzrostu — 1 j. ≈ 1 stud).
# Animacje za darmo (FxClient, po nazwach): "…Warkocz…"/"…Drobiny…" dryfują,
# "…Pierscien…" wiruje, wszystko z "Glow" sypie iskrami (Material = Neon).
# Styl: klockowy, płaskie cieniowanie. Części OSOBNO — nie łącz ich!

import bpy
import math
import random

COLLECTION_NAME = "PickAShroom_PetySwiat2"
random.seed(17)

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
# PET 1 — SOWA MGIELNA (Rzadki 55%) — pulchna szaro-błękitna sówka,
# ogromne oczy, czubki na uszach, złożone skrzydełka
# ===========================================================================
X = 0.0
M_SO_PIORA = make_material("P2S_Piora", (0.55, 0.62, 0.72))
M_SO_BRZUCH = make_material("P2S_Brzuch", (0.88, 0.90, 0.94))
M_SO_DZIOB = make_material("P2S_Dziob", (0.95, 0.72, 0.30))
M_SO_OKO_B = make_material("P2S_OkoBialko", (0.97, 0.96, 0.92), roughness=0.25)

finish(sphere(X, 0, 0.62, 0.48, squash=1.15), "P2_1_SowaMgielna_Cialo", M_SO_PIORA)
brzuch = sphere(X, 0.26, 0.52, 0.30, squash=1.15)
brzuch.scale = (0.85, 0.55, 1.0)
finish(brzuch, "P2_1_SowaMgielna_Brzuszek", M_SO_BRZUCH)
skrzydla = []
for side in (-1, 1):
    w = sphere(X + side * 0.44, -0.02, 0.60, 0.20, segments=7, rings=5)
    w.scale = (0.45, 0.8, 1.25)
    w.rotation_euler = (0, side * math.radians(-12), 0)
    skrzydla.append(w)
join_as(skrzydla, "P2_1_SowaMgielna_Skrzydelka", M_SO_PIORA)
czubki = []
for side in (-1, 1):
    czubki.append(cone(X + side * 0.26, 0, 1.22, 0.10, 0.28,
                       rot=(0, side * math.radians(20), 0), vertices=5))
join_as(czubki, "P2_1_SowaMgielna_Czubki", M_SO_PIORA)
bialka = [bead(X - 0.16, 0.40, 0.86, 0.14), bead(X + 0.16, 0.40, 0.86, 0.14)]
join_as(bialka, "P2_1_SowaMgielna_OczyBialka", M_SO_OKO_B)
zrenice = [bead(X - 0.16, 0.51, 0.86, 0.07), bead(X + 0.16, 0.51, 0.86, 0.07)]
join_as(zrenice, "P2_1_SowaMgielna_Oczy", M_OKO)
finish(cone(X, 0.46, 0.70, 0.08, 0.18, rot=(math.radians(100), 0, 0), vertices=5),
       "P2_1_SowaMgielna_Dziobek", M_SO_DZIOB)
stopki = [sphere(X - 0.16, 0.08, 0.12, 0.10, squash=0.6, segments=6, rings=4),
          sphere(X + 0.16, 0.08, 0.12, 0.10, squash=0.6, segments=6, rings=4)]
join_as(stopki, "P2_1_SowaMgielna_Stopki", M_SO_DZIOB)

# ===========================================================================
# PET 2 — SZYSZKOSTWÓR (B. Rzadki 34%) — żywa szyszka: piętra łusek
# w dwóch odcieniach, pulchne nóżki, zielony listek-czapeczka
# ===========================================================================
X = 4.0
M_SZ_LUSKI = make_material("P2Z_Luski", (0.52, 0.36, 0.20))
M_SZ_LUSKI2 = make_material("P2Z_LuskiJasne", (0.68, 0.50, 0.30))
M_SZ_CIALO = make_material("P2Z_Cialo", (0.42, 0.29, 0.17))
M_SZ_LISTEK = make_material("P2Z_Listek", (0.42, 0.62, 0.28))

finish(sphere(X, 0, 0.68, 0.40, squash=1.35), "P2_2_Szyszkostwor_Cialo", M_SZ_CIALO)
luski_a, luski_b = [], []
for tier, (z, tier_r, s) in enumerate([(0.32, 0.34, 0.15), (0.62, 0.40, 0.16),
                                       (0.92, 0.34, 0.15), (1.18, 0.24, 0.13)]):
    n = 5 if tier != 1 else 6
    for i in range(n):
        a = math.radians(i * (360 / n) + tier * 24)
        l = sphere(X + math.cos(a) * tier_r, math.sin(a) * tier_r, z, s,
                   segments=6, rings=4)
        l.scale = (1.0, 1.0, 0.55)
        l.rotation_euler = (math.radians(-28) * math.sin(a),
                            math.radians(28) * math.cos(a), 0)
        (luski_a if tier % 2 == 0 else luski_b).append(l)
join_as(luski_a, "P2_2_Szyszkostwor_Luski", M_SZ_LUSKI)
join_as(luski_b, "P2_2_Szyszkostwor_LuskiJasne", M_SZ_LUSKI2)
listek = sphere(X + 0.08, 0, 1.46, 0.14, squash=0.4, segments=6, rings=4)
listek.scale = (1.6, 0.8, 1.0)
listek.rotation_euler = (0, math.radians(-18), math.radians(20))
finish(listek, "P2_2_Szyszkostwor_Listek", M_SZ_LISTEK)
nogi = [sphere(X - 0.18, 0.06, 0.10, 0.13, squash=0.7, segments=6, rings=4),
        sphere(X + 0.18, 0.06, 0.10, 0.13, squash=0.7, segments=6, rings=4)]
join_as(nogi, "P2_2_Szyszkostwor_Nozki", M_SZ_LUSKI2)
oczy = [bead(X - 0.13, 0.36, 0.82, 0.08), bead(X + 0.13, 0.36, 0.82, 0.08)]
join_as(oczy, "P2_2_Szyszkostwor_Oczy", M_OKO)

# ===========================================================================
# PET 3 — LISEK BOROWY (Epicki 7,5%) — rudy lisek z białym pyszczkiem,
# spiczaste uszy, puszysty ogon ze ŚWIECĄCYM fioletowym koniuszkiem
# ===========================================================================
X = 8.0
M_L_FUTRO = make_material("P2L_Futro", (0.85, 0.44, 0.18))
M_L_BIALE = make_material("P2L_Biale", (0.95, 0.92, 0.88))
M_L_USZY = make_material("P2L_UszyCiemne", (0.35, 0.22, 0.16))
M_L_OGON_TIP = make_material("P2L_OgonTipGlow", (0.72, 0.42, 0.95), glow=2.5)

cialo = sphere(X, -0.05, 0.45, 0.34, squash=0.95)
cialo.scale = (0.9, 1.25, 0.95)
finish(cialo, "P2_3_LisekBorowy_Cialo", M_L_FUTRO)
finish(sphere(X, 0.30, 0.85, 0.28), "P2_3_LisekBorowy_Glowa", M_L_FUTRO)
pysk = sphere(X, 0.54, 0.78, 0.14, squash=0.85, segments=6, rings=4)
pysk.scale = (1.1, 1.3, 0.85)
finish(pysk, "P2_3_LisekBorowy_Pyszczek", M_L_BIALE)
finish(bead(X, 0.68, 0.80, 0.06), "P2_3_LisekBorowy_Nosek", M_OKO)
uszy, uszy_srodek = [], []
for side in (-1, 1):
    uszy.append(cone(X + side * 0.17, 0.26, 1.14, 0.12, 0.30,
                     rot=(0, side * math.radians(14), 0), vertices=5))
    uszy_srodek.append(cone(X + side * 0.17, 0.30, 1.12, 0.06, 0.16,
                            rot=(0, side * math.radians(14), 0), vertices=5))
join_as(uszy, "P2_3_LisekBorowy_Uszy", M_L_FUTRO)
join_as(uszy_srodek, "P2_3_LisekBorowy_UszySrodek", M_L_USZY)
# ogon: łuk 3 kul + świecący koniuszek (epicka iskra jakości)
ogon = []
for (dy, dz, r) in [(-0.42, 0.42, 0.16), (-0.60, 0.62, 0.19), (-0.68, 0.88, 0.16)]:
    ogon.append(sphere(X, dy, dz, r, segments=7, rings=5))
join_as(ogon, "P2_3_LisekBorowy_Ogon", M_L_FUTRO)
finish(sphere(X, -0.68, 1.10, 0.12, segments=6, rings=4),
       "P2_3_LisekBorowy_OgonTipGlow", M_L_OGON_TIP)
lapki = [sphere(X - 0.14, 0.28, 0.14, 0.10, squash=0.7, segments=6, rings=4),
         sphere(X + 0.14, 0.28, 0.14, 0.10, squash=0.7, segments=6, rings=4)]
join_as(lapki, "P2_3_LisekBorowy_Lapki", M_L_BIALE)
oczy = [bead(X - 0.12, 0.52, 0.92, 0.07), bead(X + 0.12, 0.52, 0.92, 0.07)]
join_as(oczy, "P2_3_LisekBorowy_Oczy", M_OKO)

# ===========================================================================
# PET 4 — MROŹNY PUSZEK (Legendarny 3,4%) — kula szronu z lodowymi
# kryształami na grzbiecie i WIRUJĄCĄ obręczą mrozu; cały lekko świeci
# ===========================================================================
X = 12.0
M_P_FUTRO = make_material("P2P_Futro", (0.80, 0.90, 0.98))
M_P_FUTRO_C = make_material("P2P_FutroCien", (0.62, 0.76, 0.90))
M_P_KRYSZTAL = make_material("P2P_KrysztalGlow", (0.62, 0.88, 1.0), roughness=0.3, glow=2.5)
M_P_OBRECZ = make_material("P2P_ObreczGlow", (0.75, 0.95, 1.0), glow=3.0)

finish(sphere(X, 0, 0.55, 0.46), "P2_4_MroznyPuszek_Cialo", M_P_FUTRO)
# kępki futra: mniejsze kule wtopione dookoła (puszystość po robloxowemu)
kepki = []
for (a_deg, z, r) in [(30, 0.30, 0.16), (150, 0.32, 0.15), (270, 0.28, 0.16),
                      (90, 0.80, 0.15), (210, 0.82, 0.14), (330, 0.78, 0.15)]:
    a = math.radians(a_deg)
    kepki.append(sphere(X + math.cos(a) * 0.38, math.sin(a) * 0.38, z, r,
                        segments=6, rings=4))
join_as(kepki, "P2_4_MroznyPuszek_Kepki", M_P_FUTRO_C)
# lodowe kryształy na grzbiecie (fasetowane stożki)
krysztaly = []
for (dx, dy, h, tilt) in [(0.0, -0.15, 0.5, 0), (-0.18, -0.08, 0.34, -18),
                          (0.18, -0.10, 0.36, 18)]:
    krysztaly.append(cone(X + dx, dy, 1.05 + h * 0.3, 0.09, h,
                          rot=(math.radians(-10), math.radians(tilt), 0), vertices=5))
join_as(krysztaly, "P2_4_MroznyPuszek_KrysztalyGlow", M_P_KRYSZTAL)
# wirująca obręcz mrozu ("Pierscien" = sama WIRUJE)
bpy.ops.mesh.primitive_torus_add(major_radius=0.62, minor_radius=0.045,
                                 major_segments=12, minor_segments=5,
                                 location=(X, 0, 0.55))
finish(bpy.context.active_object, "P2_4_MroznyPuszek_PierscienMrozuGlow", M_P_OBRECZ)
# dryfujące płatki śniegu ("Drobiny" = same się kołyszą)
platki = []
for (a_deg, d, z) in [(50, 0.62, 0.95), (190, 0.66, 0.62), (300, 0.60, 1.05)]:
    a = math.radians(a_deg)
    platki.append(bead(X + math.cos(a) * d, math.sin(a) * d, z, 0.05))
join_as(platki, "P2_4_MroznyPuszek_DrobinySniegGlow", M_P_OBRECZ)
oczy = [bead(X - 0.14, 0.42, 0.62, 0.08), bead(X + 0.14, 0.42, 0.62, 0.08)]
join_as(oczy, "P2_4_MroznyPuszek_Oczy", M_OKO)
policzki = [bead(X - 0.26, 0.38, 0.50, 0.06), bead(X + 0.26, 0.38, 0.50, 0.06)]
for p in policzki:
    p.scale = (1.0, 0.5, 0.7)
join_as(policzki, "P2_4_MroznyPuszek_Policzki", make_material("P2P_Policzek", (0.70, 0.82, 0.98)))

# ===========================================================================
# PET 5 — DZIĘCIOŁEK (SEKRET 0,1%) — leśny klejnot: granatowe piórka,
# szkarłatna pierś, ZŁOTY świecący dziób, LEWITUJĄCY czub z płomiennych
# piór ("Warkocz"), wirująca aureolka i dryfujące iskry. Ma robić WOW.
# ===========================================================================
X = 16.0
M_D_PIORA = make_material("P2D_Piora", (0.16, 0.22, 0.42))
M_D_PIERS = make_material("P2D_Piers", (0.88, 0.16, 0.22))
M_D_BIALE = make_material("P2D_Biale", (0.94, 0.92, 0.88))
M_D_DZIOB = make_material("P2D_DziobGlow", (1.0, 0.80, 0.25), roughness=0.35, glow=3.0)
M_D_CZUB = make_material("P2D_CzubGlow", (1.0, 0.35, 0.30), glow=2.5)
M_D_CZUB2 = make_material("P2D_CzubJasnyGlow", (1.0, 0.62, 0.30), glow=3.0)
M_D_AURA = make_material("P2D_AuraGlow", (1.0, 0.85, 0.45), glow=3.0)

finish(sphere(X, 0, 0.55, 0.36, squash=1.2), "P2_5_Dzieciolek_Cialo", M_D_PIORA)
piers = sphere(X, 0.22, 0.48, 0.22, squash=1.15)
piers.scale = (0.85, 0.6, 1.0)
finish(piers, "P2_5_Dzieciolek_Piers", M_D_PIERS)
finish(sphere(X, 0.08, 1.02, 0.26), "P2_5_Dzieciolek_Glowa", M_D_PIORA)
lico = sphere(X, 0.26, 0.98, 0.15, segments=6, rings=4)
lico.scale = (1.2, 0.7, 0.9)
finish(lico, "P2_5_Dzieciolek_Lico", M_D_BIALE)
# złoty dziób — duma dzięcioła (świeci)
finish(cone(X, 0.52, 1.00, 0.09, 0.42, rot=(math.radians(95), 0, 0), vertices=6),
       "P2_5_Dzieciolek_DziobGlow", M_D_DZIOB)
# skrzydełka i ogonek podpórka (dzięcioł!)
skrzydla = []
for side in (-1, 1):
    w = sphere(X + side * 0.32, -0.05, 0.55, 0.15, segments=6, rings=4)
    w.scale = (0.5, 0.8, 1.35)
    w.rotation_euler = (0, side * math.radians(-10), 0)
    skrzydla.append(w)
join_as(skrzydla, "P2_5_Dzieciolek_Skrzydelka", M_D_PIORA)
ogonek = sphere(X, -0.28, 0.22, 0.14, segments=6, rings=4)
ogonek.scale = (0.7, 0.6, 1.5)
ogonek.rotation_euler = (math.radians(30), 0, 0)
finish(ogonek, "P2_5_Dzieciolek_Ogonek", M_D_PIORA)
# LEWITUJĄCY czub: łuk płomiennych piór nad głową ("Warkocz" = dryfują
# + Glow = sypią iskrami); dwa odcienie = ognisty gradient
czub, czub2 = [], []
for i, (dy, dz, r) in enumerate([(0.02, 1.38, 0.11), (-0.10, 1.52, 0.13),
                                 (-0.26, 1.60, 0.12), (-0.42, 1.62, 0.10),
                                 (-0.56, 1.58, 0.08)]):
    b = sphere(X, dy, dz, r, segments=6, rings=4)
    (czub if i % 2 == 0 else czub2).append(b)
join_as(czub, "P2_5_Dzieciolek_CzubWarkoczGlow", M_D_CZUB)
join_as(czub2, "P2_5_Dzieciolek_CzubWarkoczJasnyGlow", M_D_CZUB2)
# wirująca aureolka ("Pierscien" = sama WIRUJE)
bpy.ops.mesh.primitive_torus_add(major_radius=0.20, minor_radius=0.03,
                                 major_segments=10, minor_segments=5,
                                 location=(X, 0.08, 1.42))
finish(bpy.context.active_object, "P2_5_Dzieciolek_PierscienAuraGlow", M_D_AURA)
# dryfujące iskry wokół ("Drobiny" = same się kołyszą)
drobiny = []
for (a_deg, d, z) in [(40, 0.50, 1.20), (165, 0.55, 0.80), (285, 0.48, 1.40)]:
    a = math.radians(a_deg)
    drobiny.append(bead(X + math.cos(a) * d, 0.05 + math.sin(a) * d, z, 0.055))
join_as(drobiny, "P2_5_Dzieciolek_DrobinyGlow", M_D_AURA)
oczy = [bead(X - 0.11, 0.28, 1.10, 0.07), bead(X + 0.11, 0.28, 1.10, 0.07)]
join_as(oczy, "P2_5_Dzieciolek_Oczy", M_OKO)

print("Gotowe! Kolekcja:", COLLECTION_NAME, "— 5 petów Świata 2.",
      "Części *Glow → Material=Neon. Czub Dzięciołka dryfuje, aureolka",
      "i obręcz mrozu wirują, iskry sypią się same (FxClient po nazwach).")
