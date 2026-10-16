extends RefCounted
## Shared authoritative, deterministic Moonwell Bastion demo simulation.
## No scene-tree, rendering, input, audio, networking, or save dependencies.

signal changed(revision: int)
signal events_emitted(events: Array[Dictionary])

const STEP := 1.0 / 60.0
const TOTAL_WAVES := 8
const BUILD_COSTS := {"ranger": 80, "ember": 120, "frost": 140}
const UPGRADE_COSTS := {1: 100, 2: 160}
const TOWER_STATS := {
	"ranger": {"damage": 26.0, "range": 235.0, "interval": 0.68, "speed": 520.0},
	"ember": {"damage": 44.0, "range": 220.0, "interval": 1.08, "speed": 390.0},
	"frost": {"damage": 23.0, "range": 245.0, "interval": 0.82, "speed": 450.0},
}
const SITE_POSITIONS: Array[Vector2] = [
	Vector2(510, 206), Vector2(646, 165), Vector2(916, 140),
	Vector2(337, 411), Vector2(693, 401), Vector2(835, 422),
]
const PATH_POINTS: Array[Vector2] = [
	Vector2(90, 230), Vector2(170, 267), Vector2(260, 312),
	Vector2(385, 348), Vector2(525, 339), Vector2(650, 290),
	Vector2(715, 203), Vector2(785, 168), Vector2(850, 192),
	Vector2(848, 253), Vector2(904, 290), Vector2(990, 305),
	Vector2(1080, 252),
]

var _revision := 0
var _tick := 0
var _accumulator := 0.0
var _seed := 1729
var _gold := 360
var _crystal := 12
var _lives := 20
var _wave := 3
var _phase := "active"
var _paused := true
var _selected_site := -1
var _spawn_remaining := 0
var _spawn_timer := 0.0
var _next_enemy_id := 0
var _next_tower_id := 0
var _next_projectile_id := 0
var _next_event_id := 0
var _towers: Array[Dictionary] = []
var _enemies: Array[Dictionary] = []
var _projectiles: Array[Dictionary] = []
var _recent_events: Array[Dictionary] = []
var _path_length := 0.0

func _init() -> void:
	for index in range(1, PATH_POINTS.size()):
		_path_length += PATH_POINTS[index - 1].distance_to(PATH_POINTS[index])
	reset()

func reset(seed_value: int = 1729) -> void:
	_reset_common(seed_value)
	_wave = 3
	_phase = "active"
	_paused = true
	_spawn_remaining = _wave_size(_wave) - 3
	_spawn_timer = 0.85
	for progress in [110.0, 230.0, 360.0]:
		_spawn_enemy(progress)
	changed.emit(_revision)

func reset_ready(seed_value: int = 1729) -> void:
	## External test/fixture helper only. Normal restart returns reset()'s snapshot.
	_reset_common(seed_value)
	_wave = 2
	_phase = "ready"
	_paused = false
	changed.emit(_revision)

func _reset_common(seed_value: int) -> void:
	_revision += 1
	_tick = 0
	_accumulator = 0.0
	_seed = seed_value
	_gold = 360
	_crystal = 12
	_lives = 20
	_selected_site = -1
	_spawn_remaining = 0
	_spawn_timer = 0.0
	_next_enemy_id = 0
	_next_tower_id = 0
	_next_projectile_id = 0
	_next_event_id = 0
	_towers.clear()
	_enemies.clear()
	_projectiles.clear()
	_recent_events.clear()
	_add_tower(0, "ranger")
	_add_tower(4, "ember")

