# Pick a Shroom — NATURA ŚWIATA 3 (Mokradła): bagienny krajobraz
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_NaturaSwiat3" (elementy obok siebie co 7 j.).
#
# Klimat: grząskie bagno — drzewa na szczudłach korzeni, wierzba płacząca,
# pałki wodne, lilie, kępy traw i świecące bagienka (bioluminescencja to
# akcent, nie tapeta). Rozmiary w grze losuje MapBuilder skalą klonów.
# Nazwy z "Drobiny"/"Glow" łapie FxClient (lewitacja/iskry).
# Styl: klockowy, płaskie cieniowanie. Części OSOBNO — nie łącz ich!

import bpy
import math
import random

COLLECTION_NAME = "PickAShroom_NaturaSwiat3"
random.seed(99)

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


def trunk(x, height, r_bottom, r_top, tilt_deg=0.0, z0=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r_bottom,
                                    radius2=r_top, depth=height,
                                    location=(x, 0, z0 + height / 2),
                                    rotation=(math.radians(tilt_deg), 0, 0))
    return bpy.context.active_object


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


def water_disc(x, z, radius, name, material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=0.06,
                                        location=(x, 0, z))
    return finish(bpy.context.active_object, name, material)


# --- materiały --------------------------------------------------------------
M_PIEN = make_material("N3_Pien", (0.30, 0.28, 0.20))
M_PIEN_MOKRY = make_material("N3_PienMokry", (0.24, 0.23, 0.18), roughness=0.5)
M_KORONA = make_material("N3_Korona", (0.36, 0.46, 0.24))
M_WIERZBA = make_material("N3_Wierzba", (0.46, 0.58, 0.30))
M_WITKI = make_material("N3_Witki", (0.55, 0.66, 0.34))
M_WODA = make_material("N3_Woda", (0.14, 0.28, 0.30), roughness=0.05)
M_TRZCINA = make_material("N3_Trzcina", (0.42, 0.52, 0.26))
M_PALKA = make_material("N3_Palka", (0.42, 0.28, 0.16))
M_LILIA = make_material("N3_Lilia", (0.28, 0.52, 0.28))
M_KWIAT = make_material("N3_KwiatLilii", (0.94, 0.66, 0.80))
M_KEPA = make_material("N3_Kepa", (0.33, 0.30, 0.20))
M_TRAWA = make_material("N3_TrawaBagienna", (0.44, 0.56, 0.28))
M_MECH = make_material("N3_Mech", (0.40, 0.56, 0.26))
M_SLIZ = make_material("N3_Sliz", (0.36, 0.55, 0.30), roughness=0.25)
M_KAMIEN = make_material("N3_Kamien", (0.42, 0.44, 0.42))
M_BLASK = make_material("N3_BlaskGlow", (0.47, 1.0, 0.78), glow=3.0)

# ===========================================================================
# 1) DRZEWO NA SZCZUDŁACH — bagienny olbrzym: pień uniesiony na korzeniach
#    (jak mangrowiec), niska rozłożysta korona
# ===========================================================================
X = 0
finish(trunk(X, 2.8, 0.5, 0.36, z0=0.9), "N301_Szczudlak_Pien", M_PIEN_MOKRY)
korzenie = []
for i in range(4):
    a = math.radians(i * 90 + 25)
    bpy.ops.mesh.primitive_cone_add(
        vertices=6, radius1=0.16, radius2=0.3, depth=1.6,
        location=(X + math.cos(a) * 0.55, math.sin(a) * 0.55, 0.75),
        rotation=(-math.sin(a) * math.radians(24), math.cos(a) * math.radians(24), 0))
    korzenie.append(bpy.context.active_object)
join_as(korzenie, "N301_Szczudlak_Korzenie", M_PIEN_MOKRY)
korona = [blob(X, 0, 4.2, 1.7, squash=0.5), blob(X + 1.1, 0.5, 3.9, 1.05, squash=0.5),
          blob(X - 1.0, -0.4, 4.0, 1.1, squash=0.45)]
join_as(korona, "N301_Szczudlak_Korona", M_KORONA)

# ===========================================================================
# 2) WIERZBA PŁACZĄCA — pochylony pień, korona wysoko i ZWISAJĄCE WITKI
# ===========================================================================
X = 7
finish(trunk(X, 3.2, 0.42, 0.28, tilt_deg=8), "N302_Wierzba_Pien", M_PIEN)
korona_w = [blob(X, 0.45, 3.9, 1.35, squash=0.65),
            blob(X + 0.8, 0.8, 3.6, 0.9, squash=0.6)]
