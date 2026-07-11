# Pick a Shroom — MODELE GRZYBÓW (4 warianty low-poly)
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_Grzyby" z 4 grzybami obok siebie.
#
# Każdy grzyb składa się z OSOBNYCH obiektów (Kapelusz / Trzon / Kropki),
# bo w Roblox jeden MeshPart = jeden kolor — osobne części pomalujesz
# niezależnie już w Studio. Eksport: patrz README.md w tym katalogu.

import bpy
import math

COLLECTION_NAME = "PickAShroom_Grzyby"

# ---------------------------------------------------------------------------
# Pomocnicze
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


def make_material(name, rgb):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
        bsdf.inputs["Roughness"].default_value = 0.9
    return mat


def finish(obj, name, material, coll, scale=None):
    obj.name = name
    if scale is not None:
        obj.scale = scale
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.clear()
    obj.data.materials.append(material)
    move_to_collection(obj, coll)
    return obj


# materiały (kolory robocze — i tak przemalujesz w Roblox)
coll = get_collection(COLLECTION_NAME)
MAT_KAPELUSZ = make_material("GrzybKapelusz", (0.80, 0.24, 0.20))
MAT_TRZON = make_material("GrzybTrzon", (0.94, 0.91, 0.82))
MAT_KROPKI = make_material("GrzybKropki", (0.98, 0.97, 0.94))

# ---------------------------------------------------------------------------
# Części grzyba
# ---------------------------------------------------------------------------

def make_stem(x, height, r_bottom, r_top, name):
    """Trzon: lekko zbieżny walec (stożek ścięty), 10 boków = low-poly."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=10,
        radius1=r_bottom,
        radius2=r_top,
        depth=height,
        location=(x, 0, height / 2),
    )
    return finish(bpy.context.active_object, name, MAT_TRZON, coll)


def make_cap_dome(x, z, radius, squash, name):
    """Kapelusz-kopuła: spłaszczona kula (12 segmentów = low-poly)."""
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=12, ring_count=8, radius=radius, location=(x, 0, z)
    )
    return finish(
        bpy.context.active_object, name, MAT_KAPELUSZ, coll,
        scale=(1.0, 1.0, squash),
    )


def make_cap_cone(x, z, radius, height, name):
    """Kapelusz-stożek (smukły, bajkowy)."""
    bpy.ops.mesh.primitive_cone_add(
        vertices=12, radius1=radius, radius2=0.02, depth=height,
        location=(x, 0, z + height / 2),
    )
    return finish(bpy.context.active_object, name, MAT_KAPELUSZ, coll)


def make_dots(x, cap_z, cap_r, squash, name, pattern):
    """Kropki: małe spłaszczone kulki NA powierzchni kopuły, złączone w 1 obiekt."""
    dots = []
    for (angle_deg, dist_frac, size) in pattern:
        a = math.radians(angle_deg)
        dx = math.cos(a) * cap_r * dist_frac
        dy = math.sin(a) * cap_r * dist_frac
        # wysokość punktu na kopule: z = squash * sqrt(r^2 - d^2)
        d = cap_r * dist_frac
        dz = squash * math.sqrt(max(cap_r * cap_r - d * d, 0.0))
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=8, ring_count=6, radius=size,
            location=(x + dx, dy, cap_z + dz),
        )
        dot = bpy.context.active_object
        dot.scale = (1.0, 1.0, 0.45)
        dots.append(dot)
    bpy.ops.object.select_all(action="DESELECT")
    for d in dots:
        d.select_set(True)
    bpy.context.view_layer.objects.active = dots[0]
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    joined.data.materials.clear()
    joined.data.materials.append(MAT_KROPKI)
    move_to_collection(joined, coll)
    return joined


# ---------------------------------------------------------------------------
# 4 warianty (obok siebie co 4 jednostki; 1 jednostka Blendera ≈ 1 stud)
# ---------------------------------------------------------------------------

# 1) KLASYK — muchomorek: kopuła + kropki
make_stem(0, 1.5, 0.45, 0.34, "Grzyb1_Trzon")
make_cap_dome(0, 1.45, 1.15, 0.62, "Grzyb1_Kapelusz")
make_dots(0, 1.45, 1.15, 0.62, "Grzyb1_Kropki",
          [(20, 0.55, 0.16), (140, 0.45, 0.13), (260, 0.6, 0.14), (80, 0.2, 0.12)])

# 2) SZEROKI TALERZ — płaski i przysadzisty
make_stem(4, 1.0, 0.55, 0.42, "Grzyb2_Trzon")
make_cap_dome(4, 0.98, 1.6, 0.38, "Grzyb2_Kapelusz")
make_dots(4, 0.98, 1.6, 0.38, "Grzyb2_Kropki",
          [(0, 0.5, 0.18), (120, 0.55, 0.15), (240, 0.5, 0.16)])

# 3) SMUKŁY STOŻEK — bajkowa "czarodziejska czapka"
make_stem(8, 2.0, 0.32, 0.24, "Grzyb3_Trzon")
make_cap_cone(8, 1.9, 0.95, 1.5, "Grzyb3_Kapelusz")

# 4) KULKA — okrągły "puf" (idealny na mini-grzybki na półkach)
make_stem(12, 0.9, 0.4, 0.32, "Grzyb4_Trzon")
make_cap_dome(12, 1.15, 0.95, 0.85, "Grzyb4_Kapelusz")
make_dots(12, 1.15, 0.95, 0.85, "Grzyb4_Kropki",
          [(60, 0.5, 0.14), (200, 0.4, 0.12), (320, 0.55, 0.13)])

print("Gotowe! Kolekcja:", COLLECTION_NAME, "— 4 grzyby. Eksport wg blender/README.md")
