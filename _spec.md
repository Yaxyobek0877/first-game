I now have full ground truth. I have everything needed to write the unified spec. Returning it directly as my final response.

---

# UNIFIED FINAL SPEC â€” Enemy AI Redesign (Disciplined WWI Kron Soldiers)

## JUDGMENT (lead's verdict, brief)

All three converge on the same correct skeleton (smoothing + turn-rate + RVO avoidance + repath throttle + perception cone/LOS/last-known-pos + role-driven FSM + per-wave roster). That consensus is the spine of this spec. Where they differ, I picked:

- **Movement smoothing math:** Proposal 1's `move_toward` (vector) for velocity â€” it caps the *magnitude* of change correctly (true accel cap), whereas P2/P3's per-axis `lerp(velocity.x, target.x, rate*delta)` is frame-rate-dependent and bleeds diagonally. **P1 wins.**
- **Rotation:** P3's `rotate_toward` / `wrapf`-based `_rotate_toward` is the cleanest and resolves the -Z forward sign explicitly. **P3 wins**, but I lock the sign now (see C) so nobody "tests in editor and locks it later."
- **Avoidance wiring:** All three agree, but P1/P2 want `move_and_slide()` moved into the `velocity_computed` callback; P3 keeps it at the end of `_physics_process` and stores `_safe_vel`. **P3 wins** â€” keeping the single `move_and_slide()` at the end of `_physics_process` preserves the existing invariant exactly and avoids a subtle bug (the callback can fire mid-physics and gravity/anim ordering gets fragile). We consume the callback into `_safe_vel`.
- **Perception 5 Hz staggered + squared-distance gating:** P3 is the most rigorous on perf. **P3 wins.**
- **Roles:** P1's 6 roles (adds OFFICER) is scope creep for v1. P2/P3's 5 roles align. I take the **5-role set** and drop OFFICER to a documented future hook. MARKSMAN vs RIFLEMAN: I keep **both as one role family** â€” RIFLEMAN is the standard ranged (range 18) and MARKSMAN is a long-range variant (range 40), distinguished only by tunables + post, so behavior code is shared.
- **Guard posts:** P3's table is the most complete and correctly separates SENTRY posts from MARKSMAN overwatch posts. **P3 wins**, lightly merged with P1's facing notes.
- **Hearing signal name:** consensus `Events.player_fired(pos)`. Adopt.
- **Wave roster:** P3's `_composition()` (explicit counts that scale, always keeps a defensive backbone) is more robust than P1's modulo tricks and P2's hard-coded small tables. **P3 wins**, with P2's wave-1-is-a-garrison framing baked in.
- **Models:** all three agree (gear additive, `walk`/`aim`/`alert` anims, `has_animation()` fallback, keep mesh+anim names). I take the union, prioritized, with per-role tint done in `enemy.gd` (cheap, no new GLBs required for v1).

Conflicts resolved. One unified spec follows. Implement as-is.

---

## A) ROLE ENUM + PER-ROLE BEHAVIOR TABLE

```gdscript
enum Role { SENTRY, PATROL, RIFLEMAN, MARKSMAN, ASSAULT, FLANKER }
@export var role: Role = Role.ASSAULT
```

`is_ranged` stays as an `@export var` (wave_manager back-compat) but is **re-derived** in `_ready()` from role so new code is authoritative:

```gdscript
# _ready(), BEFORE the await:
is_ranged = (role == Role.RIFLEMAN or role == Role.MARKSMAN)
```

Back-compat bridge (if any caller still sets only `is_ranged=true` without a role): in `_ready()`, `if is_ranged and role == Role.ASSAULT: role = Role.RIFLEMAN`.

| Role | Duty | Engage trigger | Leash / return | Speed factor | Movement flavor |
|---|---|---|---|---|---|
| **SENTRY** | Hold a fixed post | sees player (cone+LOS) AND player within `engage_range` of **post** | hard: dist(self, post) > `leash_range` â†’ RETURN | 0.0 idle / 0.8 RETURN | idle sway, periodic look-around |
| **PATROL** | Walk a 2-node loop near a post | sees player; or hears gunfire | soft: dist(self, post) > `leash_range` â†’ RETURN | 0.55 | calm walk, 1â€“2s dwell at nodes |
| **RIFLEMAN** | Hold a firing line at mid range | sees player AND LOS AND within `ranged_range` | medium leash to firing post | 0.85 | strafe + standoff band, seeks cover |
| **MARKSMAN** | Long-range overwatch | LOS AND within `ranged_range` (set 40) | strong leash to overwatch post; relocate only if LOS lost | 0.7 | mostly stationary, telegraphed shot |
| **ASSAULT** | Rusher â€” close & melee | sees player OR hears gunfire | none (whole arena) | 1.0 | full speed, slight strafe on final approach |
| **FLANKER** | Side approach then close | sees player | none | 1.1 | arcs to a flank offset before closing |

