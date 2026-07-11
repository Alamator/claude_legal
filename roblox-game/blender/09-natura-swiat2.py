# Pick a Shroom — NATURA ŚWIATA 2 (Bór Iglasty): drzewa + dodatki
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_NaturaSwiat2" (elementy obok siebie co 6 j.).
#
# Klimat: chłodny iglasty bór — świerki, sosna, martwe drzewo w głębi,
# szyszki na ściółce, paproć, borówki, szron na głazach. Ładnie, ale
# oszczędnie. Rozmiary w grze losuje MapBuilder skalą klonów (0.8–1.4).
# Styl: klockowy, płaskie cieniowanie. Części OSOBNO — nie łącz ich!

import bpy
import math
import random

COLLECTION_NAME = "PickAShroom_NaturaSwiat2"
random.seed(33)

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


def make_material(name, rgb, roughness=0.9):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
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


def trunk(x, height, r_bottom, r_top, tilt_deg=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r_bottom,
                                    radius2=r_top, depth=height,
                                    location=(x, 0, height / 2),
                                    rotation=(math.radians(tilt_deg), 0, 0))
    return bpy.context.active_object


def cone_layer(x, z, r, h):
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r, radius2=0.03,
                                    depth=h, location=(x, 0, z))
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


# --- materiały --------------------------------------------------------------
M_PIEN = make_material("N2_Pien", (0.34, 0.24, 0.15))
M_SOSNA_PIEN = make_material("N2_SosnaPien", (0.52, 0.33, 0.18))
M_MARTWE = make_material("N2_MartweDrewno", (0.32, 0.29, 0.26))
M_SWIERK = make_material("N2_Swierk", (0.15, 0.36, 0.29))
M_SWIERK_J = make_material("N2_SwierkJasny", (0.24, 0.48, 0.38))
M_SOSNA_K = make_material("N2_SosnaKorona", (0.22, 0.44, 0.30))
M_SLOJE = make_material("N2_Sloje", (0.78, 0.66, 0.46))
M_IGLIWIE = make_material("N2_Igliwie", (0.55, 0.38, 0.20))
M_SZYSZKA = make_material("N2_Szyszka", (0.48, 0.33, 0.18))
M_SZYSZKA_J = make_material("N2_SzyszkaJasna", (0.64, 0.47, 0.28))
M_PAPROC = make_material("N2_Paproc", (0.28, 0.54, 0.28))
M_KAMIEN = make_material("N2_Kamien", (0.48, 0.49, 0.54))
M_SZRON = make_material("N2_Szron", (0.93, 0.96, 1.0), roughness=0.25)
M_BOROWKA_L = make_material("N2_BorowkaListki", (0.20, 0.37, 0.24))
M_BOROWKA_O = make_material("N2_BorowkaOwoce", (0.22, 0.26, 0.48))

# ===========================================================================
# 1) ŚWIERK DUŻY — 4 piętra, przeplatane dwoma odcieniami (głębia)
# ===========================================================================
X = 0
finish(trunk(X, 2.4, 0.45, 0.32), "N201_Swierk_Pien", M_PIEN)
ciemne = [cone_layer(X, 3.2, 2.1, 2.4), cone_layer(X, 5.9, 1.35, 1.9)]
jasne = [cone_layer(X, 4.6, 1.7, 2.1), cone_layer(X, 7.0, 0.85, 1.6)]
join_as(ciemne, "N201_Swierk_PietraCiemne", M_SWIERK)
join_as(jasne, "N201_Swierk_PietraJasne", M_SWIERK_J)

# ===========================================================================
# 2) ŚWIERK MŁODY — smuklejszy, 3 piętra (do gęstych ścian lasu)
# ===========================================================================
X = 7
finish(trunk(X, 1.6, 0.3, 0.22), "N202_SwierkMlody_Pien", M_PIEN)
mlody = [cone_layer(X, 2.3, 1.3, 1.7), cone_layer(X, 3.5, 0.95, 1.5),
         cone_layer(X, 4.5, 0.6, 1.2)]
join_as(mlody, "N202_SwierkMlody_Pietra", M_SWIERK)

# ===========================================================================
# 3) SOSNA — wysoki goły pień, korona-parasol dopiero na szczycie
# ===========================================================================
X = 13
finish(trunk(X, 5.2, 0.4, 0.26, tilt_deg=3), "N203_Sosna_Pien", M_SOSNA_PIEN)
korona = [blob(X + 0.2, 0, 5.9, 1.5, squash=0.45),
          blob(X + 1.1, 0.4, 5.6, 0.9, squash=0.5),
          blob(X - 0.8, -0.3, 5.7, 1.0, squash=0.45)]
join_as(korona, "N203_Sosna_Korona", M_SOSNA_K)

