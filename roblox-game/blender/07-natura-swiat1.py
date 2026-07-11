# Pick a Shroom — NATURA ŚWIATA 1 (Las Liściasty): drzewa + dodatki
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_NaturaSwiat1" (elementy obok siebie co 6 j.).
#
# Styl: klockowato-uroczy Roblox low-poly, płaskie cieniowanie. ŁADNIE,
# ale bez przepychu — zwykły przyjemny las. Różne rozmiary w grze robi
# MapBuilder losową skalą klonów (0.8–1.4), więc tu jest po JEDNYM wzorcu.
#
# Zestaw: liściak, brzoza (kreski!), krzak, pieniek z grzybkami, omszała
# kłoda, kamień z mchem, stokrotka, dzwonek, kępka trawy, płat mchu.
# Części są OSOBNYMI obiektami (jeden MeshPart = jeden kolor) — nie łącz!

import bpy
import math
import random

COLLECTION_NAME = "PickAShroom_NaturaSwiat1"
random.seed(11)

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
    # styl Roblox: płaskie cieniowanie
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
M_PIEN = make_material("N_Pien", (0.38, 0.26, 0.16))
M_BRZOZA = make_material("N_BrzozaPien", (0.92, 0.90, 0.85))
M_KRESKI = make_material("N_BrzozaKreski", (0.15, 0.14, 0.13))
M_LISCIE = make_material("N_Liscie", (0.35, 0.62, 0.27))
M_LISCIE_J = make_material("N_LiscieJasne", (0.48, 0.72, 0.30))
M_SLOJE = make_material("N_Sloje", (0.80, 0.68, 0.48))
M_MECH = make_material("N_Mech", (0.42, 0.60, 0.25))
M_KAMIEN = make_material("N_Kamien", (0.52, 0.52, 0.55))
M_PLATKI = make_material("N_Platki", (0.97, 0.96, 0.92))
M_SRODEK = make_material("N_SrodekKwiatka", (0.95, 0.78, 0.25))
M_DZWONEK = make_material("N_Dzwonek", (0.48, 0.42, 0.80))
M_LODYGA = make_material("N_Lodyga", (0.33, 0.52, 0.24))
M_TRAWA = make_material("N_Trawa", (0.40, 0.65, 0.28))
M_GRZYBEK = make_material("N_MiniGrzybek", (0.80, 0.24, 0.20))
M_GRZYBEK_T = make_material("N_MiniGrzybekTrzon", (0.94, 0.91, 0.82))

# ===========================================================================
# 1) LIŚCIAK — klasyczne drzewo: pień + puszysta dwukolorowa korona
#    (dwa odcienie zieleni = tania głębia, wygląda drogo)
# ===========================================================================
X = 0
finish(trunk(X, 3.4, 0.55, 0.36), "N01_Lisciak_Pien", M_PIEN)
ciemne = [blob(X, 0, 4.4, 1.7), blob(X - 1.0, 0.5, 4.0, 1.15)]
join_as(ciemne, "N01_Lisciak_Korona", M_LISCIE)
jasne = [blob(X + 0.95, -0.35, 4.15, 1.05), blob(X + 0.15, 0.2, 5.1, 0.9)]
join_as(jasne, "N01_Lisciak_KoronaJasna", M_LISCIE_J)

# ===========================================================================
# 2) BRZOZA — smukły biały pień z CZARNYMI KRESKAMI, lekka korona wysoko
# ===========================================================================
X = 6
finish(trunk(X, 4.2, 0.3, 0.2), "N02_Brzoza_Pien", M_BRZOZA)
kreski = []
for i in range(7):
    a = math.radians(random.uniform(0, 360))
    h = 0.5 + i * 0.52
    r_at_h = 0.3 - (h / 4.2) * 0.1
    bpy.ops.mesh.primitive_cube_add(size=1, location=(
        X + math.cos(a) * r_at_h, math.sin(a) * r_at_h, h))
    kreska = bpy.context.active_object
    kreska.scale = (0.16, 0.05, 0.09)
    kreski.append(kreska)
join_as(kreski, "N02_Brzoza_Kreski", M_KRESKI)
korona_b = [blob(X, 0, 4.9, 1.15, squash=0.8),
            blob(X + 0.6, 0.3, 4.5, 0.8, squash=0.75)]
join_as(korona_b, "N02_Brzoza_Korona", M_LISCIE_J)

# ===========================================================================
# 3) KRZAK — niski, gęsty; wypełniacz poszycia
# ===========================================================================
X = 12
krzak = [blob(X, 0, 0.9, 1.1, squash=0.75),
         blob(X + 0.7, 0.35, 0.75, 0.7, squash=0.7),
         blob(X - 0.65, -0.3, 0.8, 0.75, squash=0.7)]
join_as(krzak, "N03_Krzak_Korona", M_LISCIE)

# ===========================================================================
# 4) PIENIEK — ścięte drzewo z jasnymi słojami i dwoma mini-grzybkami
# ===========================================================================
X = 18
finish(trunk(X, 0.9, 0.6, 0.52), "N04_Pieniek_Kora", M_PIEN)
bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=0.48, depth=0.08,
                                    location=(X, 0, 0.94))
