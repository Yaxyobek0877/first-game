# -*- coding: utf-8 -*-
"""
Kron Imperiyasi askari — stilize low-poly model (1-jahon urushi uslubi).

Bu skript Blender'da headless ishlaydi va dushman askarini qism-qismdan quradi:
dubulg'a, bosh, shinel (palto), qo'llar, oyoqlar, etiklar, kamar, miltiq+nayza.

Ishlatish (PowerShell):
  & "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" --background --python assets\\blender\\soldier.py

Natija:
  - assets/blender/_preview_soldier.png  (ko'rinishni tekshirish uchun render)
Eslatma: hozircha faqat mesh + render. Rig va animatsiya keyingi qadamda qo'shiladi.
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
    """Oddiy Principled material — faqat asosiy rang (low-poly uslub)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    # Workbench render BSDF emas, "viewport display" rangini ishlatadi — uni ham beramiz.
    m.diffuse_color = (color[0], color[1], color[2], 1.0)
    return m


def box(name, size, loc, mat, rot=(0, 0, 0)):
    """Berilgan o'lcham/joy/burchakdagi kub (cuboid) yaratadi."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0], size[1], size[2])
    o.rotation_euler = (radians(rot[0]), radians(rot[1]), radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(mat)
    return o


def cyl(name, radius, depth, loc, mat, verts=10, rot=(0, 0, 0)):
    """Past-poligonli silindr (oyoq/qo'l/dubulg'a uchun)."""
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = (radians(rot[0]), radians(rot[1]), radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(mat)
    # Tekis (flat) soyalash — low-poly uslub
    bpy.ops.object.shade_flat()
    return o


def dome(name, size, loc, mat, subdiv=2):
    """Yarim-shar (dubulg'a gumbazi uchun) — past-poligonli icosfera."""
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=0.5, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0], size[1], size[2])
    bpy.ops.object.transform_apply(scale=True)
    o.data.materials.append(mat)
    bpy.ops.object.shade_flat()
    return o


# ----------------------------------------------------------------------------
# Sahnani tozalash (standart kub/kamera/chiroqni o'chiramiz)
# ----------------------------------------------------------------------------
clear_scene()

# ----------------------------------------------------------------------------
# Ranglar (Kron Imperiyasi — sovuq, harbiy palitra)
# ----------------------------------------------------------------------------
COAT   = make_material("Kron_Coat",   (0.20, 0.24, 0.21))   # feldgrau shinel
TROUSER= make_material("Kron_Trouser",(0.16, 0.18, 0.17))   # shim
BOOT   = make_material("Kron_Boot",   (0.05, 0.05, 0.06))   # etik (qora)
BELT   = make_material("Kron_Belt",   (0.10, 0.08, 0.06), rough=0.6)  # charm kamar
SKIN   = make_material("Kron_Skin",   (0.74, 0.58, 0.48))   # teri
HELMET = make_material("Kron_Helmet", (0.18, 0.20, 0.23), rough=0.5, metal=0.3)  # po'lat dubulg'a
ACCENT = make_material("Kron_Accent", (0.45, 0.06, 0.08))   # imperiya qizil yoqasi (Kron belgisi)
WOOD   = make_material("Rifle_Wood",  (0.28, 0.16, 0.09))   # miltiq yog'ochi
METAL  = make_material("Rifle_Metal", (0.55, 0.57, 0.60), rough=0.4, metal=0.6)  # nayza/metall


# ----------------------------------------------------------------------------
# Askarni qurish (Blender: Z tepaga, oyoq Z=0 da, bo'y ~1.8 m)
# ----------------------------------------------------------------------------
parts = []

# Etiklar
parts.append(box("Boot.L", (0.16, 0.30, 0.12), (-0.12, 0.03, 0.06), BOOT))
parts.append(box("Boot.R", (0.16, 0.30, 0.12), ( 0.12, 0.03, 0.06), BOOT))

# Oyoqlar (shim)
parts.append(cyl("Leg.L", 0.085, 0.78, (-0.12, 0.0, 0.50), TROUSER))
parts.append(cyl("Leg.R", 0.085, 0.78, ( 0.12, 0.0, 0.50), TROUSER))