# ===========================================================================
# 4) MARTWE DRZEWO — nagi, pochylony pień z 3 suchymi konarami
#    (akcent do głębokich pierścieni — robi klimat bez horroru)
# ===========================================================================
X = 19
finish(trunk(X, 4.0, 0.38, 0.12, tilt_deg=7), "N204_Martwe_Pien", M_MARTWE)
konary = []
for (h, a_deg, tilt, dl) in [(2.2, 40, 55, 1.3), (2.9, 190, 50, 1.1), (3.4, 300, 42, 0.9)]:
    a = math.radians(a_deg)
    bpy.ops.mesh.primitive_cone_add(
        vertices=5, radius1=0.09, radius2=0.01, depth=dl,
        location=(X + math.cos(a) * dl * 0.4, math.sin(a) * dl * 0.4, h),
        rotation=(math.sin(a) * math.radians(tilt),
                  -math.cos(a) * math.radians(tilt), 0))
    konary.append(bpy.context.active_object)
join_as(konary, "N204_Martwe_Konary", M_MARTWE)

# ===========================================================================
# 5) PNIAK Z IGLIWIEM — ścięty świerk, wokół rude płaty opadłych igieł
# ===========================================================================
X = 25
finish(trunk(X, 0.8, 0.55, 0.48), "N205_Pniak_Kora", M_PIEN)
bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.44, depth=0.07,
                                    location=(X, 0, 0.84))
finish(bpy.context.active_object, "N205_Pniak_Sloje", M_SLOJE)
igliwie = [blob(X + 0.7, 0.3, 0.08, 0.5, squash=0.15),
           blob(X - 0.6, -0.35, 0.07, 0.45, squash=0.15),
           blob(X + 0.1, -0.7, 0.07, 0.35, squash=0.15)]
join_as(igliwie, "N205_Pniak_Igliwie", M_IGLIWIE)

# ===========================================================================
# 6) SZYSZKA — leżąca na ściółce, z łuskami (do rozsypania po całym borze)
# ===========================================================================
X = 30
bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=0.3, radius2=0.06,
                                depth=0.85, location=(X, 0, 0.28),
                                rotation=(0, math.radians(72), 0))
finish(bpy.context.active_object, "N206_Szyszka_Rdzen", M_SZYSZKA)
luski = []
for (t, count) in [(0.22, 5), (0.5, 4), (0.75, 3)]:
    # pozycje wzdłuż leżącej osi szyszki
    cx = X - 0.42 + t * 0.85
    r_at = 0.28 * (1.0 - t * 0.75)
    for i in range(count):
        a = math.radians(i * (360 / count) + t * 90)
        l = mini_sphere(cx, math.cos(a) * r_at, 0.28 + math.sin(a) * r_at, 0.09)
        l.scale = (0.6, 1.0, 0.7)
        luski.append(l)
join_as(luski, "N206_Szyszka_Luski", M_SZYSZKA_J)

# ===========================================================================
# 7) KUPKA SZYSZEK — trzy proste szyszki jedna przy drugiej (tani wypełniacz)
# ===========================================================================
X = 33
kupka = []
for (dx, dy, a_deg) in [(0, 0, 60), (0.5, 0.25, 130), (0.2, -0.4, 10)]:
    bpy.ops.mesh.primitive_cone_add(
        vertices=7, radius1=0.22, radius2=0.05, depth=0.6,
        location=(X + dx, dy, 0.2),
        rotation=(0, math.radians(75), math.radians(a_deg)))
    kupka.append(bpy.context.active_object)
join_as(kupka, "N207_KupkaSzyszek", M_SZYSZKA)

# ===========================================================================
# 8) PAPROĆ — 6 liści rozchodzących się promieniście
# ===========================================================================
X = 36
liscie = []
for i in range(6):
    a = math.radians(i * 60 + 12)
    tilt = math.radians(52)
    bpy.ops.mesh.primitive_cube_add(
        size=1,
        location=(X + math.cos(a) * 0.45, math.sin(a) * 0.45, 0.42),
        rotation=(math.sin(a) * tilt, -math.cos(a) * tilt, 0))
    lisc = bpy.context.active_object
    lisc.scale = (0.22, 1.1, 0.05)
    liscie.append(lisc)
join_as(liscie, "N208_Paproc_Liscie", M_PAPROC)

# ===========================================================================
# 9) GŁAZ ZE SZRONEM — zimny brat kamienia z mchem ze Świata 1
# ===========================================================================
X = 40
finish(blob(X, 0, 0.6, 0.9, squash=0.75), "N209_Glaz_Kamien", M_KAMIEN)
finish(blob(X + 0.1, -0.05, 1.1, 0.62, squash=0.3), "N209_Glaz_Szron", M_SZRON)

# ===========================================================================
# 10) KRZACZEK BORÓWEK — niski, ciemnozielony, z granatowymi jagodami
# ===========================================================================
X = 44
krzak = [blob(X, 0, 0.45, 0.75, squash=0.6),
         blob(X + 0.5, 0.2, 0.4, 0.45, squash=0.55)]
join_as(krzak, "N210_Borowki_Listki", M_BOROWKA_L)
jagody = []
for i in range(6):
    a = math.radians(i * 60 + 25)
    d = random.uniform(0.25, 0.6)
    jagody.append(mini_sphere(X + math.cos(a) * d, math.sin(a) * d,
                              0.62 + random.uniform(-0.08, 0.14), 0.09))
join_as(jagody, "N210_Borowki_Owoce", M_BOROWKA_O)

print("Gotowe! Kolekcja:", COLLECTION_NAME,
      "— 10 elementów natury Boru Iglastego. Eksport wg blender/README.md")
