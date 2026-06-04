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


## Silliq/qirrali shading — har ko'pburchakka to'g'ridan-to'g'ri (ops'siz, ishonchli).
def _shade(o, smooth):
    for p in o.data.polygons:
        p.use_smooth = smooth


def box(name, size, loc, mat, rot=(0, 0, 0), smooth=False):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0], size[1], size[2])
    o.rotation_euler = (radians(rot[0]), radians(rot[1]), radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(mat)
    _shade(o, smooth)
    return o


def cyl(name, radius, depth, loc, mat, verts=16, rot=(0, 0, 0), smooth=True):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = (radians(rot[0]), radians(rot[1]), radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(mat)
    _shade(o, smooth)
    return o


## Konus (yo'g'on-ingichka) — tabiiy a'zolar uchun (son/bilak — tepa/pastda har xil radius).
## r_bot = past (−Z) radius, r_top = tepa (+Z) radius. scale bilan ko'ndalang kesimni yassilash.
def taper(name, r_bot, r_top, depth, loc, mat, verts=14, rot=(0, 0, 0), scale=(1, 1, 1), smooth=True):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r_bot, radius2=r_top, depth=depth, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.rotation_euler = (radians(rot[0]), radians(rot[1]), radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(mat)
    _shade(o, smooth)
    return o


## Shar (ico) — bo'g'imlar (tizza/tirsak/yelka), bosh, jag' uchun. size bilan cho'zish.
def ball(name, size, loc, mat, subdiv=2, rot=(0, 0, 0), smooth=True):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=0.5, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0], size[1], size[2])
    o.rotation_euler = (radians(rot[0]), radians(rot[1]), radians(rot[2]))
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(mat)
    _shade(o, smooth)
    return o


# Eski "dome" nomi -> ball bilan bir xil (moslik uchun).
def dome(name, size, loc, mat, subdiv=2):
    return ball(name, size, loc, mat, subdiv=subdiv)


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
    # Oyoqlar (etik + boldir + tizza + son) — har qism oyoq suyagiga
    "Boot.L": "LegL", "Shin.L": "LegL", "Knee.L": "LegL", "Thigh.L": "LegL",
    "Boot.R": "LegR", "Shin.R": "LegR", "Knee.R": "LegR", "Thigh.R": "LegR",
    # Tos (Hips)
    "Pelvis": "Hips",
    # Tana + jihoz (Spine)
    "Torso": "Spine", "Belt": "Spine", "Collar": "Spine", "Shoulder.L": "Spine",
    "Shoulder.R": "Spine", "Backpack": "Spine", "Pouch.L": "Spine",
    "Pouch.R": "Spine", "Strap": "Spine", "Canteen": "Spine", "Button": "Spine",
    # Qo'llar (yelka pastidan: yelka-yuqori + tirsak + bilak + kaft) + miltiq
    "UpperArm.L": "ArmL", "Elbow.L": "ArmL", "Forearm.L": "ArmL", "Hand.L": "ArmL",
    "UpperArm.R": "ArmR", "Elbow.R": "ArmR", "Forearm.R": "ArmR", "Hand.R": "ArmR",
    "Rifle": "ArmR", "Bayonet": "ArmR",
    # Bo'yin + bosh + yuz + dubulg'a (Head)
    "Neck": "Head", "Head": "Head", "Jaw": "Head", "Nose": "Head", "Brow": "Head",
    "HelmetDome": "Head", "HelmetFlare": "Head",
    "HelmetLug.L": "Head", "HelmetLug.R": "Head",
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
    PACK = make_material(faction + "_Pack", (0.30, 0.26, 0.18), rough=0.95)  # kanvas/jihoz

    # --- Qismlar: yumaloq/konus shakllar + bo'g'imlar (realistikroq silueti) ---
    # Blender: Z tepaga, oyoq Z=0 da, bo'y ~1.9 m. Old tomon = -Y.
    parts = []

    # Oyoqlar (chap/o'ng): etik + boldir(konus) + tizza(shar) + son(konus)
    for sx, sfx in [(-0.13, "L"), (0.13, "R")]:
        parts.append(box("Boot." + sfx, (0.155, 0.34, 0.13), (sx, -0.04, 0.07), BOOT))
        parts.append(taper("Shin." + sfx, 0.066, 0.088, 0.40, (sx, 0.0, 0.40), TROUSER, verts=12))
        parts.append(ball("Knee." + sfx, (0.094, 0.094, 0.094), (sx, 0.0, 0.585), TROUSER, subdiv=1))
        parts.append(taper("Thigh." + sfx, 0.088, 0.122, 0.34, (sx, 0.0, 0.77), TROUSER, verts=12))

    # Tos (Hips)
    parts.append(ball("Pelvis", (0.36, 0.25, 0.27), (0.0, 0.0, 0.97), TROUSER, subdiv=2))

    # Tana (oval konus — bel ingichka, ko'krak keng) + yelka sharlari + yoqa + tugmalar
    parts.append(taper("Torso", 0.205, 0.25, 0.46, (0.0, 0.0, 1.26), COAT, verts=18, scale=(1.0, 0.72, 1.0)))
    parts.append(ball("Shoulder.L", (0.17, 0.18, 0.15), (-0.21, 0.0, 1.45), COAT, subdiv=2))
    parts.append(ball("Shoulder.R", (0.17, 0.18, 0.15), (0.21, 0.0, 1.45), COAT, subdiv=2))
    parts.append(taper("Collar", 0.135, 0.10, 0.08, (0.0, 0.0, 1.53), ACCENT, verts=14, scale=(1.0, 0.82, 1.0)))
    parts.append(box("Belt", (0.46, 0.27, 0.07), (0.0, 0.0, 0.93), BELT))
    parts.append(box("Button", (0.035, 0.02, 0.42), (0.0, -0.175, 1.26), METAL))

    # Jihoz: ryukzak (orqa +Y), beldagi patrondonlar (old -Y), ko'krak tasmasi, matara
    parts.append(box("Backpack", (0.30, 0.16, 0.36), (0.0, 0.19, 1.22), PACK))
    parts.append(box("Pouch.L", (0.11, 0.09, 0.11), (-0.13, -0.155, 0.93), PACK))
    parts.append(box("Pouch.R", (0.11, 0.09, 0.11), (0.13, -0.155, 0.93), PACK))
    parts.append(box("Strap", (0.06, 0.03, 0.56), (0.0, -0.13, 1.2), BELT, rot=(0, 28, 0)))
    parts.append(cyl("Canteen", 0.055, 0.13, (0.22, 0.06, 0.85), METAL, verts=12, rot=(90, 0, 0)))

    # Qo'llar: yelka-yuqori(konus) + tirsak(shar) + bilak(konus) + kaft(shar)
    for sx, sfx in [(-0.31, "L"), (0.31, "R")]:
        parts.append(taper("UpperArm." + sfx, 0.062, 0.08, 0.30, (sx, 0.0, 1.28), COAT, verts=12))
        parts.append(ball("Elbow." + sfx, (0.066, 0.066, 0.066), (sx, 0.0, 1.11), COAT, subdiv=1))
        parts.append(taper("Forearm." + sfx, 0.052, 0.064, 0.27, (sx, 0.01, 0.96), COAT, verts=12))
        parts.append(ball("Hand." + sfx, (0.075, 0.085, 0.105), (sx, 0.02, 0.81), SKIN, subdiv=2))

    # Bo'yin + bosh + yuz (jag', qosh, burun)
    parts.append(taper("Neck", 0.07, 0.062, 0.13, (0.0, 0.0, 1.57), SKIN, verts=12))
    parts.append(ball("Head", (0.20, 0.215, 0.235), (0.0, 0.0, 1.71), SKIN, subdiv=2))
    parts.append(ball("Jaw", (0.16, 0.165, 0.105), (0.0, -0.02, 1.635), SKIN, subdiv=2))
    parts.append(box("Brow", (0.16, 0.04, 0.035), (0.0, -0.10, 1.77), SKIN))
    parts.append(box("Nose", (0.04, 0.055, 0.06), (0.0, -0.115, 1.70), SKIN))

    # Dubulg'a (Stahlhelm): boshni qoplaydigan gumbaz + pastda ozgina qayrilgan chekka
    # (boshdan biroz keng — quloq/bo'yinni o'raydi) + yon shamollatish lug'lari.
    parts.append(ball("HelmetDome", (0.285, 0.30, 0.24), (0.0, 0.0, 1.82), HELMET, subdiv=2))
    parts.append(taper("HelmetFlare", 0.17, 0.145, 0.12, (0.0, 0.0, 1.74), HELMET, verts=20, scale=(1.0, 1.12, 1.0)))
    parts.append(ball("HelmetLug.L", (0.03, 0.03, 0.028), (-0.145, 0.0, 1.80), HELMET, subdiv=1))
    parts.append(ball("HelmetLug.R", (0.03, 0.03, 0.028), (0.145, 0.0, 1.80), HELMET, subdiv=1))

    # Miltiq + nayza (o'ng qo'lda)
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

    # idle — tinch nafas olish + og'irlik o'tkazish (jonliroq, ~72 kadr).
    new_action("idle")
    key_pose(1, {})
    key_pose(24, {"Spine": (1.6, 0, 0), "Head": (1.6, 0, 0), "Hips": (0.6, 0, 0)})
    key_pose(48, {"Spine": (0.4, 0, 1.2), "Head": (0.0, 0, 1.5)})
    key_pose(72, {})

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

    # walk — xotirjam patrul yurishi (run'dan sekinroq, kichikroq qadam).
    new_action("walk")
    for f, s in [(1, 1), (16, -1), (32, 1)]:
        key_pose(f, {
            "LegL": (16 * s, 0, 0), "LegR": (-16 * s, 0, 0),
            "ArmL": (-12 * s, 0, 0), "ArmR": (12 * s, 0, 0),
            "Spine": (3, 0, 0),
        })

    # aim — miltiqni ko'tarib nishonga olish holati (ranged jangda; loop).
    new_action("aim")
    key_pose(1, {"ArmR": (-72, 0, 0), "ArmL": (-50, 0, 0), "Spine": (8, 0, 0), "Head": (-4, 0, 0)})
    key_pose(24, {"ArmR": (-74, 0, 0), "ArmL": (-52, 0, 0), "Spine": (9, 0, 0), "Head": (-4, 0, 0)})

    # alert — atrofga qarash (post/tekshiruvda boshni o'ng-chapga buradi).
    new_action("alert")
    key_pose(1, {})
    key_pose(18, {"Head": (0, 0, 20), "Spine": (0, 0, 7)})
    key_pose(36, {"Head": (0, 0, -20), "Spine": (0, 0, -7)})
    key_pose(54, {})

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
