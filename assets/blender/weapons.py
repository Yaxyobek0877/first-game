# -*- coding: utf-8 -*-
"""
O'yinchi qurollari — realistik low-poly viewmodel (v3): Avtomat = MP18, Snayper = Gewehr 98.

Tadqiqot asosida (tanib olinadigan siluet):
  MP18: yumaloq PERFORATSIYALI stvol g'ilofi + tubular qabul + CHAPDA snail drum magazin +
        miltiq uslubi yog'och qo'ndoq + o'ngda zatvor dastasi. (stik magazin EMAS!)
  Gewehr 98 snayper: uzun ochiq stvol + to'liq yog'och qo'ndoq/handguard + barrel bands +
        PASTGA EGILGAN zatvor dastasi + markazda past durbin (halqa/turret).

+Y oldinga (Godot'da -Z), +Z tepa. Natija: avtomat.glb, sniper.glb, _preview_weapons.png
"""

import bpy
import os
from math import radians
from mathutils import Vector


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


def _apply_bevel(o, width, segments=2):
    if width <= 0.0:
        return
    bpy.context.view_layer.objects.active = o
    md = o.modifiers.new(name="Bevel", type='BEVEL')
    md.width = width
    md.segments = segments
    md.limit_method = 'ANGLE'
    md.angle_limit = radians(35)
    bpy.ops.object.modifier_apply(modifier=md.name)


