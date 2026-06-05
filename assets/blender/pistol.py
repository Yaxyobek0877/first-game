# -*- coding: utf-8 -*-
"""
Topponcha — Colt Woodsman uslubidagi nishon to'pponchasi (referens rasmga moslab, v4).

Oldingi muammo: asosiy tana (frame/receiver) va MAGAZIN (o'qdon) aniq emas edi.
Endi: yaxlit asosiy RECEIVER tanasi (uzun, to'rtburchak) + uzun blued stvol + orqada
yivli bolt (cocking piece) + aniq MAGAZIN (grip ostidan chiqib turgan tagliklik/floorplate
+ barmoq tayanchi) + yong'och grip plitalari + mushka/orqa nishon + tepki halqasi.

Qurol +Y (Blender) → Godot'da -Z (oldinga); +Z = tepa. player.tscn da "PistolModel".
5 burchakdan preview: _preview_pistol_{right,left,front,back,persp}.png

Natija:
  assets/models/topponcha.glb  (ikki qo'l bilan)
"""

import bpy
import os
from math import radians, sin, cos
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


def cyl(name, r, h, loc, material, rot=(0, 0, 0), verts=20):
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
                                     major_segments=18, minor_segments=9)
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
# TOPPONCHA (Colt Woodsman) — barrel axis z=BZ; grip ~26° orqaga
# ============================================================================
clear_scene()
W_BARREL = mat("W_Barrel", (0.04, 0.04, 0.05), rough=0.26, metal=0.9)    # blued qora stvol
W_FRAME = mat("W_Frame", (0.14, 0.15, 0.19), rough=0.34, metal=0.82)     # ko'k-kulrang frame (case-hardened)
W_DARK = mat("W_Dark", (0.03, 0.03, 0.04), rough=0.5, metal=0.5)
W_STEEL = mat("W_Steel", (0.5, 0.5, 0.55), rough=0.2, metal=0.95)        # yaltiroq tepki/vint
W_WOOD = mat("W_Wood", (0.32, 0.18, 0.08), rough=0.5)                     # yong'och grip
W_WOOD2 = mat("W_Wood2", (0.2, 0.11, 0.05), rough=0.55)                   # to'q yong'och chegara

BZ = 0.065   # stvol o'qi balandligi (z)

# --- ASOSIY TANA (receiver/frame) — uzun to'rtburchak, hammasini bog'laydi ---
box("Receiver", (0.046, 0.30, 0.10), (0, 0.02, BZ - 0.008), W_FRAME)      # asosiy tana
box("FrameLower", (0.044, 0.20, 0.07), (0, -0.02, BZ - 0.075), W_FRAME)   # past frame (grip/guard tomon)

# --- Stvol (uzun, ingichka, blued) + ustki rib + mushka ---
cyl("Barrel", 0.014, 0.34, (0, 0.34, BZ + 0.005), W_BARREL, rot=(90, 0, 0))
cyl("MuzzleCrown", 0.017, 0.022, (0, 0.51, BZ + 0.005), W_DARK, rot=(90, 0, 0))
box("TopRib", (0.018, 0.34, 0.012), (0, 0.34, BZ + 0.028), W_BARREL, bev=0.002)   # ustki sayl rib
box("FrontSight", (0.01, 0.022, 0.026), (0, 0.49, BZ + 0.042), W_DARK, bev=0.002, rot=(-12, 0, 0))

# --- Orqa cocking piece (SILINDRIK yivli dum, orqaga chiqadi — Woodsman belgisi) ---
cyl("Cocking", 0.023, 0.07, (0, -0.14, BZ + 0.02), W_DARK, rot=(90, 0, 0))
for k in range(4):                                                        # knurl (yiv) halqalar
    cyl("Knurl", 0.025, 0.006, (0, -0.118 - k * 0.013, BZ + 0.02), W_FRAME, rot=(90, 0, 0))
# --- Orqa nishon (frame ustida) ---
box("RearSightBase", (0.042, 0.05, 0.022), (0, -0.05, BZ + 0.055), W_DARK, bev=0.003)
box("RearBladeL", (0.012, 0.012, 0.024), (0.016, -0.05, BZ + 0.07), W_DARK, bev=0)
box("RearBladeR", (0.012, 0.012, 0.024), (-0.016, -0.05, BZ + 0.07), W_DARK, bev=0)

# --- Tepki halqasi + (yaltiroq) tepki + magazin tugmasi ---
torus("Guard", 0.033, 0.008, (0, -0.015, BZ - 0.135), W_FRAME, rot=(0, 90, 0))
box("Trigger", (0.011, 0.016, 0.045), (0, -0.005, BZ - 0.12), W_STEEL, bev=0.004, rot=(6, 0, 0))
box("MagButton", (0.012, 0.022, 0.026), (0.046, -0.04, BZ - 0.05), W_DARK, bev=0.003)  # magazin tugmasi
box("Screw", (0.012, 0.006, 0.012), (0.038, -0.05, BZ - 0.10), W_STEEL, bev=0)         # grip vint