func snapshot() -> Dictionary:
	var tower_views: Array[Dictionary] = []
	var site_views: Array[Dictionary] = []
	var can_build_by_site: Dictionary = {}
	var can_upgrade_by_tower: Dictionary = {}
	for tower in _towers:
		var view: Dictionary = tower.duplicate(true)
		var stats: Dictionary = _tower_stats(tower)
		view["damage"] = stats["damage"]
		view["range"] = stats["range"]
		view["interval"] = stats["interval"]
		view["next_upgrade_cost"] = UPGRADE_COSTS.get(tower["level"], 0)
		view["can_upgrade"] = _can_modify() and int(tower["level"]) < 3 and _gold >= int(view["next_upgrade_cost"])
		tower_views.append(view)
		can_upgrade_by_tower[tower["id"]] = view["can_upgrade"]
	for site_id in range(SITE_POSITIONS.size()):
		var occupant: Dictionary = _tower_on_site(site_id)
		var tower_id: int = -1 if occupant.is_empty() else int(occupant["id"])
		site_views.append({"id": site_id, "position": SITE_POSITIONS[site_id], "build_radius": 34.0, "occupied_tower_id": tower_id})
		var options: Dictionary = {}
		for type_name in BUILD_COSTS:
			options[type_name] = _can_modify() and occupant.is_empty() and _gold >= int(BUILD_COSTS[type_name])
		can_build_by_site[site_id] = options
	var selected_tower: Dictionary = _tower_on_site(_selected_site)
	return {
		"revision": _revision, "tick": _tick, "simulation_time": _tick * STEP,
		"seed": _seed, "phase": _phase, "paused": _paused,
		"gold": _gold, "crystal": _crystal, "resources": {"gold": _gold, "crystal": _crystal},
		"lives": _lives, "wave_index": _wave, "total_waves": TOTAL_WAVES,
		"wave_alive": _enemies.size(), "wave_spawn_remaining": _spawn_remaining,
		"selected_site_id": _selected_site,
		"selected_tower_id": -1 if selected_tower.is_empty() else int(selected_tower["id"]),
		"sites": site_views, "towers": tower_views,
		"enemies": _enemies.duplicate(true), "projectiles": _projectiles.duplicate(true),
		"events": _recent_events.duplicate(true), "path": PATH_POINTS.duplicate(), "path_length": _path_length,
		"build_costs": BUILD_COSTS.duplicate(), "upgrade_costs": UPGRADE_COSTS.duplicate(),
		"available_actions": {"can_start": _can_start(), "can_build_by_site": can_build_by_site, "can_upgrade_by_tower": can_upgrade_by_tower},
	}.duplicate(true)

func dispatch(command: Dictionary) -> Dictionary:
	var command_type: String = str(command.get("type", ""))
	var events: Array[Dictionary] = []
	match command_type:
		"restart":
			reset(_seed)
			return _result(true)
		"set_paused":
			if not command.get("paused") is bool:
				return _result(false, "invalid_pause_value")
			var next_paused: bool = command["paused"]
			if _paused == next_paused:
				return _result(true)
			_paused = next_paused
			_event(events, "pause_changed", {"paused": _paused})
		"select_site":
			var site_id := int(command.get("site_id", -1))
			if site_id < 0 or site_id >= SITE_POSITIONS.size():
				return _result(false, "unknown_site")
			if _selected_site == site_id:
				return _result(true)
			_selected_site = site_id
		"clear_selection":
			if _selected_site == -1:
				return _result(true)
			_selected_site = -1
		"start_wave":
			if _paused:
				return _result(false, "paused")
			if not _can_start():
				return _result(false, "wave_unavailable")
			_wave += 1
			_phase = "active"
			_spawn_remaining = _wave_size(_wave)
			_spawn_timer = 0.0
			_event(events, "wave_started", {"wave_index": _wave})
		"build":
			if not _can_modify():
				return _result(false, "paused" if _paused else "game_over")
			var site_id := int(command.get("site_id", -1))
			var tower_type: String = str(command.get("tower_type", ""))
			if site_id < 0 or site_id >= SITE_POSITIONS.size():
				return _result(false, "unknown_site")
			if not BUILD_COSTS.has(tower_type):
				return _result(false, "unknown_tower_type")
			if not _tower_on_site(site_id).is_empty():
				return _result(false, "occupied")
			if _gold < int(BUILD_COSTS[tower_type]):
				return _result(false, "insufficient_gold")
			_gold -= int(BUILD_COSTS[tower_type])
			var tower: Dictionary = _add_tower(site_id, tower_type)
			_selected_site = site_id
			_event(events, "tower_built", {"tower_id": tower["id"], "site_id": site_id, "tower_type": tower_type})
		"upgrade":
			if not _can_modify():
				return _result(false, "paused" if _paused else "game_over")
			var tower_id := int(command.get("tower_id", -1))
			var tower: Dictionary = _tower_by_id(tower_id)
			if tower.is_empty():
				return _result(false, "unknown_tower")
			var level: int = tower["level"]
			if level >= 3:
				return _result(false, "maximum_level")
			var cost: int = UPGRADE_COSTS[level]
			if _gold < cost:
				return _result(false, "insufficient_gold")
			_gold -= cost
			tower["level"] = level + 1
			_selected_site = tower["site_id"]
			_event(events, "tower_upgraded", {"tower_id": tower_id, "level": level + 1})
		_:
			return _result(false, "unknown_command")
	_revision += 1
	_publish(events)
	return _result(true)

