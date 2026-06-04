# -*- coding: utf-8 -*-
"""
Xandaq jang maydoni — low-poly bezak (dressing) proplari (1-jahon urushi uslubi).

Bu skript arena uchun bezakni QURADI va bitta .glb qilib eksport qiladi:
qum qoplar (barrikada), yog'och qutilar, metall bochkalar, tikanli sim, taxtalar.
Hammasini bitta meshga birlashtiramiz (bitta "draw call" — samarali, statik).

MUHIM — koordinatalar: arena Godot fazosida (gx = X, gz = Z poldagi, gy = balandlik).
glTF eksport Blender (x,y,z) -> Godot (x, z, -y) ga aylantiradi. Shuning uchun
Godot (gx, gz, gy) ni Blender (gx, -gz, gy) ga o'tkazamiz (gpos funksiyasi).

Ishlatish:
  & "C:\\Program Files\\Blender Foundation\\Blender 5.1\\blender.exe" --background --python assets\\blender\\props.py
Natija: assets/models/trench_dressing.glb + assets/blender/_preview_arena.png
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


def make_material(name, color, rough=0.9, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (color[0], color[1], color[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    m.diffuse_color = (color[0], color[1], color[2], 1.0)  # Workbench preview
    return m


# Godot (gx, gz, gy) -> Blender (gx, -gz, gy)
def gpos(gx, gz, gy=0.0):
    return (gx, -gz, gy)


objs = []


def box(name, size, gpos_tuple, mat, yaw=0.0):
    """gpos_tuple = (gx, gz, gy) Godot fazosida; yaw = Godot Y o'qi atrofida (daraja)."""
    loc = gpos(*gpos_tuple)
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = (size[0], size[1], size[2])
    o.rotation_euler = (0, 0, radians(yaw))   # Godot yaw = Blender Z aylanish
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    o.data.materials.append(mat)
    objs.append(o)
    return o


def cyl(name, radius, height, gpos_tuple, mat, verts=10):
    loc = gpos(*gpos_tuple)
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=height, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.data.materials.append(mat)
    bpy.ops.object.shade_flat()
    objs.append(o)
    return o


clear_scene()

# --- Ranglar ---
SAND1 = make_material("Sand1", (0.56, 0.49, 0.33))
SAND2 = make_material("Sand2", (0.50, 0.43, 0.29))
WOOD = make_material("Wood", (0.34, 0.22, 0.12))
WOOD_D = make_material("WoodDark", (0.22, 0.14, 0.08))
RUST = make_material("Rust", (0.36, 0.22, 0.13), rough=0.7, metal=0.4)
WIRE = make_material("Wire", (0.13, 0.13, 0.15), rough=0.5, metal=0.6)
SCORCH = make_material("Scorch", (0.09, 0.07, 0.05), rough=1.0)  # kuygan yer (krater)


# --- Qurilish funksiyalari ---

def sandbag_wall(gx, gz, length, yaw, rows=3, height=0.24):
    """Qum qoplardan past devor (barrikada). length — uzunlik (m), yaw — burilish."""
    bag_w, bag_d = 0.42, 0.26
    n = max(1, int(length / bag_w))
    import math
    cos_y, sin_y = math.cos(radians(yaw)), math.sin(radians(yaw))
    idx = 0
    for r in range(rows):
        # Har qatorda "g'isht" naqshi uchun yarim qop suriladi
        offset = (bag_w * 0.5) if (r % 2) else 0.0
        row_n = n if (r % 2 == 0) else n - 1
        for i in range(row_n):
            along = -length / 2 + bag_w * 0.5 + i * bag_w + offset
            # mahalliy (along o'qi) -> Godot (gx,gz) ga yaw bilan
            lx = along
            ox = gx + lx * cos_y
            oz = gz + lx * sin_y
            oy = height * 0.5 + r * (height * 0.85)
            mat = SAND1 if (idx % 2 == 0) else SAND2
            box("Sandbag", (bag_w * 0.96, bag_d, height), (ox, oz, oy), mat, yaw=yaw)
            idx += 1


def crate(gx, gz, s=0.7, yaw=0.0):
    box("Crate", (s, s, s), (gx, gz, s * 0.5), WOOD, yaw=yaw)
    # ustki qirra (qorong'i taxta)
    box("CrateLid", (s * 1.02, s * 1.02, 0.06), (gx, gz, s + 0.0), WOOD_D, yaw=yaw)


