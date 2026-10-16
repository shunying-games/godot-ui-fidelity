extends Control
## Rendering and site picking only. All game decisions remain in BattleModel.
signal site_clicked(site_id: int)
signal empty_clicked

var state: Dictionary = {}
var artwork: Dictionary = {}
var hover_site := -1
var selected_build := "ranger"
var clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	gui_input.connect(_on_gui_input)
	mouse_exited.connect(func(): hover_site = -1; queue_redraw())

func update_view(next_state: Dictionary, images: Dictionary, next_build: String, delta: float) -> void:
	state = next_state
	artwork = images
	selected_build = next_build
	clock += delta
	queue_redraw()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		hover_site = _site_at(event.position)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if hover_site >= 0 else Control.CURSOR_ARROW
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var site_id := _site_at(event.position)
		if site_id >= 0:
			site_clicked.emit(site_id)
		else:
			empty_clicked.emit()
		accept_event()

func _site_at(point: Vector2) -> int:
	if state.is_empty():
		return -1
	# The entire illustrated tower can be clicked, in addition to its stone pad.
	var towers: Array = state.get("towers", [])
	for index in range(towers.size() - 1, -1, -1):
		var tower: Dictionary = towers[index]
		if _tower_rect(tower).has_point(point):
			return int(tower["site_id"])
	for site in state.get("sites", []):
		if point.distance_to(site["position"]) <= float(site["build_radius"]):
			return int(site["id"])
	return -1

func _tower_rect(tower: Dictionary) -> Rect2:
	var height := 145.0
	var texture: Texture2D = artwork.get(str(tower["type"]))
	if texture == null:
		return Rect2()
	var width := height * texture.get_width() / float(texture.get_height())
	var anchor: Vector2 = tower["position"]
	return Rect2(anchor - Vector2(width * 0.5, height), Vector2(width, height))

func _draw() -> void:
	if artwork.is_empty() or state.is_empty():
		return
	draw_texture_rect(artwork["map"], Rect2(0, 0, 1280, 720), false)
	var selected_id := int(state.get("selected_site_id", -1))
	var selected_tower_id := int(state.get("selected_tower_id", -1))
	for tower in state["towers"]:
		if int(tower["id"]) == selected_tower_id:
			var anchor: Vector2 = tower["position"]
			var radius := float(tower["range"])
			draw_circle(anchor, radius, Color(0.28, 0.76, 0.7, 0.075))
			draw_arc(anchor, radius, 0, TAU, 96, Color(0.58, 0.88, 0.73, 0.36), 1.5, true)
	for site in state["sites"]:
		var site_id := int(site["id"])
		var center: Vector2 = site["position"]
		if site_id == selected_id or site_id == hover_site:
			var strength := 0.86 if site_id == selected_id else 0.5
			_draw_ground_ring(center, 37.0, Color(0.98, 0.79, 0.38, strength))
			if int(site["occupied_tower_id"]) < 0:
				draw_line(center - Vector2(7, 0), center + Vector2(7, 0), Color(1, 0.88, 0.55, strength), 2.0, true)
				draw_line(center - Vector2(0, 7), center + Vector2(0, 7), Color(1, 0.88, 0.55, strength), 2.0, true)
	var actors: Array[Dictionary] = []
	for tower in state["towers"]:
		actors.append({"kind": "tower", "actor": tower, "y": float(tower["position"].y)})
	for enemy in state["enemies"]:
		actors.append({"kind": "enemy", "actor": enemy, "y": float(enemy["position"].y)})
	actors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["y"] < b["y"])
	for item in actors:
		if item["kind"] == "tower":
			_draw_tower(item["actor"])
		else:
			_draw_enemy(item["actor"])
	for projectile in state["projectiles"]:
		_draw_projectile(projectile)
	var simulation_time := float(state["simulation_time"])
	for event in state["events"]:
		var elapsed := simulation_time - float(event["simulation_time"])
		if elapsed < 0 or elapsed > 0.35:
			continue
		if event["event"] == "hit" or event["event"] == "enemy_killed":
			var color := Color(1.0, 0.7, 0.3, (1.0 - elapsed / 0.35) * 0.8)
			if str(event.get("type", "")) == "frost":
				color = Color(0.45, 0.9, 1.0, color.a)
			draw_arc(event["position"], 5.0 + elapsed * 48.0, 0, TAU, 24, color, 2.0, true)

func _draw_ground_ring(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(65):
		var angle := TAU * index / 64.0
		points.append(center + Vector2(cos(angle) * radius, sin(angle) * radius * 0.56))
	draw_polyline(points, Color(color, color.a * 0.16), 8.0, true)
	draw_polyline(points, color, 1.8, true)

func _draw_tower(tower: Dictionary) -> void:
	var center: Vector2 = tower["position"]
	_draw_ground_ring(center + Vector2(0, -1), 27, Color(0.02, 0.035, 0.02, 0.28))
	var texture: Texture2D = artwork[str(tower["type"])]
	draw_texture_rect(texture, _tower_rect(tower), false)
	if int(tower["level"]) > 1:
		for level in range(int(tower["level"])):
			var x := center.x - (int(tower["level"]) - 1) * 5 + level * 10
			draw_circle(Vector2(x, center.y + 5), 3.0, Color(0.94, 0.76, 0.36))

func _draw_enemy(enemy: Dictionary) -> void:
	var center: Vector2 = enemy["position"]
	var texture: Texture2D = artwork["beetle"]
	var bob := sin(float(state["simulation_time"]) * 13 + int(enemy["id"]) * 1.7) * 1.5
	var rect := Rect2(center + Vector2(-25, -31 + bob), Vector2(50, 39.7))
	draw_circle(center + Vector2(0, 3), 16, Color(0.015, 0.02, 0.025, 0.3))
	var tint := Color(0.75, 0.9, 1.0) if float(enemy["slow_remaining"]) > 0 else Color.WHITE
	draw_texture_rect(texture, rect, false, tint)
	var health := clampf(float(enemy["health"]) / float(enemy["max_health"]), 0, 1)
	var health_rect := Rect2(center + Vector2(-18, -39), Vector2(36, 5))
	draw_style_box(_health_background(), health_rect.grow(1))
	draw_rect(health_rect, Color(0.08, 0.055, 0.04))
	draw_rect(Rect2(health_rect.position, Vector2(health_rect.size.x * health, health_rect.size.y)), Color(0.82, 0.22, 0.13))
	draw_line(health_rect.position, health_rect.position + Vector2(health_rect.size.x * health, 0), Color(1.0, 0.52, 0.31), 1)

func _health_background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.025, 0.02)
	style.set_corner_radius_all(2)
	return style

func _draw_projectile(projectile: Dictionary) -> void:
	var point: Vector2 = projectile["position"]
	var direction: Vector2 = (projectile["to"] - projectile["from"]).normalized()
	var color := Color(1, 0.81, 0.29)
	match str(projectile["type"]):
		"ember": color = Color(1, 0.39, 0.055)
		"frost": color = Color(0.36, 0.86, 1)
	draw_line(point - direction * 20, point, Color(color, 0.16), 7, true)
	draw_line(point - direction * 16, point, Color(color, 0.7), 2.6, true)
	draw_circle(point, 9.5, Color(color, 0.1))
	draw_circle(point, 5, Color(color, 0.28))
	draw_circle(point, 2.7, color)
	draw_circle(point, 1.3, Color(1, 0.97, 0.82))
