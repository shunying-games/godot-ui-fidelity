extends Control
var kind := "coin"
var tint := Color.WHITE

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size * 0.5
	match kind:
		"coin":
			draw_circle(c + Vector2(0, 1), s * 0.47, Color(0.12, 0.07, 0.02, 0.8))
			draw_circle(c, s * 0.46, Color(0.65, 0.34, 0.06) * tint)
			draw_circle(c, s * 0.38, Color(0.96, 0.71, 0.19) * tint)
			draw_arc(c, s * 0.34, 0, TAU, 36, Color(1, 0.89, 0.45) * tint, 1.2, true)
			draw_line(c + Vector2(-s * 0.07, -s * 0.23), c + Vector2(-s * 0.07, s * 0.23), Color(1, 0.9, 0.5) * tint, 1.5, true)
			draw_line(c + Vector2(s * 0.08, -s * 0.23), c + Vector2(s * 0.08, s * 0.23), Color(0.64, 0.34, 0.04) * tint, 1.4, true)
			draw_arc(c - Vector2(s * 0.03, s * 0.02), s * 0.41, 3.5, 5.5, 16, Color(1, 0.96, 0.67) * tint, 1.6, true)
		"crystal":
			var points := PackedVector2Array([Vector2(0, -0.48), Vector2(0.35, -0.18), Vector2(0.29, 0.27), Vector2(0, 0.49), Vector2(-0.29, 0.27), Vector2(-0.35, -0.18)])
			for index in range(points.size()): points[index] = c + points[index] * s
			draw_colored_polygon(points, Color(0.07, 0.65, 0.79) * tint)
			draw_colored_polygon(PackedVector2Array([points[0], points[1], c, points[5]]), Color(0.32, 0.91, 1) * tint)
			draw_colored_polygon(PackedVector2Array([points[0], c, points[3], points[4], points[5]]), Color(0.18, 0.74, 0.87) * tint)
			draw_line(points[0], points[3], Color(0.81, 1, 1) * tint, 1.3, true)
			draw_polyline(points + PackedVector2Array([points[0]]), Color(0.67, 0.98, 1) * tint, 1.2, true)
		"shield":
			var points := PackedVector2Array([c + Vector2(0, -s * 0.45), c + Vector2(s * 0.35, -s * 0.28), c + Vector2(s * 0.25, s * 0.17), c + Vector2(0, s * 0.47), c + Vector2(-s * 0.25, s * 0.17), c + Vector2(-s * 0.35, -s * 0.28)])
			draw_colored_polygon(points, Color(0.67, 0.73, 0.72))
			for index in range(points.size()): points[index] = c + (points[index] - c) * 0.72
			draw_colored_polygon(points, Color(0.18, 0.23, 0.23))
			draw_line(c + Vector2(0, -s * 0.22), c + Vector2(0, s * 0.22), Color(0.88, 0.9, 0.82), 2.4, true)
			draw_line(c + Vector2(-s * 0.12, -s * 0.04), c + Vector2(s * 0.12, -s * 0.04), Color(0.88, 0.9, 0.82), 2.4, true)
		"lantern":
			for index in range(4, 0, -1): draw_circle(c, s * (0.2 + index * 0.075), Color(1, 0.48, 0.075, 0.035))
			draw_arc(c + Vector2(0, -s * 0.25), s * 0.13, PI, TAU, 16, Color(0.73, 0.53, 0.25), 2, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -s * 0.32), c + Vector2(s * 0.23, -s * 0.13), c + Vector2(-s * 0.23, -s * 0.13)]), Color(0.51, 0.3, 0.12))
			draw_rect(Rect2(c + Vector2(-s * 0.15, -s * 0.13), Vector2(s * 0.3, s * 0.43)), Color(0.96, 0.55, 0.1))
			draw_rect(Rect2(c + Vector2(-s * 0.075, -s * 0.09), Vector2(s * 0.15, s * 0.32)), Color(1, 0.84, 0.3))
			for x in [-0.17, 0.17]: draw_line(c + Vector2(s * x, -s * 0.14), c + Vector2(s * x, s * 0.31), Color(0.35, 0.22, 0.1), 2.5, true)
			draw_line(c + Vector2(-s * 0.24, s * 0.32), c + Vector2(s * 0.24, s * 0.32), Color(0.61, 0.41, 0.17), 3.5, true)
		"chevron":
			draw_polyline(PackedVector2Array([c + Vector2(-s * 0.15, -s * 0.3), c + Vector2(s * 0.12, 0), c + Vector2(-s * 0.15, s * 0.3)]), tint, 4, true)