**Per-role tunables (grouped):**

```gdscript
@export_group("Role / Post")
@export var guard_position: Vector3 = Vector3.INF   # INF => use spawn pos
@export var guard_radius: float = 3.0
@export var leash_range: float = 14.0
@export var patrol_points: Array[Vector3] = []      # PATROL waypoints (world)
@export var engage_range: float = 26.0              # SENTRY/PATROL: see player within this of POST
@export var face_dir_deg: float = 0.0               # default facing yaw when holding (0 = face +Z/south, toward player)
@export var flank_side: int = 0                     # FLANKER: -1/+1, set by wave_manager
```

`_ready()` resolves: `if guard_position == Vector3.INF: guard_position = global_position`. RIFLEMAN/MARKSMAN posts are passed by wave_manager; default `ranged_range` stays 16 but wave_manager sets MARKSMAN's to 40 (or set it via a tiny `_apply_role_tunables()` â€” see G).

---

## B) NEW FSM STATES + TRANSITIONS

```gdscript
enum State { GUARD, PATROL, INVESTIGATE, ENGAGE, ADVANCE, REPOSITION, RETURN, ATTACK, DEAD }
```

`ATTACK` is **kept** so the proven `_strike`/`_ranged_strike`/`attack_timer` flow is reused verbatim. `IDLE`/`CHASE` are removed (absorbed by GUARD/ENGAGE/ADVANCE).

Role â†’ initial state (`_ready()`):
```
SENTRY â†’ GUARD ; PATROL â†’ PATROL ; RIFLEMAN/MARKSMAN â†’ ADVANCE (move to firing post, then ENGAGE)
ASSAULT/FLANKER â†’ ADVANCE
```

| State | Behavior | â†’ exits |
|---|---|---|
| **GUARD** | `_desired_vel = ZERO`; idle sway inside `guard_radius`; periodic look-around (rotate `face_dir_deg` Â±35Â° every 3â€“5s). Queries nav only if shoved off post. | see+in-engage_range â†’ ENGAGE Â· hear â†’ INVESTIGATE Â· shoved >`guard_radius`+1 â†’ RETURN |
| **PATROL** | Walk waypoint loop at 0.55Ã—, dwell 1â€“2s per node. | see â†’ ENGAGE Â· hear â†’ INVESTIGATE Â· leashed â†’ RETURN |
| **INVESTIGATE** | Path to `_last_known_pos`; on arrival, stop + look-around for `investigate_dwell` (2.5s). | re-see â†’ ENGAGE Â· dwell done OR leashed â†’ RETURN (guards) / role-default |
| **ENGAGE** | In combat. Melee: face player, hand to ATTACK when in `attack_range`. Ranged: strafe + standoff (C-g), to ATTACK when LOS & in band. Faces **player**. | in range+LOS â†’ ATTACK Â· too far / no LOS (melee) â†’ ADVANCE Â· ranged too-close / LOS blocked â†’ REPOSITION Â· `_time_since_seen > lose_interest_time` â†’ INVESTIGATE Â· leashed â†’ RETURN |
| **ADVANCE** | Move toward `_last_known_pos` (assault/flanker) or firing post (ranged). FLANKER targets flank offset first. Faces **move dir**. | LOS+range â†’ ENGAGE Â· timeout â†’ INVESTIGATE Â· leashed â†’ RETURN |
| **REPOSITION** | Ranged: move to a better cover/LOS slot (nearest cover-adjacent point with LOS to `_last_known_pos`); capped `reposition_timeout` 3s then re-evaluate. | range OK + LOS â†’ ENGAGE Â· leashed â†’ RETURN |
| **ATTACK** | **Existing** `_strike()` / `_ranged_strike()`, gated by `attack_timer.is_stopped()`. Faces player, `_desired_vel = ZERO`. | dist > triggerÃ—1.3 â†’ ENGAGE Â· ranged no LOS â†’ ENGAGE Â· lost â†’ INVESTIGATE |
| **RETURN** | Path to `guard_position` (or nearest patrol node) at 0.8Ã—; on arrival snap facing to `face_dir_deg` â†’ GUARD/PATROL. | arrived â†’ GUARD/PATROL Â· re-breach (see+within leash) â†’ ENGAGE |
| **DEAD** | **Unchanged** `_die()`. | terminal |

