# -*- coding: utf-8 -*-
"""
O'yinchi qurollari — yaxshilangan low-poly viewmodel (Avtomat va Snayper), 1-JU uslubi.

Yaxshilanishlar (v2): silliq quvur/durbin (verts=16), qirralar yumshatilgan (bevel
modifikatori — chamfer), boyitilgan materiallar (ko'k po'lat sheen + yong'oq + guruch),
tepki halqasi (torus), ko'proq detal (nishon quloqchalari, magazin tagligi, qisqich, h.k.).

Har qurol +Y (Blender) tomon "qaraydi" → glTF eksportdan keyin Godot'da -Z (oldinga).
player.tscn'da Weapon tuguni ostiga qo'yiladi. Umumiy o'lcham/origin saqlangan (viewmodel
joylashuvi buzilmasin).

Natija:
  assets/models/avtomat.glb, assets/models/sniper.glb
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


def _apply_bevel(o, width, segments=2):
    """Qirralarni yumshatadi (chamfer) — premium low-poly ko'rinish."""
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


def cyl(name, r, h, loc, material, rot=(0, 0, 0), verts=16, bev=0.0):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = (radians(rot[0]), radians(rot[1]), radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()      # silindrlar silliq soyalanadi
    _apply_bevel(o, bev)
    _objs.append(o)
    return o


def torus(name, major_r, minor_r, loc, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major_r, minor_radius=minor_r, location=loc,
                                     major_segments=14, minor_segments=7)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = (radians(rot[0]), radians(rot[1]), radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(material)
    bpy.ops.object.shade_smooth()
    _objs.append(o)
    return o


def trigger_guard(z_center, y_center, material, w=0.018):
    """Tepki halqasi — vertikal torus (teshigi X tomon), gun tekisligida."""
    torus("Guard", 0.032, w * 0.5, (0, y_center, z_center - 0.03), material, rot=(0, 90, 0))


def add_hand(gx, gy, gz, glove_mat, sleeve_mat):
    """Gripda qo'l (glove) + orqaga-pastga cho'zilgan bilak/yeng (kameraga tomon)."""
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
# AVTOMAT (MP18-uslubidagi avtomat / SMG — tez/zaif)
# Origin ~ qabul/grip; stvol +Y ga cho'ziladi. Umumiy uzunlik ~ avvalgidek.
# ============================================================================
clear_scene()
A_METAL = mat("A_Metal", (0.11, 0.11, 0.13), rough=0.34, metal=0.85)   # ko'k po'lat (sheen)
A_DARK = mat("A_Dark", (0.045, 0.045, 0.055), rough=0.5, metal=0.6)    # qora detallar
A_WOOD = mat("A_Wood", (0.24, 0.13, 0.06), rough=0.55)                  # yong'oq qo'ndoq
A_WOOD2 = mat("A_Wood2", (0.30, 0.17, 0.08), rough=0.5)                 # ochroq yong'oq
A_BRASS = mat("A_Brass", (0.55, 0.42, 0.16), rough=0.35, metal=0.9)     # guruch aksent

# Qabul (tubular receiver — yumaloq)
cyl("Receiver", 0.034, 0.34, (0, 0.06, 0.01), A_METAL, rot=(90, 0, 0))
box("RecTop", (0.05, 0.30, 0.03), (0, 0.07, 0.05), A_METAL)            # tepa rels (nishonlar uchun)
# Stvol g'ilofi (perforatsiyali yumaloq jacket — MP18)
cyl("Shroud", 0.046, 0.20, (0, 0.30, 0.02), A_METAL, rot=(90, 0, 0))
for yy in [0.24, 0.28, 0.32, 0.36]:                                    # sovutish teshigi halqalari
    cyl("VentRing", 0.048, 0.014, (0, yy, 0.02), A_DARK, rot=(90, 0, 0))
# Stvol (g'ilof ichidan chiqib turadi)
cyl("Barrel", 0.018, 0.40, (0, 0.44, 0.02), A_DARK, rot=(90, 0, 0))
cyl("MuzzleEnd", 0.024, 0.04, (0, 0.62, 0.02), A_DARK, rot=(90, 0, 0))
# Nishonlar
box("FrontSightBase", (0.05, 0.03, 0.02), (0, 0.52, 0.055), A_DARK, bev=0.003)
box("FrontSightPost", (0.008, 0.012, 0.04), (0, 0.52, 0.085), A_DARK, bev=0)   # mushka
box("FrontEarL", (0.008, 0.03, 0.035), (-0.02, 0.52, 0.08), A_DARK, bev=0)     # quloqchalar
box("FrontEarR", (0.008, 0.03, 0.035), (0.02, 0.52, 0.08), A_DARK, bev=0)
box("RearSight", (0.05, 0.035, 0.03), (0, -0.04, 0.075), A_DARK, bev=0.003)
box("RearNotch", (0.012, 0.04, 0.018), (0, -0.04, 0.09), A_METAL, bev=0)
# Magazin (qiya stik) + tagligi + qisqich
box("Magazine", (0.038, 0.05, 0.21), (0, 0.04, -0.15), A_DARK, rot=(8, 0, 0))
box("MagBase", (0.05, 0.06, 0.02), (0, 0.005, -0.255), A_DARK, rot=(8, 0, 0))
box("MagWell", (0.05, 0.07, 0.05), (0, 0.05, -0.04), A_METAL)
box("MagCatch", (0.045, 0.025, 0.02), (0, 0.085, -0.06), A_DARK, bev=0.003)
# Tepki + halqa
trigger_guard(-0.075, -0.02, A_METAL)
box("Trigger", (0.012, 0.018, 0.04), (0, -0.02, -0.085), A_DARK, bev=0.003)
# Tutqich (yong'och) + grip plitalari
box("Grip", (0.042, 0.05, 0.12), (0, -0.075, -0.075), A_WOOD, rot=(20, 0, 0))
# Qo'ndoq (to'liq yog'och) + butt plitasi
box("Stock", (0.05, 0.24, 0.075), (0, -0.24, -0.015), A_WOOD)
box("StockComb", (0.045, 0.14, 0.03), (0, -0.20, 0.04), A_WOOD2, bev=0.006)    # tepa qirra
box("ButtPlate", (0.055, 0.022, 0.10), (0, -0.36, -0.015), A_DARK)
# Oldingi yog'och handguard
box("Handguard", (0.05, 0.12, 0.05), (0, 0.16, -0.05), A_WOOD, rot=(2, 0, 0))
# Zatvor dastasi (o'ng) + gilza chiqargich
cyl("ChargeHandle", 0.016, 0.05, (0.05, 0.02, 0.06), A_DARK, rot=(0, 90, 0))
box("EjectPort", (0.012, 0.07, 0.03), (0.035, 0.14, 0.045), A_DARK, bev=0.003)
# Sling halqalari (detal)
torus("SlingF", 0.014, 0.004, (0, 0.30, -0.04), A_DARK, rot=(0, 90, 0))
torus("SlingR", 0.014, 0.004, (0, -0.30, -0.05), A_DARK, rot=(0, 90, 0))
A_GLOVE = mat("A_Glove", (0.15, 0.11, 0.07), rough=0.7)
A_SLEEVE = mat("A_Sleeve", (0.40, 0.34, 0.22), rough=0.85)
add_hand(0.0, -0.05, -0.095, A_GLOVE, A_SLEEVE)   # tutqich (trigger) qo'li
add_hand(0.0, 0.17, -0.075, A_GLOVE, A_SLEEVE)    # oldingi (handguard) qo'l
avtomat = join_export("Avtomat", "avtomat.glb")

# ============================================================================
# SNAYPER (Mosin/Gewehr-uslubidagi — durbin bilan, sekin/kuchli, uzoq masofa)
# ============================================================================
clear_scene()
S_METAL = mat("S_Metal", (0.10, 0.10, 0.12), rough=0.32, metal=0.85)
S_DARK = mat("S_Dark", (0.04, 0.04, 0.05), rough=0.5, metal=0.6)
S_WOOD = mat("S_Wood", (0.21, 0.11, 0.05), rough=0.55)
S_WOOD2 = mat("S_Wood2", (0.27, 0.15, 0.07), rough=0.5)
S_LENS = mat("S_Lens", (0.22, 0.45, 0.68), rough=0.08, metal=0.4)
S_BRASS = mat("S_Brass", (0.55, 0.42, 0.16), rough=0.35, metal=0.9)

# To'liq yog'och qo'ndoq (uzun) + yonoq + handguard
box("Stock", (0.05, 0.70, 0.105), (0, -0.04, -0.025), S_WOOD)
box("Comb", (0.046, 0.22, 0.05), (0, -0.20, 0.04), S_WOOD2, bev=0.006)        # yonoq qirra
box("Forestock", (0.05, 0.52, 0.07), (0, 0.40, -0.01), S_WOOD)               # oldingi yog'och
box("Handguard", (0.044, 0.40, 0.04), (0, 0.44, 0.045), S_WOOD2, bev=0.005)  # stvol usti yog'och
box("ButtPlate", (0.055, 0.02, 0.12), (0, -0.40, -0.02), S_DARK)
# Stvol (uzun, ingichka, silliq) + dulnaga + barrel bandlar
cyl("Barrel", 0.015, 0.92, (0, 0.56, 0.035), S_DARK, rot=(90, 0, 0))
cyl("Muzzle", 0.022, 0.05, (0, 1.0, 0.035), S_DARK, rot=(90, 0, 0))
cyl("BandF", 0.03, 0.03, (0, 0.66, 0.02), S_METAL, rot=(90, 0, 0))           # stvol bandi
cyl("BandR", 0.03, 0.03, (0, 0.30, 0.02), S_METAL, rot=(90, 0, 0))
# Qabul + zatvor (egilgan dasta) + tepki
box("Receiver", (0.05, 0.24, 0.075), (0, 0.06, 0.03), S_METAL)
cyl("BoltBody", 0.018, 0.16, (0, 0.04, 0.06), S_METAL, rot=(90, 0, 0))
cyl("BoltArm", 0.013, 0.10, (0.06, -0.02, 0.05), S_METAL, rot=(0, 50, 0))    # pastga egilgan
cyl("BoltKnob", 0.026, 0.03, (0.10, -0.05, 0.04), S_DARK, rot=(0, 50, 0))    # sharcha
# Magazin qutisi (pastda) + floorplate
box("MagBox", (0.05, 0.1, 0.05), (0, 0.0, -0.05), S_METAL, bev=0.004)
box("FloorPlate", (0.055, 0.11, 0.018), (0, 0.0, -0.08), S_DARK)
# Tepki + halqa
trigger_guard(-0.07, -0.02, S_METAL, w=0.016)
box("Trigger", (0.012, 0.016, 0.045), (0, -0.02, -0.075), S_DARK, bev=0.003)
# Tutqich (wrist) — qo'ndoq bo'yni
box("Grip", (0.042, 0.07, 0.085), (0, -0.06, -0.055), S_WOOD, rot=(14, 0, 0))
# Old nishon (durbin bilan, lekin baribir mushka)
box("FrontSight", (0.04, 0.025, 0.02), (0, 0.94, 0.055), S_DARK, bev=0.003)
# Durbin (scope) — tirgaklarda, halqali, turret bilan
box("ScopeMountF", (0.028, 0.03, 0.075), (0, 0.20, 0.10), S_DARK, bev=0.003)
box("ScopeMountR", (0.028, 0.03, 0.075), (0, -0.06, 0.10), S_DARK, bev=0.003)
torus("RingF", 0.04, 0.008, (0, 0.20, 0.145), S_METAL, rot=(90, 0, 0))       # halqa
torus("RingR", 0.04, 0.008, (0, -0.06, 0.145), S_METAL, rot=(90, 0, 0))
cyl("ScopeTube", 0.032, 0.40, (0, 0.07, 0.145), S_DARK, rot=(90, 0, 0))
cyl("ScopeFront", 0.05, 0.07, (0, 0.27, 0.145), S_DARK, rot=(90, 0, 0))      # old ob'ektiv
cyl("ScopeRear", 0.046, 0.07, (0, -0.14, 0.145), S_DARK, rot=(90, 0, 0))     # ko'z qismi
cyl("LensF", 0.044, 0.012, (0, 0.305, 0.145), S_LENS, rot=(90, 0, 0))
cyl("LensR", 0.039, 0.012, (0, -0.175, 0.145), S_LENS, rot=(90, 0, 0))
cyl("Turret", 0.022, 0.04, (0, 0.07, 0.185), S_DARK)                         # tepa turret
cyl("TurretCap", 0.018, 0.02, (0, 0.07, 0.21), S_METAL)
# Sling halqalari
torus("SlingF", 0.014, 0.004, (0, 0.66, -0.03), S_DARK, rot=(0, 90, 0))
torus("SlingR", 0.014, 0.004, (0, -0.34, -0.05), S_DARK, rot=(0, 90, 0))
S_GLOVE = mat("S_Glove", (0.15, 0.11, 0.07), rough=0.7)
S_SLEEVE = mat("S_Sleeve", (0.40, 0.34, 0.22), rough=0.85)
add_hand(0.0, -0.02, -0.06, S_GLOVE, S_SLEEVE)    # tepki qo'li
add_hand(0.0, 0.40, -0.02, S_GLOVE, S_SLEEVE)     # oldingi (forestock) qo'l
sniper = join_export("Snayper", "sniper.glb")


# ============================================================================
# PREVIEW: ikkala qurol yonma-yon
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

bpy.ops.object.empty_add(location=(0, 0.1, 0))
target = bpy.context.active_object
bpy.ops.object.camera_add(location=(0.7, -1.4, 0.6))
cam = bpy.context.active_object
cam.data.lens = 52
bpy.context.scene.camera = cam
c = cam.constraints.new('TRACK_TO')
c.target = target
c.track_axis = 'TRACK_NEGATIVE_Z'
c.up_axis = 'UP_Y'
bpy.ops.object.light_add(type='SUN', location=(2, -2, 4))
bpy.context.active_object.data.energy = 4.5
bpy.context.active_object.rotation_euler = (radians(50), radians(10), radians(30))

scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.color_type = 'MATERIAL'
scene.display.shading.light = 'STUDIO'
scene.display.shading.show_shadows = True
scene.render.resolution_x = 900
scene.render.resolution_y = 540
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