# Tana (shinel) — biroz keng yelka, tor bel
parts.append(box("Torso", (0.46, 0.26, 0.60), (0.0, 0.0, 1.18), COAT))
# Kamar
parts.append(box("Belt", (0.48, 0.28, 0.07), (0.0, 0.0, 0.92), BELT))
# Yoqa (Kron qizil belgisi)
parts.append(box("Collar", (0.30, 0.22, 0.08), (0.0, 0.0, 1.50), ACCENT))

# Qo'llar (yelkadan pastga) — biroz tananing yon-oldida
parts.append(cyl("Arm.L", 0.07, 0.58, (-0.30, 0.02, 1.18), COAT, rot=(0, 6, 0)))
parts.append(cyl("Arm.R", 0.07, 0.58, ( 0.30, 0.02, 1.18), COAT, rot=(0, -6, 0)))
# Qo'l panjalari (teri)
parts.append(box("Hand.L", (0.10, 0.12, 0.12), (-0.31, 0.04, 0.88), SKIN))
parts.append(box("Hand.R", (0.10, 0.12, 0.12), ( 0.31, 0.04, 0.88), SKIN))

# Bo'yin va bosh
parts.append(box("Neck", (0.12, 0.12, 0.10), (0.0, 0.0, 1.58), SKIN))
parts.append(box("Head", (0.21, 0.22, 0.23), (0.0, 0.0, 1.72), SKIN))

# Dubulg'a — bosh USTIGA o'tiradi (gumbaz bosh tojini qoplaydi, yuz pastda ko'rinadi).
# Stahlhelm uslubi: gumbaz + past chetida ixcham soyabon (flare).
parts.append(dome("HelmetDome", (0.29, 0.31, 0.27), (0.0, 0.0, 1.87), HELMET))
parts.append(box("HelmetBrim", (0.30, 0.32, 0.025), (0.0, -0.01, 1.74), HELMET))

# Miltiq (nayza bilan) — ko'krak balandligida oldinga (nayza hujumi tayyorgarligi)
parts.append(box("Rifle", (0.05, 0.85, 0.07), (0.18, 0.18, 1.02), WOOD))
parts.append(box("Bayonet", (0.022, 0.28, 0.022), (0.18, 0.74, 1.02), METAL))

print("PARTS_BUILT:", len(parts))


# ----------------------------------------------------------------------------
# Preview render (Workbench — headless uchun ishonchli, material rangini ko'rsatadi)
# ----------------------------------------------------------------------------
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
    # Osmon-rang fon
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


# ============================================================================
# RIG + SKINNING + ANIMATSIYA + glTF EKSPORT
# ============================================================================

# Har bir qism qaysi suyakka biriktiriladi (rigid skinning — har qism 1 suyak)
BONE_OF = {
    "Boot.L": "LegL", "Leg.L": "LegL",
    "Boot.R": "LegR", "Leg.R": "LegR",
    "Torso": "Spine", "Belt": "Spine", "Collar": "Spine",
    "Arm.L": "ArmL", "Hand.L": "ArmL",
    "Arm.R": "ArmR", "Hand.R": "ArmR", "Rifle": "ArmR", "Bayonet": "ArmR",
    "Neck": "Head", "Head": "Head", "HelmetDome": "Head", "HelmetBrim": "Head",
}

# 1) Har qismga vertex group (suyak nomi) + barcha verteksiga 1.0 vazn (rigid)
for o in parts:
    bname = BONE_OF[o.name]
    vg = o.vertex_groups.new(name=bname)
    vg.add(list(range(len(o.data.vertices))), 1.0, 'REPLACE')

# 2) Hamma qismni bitta meshga birlashtiramiz (bir xil nomli vertex group'lar qo'shiladi)
bpy.ops.object.select_all(action='DESELECT')
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = bpy.context.active_object
body.name = "KronSoldierMesh"

# 3) Armature (suyaklar)
arm_data = bpy.data.armatures.new("KronArmature")
arm_obj = bpy.data.objects.new("KronSoldier", arm_data)
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

