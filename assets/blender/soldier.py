# -*- coding: utf-8 -*-
"""
Askar — stilize low-poly model (1-jahon urushi uslubi). Ikki faction:
  - Kron Imperiyasi (dushman): feldgrau yashil shinel, qizil yoqa.
  - Aros (o'yinchi tomoni / ittifoqchi): xaki-jigarrang, ko'k yoqa.

Qism-qismdan quriladi (dubulg'a, bosh, shinel, qo'llar, oyoqlar, etik, kamar,
miltiq+nayza), rigid skinning bilan armaturega bog'lanadi, 4 animatsiya
(idle/run/attack/die) qo'shiladi va glTF (.glb) ga eksport qilinadi.

Ishlatish:
  & "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" --background --python assets\\blender\\soldier.py

Natija: assets/models/kron_soldier.glb, aros_soldier.glb + _preview_*.png render'lar.
DIQQAT: Kron mesh nomi "KronSoldierMesh" — enemy.gd shu nom bilan topadi, o'zgartirmang.
"""

import bpy
import os
from math import radians


# ----------------------------------------------------------------------------
# Yordamchi funksiyalar
# ----------------------------------------------------------------------------

def clear_scene():
    """Sahnani butunlay tozalaymiz (background rejimida ops emas, data API ishonchli)."""
    for obj in list(bpy.data.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    for block in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures):
        for item in list(block):
            block.remove(item)