**Centralized leash helper** (called only in ENGAGE/ADVANCE/INVESTIGATE/ATTACK, and only for guarding roles):
```gdscript
func _leashed() -> bool:
	return role in [Role.SENTRY, Role.PATROL, Role.RIFLEMAN, Role.MARKSMAN] \
		and Vector2(global_position.x - guard_position.x, global_position.z - guard_position.z).length() > leash_range
```
Keep the existing `Ã—1.3` hysteresis on the ATTACKâ†’ENGAGE distance check (already in `_do_attack`).

---

## C) MOVEMENT SYSTEM (code-level)

The state machine writes `_desired_vel` (horizontal) and a face target each frame; a shared pipeline applies avoidance â†’ accel cap â†’ turn cap â†’ one `move_and_slide()`.

**`_physics_process` skeleton (replaces current match block):**
```gdscript
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	if _state != State.DEAD:
		_update_perception(delta)
		_think(delta)            # match _state -> sets _desired_vel + face target
	else:
		_desired_vel = Vector3.ZERO
	# route desired through avoidance (consumed in _on_velocity_computed)
	if nav.avoidance_enabled and _state != State.DEAD:
		nav.set_velocity(_desired_vel)
	else:
		_safe_vel = _desired_vel
	_apply_movement(_safe_vel, delta)   # accel/decel cap (C-a)
	_apply_rotation(delta)              # turn-rate cap (C-b)
	_update_anim()
	move_and_slide()                    # STILL the only call, still at the end
```
> Note: the existing per-frame `_separation()` boids push is **deleted** â€” RVO avoidance replaces it.