join_as(korona_w, "N302_Wierzba_Korona", M_WIERZBA)
witki = []
for i in range(8):
    a = math.radians(i * 45 + 10)
    d = 1.25
    dl = random.uniform(1.4, 2.2)
    bpy.ops.mesh.primitive_cone_add(
        vertices=4, radius1=0.05, radius2=0.02, depth=dl,
        location=(X + math.cos(a) * d, 0.45 + math.sin(a) * d, 3.5 - dl / 2))
    witki.append(bpy.context.active_object)
join_as(witki, "N302_Wierzba_Witki", M_WITKI)

# ===========================================================================
# 3) USCHNIĘTY PIEŃ W WODZIE — martwy słup sterczący z własnej kałuży
# ===========================================================================
X = 14
water_disc(X, 0.06, 1.4, "N303_Uschniety_Kaluza", M_WODA)
finish(trunk(X, 2.6, 0.4, 0.14, tilt_deg=6), "N303_Uschniety_Pien", M_PIEN)
bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=0.08, radius2=0.01, depth=0.9,
                                location=(X + 0.45, 0.2, 2.1),
                                rotation=(0, math.radians(55), math.radians(20)))
finish(bpy.context.active_object, "N303_Uschniety_Konar", M_PIEN)

# ===========================================================================
# 4) PAŁKI WODNE (trzciny) — kępa: wysokie łodygi z brązowymi kolbami
# ===========================================================================
X = 20
lodygi, kolby, liscie = [], [], []
for i in range(5):
    a = math.radians(i * 72 + 30)
    dx, dy = math.cos(a) * 0.3, math.sin(a) * 0.3
    h = random.uniform(1.8, 2.6)
    tilt = math.radians(random.uniform(2, 8))
    bpy.ops.mesh.primitive_cone_add(
        vertices=4, radius1=0.05, radius2=0.03, depth=h,
        location=(X + dx, dy, h / 2),
        rotation=(math.sin(a) * tilt, -math.cos(a) * tilt, 0))
    lodygi.append(bpy.context.active_object)
    bpy.ops.mesh.primitive_cylinder_add(vertices=8, radius=0.09, depth=0.5,
                                        location=(X + dx, dy, h + 0.2))
    kolby.append(bpy.context.active_object)
for i in range(3):
    a = math.radians(i * 120 + 70)
    tilt = math.radians(16)
    bpy.ops.mesh.primitive_cone_add(
        vertices=4, radius1=0.09, radius2=0.01, depth=1.6,
        location=(X + math.cos(a) * 0.4, math.sin(a) * 0.4, 0.75),
        rotation=(math.sin(a) * tilt, -math.cos(a) * tilt, 0))
    liscie.append(bpy.context.active_object)
join_as(lodygi + liscie, "N304_Palki_Lodygi", M_TRZCINA)
join_as(kolby, "N304_Palki_Kolby", M_PALKA)

# ===========================================================================
# 5) LILIA WODNA — liść z różowym kwiatem (do kładzenia na kałużach)
# ===========================================================================
X = 26
bpy.ops.mesh.primitive_cylinder_add(vertices=9, radius=0.75, depth=0.06,
                                    location=(X, 0, 0.1))
finish(bpy.context.active_object, "N305_Lilia_Lisc", M_LILIA)
platki = []
for i in range(6):
    a = math.radians(i * 60)
    p = mini_sphere(X + math.cos(a) * 0.2, math.sin(a) * 0.2, 0.28, 0.13)
    p.scale = (1.5, 0.6, 0.5)
    bpy.context.view_layer.objects.active = p
    p.rotation_euler = (0, 0, a)
    platki.append(p)
join_as(platki, "N305_Lilia_Platki", M_KWIAT)
finish(mini_sphere(X, 0, 0.32, 0.1), "N305_Lilia_Srodek", M_BLASK)