func advance(delta_seconds: float) -> void:
	if _paused or _phase != "active" or not is_finite(delta_seconds) or delta_seconds <= 0.0:
		return
	_accumulator += delta_seconds
	var events: Array[Dictionary] = []
	var advanced := false
	while _accumulator + 0.000000001 >= STEP and _phase == "active":
		_accumulator -= STEP
		_step(events)
		advanced = true
	if _phase != "active":
		_accumulator = 0.0
	if advanced:
		_publish(events)

func _step(events: Array[Dictionary]) -> void:
	_tick += 1
	_revision += 1
	_spawn_timer -= STEP
	while _spawn_remaining > 0 and _spawn_timer <= 0.0:
		var enemy: Dictionary = _spawn_enemy(0.0)
		_spawn_remaining -= 1
		_spawn_timer += maxf(0.48, 1.0 - _wave * 0.045)
		_event(events, "enemy_spawned", {"enemy_id": enemy["id"]})
	for enemy in _enemies.duplicate():
		var slow_factor := 0.68 if float(enemy["slow_remaining"]) > 0.0 else 1.0
		enemy["path_progress"] = float(enemy["path_progress"]) + float(enemy["speed"]) * slow_factor * STEP
		enemy["position"] = path_position(enemy["path_progress"])
		enemy["slow_remaining"] = maxf(0.0, float(enemy["slow_remaining"]) - STEP)
		if float(enemy["path_progress"]) >= _path_length:
			_enemies.erase(enemy)
			_lives = maxi(0, _lives - 1)
			_event(events, "enemy_leaked", {"enemy_id": enemy["id"], "position": PATH_POINTS.back()})
			if _lives <= 0:
				_phase = "lost"
				_projectiles.clear()
				_event(events, "game_lost", {})
				return
	for tower in _towers:
		tower["cooldown"] = maxf(0.0, float(tower["cooldown"]) - STEP)
		if float(tower["cooldown"]) > 0.0:
			continue
		var stats: Dictionary = _tower_stats(tower)
		var target: Dictionary = _target_for(tower["position"], stats["range"])
		if target.is_empty():
			continue
		var projectile: Dictionary = {
			"id": _next_projectile_id, "tower_id": tower["id"], "target_id": target["id"],
			"type": tower["type"], "position": tower["position"], "from": tower["position"],
			"to": target["position"], "speed": stats["speed"], "damage": stats["damage"], "start_time": _tick * STEP,
		}
		_next_projectile_id += 1
		_projectiles.append(projectile)
		tower["cooldown"] = stats["interval"]
		_event(events, "shot", projectile.duplicate(true))
	for projectile in _projectiles.duplicate():
		var target: Dictionary = _enemy_by_id(projectile["target_id"])
		if target.is_empty():
			_projectiles.erase(projectile)
			continue
		projectile["to"] = target["position"]
		var remaining: float = Vector2(projectile["position"]).distance_to(target["position"])
		var travel: float = float(projectile["speed"]) * STEP
		if remaining > travel:
			projectile["position"] = Vector2(projectile["position"]).move_toward(target["position"], travel)
			continue
		_projectiles.erase(projectile)
		target["health"] = maxf(0.0, float(target["health"]) - float(projectile["damage"]))
		if projectile["type"] == "frost":
			target["slow_remaining"] = 1.1
		_event(events, "hit", {"enemy_id": target["id"], "position": target["position"], "type": projectile["type"]})
		if float(target["health"]) <= 0.0:
			_enemies.erase(target)
			var reward: int = 10 + _wave * 2
			_gold += reward
			_event(events, "enemy_killed", {"enemy_id": target["id"], "position": target["position"], "gold": reward})
	if _spawn_remaining == 0 and _enemies.is_empty():
		_projectiles.clear()
		_gold += 25 + _wave * 5
		_crystal += 1
		_phase = "won" if _wave >= TOTAL_WAVES else "ready"
		_event(events, "game_won" if _phase == "won" else "wave_cleared", {"wave_index": _wave})
	while not _recent_events.is_empty() and _tick - int(_recent_events[0]["tick"]) > 48:
		_recent_events.pop_front()

