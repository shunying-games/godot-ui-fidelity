# Frozen shared battle model API

Godot 4.6.3. `battle_model.gd` extends `RefCounted`, with no `class_name` or external dependency. Example:

```gdscript
const BattleModel = preload("res://battle_model.gd")
var model = BattleModel.new()

func _process(delta: float) -> void:
    model.advance(delta)
    var state: Dictionary = model.snapshot()

# Native button callback:
func resume_battle() -> void:
    model.dispatch({"type": "set_paused", "paused": false})
```

## Initial state and methods

`.new()` and the normal `restart` command produce a real paused-active wave-3 fixture: gold 360, crystal 12, lives 20, wave 3/8, ranger on site 0, ember on site 4, three beetles at progress 110/230/360 pixels, seven remaining spawns, selection -1. All positions use the complete 1280 × 720 design canvas. Preserve their common transform when scaling to 960 × 540.

The generated concept's pause glyph is overridden by the real paused state: display an appropriate native resume action. A full-screen pause overlay is optional; do not hide the required initial battle composition. Next-wave remains unavailable while the current wave is active, including when paused. Selection is allowed while paused. Build, upgrade, and start are rejected while paused.

| Method/signal | Contract |
| --- | --- |
| `snapshot() -> Dictionary` | Deep copy; changes to it cannot mutate the model. Read this to render all dynamic state. |
| `dispatch(command: Dictionary) -> Dictionary` | `{ok: bool, reason: String, revision: int}`. Rejections do not change state. Repeated same pause/selection commands are successful no-ops. |
| `advance(delta_seconds: float) -> void` | Real simulation time. Internally fixed 1/60 s; paused, terminal, nonpositive, or nonfinite input does not advance gameplay. Call once per frame. |
| `reset(seed_value: int = 1729) -> void` | Restore initial paused-active fixture. Seed is recorded; this small simulation uses no random choices. |
| `reset_ready(seed_value: int = 1729) -> void` | External test/fixture helper: gold360/crystal12/lives20, same two towers, wave2 ready/unpaused, no enemies. Do not substitute this for normal initial rendering or restart. |
| `path_position(progress: float) -> Vector2` | Position by distance along the frozen path, clamped to endpoints. |
| `changed(revision: int)` | Emitted after a real command mutation/reset or an `advance` that executes ticks. |
| `events_emitted(events: Array[Dictionary])` | Actual shot/hit/kill/spawn/leak/wave/action events produced by the command or advance. Rendering-only feedback can listen here. |

`revision` is monotonic across reset; `tick`, actor IDs, event IDs, selection and gameplay time reset. Rendering may use a separate UI clock for a glow/pulse, but must not advance enemy, projectile, combat, spawn, resource, or gameplay effect state while paused.

## Commands

Every command has `type: String`:

| Type | Additional keys | Behavior |
| --- | --- | --- |
| `set_paused` | `paused: bool` | Explicit pause/resume. |
| `select_site` | `site_id: int` | Select a valid occupied or empty site, including while paused. |
| `clear_selection` | none | Clear site/tower selection. |
| `start_wave` | none | Only ready, unpaused, below wave8: increment wave and begin real spawning. |
| `build` | `site_id: int`, `tower_type: String` | Types `ranger`80 / `ember`120 / `frost`140 gold. Atomic validation, debit, creation, and selection. |
| `upgrade` | `tower_id: int` | Level1→2 costs100; level2→3 costs160. Real damage/range/rate improve; level3 maximum. |
| `restart` | none | Restore the initial paused-active fixture from any phase. |

Build/upgrade are valid in ready or active phases while unpaused. Reasons include `paused`, `game_over`, `wave_unavailable`, `unknown_site`, `unknown_tower_type`, `occupied`, `insufficient_gold`, `unknown_tower`, `maximum_level`, `invalid_pause_value`, and `unknown_command`. An `ok` response has an empty reason. IDs are integers; tower IDs are independent of site IDs (the initial site4 ember has tower ID1).

## Snapshot exact fields

| Fields | Type / interpretation |
| --- | --- |
| `revision`, `tick`, `seed` | `int`; gameplay ticks at60 Hz. |
| `simulation_time` | `float` seconds, derived from tick. |
| `phase`, `paused` | `String`: `ready`, `active`, `won`, `lost`; `bool`. |
| `gold`, `crystal`, `lives` | `int`. Gold is spent/rewarded; crystal increases after wave clear; leaks spend lives. |
| `resources` | `Dictionary {gold:int, crystal:int}` convenience copy of the same authoritative values. |
| `wave_index`, `total_waves`, `wave_alive`, `wave_spawn_remaining` | `int`; current/last wave,8, living enemy count, remaining scheduled spawns. |
| `selected_site_id`, `selected_tower_id` | `int`; -1 when none/empty. |
| `sites` | `Array[Dictionary]`: `{id:int, position:Vector2, build_radius:float, occupied_tower_id:int}`. Radius34 in design pixels; occupied tower ID is -1 if empty. |
| `towers` | `Array[Dictionary]`: `{id:int, site_id:int, type:String, level:int, position:Vector2, cooldown:float, damage:float, range:float, interval:float, next_upgrade_cost:int, can_upgrade:bool}`. Cost0 and `can_upgrade=false` at maximum. |
| `enemies` | `Array[Dictionary]`: `{id:int, type:String, path_progress:float, position:Vector2, health:float, max_health:float, speed:float, slow_remaining:float}`. Type `beetle`; speed is base design pixels/second. Frost hits apply a real temporary slow. |
| `projectiles` | `Array[Dictionary]`: `{id:int, tower_id:int, target_id:int, type:String, position:Vector2, from:Vector2, to:Vector2, speed:float, damage:float, start_time:float}`. Position/target movement and hit damage belong to the model. |
| `events` | `Array[Dictionary]` of recent actual events (roughly0.8 simulation seconds). Every record has `event:String`, `event_id:int`, `tick:int`, `simulation_time:float`, plus type-specific fields below. |
| `path`, `path_length` | `Array[Vector2]`, `float` total design pixels. |
| `build_costs`, `upgrade_costs` | `Dictionary {ranger:80, ember:120, frost:140}`, `Dictionary {1:100, 2:160}`. |
| `available_actions` | `Dictionary {can_start:bool, can_build_by_site:Dictionary, can_upgrade_by_tower:Dictionary}`. |

Availability dictionaries use integer ID keys: `can_build_by_site[site_id][tower_type] -> bool`; `can_upgrade_by_tower[tower_id] -> bool`. Use them for native disabled states. A selected paused site can show context and prices while its purchase actions stay disabled.

Events: `shot` includes the projectile record; `hit` has enemy_id/position/type; `enemy_killed` has enemy_id/position/gold; `enemy_spawned` has enemy_id; `enemy_leaked` has enemy_id/position; `tower_built` has tower_id/site_id/tower_type; `tower_upgraded` has tower_id/level; `wave_started`, `wave_cleared`, `game_won` have wave_index; `game_lost` has only common keys; `pause_changed` has paused.

The model auto-targets the furthest-progress living enemy in range, shoots real moving projectiles, applies hits, rewards kills, leaks at the endpoint, clears waves, and stops at won/lost. The UI chooses visuals; it must not duplicate those decisions or fabricate decorative enemies/shots as gameplay evidence.