def make_material(name, color, rough=0.85, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    m.diffuse_color = (color[0], color[1], color[2], 1.0)  # Workbench preview
    return m


def box(name, size, loc, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0], size[1], size[2])
    o.rotation_euler = (radians(rot[0]), radians(rot[1]), radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(mat)
    return o


def cyl(name, radius, depth, loc, mat, verts=10, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = (radians(rot[0]), radians(rot[1]), radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(mat)
    bpy.ops.object.shade_flat()
    return o


def dome(name, size, loc, mat, subdiv=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=0.5, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0], size[1], size[2])
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(mat)
    bpy.ops.object.shade_flat()
    return o


def setup_camera_and_light():
    bpy.ops.object.empty_add(location=(0.0, 0.0, 0.95))
    target = bpy.context.active_object
    bpy.ops.object.camera_add(location=(2.6, -3.4, 1.7))
    cam = bpy.context.active_object
    bpy.context.scene.camera = cam
    c = cam.constraints.new('TRACK_TO')
    c.target = target
    c.track_axis = 'TRACK_NEGATIVE_Z'
    c.up_axis = 'UP_Y'
    bpy.ops.object.light_add(type='SUN', location=(3, -2, 6))
    sun = bpy.context.active_object
    sun.data.energy = 4.0
    sun.rotation_euler = (radians(50), radians(15), radians(35))


def render_preview(path):
    scene = bpy.context.scene
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.color_type = 'MATERIAL'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 600
    scene.render.resolution_y = 720
    scene.render.film_transparent = False
    world = bpy.data.worlds[0] if bpy.data.worlds else bpy.data.worlds.new("World")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs[0].default_value = (0.55, 0.60, 0.66, 1.0)
        bg.inputs[1].default_value = 1.0
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    print("RENDER_OK:", os.path.exists(path))


# Har qism qaysi suyakka biriktiriladi (rigid skinning — har qism 1 suyak)
BONE_OF = {
    "Boot.L": "LegL", "Leg.L": "LegL",
    "Boot.R": "LegR", "Leg.R": "LegR",
    "Torso": "Spine", "Belt": "Spine", "Collar": "Spine",
    "Arm.L": "ArmL", "Hand.L": "ArmL",
    "Arm.R": "ArmR", "Hand.R": "ArmR", "Rifle": "ArmR", "Bayonet": "ArmR",
    "Neck": "Head", "Head": "Head", "HelmetDome": "Head", "HelmetBrim": "Head",
}
ALL_BONES = ["Hips", "Spine", "Head", "ArmL", "ArmR", "LegL", "LegR"]


# ----------------------------------------------------------------------------
# Faction ranglari
# ----------------------------------------------------------------------------
FACTIONS = {
    "kron": {  # Kron Imperiyasi (dushman) — feldgrau yashil, qizil yoqa
        "coat": (0.20, 0.24, 0.21), "trouser": (0.16, 0.18, 0.17),
        "boot": (0.05, 0.05, 0.06), "belt": (0.10, 0.08, 0.06),
        "skin": (0.74, 0.58, 0.48), "helmet": (0.18, 0.20, 0.23),
        "accent": (0.45, 0.06, 0.08),
        "glb": "kron_soldier.glb", "mesh": "KronSoldierMesh", "arm": "KronSoldier",
    },
    "aros": {  # Aros (o'yinchi tomoni) — xaki-jigarrang, ko'k yoqa
        "coat": (0.42, 0.36, 0.24), "trouser": (0.31, 0.27, 0.18),
        "boot": (0.11, 0.09, 0.06), "belt": (0.15, 0.10, 0.07),
        "skin": (0.78, 0.62, 0.50), "helmet": (0.32, 0.31, 0.25),
        "accent": (0.16, 0.30, 0.46),
        "glb": "aros_soldier.glb", "mesh": "ArosSoldierMesh", "arm": "ArosSoldier",
    },
}


def build_soldier(faction, cfg):
    """Bitta faction askarini quradi, riglaydi, animatsiyalaydi va eksport qiladi."""
    clear_scene()

    # --- Materiallar ---
    COAT = make_material(faction + "_Coat", cfg["coat"])
    TROUSER = make_material(faction + "_Trouser", cfg["trouser"])
    BOOT = make_material(faction + "_Boot", cfg["boot"])
    BELT = make_material(faction + "_Belt", cfg["belt"], rough=0.6)
    SKIN = make_material(faction + "_Skin", cfg["skin"])
    HELMET = make_material(faction + "_Helmet", cfg["helmet"], rough=0.5, metal=0.3)
    ACCENT = make_material(faction + "_Accent", cfg["accent"])
    WOOD = make_material(faction + "_RifleWood", (0.28, 0.16, 0.09))
    METAL = make_material(faction + "_RifleMetal", (0.55, 0.57, 0.60), rough=0.4, metal=0.6)

    # --- Qismlar (Blender: Z tepaga, oyoq Z=0 da, bo'y ~1.85 m) ---
    parts = []
    parts.append(box("Boot.L", (0.16, 0.30, 0.12), (-0.12, 0.03, 0.06), BOOT))
    parts.append(box("Boot.R", (0.16, 0.30, 0.12), (0.12, 0.03, 0.06), BOOT))
    parts.append(cyl("Leg.L", 0.085, 0.78, (-0.12, 0.0, 0.50), TROUSER))
    parts.append(cyl("Leg.R", 0.085, 0.78, (0.12, 0.0, 0.50), TROUSER))
    parts.append(box("Torso", (0.46, 0.26, 0.60), (0.0, 0.0, 1.18), COAT))
    parts.append(box("Belt", (0.48, 0.28, 0.07), (0.0, 0.0, 0.92), BELT))
    parts.append(box("Collar", (0.30, 0.22, 0.08), (0.0, 0.0, 1.50), ACCENT))
    parts.append(cyl("Arm.L", 0.07, 0.58, (-0.30, 0.02, 1.18), COAT, rot=(0, 6, 0)))
    parts.append(cyl("Arm.R", 0.07, 0.58, (0.30, 0.02, 1.18), COAT, rot=(0, -6, 0)))
    parts.append(box("Hand.L", (0.10, 0.12, 0.12), (-0.31, 0.04, 0.88), SKIN))
    parts.append(box("Hand.R", (0.10, 0.12, 0.12), (0.31, 0.04, 0.88), SKIN))
    parts.append(box("Neck", (0.12, 0.12, 0.10), (0.0, 0.0, 1.58), SKIN))
    parts.append(box("Head", (0.21, 0.22, 0.23), (0.0, 0.0, 1.72), SKIN))
    parts.append(dome("HelmetDome", (0.29, 0.31, 0.27), (0.0, 0.0, 1.87), HELMET))
    parts.append(box("HelmetBrim", (0.30, 0.32, 0.025), (0.0, -0.01, 1.74), HELMET))
    parts.append(box("Rifle", (0.05, 0.85, 0.07), (0.18, 0.18, 1.02), WOOD))
    parts.append(box("Bayonet", (0.022, 0.28, 0.022), (0.18, 0.74, 1.02), METAL))

    # --- Rigid skinning: har qismga suyak nomli vertex group (vazn 1.0) ---
    for o in parts:
        vg = o.vertex_groups.new(name=BONE_OF[o.name])
        vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')

    # --- Birlashtirish (bir xil nomli vertex group'lar qo'shiladi) ---
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    body = bpy.context.active_object
    body.name = cfg["mesh"]   # Kron uchun "KronSoldierMesh" (enemy.gd shunga bog'liq)

    # --- Armature (suyaklar) ---
    arm_data = bpy.data.armatures.new(faction + "_Armature")
    arm_obj = bpy.data.objects.new(cfg["arm"], arm_data)
    bpy.context.collection.objects.link(arm_obj)
    bpy.ops.object.select_all(action='DESELECT')
    arm_obj.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj
    bpy.ops.object.mode_set(mode='EDIT')
    eb = arm_data.edit_bones

    def make_bone(name, head, tail, parent=None):
        b = eb.new(name)
        b.head = head
        b.tail = tail
        if parent:
            b.parent = eb[parent]
            b.use_connect = False
        return b

    make_bone("Hips", (0, 0, 0.90), (0, 0, 1.05))
    make_bone("Spine", (0, 0, 1.00), (0, 0, 1.50), "Hips")
    make_bone("Head", (0, 0, 1.55), (0, 0, 1.90), "Spine")
    make_bone("ArmL", (-0.30, 0, 1.45), (-0.32, 0, 0.85), "Spine")
    make_bone("ArmR", (0.30, 0, 1.45), (0.32, 0, 0.85), "Spine")
    make_bone("LegL", (-0.12, 0, 0.90), (-0.12, 0, 0.02), "Hips")
    make_bone("LegR", (0.12, 0, 0.90), (0.12, 0, 0.02), "Hips")
    bpy.ops.object.mode_set(mode='OBJECT')

    mod = body.modifiers.new("Armature", 'ARMATURE')
    mod.object = arm_obj
    body.parent = arm_obj

    # --- Animatsiyalar (har action alohida glTF animatsiyasi) ---
    arm_obj.animation_data_create()
    bpy.context.scene.render.fps = 24

    def new_action(name):
        act = bpy.data.actions.new(name)
        act.use_fake_user = True
        arm_obj.animation_data.action = act
        return act

    def key(frame, bone, rot):
        pb = arm_obj.pose.bones[bone]
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (radians(rot[0]), radians(rot[1]), radians(rot[2]))
        pb.keyframe_insert("rotation_euler", frame=frame)

    def key_pose(frame, pose):
        # Har animatsiya BARCHA suyaklarni belgilaydi (self-contained — "oqib ketmaydi").
        for b in ALL_BONES:
            key(frame, b, pose.get(b, (0, 0, 0)))

    new_action("idle")
    key_pose(1, {})
    key_pose(24, {"Spine": (2.5, 0, 0), "Head": (-1.0, 0, 0)})
    key_pose(48, {})

    new_action("run")
    for f, s in [(1, 1), (12, -1), (24, 1)]:
        key_pose(f, {
            "LegL": (28 * s, 0, 0), "LegR": (-28 * s, 0, 0),
            "ArmL": (-30 * s, 0, 0), "ArmR": (30 * s, 0, 0),
            "Spine": (6, 0, 0),
        })

    new_action("attack")
    key_pose(1, {"ArmR": (10, 0, 0)})
    key_pose(5, {"ArmR": (-78, 0, 0), "Spine": (16, 0, 0)})
    key_pose(13, {"ArmR": (10, 0, 0)})

    new_action("die")
    key_pose(1, {})
    key_pose(13, {"Hips": (-72, 0, 0), "LegL": (38, 0, 0), "LegR": (22, 0, 0)})
    key_pose(22, {"Hips": (-88, 0, 0), "LegL": (42, 0, 0), "LegR": (26, 0, 0)})

    # --- glTF eksport (faqat armature + mesh) ---
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='DESELECT')
    arm_obj.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = arm_obj
    glb_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "models"))
    os.makedirs(glb_dir, exist_ok=True)
    glb_path = os.path.join(glb_dir, cfg["glb"])
    bpy.ops.export_scene.gltf(
        filepath=glb_path, export_format='GLB', use_selection=True,
        export_animations=True, export_animation_mode='ACTIONS', export_skins=True,
    )
    print("GLB_EXPORT:", faction, os.path.exists(glb_path), os.path.getsize(glb_path) if os.path.exists(glb_path) else 0)

    # --- Preview render (rest poza) ---
    arm_obj.animation_data.action = None
    bpy.context.scene.frame_set(0)
    setup_camera_and_light()
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_preview_%s.png" % faction)
    render_preview(out)


for _fname, _cfg in FACTIONS.items():
    build_soldier(_fname, _cfg)
print("DONE")
