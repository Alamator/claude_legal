# Pick a Shroom — 10 GATUNKÓW ŚWIATA 3 (Mokradła), low-poly
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_Swiat3" z 10 grzybami obok siebie (co 4 j.).
#
# Klimat mokradeł: błoto, śluz, woda, mgła i BIOLUMINESCENCJA — to świat
# świecących kałuż, więc glow wchodzi mocniej niż w Borze. Drabinka:
# 1 Błotnik → 10 Król Mokradeł (świecąca korona + dryfujące krople światła).
# Nazwy z "Halo"/"Drobiny"/"Glow" łapie FxClient (obrót/lewitacja/iskry).
# Styl: klockowy, płaskie cieniowanie. Części OSOBNO — nie łącz ich!
#
# W Roblox: części *Glow → Material=Neon; Trzęsak (galareta) i mgła Mglaka
# → dodatkowo Transparency ~0.35–0.5.

import bpy
import math
import random

COLLECTION_NAME = "PickAShroom_Swiat3"
random.seed(44)

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


def stem(x, height, r_bottom, r_top, name, material, tilt_deg=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=r_bottom,
                                    radius2=r_top, depth=height,
                                    location=(x, 0, height / 2),
                                    rotation=(0, math.radians(tilt_deg), 0))
    return finish(bpy.context.active_object, name, material)


def dome(x, z, radius, squash, name, material, y=0.0):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5,
                                         radius=radius, location=(x, y, z))
    return finish(bpy.context.active_object, name, material,
                  scale=(1.0, 1.0, squash))


def mini_sphere(x, y, z, r, squash=1.0):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=6, ring_count=4, radius=r,
                                         location=(x, y, z))
    obj = bpy.context.active_object
    if squash != 1.0:
        obj.scale = (1.0, 1.0, squash)
    return obj


def dots_on_dome(x, cap_z, cap_r, squash, name, material, pattern):
    parts = []
    for (angle_deg, dist_frac, size) in pattern:
        a = math.radians(angle_deg)
        d = cap_r * dist_frac
        dz = squash * math.sqrt(max(cap_r * cap_r - d * d, 0.0))
        parts.append(mini_sphere(x + math.cos(a) * d, math.sin(a) * d,
                                 cap_z + dz, size, squash=0.5))
    return join_as(parts, name, material)


def water_disc(x, z, radius, name, material):
    bpy.ops.mesh.primitive_cylinder_add(vertices=10, radius=radius, depth=0.05,
                                        location=(x, 0, z))
    return finish(bpy.context.active_object, name, material)


# --- materiały --------------------------------------------------------------
M_TRZON = make_material("S3_Trzon", (0.82, 0.80, 0.68))
M_BLOTO = make_material("S3_Bloto", (0.35, 0.28, 0.18))
M_BLOTNIK = make_material("S3_Blotnik", (0.48, 0.42, 0.24))
M_ZGNILEK = make_material("S3_Zgnilek", (0.50, 0.52, 0.28))
M_ZGNILIZNA = make_material("S3_Zgnilizna", (0.30, 0.26, 0.14))
M_GALARETA = make_material("S3_Galareta", (0.72, 0.62, 0.28), roughness=0.08)
M_MECH = make_material("S3_Mech", (0.38, 0.56, 0.26))
M_MSZARNIK = make_material("S3_Mszarnik", (0.44, 0.40, 0.26))
M_KURKA_B = make_material("S3_BagiennaKurka", (0.28, 0.58, 0.48))
M_WODA = make_material("S3_Woda", (0.16, 0.35, 0.42), roughness=0.05)
M_FOSFOREK = make_material("S3_Fosforek", (0.20, 0.26, 0.22))
M_FOSFOR = make_material("S3_FosforGlow", (0.45, 1.0, 0.55), glow=4.0)
M_SWIETLIK = make_material("S3_SwietlikGlow", (0.35, 0.95, 0.85), glow=3.0)
M_LATARNIE = make_material("S3_LatarnieGlow", (0.85, 1.0, 0.60), glow=5.0)
M_TOPIELEC = make_material("S3_Topielec", (0.24, 0.40, 0.36))
M_MGLAK = make_material("S3_MglakGlow", (0.88, 0.92, 0.94), glow=1.2)
M_MGLA = make_material("S3_Mgla", (0.92, 0.95, 0.97), roughness=0.6)
M_KROL = make_material("S3_Krol", (0.16, 0.30, 0.24))
M_KORONA = make_material("S3_KoronaGlow", (0.40, 1.0, 0.75), glow=4.0)
M_LILIA = make_material("S3_Lilia", (0.30, 0.55, 0.30))
M_KWIAT = make_material("S3_KwiatLilii", (0.92, 0.65, 0.80))

