# -*- coding: utf-8 -*-
"""
O'yinchi qurollari — low-poly viewmodel (Avtomat va Miltiq), 1-jahon urushi uslubi.

Har qurol +Y (Blender) tomon "qaraydi" → glTF eksportdan keyin Godot'da -Z (oldinga)
bo'ladi, ya'ni kamera qaragan tomon. player.tscn'da Weapon tuguni ostiga qo'yiladi.

Natija:
  assets/models/avtomat.glb, assets/models/miltiq.glb
  assets/blender/_preview_weapons.png
"""

import bpy
import os
from math import radians


def clear_scene():
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials):
        for item in list(block):
            block.remove(item)


def mat(name, color, rough=0.5, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    m.diffuse_color = (color[0], color[1], color[2], 1.0)
    return m


_objs = []


def box(name, size, loc, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0], size[1], size[2])
    o.rotation_euler = (radians(rot[0]), radians(rot[1]), radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(material)
    _objs.append(o)
    return o


def cyl(name, r, h, loc, material, rot=(0, 0, 0), verts=10):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = (radians(rot[0]), radians(rot[1]), radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(material)
    bpy.ops.object.shade_flat()
    _objs.append(o)
    return o


def join_export(name, glb_name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in _objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = _objs[0]
    bpy.ops.object.join()
    obj = bpy.context.active_object
    obj.name = name
    glb_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "models"))
    os.makedirs(glb_dir, exist_ok=True)
    path = os.path.join(glb_dir, glb_name)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_animations=False)
    print("GLB:", glb_name, os.path.exists(path))
    _objs.clear()   # keyingi qurol uchun ro'yxatni tozalaymiz (eski havolalar qolmasin)
    return obj


# ============================================================================
# AVTOMAT (dastlabki avtomat / SMG — tez/zaif)
# Origin ~ tutqich/qabul qismi; stvol +Y ga cho'ziladi.
# ============================================================================
clear_scene()
A_METAL = mat("A_Metal", (0.16, 0.16, 0.18), rough=0.4, metal=0.6)
A_WOOD = mat("A_Wood", (0.30, 0.18, 0.09), rough=0.7)

box("Receiver", (0.055, 0.34, 0.085), (0, 0.05, 0), A_METAL)           # qabul qismi
cyl("Barrel", 0.018, 0.34, (0, 0.34, 0.02), A_METAL, rot=(90, 0, 0))    # stvol (oldinga)
box("BarrelShroud", (0.05, 0.16, 0.05), (0, 0.27, 0.02), A_METAL)       # stvol g'ilofi
box("Magazine", (0.04, 0.05, 0.17), (0, 0.08, -0.12), A_METAL)         # magazin (pastga)
box("Grip", (0.04, 0.05, 0.10), (0, -0.07, -0.07), A_WOOD, rot=(18, 0, 0))  # tutqich
box("Stock", (0.045, 0.18, 0.06), (0, -0.20, -0.01), A_WOOD)          # qo'ndoq (orqaga)
box("FrontGrip", (0.035, 0.04, 0.08), (0, 0.20, -0.07), A_WOOD)       # oldingi tutqich
avtomat = join_export("Avtomat", "avtomat.glb")

# ============================================================================
# MILTIQ (zatvorli miltiq — sekin/kuchli), nayza bilan
# ============================================================================
clear_scene()
M_METAL = mat("M_Metal", (0.20, 0.20, 0.22), rough=0.4, metal=0.6)
M_WOOD = mat("M_Wood", (0.33, 0.20, 0.10), rough=0.7)
M_BAYO = mat("M_Bayo", (0.55, 0.57, 0.60), rough=0.3, metal=0.7)

box("Stock", (0.05, 0.62, 0.09), (0, 0.0, -0.01), M_WOOD)              # yog'och qo'ndoq (uzun)
cyl("Barrel", 0.014, 0.66, (0, 0.42, 0.035), M_METAL, rot=(90, 0, 0))  # stvol (tepada, oldinga)
box("Receiver", (0.045, 0.14, 0.06), (0, 0.06, 0.03), M_METAL)        # qabul/zatvor qismi
box("Bolt", (0.10, 0.03, 0.03), (0.06, 0.05, 0.05), M_METAL)          # zatvor dastasi (yonda)
box("Trigger", (0.02, 0.03, 0.05), (0, 0.0, -0.06), M_METAL)          # tepki
box("Bayonet", (0.012, 0.24, 0.012), (0, 0.86, 0.035), M_BAYO)        # nayza (uchida)
miltiq = join_export("Miltiq", "miltiq.glb")


# ============================================================================
# PREVIEW: ikkala qurol yonma-yon
# ============================================================================
# Avtomat va miltiqni qayta yuklab yonma-yon qo'yamiz (preview uchun)
clear_scene()
a_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "models"))


def import_glb(path, dx):
    pre = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in pre]
    for o in new:
        o.location.x += dx


import_glb(os.path.join(a_dir, "avtomat.glb"), -0.45)
import_glb(os.path.join(a_dir, "miltiq.glb"), 0.45)

bpy.ops.object.empty_add(location=(0, 0.1, 0))
target = bpy.context.active_object
bpy.ops.object.camera_add(location=(0.7, -1.3, 0.6))
cam = bpy.context.active_object
cam.data.lens = 50
bpy.context.scene.camera = cam
c = cam.constraints.new('TRACK_TO')
c.target = target
c.track_axis = 'TRACK_NEGATIVE_Z'
c.up_axis = 'UP_Y'
bpy.ops.object.light_add(type='SUN', location=(2, -2, 4))
bpy.context.active_object.data.energy = 4.0
bpy.context.active_object.rotation_euler = (radians(50), radians(10), radians(30))

scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.color_type = 'MATERIAL'
scene.display.shading.light = 'STUDIO'
scene.display.shading.show_shadows = True
scene.render.resolution_x = 800
scene.render.resolution_y = 500
world = bpy.data.worlds[0] if bpy.data.worlds else bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.5, 0.53, 0.57, 1.0)
out_png = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_preview_weapons.png")
scene.render.filepath = out_png
bpy.ops.render.render(write_still=True)
print("RENDER_OK:", os.path.exists(out_png))
