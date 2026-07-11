# Pick a Shroom — MODEL SPRZEDAWCY NPC (klockowo-uroczy, low-poly)
# Jak użyć: Blender → zakładka "Scripting" → New → wklej całość → Run Script (▶)
# Powstanie kolekcja "PickAShroom_Sprzedawca" z częściami do osobnego
# malowania w Roblox: Skóra / Ubranie / Kapelusz / KropkiKapelusza / Twarz.
#
# Twarz sprzedawcy patrzy w stronę -Y (w Blenderze "do przodu").

import bpy
import math

COLLECTION_NAME = "PickAShroom_Sprzedawca"


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
        bsdf.inputs["Roughness"].default_value = 0.85
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


def cube(x, y, z, sx, sy, sz):
    bpy.ops.mesh.primitive_cube_add(size=1, location=(x, y, z))
    obj = bpy.context.active_object
    obj.scale = (sx, sy, sz)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def sphere(x, y, z, r, squash=1.0, segments=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=8,
                                         radius=r, location=(x, y, z))
    obj = bpy.context.active_object
    if squash != 1.0:
        obj.scale = (1.0, 1.0, squash)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


coll = get_collection(COLLECTION_NAME)
MAT_SKORA = make_material("NpcSkora", (0.95, 0.78, 0.60))
MAT_UBRANIE = make_material("NpcUbranie", (0.35, 0.55, 0.40))
MAT_KAPELUSZ = make_material("NpcKapelusz", (0.80, 0.24, 0.20))
MAT_KROPKI = make_material("NpcKropki", (0.98, 0.97, 0.94))
MAT_TWARZ = make_material("NpcTwarz", (0.12, 0.12, 0.16))

# --- ubranie: nogi + korpus + buty -----------------------------------------
ubranie = []
ubranie.append(cube(0, 0, 0.8, 1.5, 0.9, 1.6))       # nogi (jedna bryła)
ubranie.append(cube(0, 0, 2.45, 1.9, 1.1, 1.7))      # korpus
ubranie.append(cube(0, -0.15, 0.15, 1.7, 1.3, 0.35)) # buty/podstawka
join_as(ubranie, "Sprzedawca_Ubranie", MAT_UBRANIE, coll)

# --- skóra: głowa + ręce (prawa uniesiona w geście machania) ---------------
skora = []
skora.append(sphere(0, 0, 4.1, 0.72))                                 # głowa
skora.append(cube(-1.2, 0, 2.45, 0.5, 0.55, 1.5))                     # lewa ręka
# prawa ręka uniesiona ukośnie (na sztywno — animować będzie Roblox/tween)
bpy.ops.mesh.primitive_cube_add(size=1, location=(1.35, 0, 3.1),
                                rotation=(0, math.radians(-40), 0))
prawa = bpy.context.active_object
prawa.scale = (0.5, 0.55, 1.5)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
skora.append(prawa)
join_as(skora, "Sprzedawca_Skora", MAT_SKORA, coll)

# --- twarz: oczy + uśmiech (osobny ciemny obiekt) ---------------------------
twarz = []
for side in (-0.24, 0.24):
    twarz.append(sphere(side, -0.62, 4.2, 0.09, segments=8))
twarz.append(cube(0, -0.68, 3.9, 0.4, 0.08, 0.09))  # uśmiech
join_as(twarz, "Sprzedawca_Twarz", MAT_TWARZ, coll)

# --- grzybowy kapelusz + kropki ---------------------------------------------
kapelusz = sphere(0, 0, 4.75, 1.05, squash=0.55)
kapelusz.name = "Sprzedawca_Kapelusz"
kapelusz.data.materials.clear()
kapelusz.data.materials.append(MAT_KAPELUSZ)
move_to_collection(kapelusz, coll)

kropki = []
for (angle_deg, dist, size) in [(30, 0.55, 0.16), (150, 0.5, 0.13), (270, 0.45, 0.14)]:
    a = math.radians(angle_deg)
    dx = math.cos(a) * dist
    dy = math.sin(a) * dist
    dz = 0.55 * math.sqrt(max(1.05 ** 2 - (dist) ** 2, 0.0))
    kropki.append(sphere(dx, dy, 4.75 + dz, size, squash=0.5, segments=8))
join_as(kropki, "Sprzedawca_KropkiKapelusza", MAT_KROPKI, coll)

print("Gotowe! Kolekcja:", COLLECTION_NAME, "— sprzedawca. Eksport wg blender/README.md")