func path_position(progress: float) -> Vector2:
	var remaining := maxf(0.0, progress)
	for index in range(1, PATH_POINTS.size()):
		var start: Vector2 = PATH_POINTS[index - 1]
		var end: Vector2 = PATH_POINTS[index]
		var length := start.distance_to(end)
		if remaining <= length:
			return start.lerp(end, remaining / length)
		remaining -= length
	return PATH_POINTS.back()

func _spawn_enemy(progress: float) -> Dictionary:
	var health := 70.0 + _wave * 16.0
	var enemy: Dictionary = {
		"id": _next_enemy_id, "type": "beetle", "path_progress": progress,
		"position": path_position(progress), "health": health, "max_health": health,
		"speed": 42.0 + _wave * 2.0, "slow_remaining": 0.0,
	}
	_next_enemy_id += 1
	_enemies.append(enemy)
	return enemy

func _add_tower(site_id: int, tower_type: String) -> Dictionary:
	var tower: Dictionary = {"id": _next_tower_id, "site_id": site_id, "type": tower_type, "level": 1, "position": SITE_POSITIONS[site_id], "cooldown": 0.0}
	_next_tower_id += 1
	_towers.append(tower)
	return tower

func _tower_stats(tower: Dictionary) -> Dictionary:
	var stats: Dictionary = TOWER_STATS[tower["type"]].duplicate()
	var extra_level: int = int(tower["level"]) - 1
	stats["damage"] = float(stats["damage"]) * (1.0 + extra_level * 0.65)
	stats["range"] = float(stats["range"]) + extra_level * 14.0
	stats["interval"] = float(stats["interval"]) / (1.0 + extra_level * 0.1)
	return stats

func _tower_on_site(site_id: int) -> Dictionary:
	for tower in _towers:
		if int(tower["site_id"]) == site_id:
			return tower
	return {}

func _tower_by_id(tower_id: int) -> Dictionary:
	for tower in _towers:
		if int(tower["id"]) == tower_id:
			return tower
	return {}

func _enemy_by_id(enemy_id: int) -> Dictionary:
	for enemy in _enemies:
		if int(enemy["id"]) == enemy_id:
			return enemy
	return {}

func _target_for(position: Vector2, attack_range: float) -> Dictionary:
	var target: Dictionary = {}
	var furthest := -1.0
	for enemy in _enemies:
		if position.distance_to(enemy["position"]) <= attack_range and float(enemy["path_progress"]) > furthest:
			target = enemy
			furthest = enemy["path_progress"]
	return target

func _wave_size(wave: int) -> int:
	return 4 + wave * 2

func _can_modify() -> bool:
	return not _paused and (_phase == "active" or _phase == "ready")

func _can_start() -> bool:
	return not _paused and _phase == "ready" and _wave < TOTAL_WAVES

func _result(ok: bool, reason: String = "") -> Dictionary:
	return {"ok": ok, "reason": reason, "revision": _revision}

func _event(events: Array[Dictionary], event_type: String, data: Dictionary) -> void:
	var event: Dictionary = data.duplicate(true)
	event["event_id"] = _next_event_id
	event["event"] = event_type
	event["tick"] = _tick
	event["simulation_time"] = _tick * STEP
	_next_event_id += 1
	events.append(event)
	_recent_events.append(event.duplicate(true))

func _publish(events: Array[Dictionary]) -> void:
	if not events.is_empty():
		events_emitted.emit(events.duplicate(true))
	changed.emit(_revision)