make_bone("Hips",  (0, 0, 0.90), (0, 0, 1.05))
make_bone("Spine", (0, 0, 1.00), (0, 0, 1.50), "Hips")
make_bone("Head",  (0, 0, 1.55), (0, 0, 1.90), "Spine")
make_bone("ArmL",  (-0.30, 0, 1.45), (-0.32, 0, 0.85), "Spine")
make_bone("ArmR",  (0.30, 0, 1.45), (0.32, 0, 0.85), "Spine")
make_bone("LegL",  (-0.12, 0, 0.90), (-0.12, 0, 0.02), "Hips")
make_bone("LegR",  (0.12, 0, 0.90), (0.12, 0, 0.02), "Hips")
bpy.ops.object.mode_set(mode='OBJECT')

# 4) Mesh'ni armature'ga bog'lash (vaznlar qo'lda berilgan — Armature modifier)
mod = body.modifiers.new("Armature", 'ARMATURE')
mod.object = arm_obj
body.parent = arm_obj

# 5) Animatsiyalar — har action alohida glTF animatsiyasi bo'ladi
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

ALL_BONES = ["Hips", "Spine", "Head", "ArmL", "ArmR", "LegL", "LegR"]

def key_pose(frame, pose):
    # Har animatsiya BARCHA suyaklarni belgilaydi (ko'rsatilmagani 0 = neytral).
    # Shunda Godot'da animatsiyalar bir-biriga "oqib" ketmaydi (run->attack toza qoladi).
    for b in ALL_BONES:
        key(frame, b, pose.get(b, (0, 0, 0)))

# --- idle: sokin nafas (yengil tebranish) ---
new_action("idle")
key_pose(1, {})
key_pose(24, {"Spine": (2.5, 0, 0), "Head": (-1.0, 0, 0)})
key_pose(48, {})

# --- run: yurish/yugurish sikli (oyoq-qo'l almashinadi) ---
new_action("run")
for f, s in [(1, 1), (12, -1), (24, 1)]:
    key_pose(f, {
        "LegL": (28 * s, 0, 0), "LegR": (-28 * s, 0, 0),
        "ArmL": (-30 * s, 0, 0), "ArmR": (30 * s, 0, 0),
        "Spine": (6, 0, 0),
    })

# --- attack: nayza zarbasi (o'ng qo'l + tana oldinga intiladi) ---
new_action("attack")
key_pose(1, {"ArmR": (10, 0, 0)})
key_pose(5, {"ArmR": (-78, 0, 0), "Spine": (16, 0, 0)})
key_pose(13, {"ArmR": (10, 0, 0)})

# --- die: orqaga yiqilish (butun tana son bo'g'imidan ag'dariladi) ---
new_action("die")
key_pose(1, {})
key_pose(13, {"Hips": (-72, 0, 0), "LegL": (38, 0, 0), "LegR": (22, 0, 0)})
key_pose(22, {"Hips": (-88, 0, 0), "LegL": (42, 0, 0), "LegR": (26, 0, 0)})

# 6) glTF eksport (faqat armature + mesh)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='DESELECT')
arm_obj.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = arm_obj
glb_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "models"))
os.makedirs(glb_dir, exist_ok=True)
glb_path = os.path.join(glb_dir, "kron_soldier.glb")
bpy.ops.export_scene.gltf(
    filepath=glb_path,
    export_format='GLB',
    use_selection=True,
    export_animations=True,
    export_animation_mode='ACTIONS',
    export_skins=True,
)
print("GLB_EXPORT:", os.path.exists(glb_path), os.path.getsize(glb_path) if os.path.exists(glb_path) else 0, "bytes")
print("ANIMATIONS:", sorted(a.name for a in bpy.data.actions))

# 7) Preview render'lar (rest poza + yurish + hujum kadrlari)
setup_camera_and_light()
out_dir = os.path.dirname(os.path.abspath(__file__))
arm_obj.animation_data.action = None
bpy.context.scene.frame_set(0)
render_preview(os.path.join(out_dir, "_preview_soldier.png"))
arm_obj.animation_data.action = bpy.data.actions["run"]
bpy.context.scene.frame_set(12)
render_preview(os.path.join(out_dir, "_preview_run.png"))
arm_obj.animation_data.action = bpy.data.actions["attack"]
bpy.context.scene.frame_set(5)
render_preview(os.path.join(out_dir, "_preview_attack.png"))