def crate_pile(gx, gz):
    crate(gx, gz, 0.7, 8)
    crate(gx + 0.75, gz + 0.1, 0.65, -6)
    crate(gx + 0.2, gz + 0.05, 0.6, 0)  # tepada
    objs[-1].location.z += 0.7  # eng oxirgi qutini tepaga
    bpy.ops.object.transform_apply(location=True)


def barrel(gx, gz):
    cyl("Barrel", 0.27, 0.9, (gx, gz, 0.45), RUST, verts=12)
    # ikkita halqa
    box("Ring", (0.58, 0.58, 0.05), (gx, gz, 0.25), WOOD_D)
    box("Ring", (0.58, 0.58, 0.05), (gx, gz, 0.65), WOOD_D)


def post(gx, gz, h=1.1, yaw=0.0, tilt=0.0):
    box("Post", (0.08, 0.08, h), (gx, gz, h * 0.5), WOOD_D, yaw=yaw)


def crater(gx, gz, r=1.6):
    """Snaryad chuquri — yerda kuygan yassi disk + chetiga sochilgan tuproq bo'laklari."""
    cyl("CraterFloor", r, 0.05, (gx, gz, 0.02), SCORCH, verts=12)
    # chetidagi ko'tarilgan tuproq (bir nechta kichik bo'lak)
    import math
    for i in range(6):
        a = i * (math.pi * 2 / 6)
        ex = gx + math.cos(a) * (r * 0.95)
        ez = gz + math.sin(a) * (r * 0.95)
        box("CraterRim", (0.4, 0.4, 0.14), (ex, ez, 0.07), SAND2, yaw=math.degrees(a))


def barbed_wire_line(gx1, gz1, gx2, gz2):
    """Ikki nuqta orasida qoziqlar + zigzag sim."""
    import math
    dx, dz = gx2 - gx1, gz2 - gz1
    dist = math.hypot(dx, dz)
    n = max(2, int(dist / 1.6))
    yaw = math.degrees(math.atan2(dz, dx))
    for i in range(n + 1):
        t = i / n
        px, pz = gx1 + dx * t, gz1 + dz * t
        post(px, pz, 0.95)
        # X-shakl tepa (qoziq uchidagi tirgak)
        box("Stake", (0.05, 0.05, 0.34), (px, pz, 0.92), WIRE, yaw=35)
        box("Stake", (0.05, 0.05, 0.34), (px, pz, 0.92), WIRE, yaw=-35)
    # zigzag sim (uchta balandlikda)
    for h in (0.45, 0.7, 0.92):
        segs = n * 3
        for s in range(segs):
            t0 = s / segs
            t1 = (s + 1) / segs
            ax, az = gx1 + dx * t0, gz1 + dz * t0
            bx, bz = gx1 + dx * t1, gz1 + dz * t1
            mx, mz = (ax + bx) / 2, (az + bz) / 2
            mh = h + (0.12 if s % 2 else -0.12)
            seg_len = math.hypot(bx - ax, bz - az)
            seg_yaw = math.degrees(math.atan2(bz - az, bx - ax))
            box("Wire", (seg_len, 0.02, 0.02), (mx, mz, (h + mh) / 2), WIRE, yaw=seg_yaw)


# ============================================================================
# JOYLASHTIRISH (Godot koordinatalari; arena ichi ~ [-27,27], o'yinchi z=20 da)
# Markaziy jang yo'lagi ochiq qoldiriladi — gameplay uchun.
# Asosiy panoh — mavjud CSG qutilari (collision bilan); bular faqat BEZAK.
# ============================================================================

# --- Perimetr istehkomi: 4 devor ichida qum qop devorlari ---
sandbag_wall(0, -26, 48, 0, rows=3)            # shimol (dushman) chizig'i
sandbag_wall(0, 26, 48, 0, rows=3)             # janub (o'yinchi orqasi)
sandbag_wall(-26, 0, 48, 90, rows=3)           # g'arb
sandbag_wall(26, 0, 48, 90, rows=3)            # sharq

# --- No-man's-land tikanli sim (shimol, dushman oldida) ---
barbed_wire_line(-23, -23, 23, -23)
barbed_wire_line(-21, -20.5, 21, -20.5)
barbed_wire_line(-23, 23, 23, 23)              # janub chegarasida ham bir qator

# --- Oldingi panoh chiziqlari (markazdan chetda) ---
sandbag_wall(-13, -9, 6.0, 20, rows=3)         # chap flang panoh
sandbag_wall(13, -9, 6.0, -20, rows=3)         # o'ng flang panoh
sandbag_wall(0, -5, 7.0, 0, rows=2)            # markaziy past devor

