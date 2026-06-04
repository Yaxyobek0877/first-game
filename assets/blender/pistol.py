# -*- coding: utf-8 -*-
"""
Topponcha (Luger P08) — low-poly viewmodel, BOG'LANGAN markaziy ramka bilan (v3).

Oldingi muammo: stvol/toggle yuqorida, grip pastda, ularni bog'lovchi MARKAZIY RAMKA
yetishmasdi ("markazi yo'q" ko'rinardi). Endi to'liq frame (lower receiver) qo'shildi:
stvol/breech → frame → grip hammasi yaxlit ulanadi. Detallar: stepped barrel, yumaloq
toggle knoblar, grip safety, magazin, nishonlar, tepki halqasi.

Qurol +Y (Blender) → Godot'da -Z (oldinga); +Z = tepa. player.tscn da "PistolModel".
5 burchakdan preview render: _preview_pistol_{right,left,front,back,persp}.png

Natija:
  assets/models/topponcha.glb  (ikki qo'l bilan)
  assets/blender/_preview_pistol_*.png  (5 ta — qo'lsiz, toza ko'rinish)
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


def box(name, size, loc, material, rot=(0, 0, 0), bev=0.003):
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


def cyl(name, r, h, loc, material, rot=(0, 0, 0), verts=18):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = (radians(rot[0]), radians(rot[1]), radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
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
    box("Glove", (0.075, 0.09, 0.07), (gx, gy, gz), glove_mat, bev=0.018)
    box("Knuckles", (0.075, 0.045, 0.026), (gx, gy + 0.025, gz + 0.045), glove_mat, bev=0.01)
    box("Forearm", (0.07, 0.20, 0.07), (gx, gy - 0.12, gz - 0.06), sleeve_mat, rot=(-28, 0, 0), bev=0.018)


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
# TOPPONCHA (Luger P08) — barrel axis z=0.075 (tepa), grip ~32° orqaga
# ============================================================================
clear_scene()
P_METAL = mat("P_Metal", (0.12, 0.12, 0.14), rough=0.30, metal=0.88)
P_DARK = mat("P_Dark", (0.045, 0.045, 0.055), rough=0.5, metal=0.6)
P_WOOD = mat("P_Wood", (0.27, 0.15, 0.07), rough=0.5)
P_BRASS = mat("P_Brass", (0.55, 0.42, 0.16), rough=0.35, metal=0.9)

BZ = 0.075   # barrel axis balandligi (z)

# --- Stvol (oldinga) ---
cyl("Barrel", 0.015, 0.26, (0, 0.27, BZ), P_METAL, rot=(90, 0, 0))           # asosiy stvol
cyl("MuzzleRing", 0.019, 0.03, (0, 0.40, BZ), P_DARK, rot=(90, 0, 0))        # dulnaga
cyl("BarrelStep", 0.024, 0.07, (0, 0.16, BZ), P_METAL, rot=(90, 0, 0))       # Luger stepped root
box("FrontSight", (0.007, 0.012, 0.022), (0, 0.385, BZ + 0.026), P_DARK, bev=0)

# --- Breech / receiver (toggle ustida turadi) ---
box("Receiver", (0.044, 0.17, 0.075), (0, 0.06, BZ), P_METAL)               # breech bloki
# Toggle (Luger belgisi) — ikki bo'g'im + yumaloq knoblar
box("ToggleRear", (0.038, 0.07, 0.032), (0, 0.0, BZ + 0.052), P_DARK, rot=(-8, 0, 0))
box("ToggleFront", (0.034, 0.06, 0.026), (0, 0.07, BZ + 0.045), P_METAL, bev=0.003)
cyl("KnobL", 0.021, 0.018, (0.043, 0.0, BZ + 0.06), P_DARK, rot=(0, 90, 0))
cyl("KnobR", 0.021, 0.018, (-0.043, 0.0, BZ + 0.06), P_DARK, rot=(0, 90, 0))
box("RearSight", (0.03, 0.016, 0.018), (0, -0.05, BZ + 0.03), P_DARK, bev=0.002)
box("RearNotch", (0.008, 0.02, 0.012), (0, -0.05, BZ + 0.042), P_METAL, bev=0)

# --- MARKAZIY RAMKA (frame / lower receiver) — HAMMANI BOG'LAYDI ---
# Breech ostidan grip boshigacha yaxlit tana (avval yetishmagan qism).
box("Frame", (0.046, 0.19, 0.085), (0, 0.02, BZ - 0.072), P_METAL)          # asosiy frame bloki
box("FrameFront", (0.042, 0.05, 0.055), (0, 0.135, BZ - 0.055), P_METAL, bev=0.004)  # stvol oldi (dust cover)
box("FrameRear", (0.044, 0.05, 0.08), (0, -0.085, BZ - 0.045), P_METAL, bev=0.004)   # orqa (grip safety tomon)

# --- Tepki + halqa ---
torus("Guard", 0.03, 0.008, (0, 0.0, BZ - 0.16), P_METAL, rot=(0, 90, 0))
box("Trigger", (0.011, 0.015, 0.032), (0, 0.005, BZ - 0.145), P_DARK, bev=0.003)

# --- Grip (~32° orqaga) — frame orqa-pastidan chiqadi, yaxlit ulanadi ---
GY, GZ = -0.085, BZ - 0.20
box("GripFrame", (0.044, 0.062, 0.18), (0, GY, GZ), P_METAL, rot=(32, 0, 0))
box("GripPlateL", (0.013, 0.052, 0.155), (0.037, GY, GZ), P_WOOD, rot=(32, 0, 0))
box("GripPlateR", (0.013, 0.052, 0.155), (-0.037, GY, GZ), P_WOOD, rot=(32, 0, 0))
box("BackStrap", (0.03, 0.026, 0.12), (0, -0.045, BZ - 0.12), P_METAL, rot=(32, 0, 0), bev=0.004)  # grip safety/orqa
box("MagFloor", (0.05, 0.058, 0.018), (0, -0.145, BZ - 0.275), P_DARK, rot=(32, 0, 0))
cyl("MagFollower", 0.01, 0.018, (0, -0.085, BZ - 0.27), P_BRASS, rot=(90, 0, 0))


# ============================================================================
# 5 BURCHAKDAN PREVIEW (qo'lsiz — toza ko'rinish), keyin qo'l qo'shib eksport
# ============================================================================
_TARGET = (0.0, 0.05, BZ - 0.07)   # gun massasi markazi (mo'ljal)


def setup_render():
    bpy.ops.object.light_add(type='SUN', location=(2, -2, 4))
    s = bpy.context.active_object
    s.data.energy = 4.2
    s.rotation_euler = (radians(52), radians(8), radians(28))
    bpy.ops.object.light_add(type='SUN', location=(-2, 2, 3))
    f = bpy.context.active_object
    f.data.energy = 1.5
    f.rotation_euler = (radians(60), 0, radians(210))
    bpy.ops.object.camera_add(location=(1.0, 0.05, 0.12))
    cam = bpy.context.active_object
    cam.data.lens = 46
    bpy.context.scene.camera = cam
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.color_type = 'MATERIAL'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.show_shadows = True
    sc.render.resolution_x = 720
    sc.render.resolution_y = 540
    world = bpy.data.worlds[0] if bpy.data.worlds else bpy.data.worlds.new("World")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.5, 0.53, 0.57, 1.0)
    return cam


def render_view(cam, loc, name):
    # Qo'lda mo'ljal (TRACK_TO constraint render oldidan yangilanmaydi — shuning uchun look_at).
    cam.location = loc
    d = Vector(_TARGET) - Vector(loc)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_preview_pistol_%s.png" % name)
    bpy.context.scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("RENDER:", name, os.path.exists(out))


_cam = setup_render()
render_view(_cam, (1.0, 0.06, 0.12), "right")     # o'ng yon
render_view(_cam, (-1.0, 0.06, 0.12), "left")     # chap yon
render_view(_cam, (0.06, 1.15, 0.16), "front")    # old (dulnaga tomon)
render_view(_cam, (0.06, -1.1, 0.16), "back")     # orqa
render_view(_cam, (0.78, -0.78, 0.7), "persp")    # 3/4 perspektiva

# Endi qo'llar qo'shib eksport (o'yin uchun) — preview'da qo'l yo'q edi.
P_GLOVE = mat("P_Glove", (0.15, 0.11, 0.07), rough=0.7)
P_SLEEVE = mat("P_Sleeve", (0.40, 0.34, 0.22), rough=0.85)
add_hand(0.0, -0.10, BZ - 0.18, P_GLOVE, P_SLEEVE)        # asosiy qo'l
add_hand(-0.05, -0.135, BZ - 0.215, P_GLOVE, P_SLEEVE)   # tayanch qo'l
pistol = join_export("Topponcha", "topponcha.glb")
print("DONE")