# ===========================================================================
# 1) BŁOTNIK (1) — uklepany w błocie: niska kopułka, bryzgi błota na rondzie
# ===========================================================================
X = 0
stem(X, 0.7, 0.34, 0.28, "M01_Blotnik_Trzon", M_TRZON)
dome(X, 0.75, 1.0, 0.4, "M01_Blotnik_Kapelusz", M_BLOTNIK)
dots_on_dome(X, 0.75, 1.0, 0.4, "M01_Blotnik_Bryzgi", M_BLOTO,
             [(40, 0.8, 0.16), (170, 0.85, 0.13), (280, 0.75, 0.15)])

# ===========================================================================
# 2) ZGNIŁEK (2) — oklapnięty: krzywy, opadnięty kapelusz z plamami zgnilizny
# ===========================================================================
X = 4
stem(X, 0.8, 0.3, 0.22, "M02_Zgnilek_Trzon", M_TRZON, tilt_deg=8)
bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5, radius=1.0,
                                     location=(X + 0.15, 0, 0.85),
                                     rotation=(math.radians(9), math.radians(-7), 0))
zgn = bpy.context.active_object
zgn.scale = (1.05, 0.85, 0.32)
finish(zgn, "M02_Zgnilek_Kapelusz", M_ZGNILEK)
dots_on_dome(X + 0.15, 0.85, 0.95, 0.3, "M02_Zgnilek_Plamy", M_ZGNILIZNA,
             [(60, 0.5, 0.2), (220, 0.6, 0.24)])

# ===========================================================================
# 3) TRZĘSAK BAGIENNY (3) — GALARETA: rozedrgana bryła, lustrzany połysk
#    (w Roblox daj Transparency ~0.35 — będzie jak żelka)
# ===========================================================================
X = 8
stem(X, 0.6, 0.3, 0.26, "M03_Trzesak_Trzon", M_TRZON)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2, radius=0.85,
                                      location=(X, 0, 1.0))
galareta = bpy.context.active_object
galareta.scale = (1.0, 1.0, 0.75)
bpy.context.view_layer.objects.active = galareta
bpy.ops.object.select_all(action="DESELECT")
galareta.select_set(True)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
for v in galareta.data.vertices:
    v.co.x += random.uniform(-0.09, 0.09)
    v.co.y += random.uniform(-0.09, 0.09)
    v.co.z += random.uniform(-0.06, 0.06)
finish(galareta, "M03_Trzesak_Galareta", M_GALARETA)

# ===========================================================================
# 4) MSZARNIK (4) — porośnięty: szarobury kapelusz pod kożuchem mchu
# ===========================================================================
X = 12
stem(X, 0.9, 0.32, 0.26, "M04_Mszarnik_Trzon", M_TRZON)
dome(X, 0.95, 1.05, 0.45, "M04_Mszarnik_Kapelusz", M_MSZARNIK)
mech = []
for (a_deg, d, r) in [(30, 0.35, 0.45), (150, 0.5, 0.38), (260, 0.3, 0.4), (0, 0.0, 0.5)]:
    a = math.radians(a_deg)
    dd = 1.05 * d
    dz = 0.45 * math.sqrt(max(1.05 ** 2 - dd * dd, 0.0))
    m = mini_sphere(X + math.cos(a) * dd, math.sin(a) * dd, 0.95 + dz, r, squash=0.35)
    mech.append(m)
join_as(mech, "M04_Mszarnik_Mech", M_MECH)

# ===========================================================================
# 5) BAGIENNA KURKA (6) — morski lejek z OCZKIEM WODY w środku
# ===========================================================================
X = 16
stem(X, 0.7, 0.28, 0.22, "M05_BagiennaKurka_Trzon", M_KURKA_B)
bpy.ops.mesh.primitive_cone_add(vertices=9, radius1=0.22, radius2=1.0,
                                depth=0.85, location=(X, 0, 1.1))
finish(bpy.context.active_object, "M05_BagiennaKurka_Lejek", M_KURKA_B)
water_disc(X, 1.38, 0.55, "M05_BagiennaKurka_Oczko", M_WODA)

# ===========================================================================
# 6) FOSFOREK (8) — ciemny malec z JARZĄCYMI SIĘ zielonymi kropkami
# ===========================================================================
X = 20
stem(X, 0.9, 0.26, 0.2, "M06_Fosforek_Trzon", M_FOSFOREK)
dome(X, 0.95, 0.85, 0.55, "M06_Fosforek_Kapelusz", M_FOSFOREK)
dots_on_dome(X, 0.95, 0.85, 0.55, "M06_Fosforek_KropkiGlow", M_FOSFOR,
             [(20, 0.55, 0.13), (110, 0.4, 0.11), (200, 0.6, 0.12),
              (300, 0.45, 0.11), (75, 0.0, 0.14)])