# --- Burchak klasterlari: qutilar + bochkalar ---
for (cx, cz) in [(24, -24), (-24, -24), (24, 24), (-24, 24)]:
    crate_pile(cx, cz)
    barrel(cx + (-1.4 if cx > 0 else 1.4), cz)

# --- Qo'shimcha qutilar/bochkalar (chet hududlarda) ---
crate(18, -5, 0.7, 18)
crate(-18, -4, 0.7, -14)
crate(20, 9, 0.65, 8)
crate(-20, 10, 0.7, -10)
barrel(-19, 12)
barrel(16, -13)
barrel(7, 16)
barrel(-8, 17)

# --- Sochilgan taxtalar / xarobalar (chetlarda) ---
box("Plank", (2.4, 0.18, 0.08), (18, -13, 0.05), WOOD, yaw=30)
box("Plank", (1.9, 0.16, 0.08), (-18, -12, 0.05), WOOD, yaw=-50)
box("Plank", (2.6, 0.2, 0.08), (-14, 18, 0.05), WOOD, yaw=70)
box("Plank", (2.2, 0.18, 0.08), (12, 18, 0.05), WOOD, yaw=-35)
post(-25, -25, 1.4)
post(25, -24, 1.2)
post(24, 25, 1.3)

# --- Snaryad chuqurlari (no-man's-land va maydon bo'ylab — jang izlari) ---
crater(-5, -16, 2.0)
crater(9, -18, 1.6)
crater(-13, -5, 1.5)
crater(14, -6, 1.7)
crater(2, 6, 1.4)
crater(-9, 13, 1.6)
crater(11, 11, 1.5)

print("PROPS_BUILT:", len(objs))


# ============================================================================
# BIRLASHTIRISH + EKSPORT
# ============================================================================
bpy.ops.object.select_all(action='DESELECT')
for o in objs:
    o.select_set(True)
bpy.context.view_layer.objects.active = objs[0]
bpy.ops.object.join()
dressing = bpy.context.active_object
dressing.name = "TrenchDressing"

glb_dir = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "models"))
os.makedirs(glb_dir, exist_ok=True)
glb_path = os.path.join(glb_dir, "trench_dressing.glb")
bpy.ops.object.select_all(action='DESELECT')
dressing.select_set(True)
bpy.context.view_layer.objects.active = dressing
bpy.ops.export_scene.gltf(filepath=glb_path, export_format='GLB', use_selection=True, export_animations=False)
print("GLB_EXPORT:", os.path.exists(glb_path), os.path.getsize(glb_path) if os.path.exists(glb_path) else 0, "bytes")


# ============================================================================
# PREVIEW RENDER (yuqoridan qiya — joylashuvni ko'rish uchun; pol vaqtinchalik)
# ============================================================================
# Vaqtinchalik loyqa pol (faqat preview uchun — eksportga kirmaydi, allaqachon eksport qildik)
MUD = make_material("Mud", (0.30, 0.24, 0.17))
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
bpy.context.active_object.data.materials.append(MUD)

# 3/4 yuqori burchak — butun maydon kompozitsiyasini ko'rish uchun.
# Godot kamera (15,11,17) -> markaz (0,1,-2). Blender: gpos bilan aylantiramiz.
bpy.ops.object.empty_add(location=gpos(0, -2, 1.0))
target = bpy.context.active_object
bpy.ops.object.camera_add(location=gpos(15, 17, 11))
cam = bpy.context.active_object
cam.data.lens = 28
bpy.context.scene.camera = cam
c = cam.constraints.new('TRACK_TO')
c.target = target
c.track_axis = 'TRACK_NEGATIVE_Z'
c.up_axis = 'UP_Y'

bpy.ops.object.light_add(type='SUN', location=(5, 5, 20))
bpy.context.active_object.data.energy = 3.5
bpy.context.active_object.rotation_euler = (radians(55), radians(10), radians(30))

scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.color_type = 'MATERIAL'
scene.display.shading.light = 'STUDIO'
scene.display.shading.show_shadows = True
scene.render.resolution_x = 900
scene.render.resolution_y = 600
world = bpy.data.worlds[0] if bpy.data.worlds else bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
if bg:
    bg.inputs[0].default_value = (0.55, 0.58, 0.62, 1.0)
out_png = os.path.join(os.path.dirname(os.path.abspath(__file__)), "_preview_arena.png")
scene.render.filepath = out_png
bpy.ops.render.render(write_still=True)
print("RENDER_OK:", os.path.exists(out_png))
