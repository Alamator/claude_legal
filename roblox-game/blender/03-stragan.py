# Pick a Shroom — MODEL STRAGANU (low-poly, części do osobnego malowania)
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_Stragan": drewno / daszek / pasy / skrzynki.

import bpy
import math

COLLECTION_NAME = "PickAShroom_Stragan"


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


def cube(x, y, z, sx, sy, sz, rot_z_deg=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z),
                                    rotation=(0, 0, math.radians(rot_z_deg)))
    obj = bpy.context.active_object
    obj.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def cylinder(x, y, z, r, h, vertices=8):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=r, depth=h,
                                        location=(x, y, z))
    return bpy.context.active_object


coll = get_collection(COLLECTION_NAME)
MAT_DREWNO = make_material("StraganDrewno", (0.55, 0.38, 0.22))
MAT_DASZEK = make_material("StraganDaszek", (0.78, 0.20, 0.18))
MAT_PASY = make_material("StraganPasy", (0.95, 0.93, 0.86))

# --- konstrukcja drewniana: 4 słupki + lada + blat tylny -------------------
drewno = []
for dx in (-3.5, 3.5):
    for dy in (-3.0, 3.0):
        drewno.append(cylinder(dx, dy, 3.0, 0.22, 6.0))
drewno.append(cube(0, 3.0, 1.6, 7.4, 0.9, 1.0))    # lada od frontu
drewno.append(cube(0, -2.9, 1.3, 7.0, 0.8, 0.7))   # blat tylny
join_as(drewno, "Stragan_Drewno", MAT_DREWNO, coll)

# --- daszek: dwie pochylone połacie ----------------------------------------
daszek = []
for side, tilt in ((1, -18), (-1, 18)):
    bpy.ops.mesh.primitive_cube_add(
        size=1, location=(0, side * 2.05, 6.6),
        rotation=(math.radians(tilt), 0, 0))
    polac = bpy.context.active_object
    polac.scale = (8.4, 4.4, 0.25)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    daszek.append(polac)
join_as(daszek, "Stragan_Daszek", MAT_DASZEK, coll)

# --- białe pasy na daszku (osobny obiekt = osobny kolor w Roblox) ----------
pasy = []
for px in (-2.8, 0.0, 2.8):
    for side, tilt in ((1, -18), (-1, 18)):
        bpy.ops.mesh.primitive_cube_add(
            size=1, location=(px, side * 2.05, 6.74),
            rotation=(math.radians(tilt), 0, 0))
        pas = bpy.context.active_object
        pas.scale = (1.1, 4.5, 0.12)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        pasy.append(pas)
join_as(pasy, "Stragan_Pasy", MAT_PASY, coll)

# --- skrzynki z towarem obok lady ------------------------------------------
skrzynki = []
skrzynki.append(cube(-5.2, 2.2, 0.8, 1.8, 1.8, 1.6, rot_z_deg=8))
skrzynki.append(cube(5.2, 2.4, 0.8, 1.8, 1.8, 1.6, rot_z_deg=-12))
skrzynki.append(cube(5.0, 2.2, 2.2, 1.5, 1.5, 1.2, rot_z_deg=20))
join_as(skrzynki, "Stragan_Skrzynki", MAT_DREWNO, coll)

print("Gotowe! Kolekcja:", COLLECTION_NAME, "— stragan. Eksport wg blender/README.md")