finish(bpy.context.active_object, "N04_Pieniek_Sloje", M_SLOJE)
gt, gk = [], []
for (dx, dy, s) in [(0.45, 0.3, 0.55), (0.6, -0.15, 0.4)]:
    bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.08 * s / 0.5,
                                    radius2=0.06 * s / 0.5, depth=0.3 * s,
                                    location=(X + dx, dy, 0.98 + 0.15 * s))
    gt.append(bpy.context.active_object)
    gk.append(mini_sphere(X + dx, dy, 0.98 + 0.32 * s, 0.16 * s / 0.5 * 0.5, squash=0.6))
join_as(gt, "N04_Pieniek_GrzybkiTrzony", M_GRZYBEK_T)
join_as(gk, "N04_Pieniek_GrzybkiKapelusze", M_GRZYBEK)

# ===========================================================================
# 5) OMSZAŁA KŁODA — leżący pień z płatem mchu i jasnymi końcami
# ===========================================================================
X = 24
bpy.ops.mesh.primitive_cylinder_add(vertices=9, radius=0.45, depth=3.0,
                                    location=(X, 0, 0.45),
                                    rotation=(0, math.radians(90), math.radians(15)))
finish(bpy.context.active_object, "N05_Kloda_Pien", M_PIEN)
sloje = []
for endx in (-1.5, 1.5):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=9, radius=0.4, depth=0.06,
        location=(X + endx * math.cos(math.radians(15)),
                  endx * math.sin(math.radians(15)), 0.45),
        rotation=(0, math.radians(90), math.radians(15)))
    sloje.append(bpy.context.active_object)
join_as(sloje, "N05_Kloda_Sloje", M_SLOJE)
mech_k = [blob(X - 0.4, -0.1, 0.85, 0.55, squash=0.35),
          blob(X + 0.6, 0.2, 0.82, 0.4, squash=0.3)]
join_as(mech_k, "N05_Kloda_Mech", M_MECH)

# ===========================================================================
# 6) KAMIEŃ Z MCHEM — głaz z zieloną czapą (mech od północy!)
# ===========================================================================
X = 30
glaz = blob(X, 0, 0.55, 0.85, squash=0.75)
finish(glaz, "N06_Kamien_Glaz", M_KAMIEN)
czapa = blob(X - 0.15, 0.1, 1.0, 0.6, squash=0.35)
finish(czapa, "N06_Kamien_Mech", M_MECH)

# ===========================================================================
# 7) STOKROTKA — łodyga, 6 białych płatków, żółty środek
# ===========================================================================
X = 34
bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.05, radius2=0.035,
                                depth=0.9, location=(X, 0, 0.45))
finish(bpy.context.active_object, "N07_Stokrotka_Lodyga", M_LODYGA)
platki = []
for i in range(6):
    a = math.radians(i * 60)
    p = mini_sphere(X + math.cos(a) * 0.24, math.sin(a) * 0.24, 0.92, 0.15)
    p.scale = (1.4, 0.7, 0.35)
    platki.append(p)
join_as(platki, "N07_Stokrotka_Platki", M_PLATKI)
finish(mini_sphere(X, 0, 0.96, 0.13, squash=0.6), "N07_Stokrotka_Srodek", M_SRODEK)

# ===========================================================================
# 8) DZWONEK — pochylona łodyżka z fioletowym kielichem w dół
# ===========================================================================
X = 37
bpy.ops.mesh.primitive_cone_add(vertices=6, radius1=0.045, radius2=0.03,
                                depth=0.85, location=(X, 0, 0.42),
                                rotation=(math.radians(12), 0, 0))
finish(bpy.context.active_object, "N08_Dzwonek_Lodyga", M_LODYGA)
bpy.ops.mesh.primitive_cone_add(vertices=7, radius1=0.2, radius2=0.05,
                                depth=0.32,
                                location=(X, -0.14, 0.78))
finish(bpy.context.active_object, "N08_Dzwonek_Kielich", M_DZWONEK)

# ===========================================================================
# 9) KĘPKA TRAWY — 5 rozchylonych źdźbeł
# ===========================================================================
X = 40
zdzbla = []
for i in range(5):
    a = math.radians(i * 72 + 20)
    tilt = math.radians(random.uniform(10, 24))
    bpy.ops.mesh.primitive_cone_add(
        vertices=4, radius1=0.06, radius2=0.005, depth=0.75,
        location=(X + math.cos(a) * 0.12, math.sin(a) * 0.12, 0.36),
        rotation=(math.sin(a) * tilt, -math.cos(a) * tilt, 0))
    zdzbla.append(bpy.context.active_object)
join_as(zdzbla, "N09_Trawa_Zdzbla", M_TRAWA)

# ===========================================================================
# 10) PŁAT MCHU — miękka "poducha" do kładzenia pod drzewami
# ===========================================================================
X = 43
plat = [blob(X, 0, 0.16, 0.8, squash=0.22),
        blob(X + 0.5, 0.3, 0.14, 0.45, squash=0.25),
        blob(X - 0.45, -0.25, 0.15, 0.4, squash=0.22)]
join_as(plat, "N10_Mech_Plat", M_MECH)

print("Gotowe! Kolekcja:", COLLECTION_NAME,
      "— 10 elementów natury Świata 1. Eksport wg blender/README.md")