# ===========================================================================
# 7) ŚWIETLIK BAGIENNY (11) — żywa latarnia: świecący kapelusz, a pod rondem
#    wiszą KROPLE ŚWIATŁA (nazwa "Drobiny" = FxClient sam je kołysze)
# ===========================================================================
X = 24
stem(X, 1.3, 0.28, 0.22, "M07_Swietlik_Trzon", M_TRZON)
dome(X, 1.4, 1.05, 0.5, "M07_Swietlik_KapeluszGlow", M_SWIETLIK)
latarnie = []
for i in range(5):
    a = math.radians(i * 72 + 20)
    d = 1.05 * 0.8
    l = mini_sphere(X + math.cos(a) * d, math.sin(a) * d, 1.12, 0.12)
    l.scale = (0.8, 0.8, 1.5)
    latarnie.append(l)
join_as(latarnie, "M07_Swietlik_DrobinyLatarnieGlow", M_LATARNIE)

# ===========================================================================
# 8) TOPIELEC (15) — wynurza się z wody: przekrzywiony, z taflą wody u stóp
#    i kroplami ściekającymi z ronda
# ===========================================================================
X = 28
water_disc(X, 0.3, 1.15, "M08_Topielec_Tafla", M_WODA)
stem(X, 1.2, 0.34, 0.26, "M08_Topielec_Trzon", M_TOPIELEC, tilt_deg=16)
bpy.ops.mesh.primitive_uv_sphere_add(segments=8, ring_count=5, radius=1.05,
                                     location=(X + 0.35, 0, 1.35),
                                     rotation=(0, math.radians(14), 0))
topielec = bpy.context.active_object
topielec.scale = (1.0, 1.0, 0.5)
finish(topielec, "M08_Topielec_Kapelusz", M_TOPIELEC)
krople = []
for (a_deg, drop_z) in [(50, 1.0), (200, 1.1), (310, 0.95)]:
    a = math.radians(a_deg)
    k = mini_sphere(X + 0.35 + math.cos(a) * 0.9, math.sin(a) * 0.9, drop_z, 0.09)
    k.scale = (0.7, 0.7, 1.6)
    krople.append(k)
join_as(krople, "M08_Topielec_Krople", M_WODA)

# ===========================================================================
# 9) MGLAK (20) — owinięty własną mgłą: blada poświata + WIRUJĄCY pierścień
#    mgły (nazwa "Halo" = FxClient go obraca; w Roblox Transparency ~0.5)
# ===========================================================================
X = 32
stem(X, 1.4, 0.3, 0.24, "M09_Mglak_Trzon", M_TRZON)
dome(X, 1.5, 1.1, 0.55, "M09_Mglak_KapeluszGlow", M_MGLAK)
bpy.ops.mesh.primitive_torus_add(major_radius=1.45, minor_radius=0.16,
                                 major_segments=14, minor_segments=6,
                                 location=(X, 0, 1.45),
                                 rotation=(math.radians(8), 0, 0))
finish(bpy.context.active_object, "M09_Mglak_MglaHalo", M_MGLA)

# ===========================================================================
# 10) KRÓL MOKRADEŁ (28) — władca bagien: wielka ciemna kopuła, ŚWIECĄCA
#     KORONA z 5 kolców, dryfujące krople światła wokół i lilia u stóp
# ===========================================================================
X = 36
water_disc(X, 0.28, 1.3, "M10_Krol_Tafla", M_WODA)
stem(X, 1.7, 0.5, 0.36, "M10_Krol_Trzon", M_KROL)
dome(X, 1.8, 1.5, 0.55, "M10_Krol_Kapelusz", M_KROL)
korona = []
for i in range(5):
    a = math.radians(i * 72)
    bpy.ops.mesh.primitive_cone_add(
        vertices=5, radius1=0.13, radius2=0.015, depth=0.55,
        location=(X + math.cos(a) * 0.55, math.sin(a) * 0.55, 2.75))
    korona.append(bpy.context.active_object)
join_as(korona, "M10_Krol_KoronaGlow", M_KORONA)
drobiny = []
for (a_deg, d, z, r) in [(30, 1.5, 2.2, 0.12), (140, 1.75, 1.8, 0.1),
                         (230, 1.6, 2.5, 0.11), (320, 1.85, 2.05, 0.09)]:
    a = math.radians(a_deg)
    drobiny.append(mini_sphere(X + math.cos(a) * d, math.sin(a) * d, z, r,
                               squash=0.7))
join_as(drobiny, "M10_Krol_DrobinyGlow", M_KORONA)
bpy.ops.mesh.primitive_cylinder_add(vertices=9, radius=0.5, depth=0.06,
                                    location=(X + 1.0, 0.55, 0.33))
finish(bpy.context.active_object, "M10_Krol_Lilia", M_LILIA)
finish(mini_sphere(X + 1.0, 0.55, 0.44, 0.14, squash=0.7), "M10_Krol_KwiatLilii", M_KWIAT)

print("Gotowe! Kolekcja:", COLLECTION_NAME,
      "— 10 gatunków Mokradeł. *Glow → Material=Neon;",
      "Trzęsak Transparency ~0.35, mgła Mglaka ~0.5.")
