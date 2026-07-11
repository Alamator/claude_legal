# Pick a Shroom — MODELE DRZEW (liściaste + świerk + bagienne, low-poly)
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_Drzewa" z 3 drzewami obok siebie.
#
# Pień i korona to OSOBNE obiekty (w Roblox pomalujesz je niezależnie).

import bpy
import math

COLLECTION_NAME = "PickAShroom_Drzewa"


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
        bsdf.inputs["Roughness"].default_value = 0.95
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


def join_as(objs, name, material, coll):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    joined.data.materials.clear()
    joined.data.materials.append(material)
    move_to_collection(joined, coll)
    return joined


coll = get_collection(COLLECTION_NAME)
MAT_PIEN = make_material("DrzewoPien", (0.38, 0.26, 0.16))
MAT_LISCIE = make_material("DrzewoLiscie", (0.33, 0.62, 0.28))
MAT_IGLY = make_material("DrzewoIgly", (0.16, 0.44, 0.36))
MAT_BAGNO = make_material("DrzewoBagno", (0.34, 0.45, 0.24))


def make_trunk(x, height, r_bottom, r_top, name, tilt_deg=0.0):
    bpy.ops.mesh.primitive_cone_add(
        vertices=8, radius1=r_bottom, radius2=r_top, depth=height,
        location=(x, 0, height / 2),
        rotation=(math.radians(tilt_deg), 0, 0),
    )
    return finish(bpy.context.active_object, name, MAT_PIEN, coll)


def blob(x, y, z, r, squash=0.9):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=(x, y, z))
    obj = bpy.context.active_object
    obj.scale = (1.0, 1.0, squash)
    return obj


# ---------------------------------------------------------------------------
# 1) DRZEWO LIŚCIASTE — pień + korona z 4 zlepionych brył (chmurka)
# ---------------------------------------------------------------------------
make_trunk(0, 3.2, 0.55, 0.38, "Drzewo1_Pien")
korona = [
    blob(0, 0, 4.3, 1.7),
    blob(1.0, 0.5, 3.9, 1.15),
    blob(-1.05, -0.4, 4.0, 1.2),
    blob(0.2, -0.9, 4.7, 1.0),
]
join_as(korona, "Drzewo1_Korona", MAT_LISCIE, coll)

# ---------------------------------------------------------------------------
# 2) ŚWIERK — pień + 3 stożki malejące ku górze
# ---------------------------------------------------------------------------
make_trunk(6, 2.2, 0.42, 0.3, "Drzewo2_Pien")
stozki = []
for i, (r, h, z) in enumerate([(1.9, 2.2, 3.0), (1.45, 1.9, 4.4), (0.95, 1.7, 5.7)]):
    bpy.ops.mesh.primitive_cone_add(
        vertices=9, radius1=r, radius2=0.03, depth=h, location=(6, 0, z)
    )
    stozki.append(bpy.context.active_object)
join_as(stozki, "Drzewo2_Igly", MAT_IGLY, coll)

# ---------------------------------------------------------------------------
# 3) DRZEWO BAGIENNE — krzywy pień + niska rozlana korona
# ---------------------------------------------------------------------------
make_trunk(12, 2.4, 0.7, 0.45, "Drzewo3_Pien", tilt_deg=10)
bagno = [
    blob(12, 0.3, 3.0, 1.6, squash=0.5),
    blob(12.9, -0.5, 2.7, 1.0, squash=0.55),
    blob(11.1, 0.6, 2.8, 0.9, squash=0.5),
]
join_as(bagno, "Drzewo3_Korona", MAT_BAGNO, coll)

print("Gotowe! Kolekcja:", COLLECTION_NAME, "— 3 drzewa. Eksport wg blender/README.md")