# --- Grip (~26° orqaga) — TEPASI frame ichiga ulanadi (osilib qolmaydi!) ---
# Bo'yin (neck): frame past qismini grip tepasiga yaxlit bog'lovchi blok — gap qolmasin.
box("Neck", (0.046, 0.10, 0.085), (0, -0.05, BZ - 0.10), W_FRAME, bev=0.004)
GROT = 26.0
GY, GZ = -0.06, BZ - 0.165   # ko'tarilgan: grip tepasi frame ichida
_TH = radians(GROT)


def gpos(lz):
    """Grip o'qi bo'ylab lz birlik (lokal -Z = pastga) siljitilgan dunyo koordinatasi.
    Magazin shu o'q bo'ylab joylashadi -> grip bilan TO'G'RI chiziqda, bukilmaydi."""
    return (0.0, GY - lz * sin(_TH), GZ + lz * cos(_TH))


box("GripFrame", (0.046, 0.09, 0.205), (0, GY, GZ), W_FRAME, rot=(GROT, 0, 0))
box("GripBorderL", (0.013, 0.08, 0.18), (0.036, GY, GZ), W_WOOD2, rot=(GROT, 0, 0))
box("GripBorderR", (0.013, 0.08, 0.18), (-0.036, GY, GZ), W_WOOD2, rot=(GROT, 0, 0))
box("GripPlateL", (0.012, 0.065, 0.16), (0.042, GY, GZ), W_WOOD, rot=(GROT, 0, 0))
box("GripPlateR", (0.012, 0.065, 0.16), (-0.042, GY, GZ), W_WOOD, rot=(GROT, 0, 0))
# Thumb-rest (bosh barmoq tirgagi) — chap yon yuqorida kichik taxtacha (nishon to'pponchasi belgisi)
box("ThumbRest", (0.03, 0.05, 0.013), (0.052, GY - (-0.02) * sin(_TH), GZ + (-0.02) * cos(_TH)), W_WOOD, rot=(GROT, 0, 0), bev=0.004)

# --- MAGAZIN (o'qdon) — Woodsman: FLUSH (grip ichida), tashqi qalin magazin YO'Q.
# Grip pastida faqat tekis tagliklik (heel) ko'rinadi — bu real va "bukilish" bo'lmaydi.
box("MagFloor", (0.047, 0.075, 0.02), gpos(-0.118), W_DARK, rot=(GROT, 0, 0), bev=0.003)


# ============================================================================
# 5 BURCHAKDAN PREVIEW (qo'lsiz — toza ko'rinish), keyin qo'l qo'shib eksport
# ============================================================================
_TARGET = (0.0, 0.07, BZ - 0.09)   # gun massasi markazi (mo'ljal)


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
    cam.data.lens = 44
    bpy.context.scene.camera = cam
    sc = bpy.context.scene
    sc.render.engine = 'BLENDER_WORKBENCH'
    sc.display.shading.color_type = 'MATERIAL'
    sc.display.shading.light = 'STUDIO'
    sc.display.shading.show_shadows = True
    sc.render.resolution_x = 760
    sc.render.resolution_y = 520
    world = bpy.data.worlds[0] if bpy.data.worlds else bpy.data.worlds.new("World")
    sc.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.92, 0.92, 0.93, 1.0)   # oq fon (referensga o'xshash)
    return cam


def render_view(cam, loc, name):
    cam.location = loc
    d = Vector(_TARGET) - Vector(loc)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_preview_pistol_%s.png" % name)
    bpy.context.scene.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("RENDER:", name, os.path.exists(out))


_cam = setup_render()
render_view(_cam, (1.05, 0.07, 0.13), "right")
render_view(_cam, (-1.05, 0.07, 0.13), "left")
render_view(_cam, (0.06, 1.2, 0.16), "front")
render_view(_cam, (0.06, -1.15, 0.16), "back")
render_view(_cam, (0.8, -0.8, 0.72), "persp")

# Qo'llar qo'shib eksport
P_GLOVE = mat("P_Glove", (0.15, 0.11, 0.07), rough=0.7)
P_SLEEVE = mat("P_Sleeve", (0.40, 0.34, 0.22), rough=0.85)
add_hand(0.0, -0.095, BZ - 0.20, P_GLOVE, P_SLEEVE)        # asosiy qo'l
add_hand(-0.05, -0.13, BZ - 0.235, P_GLOVE, P_SLEEVE)     # tayanch qo'l
pistol = join_export("Topponcha", "topponcha.glb")
print("DONE")