def box(name, size, loc, material, rot=(0, 0, 0), bev=0.004):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0], size[1], size[2])
    o.rotation_euler = (radians(rot[0]), radians(rot[1]), radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(material)
    _apply_bevel(o, bev)
    _objs.append(o)
    return o


def cyl(name, r, h, loc, material, rot=(0, 0, 0), verts=18, bev=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = (radians(rot[0]), radians(rot[1]), radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    _apply_bevel(o, bev)
    _objs.append(o)
    return o


def torus(name, major_r, minor_r, loc, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_r, minor_radius=minor_r, location=loc,
                                     major_segments=16, minor_segments=8)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = (radians(rot[0]), radians(rot[1]), radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    _objs.append(o)
    return o


def add_hand(gx, gy, gz, glove_mat, sleeve_mat):
    box("Glove", (0.085, 0.10, 0.075), (gx, gy, gz), glove_mat, bev=0.02)
    box("Knuckles", (0.085, 0.05, 0.028), (gx, gy + 0.03, gz + 0.05), glove_mat, bev=0.012)
    box("Forearm", (0.075, 0.22, 0.075), (gx, gy - 0.13, gz - 0.07), sleeve_mat, rot=(-26, 0, 0), bev=0.02)


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
    _objs.clear()
    return obj


# ============================================================================
# AVTOMAT = MP18 — yumaloq perforatsiyali g'ilof + snail drum (chapda)
# Barrel/jacket o'qi z=BZ; +Y oldinga.
# ============================================================================
clear_scene()
A_METAL = mat("A_Metal", (0.17, 0.17, 0.19), rough=0.5, metal=0.7)    # matte gunmetal
A_DARK = mat("A_Dark", (0.035, 0.035, 0.04), rough=0.6, metal=0.4)    # teshik/qora
A_WOOD = mat("A_Wood", (0.40, 0.25, 0.12), rough=0.55)                 # yong'oq
A_WOOD2 = mat("A_Wood2", (0.32, 0.19, 0.09), rough=0.6)
BZ = 0.02

# Tubular qabul (yo'g'onroq, markaz-orqa)
cyl("Receiver", 0.041, 0.26, (0, 0.03, BZ), A_METAL, rot=(90, 0, 0))    # y -0.10..0.16
# Perforatsiyali stvol g'ilofi (ingichkaroq, oldinga)
RJ = 0.036
cyl("Jacket", RJ, 0.36, (0, 0.37, BZ), A_METAL, rot=(90, 0, 0))         # y 0.19..0.55
# Teshiklar (yumaloq qora nuqtalar — 3 qator: tepa + ikki yon)
for k in range(8):
    yy = 0.23 + k * 0.040
    cyl("HoleT", 0.009, 0.014, (0, yy, BZ + RJ - 0.003), A_DARK)                       # tepa
    cyl("HoleR", 0.009, 0.014, (RJ * 0.52, yy, BZ + RJ * 0.86 - 0.003), A_DARK, rot=(0, 32, 0))   # o'ng-tepa
    cyl("HoleL", 0.009, 0.014, (-RJ * 0.52, yy, BZ + RJ * 0.86 - 0.003), A_DARK, rot=(0, -32, 0))  # chap-tepa
# Stvol uchi (g'ilofdan chiqadi) + dulnaga
cyl("Barrel", 0.015, 0.10, (0, 0.58, BZ), A_DARK, rot=(90, 0, 0))
# Nishonlar
box("FrontSight", (0.008, 0.022, 0.026), (0, 0.55, BZ + RJ + 0.005), A_DARK, bev=0)
box("RearSight", (0.034, 0.022, 0.022), (0, -0.04, BZ + 0.05), A_DARK, bev=0.002)

# Snail drum magazin (CHAPDA, yumaloq yassi baraban — MP18 belgisi)
box("MagNeck", (0.05, 0.05, 0.05), (-0.035, 0.07, BZ - 0.045), A_METAL, bev=0.004)
cyl("Drum", 0.07, 0.034, (-0.075, 0.05, BZ - 0.085), A_DARK, rot=(0, 90, 0), bev=0.004)   # disk (o'q X)
cyl("DrumHub", 0.022, 0.04, (-0.075, 0.05, BZ - 0.085), A_METAL, rot=(0, 90, 0))           # markaz tugma
cyl("DrumRim", 0.062, 0.04, (-0.075, 0.05, BZ - 0.085), A_METAL, rot=(0, 90, 0))           # ободок

# Zatvor dastasi (O'NGDA)
cyl("BoltKnob", 0.016, 0.055, (0.05, 0.0, BZ + 0.01), A_DARK, rot=(0, 90, 0))

# Tetik + halqa (qabul ostida)
torus("Guard", 0.03, 0.008, (0, -0.05, BZ - 0.07), A_METAL, rot=(0, 90, 0))
box("Trigger", (0.011, 0.016, 0.038), (0, -0.045, BZ - 0.055), A_DARK, bev=0.003)

# Yog'och: oldingi forend (g'ilof tagida, qabul oldi) + qo'ndoq wrist + but
box("Forend", (0.05, 0.13, 0.06), (0, 0.21, BZ - 0.05), A_WOOD)
box("Wrist", (0.046, 0.16, 0.06), (0, -0.14, BZ - 0.035), A_WOOD, rot=(6, 0, 0))      # qo'ndoq bo'yni
box("Butt", (0.052, 0.15, 0.115), (0, -0.30, BZ - 0.075), A_WOOD, rot=(10, 0, 0))     # but (pastga qiya)
box("ButtPlate", (0.057, 0.022, 0.12), (0, -0.375, BZ - 0.095), A_DARK)
box("Comb", (0.046, 0.12, 0.03), (0, -0.22, BZ + 0.02), A_WOOD2, bev=0.006)           # tepa qirra

A_GLOVE = mat("A_Glove", (0.16, 0.12, 0.08), rough=0.7)
A_SLEEVE = mat("A_Sleeve", (0.40, 0.34, 0.22), rough=0.85)
add_hand(0.0, -0.06, BZ - 0.085, A_GLOVE, A_SLEEVE)   # tetik (wrist) qo'li
add_hand(0.0, 0.21, BZ - 0.085, A_GLOVE, A_SLEEVE)    # oldingi (forend) qo'l
avtomat = join_export("Avtomat", "avtomat.glb")

# ============================================================================
# SNAYPER = Gewehr 98 — ochiq stvol + to'liq yog'och + pastga egilgan zatvor + durbin
# ============================================================================
clear_scene()
S_METAL = mat("S_Metal", (0.09, 0.09, 0.11), rough=0.34, metal=0.85)   # blued qora
S_DARK = mat("S_Dark", (0.04, 0.04, 0.05), rough=0.5, metal=0.6)
S_WOOD = mat("S_Wood", (0.34, 0.20, 0.09), rough=0.55)                  # yong'oq
S_WOOD2 = mat("S_Wood2", (0.28, 0.16, 0.07), rough=0.5)
S_LENS = mat("S_Lens", (0.22, 0.45, 0.68), rough=0.08, metal=0.4)
SZ = 0.035

# To'liq yog'och qo'ndoq (past chiziq) + handguard (stvol usti, qisman)
box("Stock", (0.052, 0.70, 0.10), (0, -0.02, SZ - 0.06), S_WOOD)
box("Comb", (0.048, 0.20, 0.05), (0, -0.20, SZ + 0.01), S_WOOD2, bev=0.006)
box("Forestock", (0.052, 0.46, 0.075), (0, 0.40, SZ - 0.04), S_WOOD)
box("Handguard", (0.046, 0.34, 0.04), (0, 0.42, SZ + 0.03), S_WOOD2, bev=0.005)
box("ButtPlate", (0.057, 0.02, 0.12), (0, -0.40, SZ - 0.075), S_DARK)
# Uzun OCHIQ stvol (old qismi yog'ochdan tashqarida) + dulnaga + barrel bands
cyl("Barrel", 0.014, 0.92, (0, 0.56, SZ + 0.005), S_DARK, rot=(90, 0, 0))
cyl("Muzzle", 0.02, 0.05, (0, 1.0, SZ + 0.005), S_DARK, rot=(90, 0, 0))
cyl("BandF", 0.03, 0.03, (0, 0.66, SZ - 0.02), S_METAL, rot=(90, 0, 0))
cyl("BandR", 0.03, 0.03, (0, 0.30, SZ - 0.02), S_METAL, rot=(90, 0, 0))
# Qabul + PASTGA EGILGAN zatvor dastasi (snayper belgisi)
box("Receiver", (0.05, 0.24, 0.07), (0, 0.05, SZ), S_METAL)
cyl("BoltBody", 0.017, 0.16, (0, 0.03, SZ + 0.03), S_METAL, rot=(90, 0, 0))
cyl("BoltArm", 0.012, 0.11, (0.055, -0.04, SZ - 0.02), S_METAL, rot=(35, 0, 0))     # pastga egilgan
cyl("BoltKnob", 0.024, 0.028, (0.075, -0.10, SZ - 0.05), S_DARK)                    # sharcha (pastda)
# Magazin qutisi (pastda) + spusk
box("MagBox", (0.05, 0.10, 0.05), (0, -0.01, SZ - 0.055), S_METAL, bev=0.004)
box("FloorPlate", (0.055, 0.11, 0.018), (0, -0.01, SZ - 0.085), S_DARK)
torus("Guard", 0.03, 0.008, (0, -0.08, SZ - 0.07), S_METAL, rot=(0, 90, 0))
box("Trigger", (0.012, 0.016, 0.045), (0, -0.08, SZ - 0.055), S_DARK, bev=0.003)
# Semi-pistol grip (qo'ndoq bo'yni yengil egilish)
box("Grip", (0.044, 0.08, 0.08), (0, -0.10, SZ - 0.07), S_WOOD, rot=(16, 0, 0))
# Nishonlar
box("FrontSight", (0.04, 0.025, 0.03), (0, 0.95, SZ + 0.03), S_DARK, bev=0.002)
box("RearSight", (0.05, 0.06, 0.018), (0, 0.20, SZ + 0.04), S_DARK, bev=0.002)
# Durbin (markazda, past — halqa + turret)
box("ScopeMountF", (0.026, 0.03, 0.06), (0, 0.18, SZ + 0.075), S_DARK, bev=0.003)
box("ScopeMountR", (0.026, 0.03, 0.06), (0, -0.05, SZ + 0.075), S_DARK, bev=0.003)
torus("RingF", 0.036, 0.008, (0, 0.18, SZ + 0.115), S_METAL, rot=(90, 0, 0))
torus("RingR", 0.036, 0.008, (0, -0.05, SZ + 0.115), S_METAL, rot=(90, 0, 0))
cyl("ScopeTube", 0.03, 0.38, (0, 0.06, SZ + 0.115), S_DARK, rot=(90, 0, 0))
cyl("ScopeFront", 0.046, 0.07, (0, 0.25, SZ + 0.115), S_DARK, rot=(90, 0, 0))
cyl("ScopeRear", 0.043, 0.07, (0, -0.12, SZ + 0.115), S_DARK, rot=(90, 0, 0))
cyl("LensF", 0.04, 0.012, (0, 0.285, SZ + 0.115), S_LENS, rot=(90, 0, 0))
cyl("LensR", 0.036, 0.012, (0, -0.155, SZ + 0.115), S_LENS, rot=(90, 0, 0))
cyl("Turret", 0.02, 0.038, (0, 0.06, SZ + 0.15), S_DARK)
S_GLOVE = mat("S_Glove", (0.16, 0.12, 0.08), rough=0.7)
S_SLEEVE = mat("S_Sleeve", (0.40, 0.34, 0.22), rough=0.85)
add_hand(0.0, -0.08, SZ - 0.10, S_GLOVE, S_SLEEVE)    # tetik qo'li
add_hand(0.0, 0.40, SZ - 0.07, S_GLOVE, S_SLEEVE)     # oldingi qo'l
sniper = join_export("Snayper", "sniper.glb")


# ============================================================================
# PREVIEW: ikkala qurol yonma-yon (CHAP tomondan — MP18 drumini ko'rsatish uchun)
# ============================================================================
clear_scene()
a_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "models"))


def import_glb(path, dx):
    pre = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in pre]
    for o in new:
        o.location.x += dx


import_glb(os.path.join(a_dir, "avtomat.glb"), -0.5)
import_glb(os.path.join(a_dir, "sniper.glb"), 0.5)

_cam_loc = (-0.95, -1.75, 0.7)   # chap-old (MP18 drumini ko'rsatish uchun)
bpy.ops.object.camera_add(location=_cam_loc)
cam = bpy.context.active_object
cam.data.lens = 40
bpy.context.scene.camera = cam
_d = Vector((0.0, 0.12, 0.0)) - Vector(_cam_loc)
cam.rotation_euler = _d.to_track_quat('-Z', 'Y').to_euler()
bpy.ops.object.light_add(type='SUN', location=(2, -2, 4))
bpy.context.active_object.data.energy = 4.5
bpy.context.active_object.rotation_euler = (radians(50), radians(10), radians(30))

scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.color_type = 'MATERIAL'
scene.display.shading.light = 'STUDIO'
scene.display.shading.show_shadows = True
scene.render.resolution_x = 960
scene.render.resolution_y = 560
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
