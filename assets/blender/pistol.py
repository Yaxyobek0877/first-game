# -*- coding: utf-8 -*-
"""
Topponcha (pistol) — low-poly viewmodel, 1-jahon urushi uslubi (Luger-simon).

Qurol +Y (Blender) tomon "qaraydi" → glTF eksportdan keyin Godot'da -Z (oldinga).
player.tscn'da Weapon tuguni ostiga "PistolModel" sifatida qo'yiladi.

Natija:
  assets/models/topponcha.glb
  assets/blender/_preview_pistol.png
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
    box("Glove", (0.075, 0.09, 0.07), (gx, gy, gz), glove_mat)
    box("Forearm", (0.07, 0.20, 0.07), (gx, gy - 0.12, gz - 0.06), sleeve_mat, rot=(-28, 0, 0))


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
# TOPPONCHA (pistol) — Luger-simon: stvol+toggle, qiya grip, magazin gripda
# Origin ~ qabul/grip ustida; stvol +Y ga cho'ziladi.
# ============================================================================
clear_scene()
P_METAL = mat("P_Metal", (0.16, 0.16, 0.18), rough=0.35, metal=0.7)   # ko'k-po'lat
P_DARK = mat("P_Dark", (0.06, 0.06, 0.07), rough=0.5, metal=0.5)
P_WOOD = mat("P_Wood", (0.32, 0.19, 0.10), rough=0.7)                  # yog'och tutqich

# Stvol (oldinga, ingichka)
cyl("Barrel", 0.018, 0.22, (0, 0.20, 0.045), P_METAL, rot=(90, 0, 0))
# Stvol ustidagi yivli qism (Luger toggle his uchun)
box("BarrelTop", (0.034, 0.20, 0.03), (0, 0.16, 0.07), P_METAL)
# Qabul (receiver) — markaziy blok
box("Receiver", (0.04, 0.18, 0.075), (0, 0.05, 0.045), P_METAL)
# Toggle bo'g'imi (Luger belgisi) — qabul orqasida ko'tarilgan
box("Toggle", (0.045, 0.07, 0.04), (0, -0.02, 0.085), P_DARK, rot=(-12, 0, 0))
box("ToggleKnobL", (0.018, 0.03, 0.03), (0.035, -0.02, 0.10), P_DARK)
box("ToggleKnobR", (0.018, 0.03, 0.03), (-0.035, -0.02, 0.10), P_DARK)
# Old nishon (mushka) va orqa nishon
box("FrontSight", (0.008, 0.015, 0.022), (0, 0.29, 0.085), P_DARK)
box("RearSight", (0.03, 0.018, 0.022), (0, -0.05, 0.078), P_DARK)
# Trigger guard (tepki halqasi) + tepki
box("GuardFront", (0.03, 0.015, 0.05), (0, 0.0, -0.005), P_METAL)
box("GuardBottom", (0.03, 0.05, 0.012), (0, -0.03, -0.03), P_METAL)
box("Trigger", (0.015, 0.02, 0.04), (0, -0.01, -0.01), P_DARK)
# Grip — qiya orqaga (Luger uslubi), yog'och tutqich plitalari bilan
box("Grip", (0.045, 0.06, 0.16), (0, -0.10, -0.085), P_METAL, rot=(28, 0, 0))
box("GripPlateL", (0.012, 0.055, 0.15), (0.04, -0.10, -0.085), P_WOOD, rot=(28, 0, 0))
box("GripPlateR", (0.012, 0.055, 0.15), (-0.04, -0.10, -0.085), P_WOOD, rot=(28, 0, 0))
# Magazin tagligi (grip ostida)
box("MagBase", (0.05, 0.06, 0.018), (0, -0.155, -0.16), P_DARK, rot=(28, 0, 0))

# Qo'l (gripni ushlagan)
P_GLOVE = mat("P_Glove", (0.16, 0.12, 0.08), rough=0.7)
P_SLEEVE = mat("P_Sleeve", (0.41, 0.35, 0.23), rough=0.85)
add_hand(0.0, -0.11, -0.10, P_GLOVE, P_SLEEVE)

pistol = join_export("Topponcha", "topponcha.glb")


# ============================================================================
# PREVIEW render
# ============================================================================
clear_scene()
a_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "models"))
bpy.ops.import_scene.gltf(filepath=os.path.join(a_dir, "topponcha.glb"))

bpy.ops.object.empty_add(location=(0, 0.05, -0.02))
target = bpy.context.active_object
bpy.ops.object.camera_add(location=(0.55, -0.9, 0.45))
cam = bpy.context.active_object
cam.data.lens = 55
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
scene.render.resolution_x = 700
scene.render.resolution_y = 500
world = bpy.data.worlds[0] if bpy.data.worlds else bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.5, 0.53, 0.57, 1.0)
out_png = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_preview_pistol.png")
scene.render.filepath = out_png
bpy.ops.render.render(write_still=True)
print("RENDER_OK:", os.path.exists(out_png))