**(a) Acceleration / damping** â€” magnitude-capped (P1's `move_toward` vector form):
```gdscript
@export var accel: float = 14.0   # m/s^2
@export var decel: float = 18.0
func _apply_movement(target_planar: Vector3, delta: float) -> void:
	var cur := Vector3(velocity.x, 0.0, velocity.z)
	var rate := accel if target_planar.length() > cur.length() else decel
	var nv := cur.move_toward(target_planar, rate * delta)
	velocity.x = nv.x
	velocity.z = nv.z
```

**(b) Turn-rate-capped rotation** (P3, sign locked now):
```gdscript
@export var turn_rate_deg: float = 300.0   # deg/s
var _face_yaw: float = 0.0
func _set_face_dir(dir: Vector3) -> void:
	if dir.length_squared() > 0.0004:
		_face_yaw = atan2(-dir.x, -dir.z)   # SIGN LOCKED: Godot model forward is -Z (matches existing look_at)
func _apply_rotation(delta: float) -> void:
	rotation.y = rotate_toward(rotation.y, _face_yaw, deg_to_rad(turn_rate_deg) * delta)
```
**Sign justification (do not re-test):** the current `_face_player()` uses `look_at(target, UP)`, which points local **-Z** at the target. `atan2(-dir.x, -dir.z)` produces the yaw whose -Z axis aligns with `dir`. This is identical to the old facing. Lock it.
- While moving (ADVANCE/PATROL/RETURN/INVESTIGATE-transit): `_set_face_dir(horizontal velocity)`.
- While ENGAGE/ATTACK/REPOSITION: `_set_face_dir(player_pos - global_position)`.
- While GUARD/look-around: set `_face_yaw` directly to the swept angle.

**(c) NavigationAgent3D avoidance wiring.** In `enemy.tscn`, set on the `NavigationAgent3D` node: `avoidance_enabled = true`, `radius = 0.5`, `neighbor_distance = 4.0`, `max_neighbors = 8`, `time_horizon_agents = 1.5`, `time_horizon_obstacles = 0.5`. In `_ready()`:
```gdscript
nav.max_speed = move_speed
nav.velocity_computed.connect(_on_velocity_computed)
...
func _on_velocity_computed(safe: Vector3) -> void:
	_safe_vel = Vector3(safe.x, 0.0, safe.z)
```
`_safe_vel` is the *lerp target* in `_apply_movement`. Stationary agents (GUARD/MARKSMAN holding) still call `nav.set_velocity(Vector3.ZERO)` so RVO nudges them apart without drift. In `_die()` add `nav.avoidance_enabled = false` (corpse is not an RVO obstacle).

**(d) Repath throttle** (per-agent staggered):
```gdscript
@export var repath_interval: float = 0.35
var _repath_accum: float = 0.0
var _goal: Vector3 = Vector3.INF
func _request_path_to(goal: Vector3, delta: float) -> void:
	_repath_accum -= delta
	if _repath_accum <= 0.0 or _goal.distance_to(goal) > 1.5:
		_goal = goal
		nav.target_position = goal
		_repath_accum = repath_interval + randf() * 0.1
```
ASSAULT/FLANKER path to `_last_known_pos`, **not** the live player, whenever `_can_see_player == false` â€” this is the core "not psychic" change.

**(e) Per-enemy variation** (`_ready()`, after deriving role/tunables):
```gdscript
move_speed *= randf_range(0.9, 1.1)
turn_rate_deg *= randf_range(0.9, 1.1)
attack_cooldown *= randf_range(0.9, 1.15)
repath_interval *= randf_range(0.85, 1.15)
_repath_accum = randf() * repath_interval
_percept_accum = randf() * PERCEPT_INTERVAL
_strafe_sign = 1.0 if randf() < 0.5 else -1.0
nav.max_speed = move_speed   # after the speed jitter
```
Effective per-state speed = `move_speed * _state_speed_factor()` (table in A).

**(f) Idle sway / patrol wander.** GUARD: `_desired_vel = ZERO`; every `look_interval` (randf 3â€“5s) set `_face_yaw = deg_to_rad(face_dir_deg) + deg_to_rad(randf_range(-35,35))`. PATROL: pick next waypoint; occasionally offset it by a random point in a disc of `guard_radius*0.5` so the loop isn't a perfect line.

**(g) Ranged strafe + standoff** (RIFLEMAN/MARKSMAN in ENGAGE):
```gdscript
@export var ideal_range: float = 12.0
@export var min_standoff: float = 8.0
var _strafe_sign: float = 1.0
var _strafe_flip_t: float = 0.0
func _ranged_desired_vel(player_pos: Vector3, dist: float, delta: float) -> Vector3:
	_strafe_flip_t -= delta
	if _strafe_flip_t <= 0.0:
		_strafe_flip_t = randf_range(1.5, 3.0)
		_strafe_sign = -_strafe_sign
	var to := player_pos - global_position; to.y = 0.0
	var fwd := to.normalized()
	var side := fwd.cross(Vector3.UP) * _strafe_sign
	var radial := 0.0
	if dist < ideal_range - 1.0: radial = 1.0       # back off
	elif dist > ideal_range + 2.0: radial = -1.0    # close in
	return (side * 0.7 - fwd * radial * 0.6).normalized() * move_speed * 0.9
```
MARKSMAN uses larger `ideal_range`/`min_standoff` (set in `_apply_role_tunables`) and mostly returns near-zero (stand and shoot). Flip `_strafe_sign` early if `get_slide_collision_count() > 0` (blocked).

**FLANKER offset** (ADVANCE): `flank_target = player_pos + player_right * flank_side * 8.0`, where `player_right` is the player's right vector flattened; once within `attack_range*2.5` of player, drop offset and path straight to `_last_known_pos`.

---

## D) PERCEPTION

```gdscript
@export_group("Perception")
@export var vision_range: float = 32.0
@export var vision_fov_deg: float = 110.0      # full cone (Â±55Â°)
@export var hearing_range: float = 14.0
@export var lose_interest_time: float = 4.0
const PERCEPT_INTERVAL := 0.2                  # 5 Hz
var _can_see_player := false
var _last_known_pos := Vector3.INF
var _time_since_seen := 999.0
var _percept_accum := 0.0
var _los_cached := false
```

```gdscript
func _update_perception(delta: float) -> void:
	_time_since_seen += delta
	_percept_accum -= delta
	if _percept_accum > 0.0: return
	_percept_accum = PERCEPT_INTERVAL + randf() * 0.05
	_can_see_player = _check_vision()
	_los_cached = _can_see_player           # cache for combat (no extra ray)
	if _can_see_player:
		_last_known_pos = _player.global_position
		_time_since_seen = 0.0

func _check_vision() -> bool:
	if not is_instance_valid(_player): return false
	var to := _player.global_position - global_position
	if to.length_squared() > vision_range * vision_range: return false   # squared gate
	var flat := Vector3(to.x, 0.0, to.z)
	var fwd := -global_transform.basis.z; fwd.y = 0.0
	if flat.normalized().dot(fwd.normalized()) < cos(deg_to_rad(vision_fov_deg * 0.5)):
		# peripheral: still see if very close
		if to.length() > 4.0: return false
	return _has_line_of_sight()             # existing raycast â€” only fires past cheap gates
```

**Hearing** (event-driven, no polling). Add `signal player_fired(world_pos: Vector3)` to `events.gd`; emit from `weapon.gd._shoot()` via `Events.player_fired.emit(muzzle.global_position)` (player position is fine too). In `enemy.gd._ready()`: `Events.player_fired.connect(_on_player_fired)`.
```gdscript
func _on_player_fired(pos: Vector3) -> void:
	if _state in [State.DEAD, State.ENGAGE, State.ADVANCE, State.ATTACK]: return
	if global_position.distance_to(pos) <= hearing_range:
		_last_known_pos = pos
		if _state in [State.GUARD, State.PATROL, State.RETURN]:
			_enter_investigate()
```
Also: in `take_damage()`, set `_last_known_pos = _player.global_position` and, if idle/guarding, `_enter_investigate()` (being shot tells you roughly where the shooter is).

**Combat LOS reuse:** ENGAGE/ATTACK use the cached `_los_cached` for state decisions. `_ranged_strike()` keeps its **single** `_has_line_of_sight()` ray at fire time (already gated by the 1.2s `attack_timer`), so no per-frame ray.

---

## E) GUARD OBJECTIVE & POST ASSIGNMENT

A "post" = `guard_position` + `guard_radius` + `leash_range`. Concrete posts from the 8 cover boxes (world x,z; y=0, resolved against floor). Sentries spawn **on** the post (already defending), facing south toward the player's z=20 approach (`face_dir_deg = 0`).

```gdscript
# wave_manager.gd constants
const GUARD_POSTS: Array[Vector3] = [
	Vector3(0, 0, -18),    # center-forward, 3x3 box â€” main line
	Vector3(8, 0, -10),    # east 2x2
	Vector3(-9, 0, -12),   # west 2x2
	Vector3(0, 0, 0),      # dead-center 2x2 â€” the "objective"
]
const MARKSMAN_POSTS: Array[Vector3] = [
	Vector3(17, 0, -15),   # NE 3x3 overwatch
	Vector3(-17, 0, -15),  # NW 3x3 overwatch
	Vector3(0, 0, -24),    # rear-center overwatch
]
const PATROL_LOOPS: Array = [
	[Vector3(8,0,-10), Vector3(0,0,-18), Vector3(-9,0,-12)],   # forward line
	[Vector3(13,0,4),  Vector3(17,0,-15)],                      # right lane
	[Vector3(-14,0,3), Vector3(-17,0,-15)],                     # left lane
]
```
SENTRY/RIFLEMAN spawn at `GUARD_POSTS` (pop so two don't share). MARKSMAN spawn at `MARKSMAN_POSTS` (with `ranged_range = 40`). PATROL gets a `PATROL_LOOPS` entry (spawn at its first node, `guard_position` = first node). ASSAULT/FLANKER spawn from the existing north/flank `_spawn_points`. **No spawn jitter for guards** (snap onto post); keep jitter only for ASSAULT/FLANKER.

> Future hook (not v1): a `Marker3D "Objective"` at `(0,0,-18)`; if player holds within 4m for N s, wave ends early. Post layout already supports it.

---

## F) WAVE_MANAGER ROLE-MIX PER WAVE

Replace `if i % 3 == 2: e.is_ranged = true` with an explicit composition that always keeps a defensive backbone and scales pressure (P3's algorithm, P2's framing). `count` stays `base_count + _wave`.

```gdscript
func _composition(wave: int, count: int) -> Array:
	var roles: Array = []
	if wave == 1:
		roles = [Role.SENTRY, Role.SENTRY, Role.PATROL]            # garrison: learn "they guard"
	elif wave == 2:
		roles = [Role.SENTRY, Role.PATROL, Role.RIFLEMAN, Role.ASSAULT]
	elif wave == 3:
		roles = [Role.SENTRY, Role.RIFLEMAN, Role.MARKSMAN, Role.ASSAULT, Role.FLANKER]
	else:
		var sentries := clampi(2 + wave / 3, 2, 4)
		var marksmen := clampi(wave / 3, 1, 3)
		var riflemen := clampi(wave / 2, 1, 4)
		var flankers := clampi((wave - 3) / 2, 1, 3)
		for i in sentries: roles.append(Role.SENTRY if i % 2 == 0 else Role.PATROL)
		for i in marksmen: roles.append(Role.MARKSMAN)
		for i in riflemen: roles.append(Role.RIFLEMAN)
		for i in flankers: roles.append(Role.FLANKER)
		while roles.size() < count: roles.append(Role.ASSAULT)   # fill pressure with rushers
	while roles.size() < count: roles.append(Role.ASSAULT)
	return roles.slice(0, count)
```
Spawn loop: compute `roles = _composition(_wave, count)`; for each `i`, `e.role = roles[i]`, then place per E, set `e.guard_position`/`e.patrol_points`/`e.flank_side`/`ranged_range`. Keep `Events.wave_started.emit(_wave)` unchanged. (Optional: also emit a count summary for the HUD later.)

Feel: W1 = clearable static garrison (teaches "they hold posts, they leash"). W2 = +patroller +1 rusher. W3 = +flanker +marksman (teaches "watch sides / break LOS"). W4+ = defended position being overrun, never a zombie swarm.

---

## G) enemy.gd REFACTOR OUTLINE

**KEEP verbatim (invariants â€” do not touch):**
- `take_damage(amount: float)`, `add_to_group("enemy")`, `Events.enemy_died.emit(self)`.
- `_strike()`, `_ranged_strike()`, `_has_line_of_sight()`, all effect funcs (`_spawn_tracer`, `_spawn_impact`, `_enemy_muzzle_flash`, `_flash`/`_clear_flash`, `_blood_burst`, `_blood_pool`), and **`_die()`** (corpse flow, `corpse_lifetime`, group/collision removal). Add only one line to `_die()`: `nav.avoidance_enabled = false`.
- `_mesh_inst`/`_anim` lookup via `find_child("KronSoldierMesh"...)` and `find_child("AnimationPlayer"...)`. Mesh + anim names `idle/run/attack/die`.
- The `await get_tree().physics_frame` in `_ready()`, the navmesh `map_get_iteration_id(...) == 0` guard before any nav read, single `move_and_slide()` at end of `_physics_process`, and the post-`await` `if _state != State.ATTACK: return` + `is_instance_valid(_player)` guards in `_strike`/`_ranged_strike` (just rename the state check target to `State.ATTACK`, which still exists).

**CHANGE / ADD:**
- New `Role` + expanded `State` enums; all `@export` vars from A/C/D.
- `_ready()` additions (order matters): derive `is_ranged` from role â†’ `_apply_role_tunables()` â†’ resolve `guard_position` â†’ per-enemy jitter â†’ connect `nav.velocity_computed` + `Events.player_fired` â†’ set initial `_state` by role â†’ (existing) loop-mode loop extended to `["idle","run","walk","aim"]` guarded by `has_animation`.
- **Delete** `_do_idle`/`_do_chase` and `_separation()`. Replace the `match` body with `_think(delta)` dispatch: `_do_guard/_do_patrol/_do_investigate/_do_engage/_do_advance/_do_reposition/_do_return/_do_attack`. Each sets `_desired_vel` + face target; movement/rotation/avoidance handled by the shared pipeline (C).
- New funcs: `_apply_movement`, `_apply_rotation`, `_set_face_dir`, `_on_velocity_computed`, `_request_path_to`, `_update_perception`, `_check_vision`, `_on_player_fired`, `_enter_investigate`, `_ranged_desired_vel`, `_state_speed_factor`, `_leashed`, `_apply_role_tunables`.
- `_apply_role_tunables()`: e.g. `match role: MARKSMAN: ranged_range = 40; ideal_range = 22; min_standoff = 14; move_speed *= 0.7 ...` â€” keeps per-role numbers in one place.
- `_update_anim()` extended (graceful fallback so an un-regenerated GLB still runs):
```gdscript
if _anim.current_animation == "attack": return
var spd := Vector2(velocity.x, velocity.z).length()
var want := "idle"
match _state:
	State.GUARD: want = "alert"
	State.INVESTIGATE, State.RETURN: want = "walk" if spd > 0.4 else "alert"
	State.PATROL: want = "walk" if spd > 0.4 else "idle"
	State.ENGAGE, State.REPOSITION: want = "aim" if is_ranged else ("run" if spd > 0.4 else "idle")
	State.ADVANCE: want = "run" if spd > move_speed * 0.6 else "walk"
	_: want = "run" if spd > 0.4 else "idle"
if not _anim.has_animation(want): want = "run" if spd > 0.4 else "idle"
if _anim.current_animation != want: _anim.play(want)
```
- **Per-role tint** (cheap, no new GLB) in `_ready()`: e.g. MARKSMAN darker, set `_mesh_inst.material_override` accent â€” but only if not flashing (the `_flash`/`_clear_flash` path sets/clears `material_override`; to avoid conflict, apply role tint as a **base** and have `_clear_flash` restore that tint instead of `null`). Store `_base_material` and make `_clear_flash` do `_mesh_inst.material_override = _base_material`.

---

## H) soldier.py CHARACTER IMPROVEMENTS (prioritized, pipeline-safe)

Keep pipeline, 7-bone rig, `KronSoldierMesh`/`ArosSoldierMesh` names, and `idle/run/attack/die` action names. **Additive only.** Priority order:

**P1 â€” New animations the AI needs** (biggest gameplay payoff; `key_pose` already keys ALL_BONES so they stay self-contained):
- `walk` â€” calm patrol gait: `LegL/R Â±16Â°`, `ArmL/R Â±12Â°`, `Spine 3Â°`, slower (frames 1/16/32). Used by PATROL/ADVANCE-slow/RETURN.
- `aim` â€” rifle-up firing stance (loop): `ArmR -55Â°`, `ArmL -35Â°`, `Spine 8Â°`, `Head -3Â°`. Used by ranged ENGAGE.
- `alert` â€” look-around (non-loop, ~1.5s): `Head` yaw sweep Â±18Â° + slight `Spine` turn. Used by GUARD/INVESTIGATE/RETURN-idle.
- Improve `idle`: add breathing/weight-shift â€” `Spine Â±1.5Â°`, `Head Â±2Â°`, `Hips Â±1Â°`, extend to ~72 frames, slower.
- In `enemy.gd`, extend the loop-mode list to `["idle","run","walk","aim"]` (already specified in G).

**P2 â€” Gear (silhouette â†’ "soldier", rides existing bones via `BONE_OF`, joins into same mesh):**
- `Backpack` box `(0.30,0.16,0.34)` on `Spine`, behind torso. `Pouches` 2Ã— small boxes on belt â†’ `Spine`. `Strap`/bandolier thin angled box across chest â†’ `Spine`. `Canteen` small cyl on hip â†’ `Spine`. Add each to `BONE_OF`, append to `parts` before the join.

**P3 â€” Proportions:** narrow torso depth `(0.46,0.26,0.60)â†’(0.42,0.24,0.58)`; add a `Shoulders` box `(0.50,0.26,0.14)` at zâ‰ˆ1.42 â†’ `Spine`; slightly smaller head `(0.21,0.22,0.23)â†’(0.19,0.20,0.22)`; boot heel taper. Helmet brim ridge for Kron WWI read.

**P4 â€” Variants (optional for v1; per-role distinction done by tint in `enemy.gd` first):** parametrize `build_soldier(faction, cfg, variant="line")` + `VARIANTS` dict; export extra `kron_marksman.glb` (longer rifle, scope cyl, no bayonet) and later `kron_officer.glb` (peaked cap). All keep mesh name `KronSoldierMesh` so `enemy.gd` is untouched; `enemy.gd` may swap the `Model` instance per role later. **For v1, ship one improved `kron_soldier.glb` + tint; defer variant GLBs.**

---

## I) IMPLEMENTATION CHECKLIST (smallest-risk first; validate headless after each)

1. **Movement smoothing only** on the *current* IDLE/CHASE/ATTACK FSM: add `_apply_movement` (accel cap) + `_apply_rotation` (turn cap) + `_request_path_to` (repath throttle), replace direct `velocity.x/z=` and `look_at`. Delete `_separation()`. â†’ instantly kills the robot feel. Validate.
2. **Avoidance**: `enemy.tscn` flags + `velocity_computed` wiring + `_safe_vel`; `_die()` gets `avoidance_enabled=false`. Confirm enemies still reach player and stop clipping. Validate.
3. **Perception rewrite**: cone + LOS cache + last-known-pos + `lose_interest_time`; `events.gd` `player_fired` signal + `weapon.gd` emit + `_on_player_fired`. Enemies stop being psychic. Validate.
4. **Role enum + expanded FSM**: GUARD/PATROL/INVESTIGATE/ENGAGE/ADVANCE/REPOSITION/RETURN/ATTACK, `_apply_role_tunables`, leash, post resolution. Keep ATTACK/`_strike`/`_ranged_strike`/`_die`. Validate.
5. **wave_manager**: `GUARD_POSTS`/`MARKSMAN_POSTS`/`PATROL_LOOPS`, `_composition`, post assignment, derive role. Validate the full match (`res://scenes/main.tscn`).
6. **soldier.py**: P1 anims first (rebuild GLB, Read preview), then P2 gear, P3 proportions. `enemy.gd` anim-select + loop list + per-role tint. Validate + visually confirm via preview render / in-game frame grab.

Validation each step: `<godot> --headless --path D:\first_game res://scenes/main.tscn --fixed-fps 60 --quit-after 1500` â†’ stderr clean (late "Pages in use at exit" from live corpses is the known harmless case); navmesh poly > 0.

---

## J) RISKS / PITFALLS

1. **Coroutine races (`await`):** keep the proven post-`await` guards in `_strike`/`_ranged_strike` (`if _state != State.ATTACK: return` + `is_instance_valid(_player)`). Add **no** new `await` in the state code â€” all delays are accumulators (`_percept_accum`, `_repath_accum`, dwell timers as `var t -= delta`). The `_die()` `await create_timer(corpse_lifetime,false)` is unchanged; add `if not is_inside_tree(): return` after it before `queue_free()` is harmless extra safety.
2. **Navmesh readiness:** preserve `map_get_iteration_id(...) == 0` guard before any `nav.target_position`/`get_next_path_position`. GUARD/idle states use local offsets only â†’ enemies behave sanely before navmesh syncs. Resolve `guard_position` **before** the `await physics_frame` so a shoved bot still knows its post.
3. **Avoidance jitter / double-integration:** when `avoidance_enabled`, *only* feed `_safe_vel` (the callback output) to `_apply_movement`; never feed raw `_desired_vel` to movement. `velocity_computed` fires once per physics frame; using last frame's `_safe_vel` (1-frame latency) is imperceptible and race-free. Stationary holders still `set_velocity(ZERO)` so they nudge apart without drifting off-post.
4. **Perf (raycast/repath storms):** vision = squared-distance + cone gate before the single LOS ray, at 5 Hz, staggered per-agent (`_percept_accum = randf()*PERCEPT_INTERVAL`). Repath throttled + staggered. Combat reuses cached LOS (one ray per shot, gated by 1.2s cooldown). Use `distance_squared_to` in hot range gates. RVO kept cheap (`max_neighbors=8`, `neighbor_distance=4`). Target: dozens of agents without spikes.
5. **`_flash` vs role tint conflict:** `_flash` sets `material_override` and `_clear_flash` currently nulls it. If role tint uses `material_override`, store `_base_material` and have `_clear_flash` restore *that*, not `null` â€” otherwise hit-flash wipes the tint permanently.
6. **`move_speed` jitter vs `nav.max_speed`:** set `nav.max_speed = move_speed` **after** applying the speed jitter, or avoidance clamps to the wrong speed.
7. **Sign of facing:** locked as `atan2(-dir.x, -dir.z)` (matches existing `look_at`). Do not "test and adjust" â€” it is correct against the current rig's -Z forward.
8. **Pause/game-over:** keep all `create_timer(..., false)` (pausable) so AI halts on game-over. RVO `set_velocity` is skipped when `_state == DEAD`; ensure `_on_player_fired`/perception early-return on DEAD.
9. **Wave back-compat:** if `_composition` ever returns fewer than `count` (clamp edge), the trailing `while ... append(ASSAULT)` guarantees exact length; `slice(0,count)` guarantees no overflow. PATROL_LOOPS/posts pop safely with modulo.

**Files to edit (absolute):** `D:\first_game\scripts\enemies\enemy.gd` (core), `D:\first_game\scenes\enemies\enemy.tscn` (avoidance flags), `D:\first_game\scripts\world\wave_manager.gd` (roster + posts), `D:\first_game\scripts\autoload\events.gd` (add `player_fired`), `D:\first_game\scripts\player\weapon.gd` (emit `player_fired` in `_shoot`), `D:\first_game\assets\blender\soldier.py` (anims + gear + proportions).
