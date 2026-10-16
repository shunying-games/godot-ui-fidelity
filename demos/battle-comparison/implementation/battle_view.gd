extends Node2D

const MAP = preload("res://assets/map.webp")
const BEETLE = preload("res://assets/beetle.png")
const ACTORS = {
	"ranger": preload("res://assets/ranger.png"),
	"ember": preload("res://assets/ember.png"),
	"frost": preload("res://assets/frost.png"),
}
const TYPE_COLORS = {
	"ranger": Color("d9c77a"),
	"ember": Color("ff9e35"),
	"frost": Color("81e6fb"),
}
var state: Dictionary = {}
var hover_site := -1

func _draw() -> void:
	draw_texture_rect(MAP, Rect2(0, 0, 1280, 720), false)
	if state.is_empty():
		return
	var selected_id: int = state["selected_site_id"]
	var selected_tower: Dictionary = {}
	for tower in state["towers"]:
		if int(tower["site_id"]) == selected_id:
			selected_tower = tower
	if not selected_tower.is_empty():
		var tint: Color = TYPE_COLORS[selected_tower["type"]]
		draw_circle(selected_tower["position"], float(selected_tower["range"]), Color(tint, 0.035))
		draw_arc(selected_tower["position"], float(selected_tower["range"]), 0, TAU, 100, Color(tint, 0.27), 1.0, true)
	for site in state["sites"]:
		var site_id: int = site["id"]
		if site_id == selected_id or site_id == hover_site:
			var tint := Color("ebcd87") if site_id == selected_id else Color("a9d5cf")
			_ellipse(site["position"], Vector2(40, 25), Color(0.03, 0.08, 0.07, 0.4), 7.0)
			_ellipse(site["position"], Vector2(39, 24), Color(tint, 0.94), 2.0)
			_ellipse(site["position"], Vector2(34, 20), Color(tint, 0.32), 1.0)
			if int(site["occupied_tower_id"]) < 0:
				draw_line(site["position"] - Vector2(7, 0), site["position"] + Vector2(7, 0), tint, 1.5, true)
				draw_line(site["position"] - Vector2(0, 6), site["position"] + Vector2(0, 6), tint, 1.5, true)
	var actors: Array[Dictionary] = []
	for tower in state["towers"]:
		actors.append({"kind": "tower", "data": tower, "y": tower["position"].y})
	for enemy in state["enemies"]:
		actors.append({"kind": "enemy", "data": enemy, "y": enemy["position"].y})
	actors.sort_custom(func(a: Dictionary, b: Dictionary): return float(a["y"]) < float(b["y"]))
	for actor in actors:
		if actor["kind"] == "tower":
			_draw_tower(actor["data"])
		else:
			_draw_enemy(actor["data"])
	for projectile in state["projectiles"]:
		_draw_projectile(projectile)
	for effect in state["events"]:
		if str(effect["event"]) == "hit":
			var age: float = float(state["simulation_time"]) - float(effect["simulation_time"])
			if age >= 0.0 and age <= 0.25:
				var color: Color = TYPE_COLORS.get(effect.get("type", "ranger"), TYPE_COLORS["ranger"])
				var alpha := 1.0 - age / 0.25
				draw_arc(effect["position"], 5.0 + age * 54.0, 0, TAU, 22, Color(color, alpha * 0.8), 1.6, true)

func _draw_tower(tower: Dictionary) -> void:
	var texture: Texture2D = ACTORS[tower["type"]]
	var height: float = minf(144.0, float(tower["position"].y) - 56.0)
	var width := height * float(texture.get_width()) / float(texture.get_height())
	var ground: Vector2 = tower["position"]
	_ellipse(ground + Vector2(0, -1), Vector2(30, 11), Color(0.005, 0.01, 0.01, 0.55), 13.0)
	draw_texture_rect(texture, Rect2(ground - Vector2(width * 0.5, height), Vector2(width, height)), false)
	if int(tower["level"]) > 1:
		for index in range(int(tower["level"])):
			var center := ground + Vector2((index - (int(tower["level"]) - 1) * 0.5) * 8, 5)
			draw_colored_polygon(PackedVector2Array([center + Vector2(0, -3), center + Vector2(3, 0), center + Vector2(0, 3), center + Vector2(-3, 0)]), Color("f8d894"))

func _draw_enemy(enemy: Dictionary) -> void:
	var center: Vector2 = enemy["position"]
	_ellipse(center + Vector2(0, 9), Vector2(19, 6), Color(0.005, 0.01, 0.01, 0.6), 8.0)
	var tint := Color(0.72, 0.94, 1.1) if float(enemy["slow_remaining"]) > 0.0 else Color.WHITE
	draw_texture_rect(BEETLE, Rect2(center - Vector2(24, 21), Vector2(48, 38.1)), false, tint)
	var bar_position := center - Vector2(19, 28)
	draw_style_box(_health_background(), Rect2(bar_position, Vector2(38, 6)))
	draw_rect(Rect2(bar_position + Vector2.ONE, Vector2(36.0 * clampf(float(enemy["health"]) / float(enemy["max_health"]), 0, 1), 4)), Color("b84438"))
	draw_line(bar_position + Vector2(1, 1), bar_position + Vector2(36.0 * clampf(float(enemy["health"]) / float(enemy["max_health"]), 0, 1), 1), Color("eb8c62"), 1)

var health_box: StyleBoxFlat
func _health_background() -> StyleBoxFlat:
	if health_box == null:
		health_box = StyleBoxFlat.new()
		health_box.bg_color = Color(0.01, 0.015, 0.02, 0.95)
		health_box.border_color = Color(0.02, 0.025, 0.02)
		health_box.set_border_width_all(1)
		health_box.set_corner_radius_all(1)
	return health_box

func _draw_projectile(projectile: Dictionary) -> void:
	var point: Vector2 = projectile["position"]
	var direction: Vector2 = (projectile["to"] - point).normalized()
	var color: Color = TYPE_COLORS[projectile["type"]]
	var tail := point - direction * 22.0
	draw_line(tail, point, Color(color, 0.12), 8.0, true)
	draw_line(tail + direction * 6.0, point, Color(color, 0.45), 3.0, true)
	if projectile["type"] == "ranger":
		draw_line(tail, point, color, 1.3, true)
		var normal := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([point + direction * 5, point - direction * 4 + normal * 2.5, point - direction * 4 - normal * 2.5]), Color("fff0bc"))
	elif projectile["type"] == "ember":
		draw_circle(point, 7, Color(color, 0.16))
		draw_circle(point, 4, color)
		draw_circle(point, 2, Color("fff3bd"))
	else:
		var normal := direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([point + direction * 6, point + normal * 3, point - direction * 5, point - normal * 3]), Color("b6f5ff"))

func _ellipse(center: Vector2, radius: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in range(65):
		var angle := TAU * index / 64.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_polyline(points, color, width, true)