# ===========================================================================
# 6) KĘPA BAGIENNA — kopiec z czupryną trawy (po nich się „skacze" po bagnie)
# ===========================================================================
X = 31
finish(blob(X, 0, 0.35, 0.8, squash=0.55), "N306_Kepa_Kopiec", M_KEPA)
czupryna = []
for i in range(7):
    a = math.radians(i * 51 + 10)
    tilt = math.radians(random.uniform(14, 30))
    dl = random.uniform(0.6, 0.95)
    bpy.ops.mesh.primitive_cone_add(
        vertices=4, radius1=0.05, radius2=0.005, depth=dl,
        location=(X + math.cos(a) * 0.25, math.sin(a) * 0.25, 0.65 + dl / 2 * 0.8),
        rotation=(math.sin(a) * tilt, -math.cos(a) * tilt, 0))
    czupryna.append(bpy.context.active_object)
join_as(czupryna, "N306_Kepa_Trawa", M_TRAWA)

# ===========================================================================
# 7) ZATOPIONA KŁODA — na wpół w wodzie, z kożuchem mchu
# ===========================================================================
X = 36
water_disc(X, 0.06, 1.5, "N307_Kloda_Woda", M_WODA)
bpy.ops.mesh.primitive_cylinder_add(vertices=9, radius=0.42, depth=2.8,
                                    location=(X, 0, 0.25),
                                    rotation=(0, math.radians(84), math.radians(25)))
finish(bpy.context.active_object, "N307_Kloda_Pien", M_PIEN_MOKRY)
mech = [blob(X - 0.5, -0.2, 0.6, 0.5, squash=0.35),
        blob(X + 0.6, 0.3, 0.5, 0.4, squash=0.3)]
join_as(mech, "N307_Kloda_Mech", M_MECH)

# ===========================================================================
# 8) OŚLIZGŁY GŁAZ — kamień w zielonym śluzie ściekającym po bokach
# ===========================================================================
X = 41
finish(blob(X, 0, 0.55, 0.85, squash=0.75), "N308_Glaz_Kamien", M_KAMIEN)
sliz = [blob(X + 0.05, 0.05, 1.0, 0.62, squash=0.35)]
for (a_deg, drop_len) in [(40, 0.5), (170, 0.35), (290, 0.45)]:
    a = math.radians(a_deg)
    drop = mini_sphere(X + math.cos(a) * 0.72, math.sin(a) * 0.72, 0.75, 0.1)
    drop.scale = (0.7, 0.7, drop_len / 0.2)
    sliz.append(drop)
join_as(sliz, "N308_Glaz_Sliz", M_SLIZ)

# ===========================================================================
# 9) ŚWIECĄCE BAGIENKO — kałuża blasku z drobinami unoszącymi się nad taflą
#    (nazwa "Drobiny" = FxClient sam je kołysze; serce bioluminescencji)
# ===========================================================================
X = 46
bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=1.2, depth=0.05,
                                    location=(X, 0, 0.06))
finish(bpy.context.active_object, "N309_Bagienko_TaflaGlow", M_BLASK)
drobiny = []
for (a_deg, d, z, r) in [(20, 0.5, 0.6, 0.09), (120, 0.8, 1.0, 0.08),
                         (230, 0.4, 1.4, 0.07), (320, 0.75, 0.8, 0.08)]:
    a = math.radians(a_deg)
    drobiny.append(mini_sphere(X + math.cos(a) * d, math.sin(a) * d, z, r))
join_as(drobiny, "N309_Bagienko_DrobinyGlow", M_BLASK)

# ===========================================================================
# 10) KORZEŃ-ŁUK — wygięty korzeń wystający z bagna (pół zakopany torus);
#     postawiony nad ścieżką robi naturalną bramkę
# ===========================================================================
X = 51
bpy.ops.mesh.primitive_torus_add(major_radius=1.6, minor_radius=0.28,
                                 major_segments=12, minor_segments=6,
                                 location=(X, 0, 0),
                                 rotation=(math.radians(90), 0, 0))
finish(bpy.context.active_object, "N310_KorzenLuk", M_PIEN_MOKRY)
finish(blob(X + 1.5, 0.1, 0.2, 0.45, squash=0.4), "N310_KorzenLuk_MechPrawy", M_MECH)
finish(blob(X - 1.5, -0.1, 0.2, 0.4, squash=0.4), "N310_KorzenLuk_MechLewy", M_MECH)

print("Gotowe! Kolekcja:", COLLECTION_NAME,
      "— 10 elementów natury Mokradeł. *Glow → Material=Neon.",
      "BIBLIOTEKA MODELI KOMPLETNA: 5/5 światów (grzyby + natura)!")
