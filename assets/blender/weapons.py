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


def add_hand(gx, gy, gz, glove_mat, sleeve_mat):
    """Gripda qo'l (glove) + orqaga-pastga cho'zilgan bilak/yeng (kameraga tomon)."""
    box("Glove", (0.085, 0.10, 0.075), (gx, gy, gz), glove_mat)
    # Bilak/yeng: -Y (orqaga, kameraga) va biroz -Z (pastga) cho'ziladi
    box("Forearm", (0.075, 0.22, 0.075), (gx, gy - 0.13, gz - 0.07), sleeve_mat, rot=(-26, 0, 0))


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
A_METAL = mat("A_Metal", (0.15, 0.15, 0.17), rough=0.4, metal=0.6)
A_DARK = mat("A_Dark", (0.07, 0.07, 0.08), rough=0.5, metal=0.5)
A_WOOD = mat("A_Wood", (0.30, 0.18, 0.09), rough=0.7)

box("Receiver", (0.058, 0.36, 0.09), (0, 0.05, 0), A_METAL)            # qabul qismi
cyl("Barrel", 0.017, 0.36, (0, 0.36, 0.02), A_DARK, rot=(90, 0, 0))     # stvol
box("BarrelShroud", (0.05, 0.18, 0.05), (0, 0.27, 0.02), A_METAL)       # stvol g'ilofi
for yy in [0.22, 0.30, 0.38]:                                          # g'ilof yivlari (detal)
    box("Vent", (0.053, 0.012, 0.053), (0, yy, 0.02), A_DARK)
box("Magazine", (0.04, 0.055, 0.20), (0, 0.05, -0.14), A_DARK, rot=(8, 0, 0))  # qiya magazin
box("MagWell", (0.046, 0.06, 0.05), (0, 0.05, -0.035), A_METAL)        # magazin uyasi
box("Grip", (0.04, 0.05, 0.11), (0, -0.07, -0.08), A_WOOD, rot=(20, 0, 0))  # tutqich
box("Stock", (0.045, 0.20, 0.06), (0, -0.22, -0.01), A_WOOD)          # qo'ndoq
box("StockPlate", (0.05, 0.02, 0.085), (0, -0.32, -0.01), A_DARK)     # qo'ndoq plitasi
box("FrontGrip", (0.035, 0.045, 0.09), (0, 0.18, -0.08), A_WOOD)      # oldingi tutqich
box("FrontSight", (0.012, 0.02, 0.05), (0, 0.50, 0.065), A_DARK)      # old nishon (mushka)
box("RearSight", (0.04, 0.03, 0.04), (0, -0.06, 0.07), A_DARK)        # orqa nishon
box("ChargeHandle", (0.055, 0.045, 0.022), (0.035, 0.0, 0.055), A_DARK)  # zatvor dastasi
box("EjectPort", (0.05, 0.08, 0.03), (0.032, 0.13, 0.04), A_DARK)     # gilza chiqargich
A_GLOVE = mat("A_Glove", (0.16, 0.12, 0.08), rough=0.7)
A_SLEEVE = mat("A_Sleeve", (0.41, 0.35, 0.23), rough=0.85)
add_hand(0.0, -0.05, -0.095, A_GLOVE, A_SLEEVE)   # tutqich (trigger) qo'li
add_hand(0.0, 0.18, -0.11, A_GLOVE, A_SLEEVE)     # oldingi tutqich qo'li
avtomat = join_export("Avtomat", "avtomat.glb")

# ============================================================================
# SNAYPER (durbin/scope bilan — sekin/kuchli, uzoq masofa)
# ============================================================================
clear_scene()
S_METAL = mat("S_Metal", (0.13, 0.13, 0.15), rough=0.4, metal=0.6)
S_DARK = mat("S_Dark", (0.05, 0.05, 0.06), rough=0.5, metal=0.5)
S_WOOD = mat("S_Wood", (0.26, 0.15, 0.08), rough=0.7)
S_LENS = mat("S_Lens", (0.25, 0.45, 0.65), rough=0.1, metal=0.3)       # ko'k linza

box("Stock", (0.05, 0.66, 0.10), (0, -0.05, -0.02), S_WOOD)           # uzun yog'och qo'ndoq
box("Cheek", (0.052, 0.20, 0.05), (0, -0.18, 0.045), S_WOOD)          # yonoq tayanchi
cyl("Barrel", 0.014, 0.88, (0, 0.52, 0.03), S_DARK, rot=(90, 0, 0))    # uzun ingichka stvol
box("Receiver", (0.05, 0.22, 0.07), (0, 0.06, 0.03), S_METAL)         # qabul qismi
box("Bolt", (0.11, 0.03, 0.03), (0.07, 0.04, 0.05), S_METAL)          # zatvor dastasi
box("BoltKnob", (0.045, 0.045, 0.045), (0.125, 0.04, 0.05), S_DARK)   # zatvor sharchasi
box("Trigger", (0.02, 0.03, 0.05), (0, 0.0, -0.06), S_METAL)          # tepki
box("Grip", (0.04, 0.05, 0.10), (0, -0.04, -0.07), S_WOOD, rot=(18, 0, 0))  # tutqich
box("Muzzle", (0.035, 0.06, 0.035), (0, 0.95, 0.03), S_DARK)          # stvol uchi (dulnaga)
# Durbin (scope) — stvol ustida, tirgaklarda
box("ScopeMountF", (0.03, 0.03, 0.07), (0, 0.18, 0.095), S_DARK)
box("ScopeMountR", (0.03, 0.03, 0.07), (0, -0.04, 0.095), S_DARK)
cyl("ScopeTube", 0.035, 0.34, (0, 0.07, 0.135), S_DARK, rot=(90, 0, 0))   # durbin tanasi
cyl("ScopeFront", 0.052, 0.06, (0, 0.25, 0.135), S_DARK, rot=(90, 0, 0))  # old ob'ektiv
cyl("ScopeRear", 0.047, 0.06, (0, -0.11, 0.135), S_DARK, rot=(90, 0, 0))  # ko'z qismi
cyl("LensF", 0.042, 0.012, (0, 0.278, 0.135), S_LENS, rot=(90, 0, 0))     # old linza (ko'k)
cyl("LensR", 0.037, 0.012, (0, -0.138, 0.135), S_LENS, rot=(90, 0, 0))    # ko'z linzasi
S_GLOVE = mat("S_Glove", (0.16, 0.12, 0.08), rough=0.7)
S_SLEEVE = mat("S_Sleeve", (0.41, 0.35, 0.23), rough=0.85)
add_hand(0.0, 0.0, -0.075, S_GLOVE, S_SLEEVE)     # tepki (trigger) qo'li
add_hand(0.0, 0.36, -0.045, S_GLOVE, S_SLEEVE)    # oldingi qo'l (forestock)
sniper = join_export("Snayper", "sniper.glb")


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
import_glb(os.path.join(a_dir, "sniper.glb"), 0.45)

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
