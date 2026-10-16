extends Control

var kind := "coin"
var progress_value := 0.0

func _draw() -> void:
	var s := size
	var center := s * 0.5
	match kind:
		"coin":
			var radius := minf(s.x, s.y) * 0.44
			draw_circle(center + Vector2(0, 1), radius + 1.1, Color("54360c"))
			draw_circle(center, radius, Color("c58b1b"))
			draw_circle(center + Vector2(-0.7, -0.6), radius - 1.8, Color("f0bd40"))
			draw_arc(center, radius - 2.8, 0, TAU, 28, Color("fff0a0"), 1.0, true)
			var r := radius * 0.49
			draw_colored_polygon(PackedVector2Array([center + Vector2(-r * 0.6, -r), center + Vector2(r * 0.55, -r * 0.35), center + Vector2(r * 0.5, r * 0.7), center + Vector2(-r * 0.6, r)]), Color("ffe8a0"))
			draw_line(center + Vector2(-r * 0.9, -r * 0.7), center + Vector2(r * 0.6, r * 0.8), Color("d89a28"), 1, true)
		"crystal":
			var polygon := PackedVector2Array([Vector2(s.x * 0.49, 1), Vector2(s.x * 0.9, s.y * 0.32), Vector2(s.x * 0.88, s.y * 0.72), Vector2(s.x * 0.49, s.y - 1), Vector2(s.x * 0.1, s.y * 0.72), Vector2(s.x * 0.1, s.y * 0.33)])
			draw_colored_polygon(polygon, Color("4ed6eb"))
			draw_colored_polygon(PackedVector2Array([polygon[0], polygon[1], center, polygon[5]]), Color("a8f6ff"))
			draw_colored_polygon(PackedVector2Array([center, polygon[1], polygon[2], polygon[3]]), Color("24a6c0"))
			draw_line(polygon[0], polygon[3], Color("ddfeff"), 1.3, true)
			draw_line(polygon[0], polygon[5], Color("e2ffff"), 1, true)
		"shield":
			var points := PackedVector2Array([Vector2(s.x * 0.5, 1), Vector2(s.x * 0.67, s.y * 0.15), Vector2(s.x * 0.95, s.y * 0.18), Vector2(s.x * 0.86, s.y * 0.65), Vector2(s.x * 0.5, s.y - 1), Vector2(s.x * 0.15, s.y * 0.65), Vector2(s.x * 0.05, s.y * 0.18), Vector2(s.x * 0.33, s.y * 0.15), Vector2(s.x * 0.5, 1)])
			draw_colored_polygon(points, Color("c7d0ca"))
			for index in range(points.size()):
				points[index] = center + (points[index] - center) * 0.71
			draw_colored_polygon(points, Color("39454a"))
			draw_line(center + Vector2(0, -7), center + Vector2(0, 7), Color("e2e6dc"), 2, true)
			draw_line(center + Vector2(-5, -2), center + Vector2(5, -2), Color("e2e6dc"), 2, true)
		"resume":
			draw_colored_polygon(PackedVector2Array([Vector2(s.x * 0.29, s.y * 0.12), Vector2(s.x * 0.81, s.y * 0.5), Vector2(s.x * 0.29, s.y * 0.89)]), Color("f2dfb7"))
		"pause":
			draw_rect(Rect2(s.x * 0.21, s.y * 0.13, s.x * 0.2, s.y * 0.74), Color("f2dfb7"))
			draw_rect(Rect2(s.x * 0.59, s.y * 0.13, s.x * 0.2, s.y * 0.74), Color("f2dfb7"))
		"chevron":
			draw_colored_polygon(PackedVector2Array([Vector2(1, 0), Vector2(s.x, s.y * 0.5), Vector2(1, s.y), Vector2(s.x * 0.32, s.y * 0.5)]), Color("ffeac1"))
		"wave_progress":
			draw_style_box(_pill(Color("283837")), Rect2(Vector2.ZERO, s))
			draw_style_box(_pill(Color("97d9de")), Rect2(Vector2.ZERO, Vector2(s.x * clampf(progress_value, 0.0, 1.0), s.y)))
		"lantern":
			var glow := Color(1.0, 0.57, 0.12, 0.09)
			draw_circle(center, 19, glow)
			draw_circle(center, 13, glow)
			draw_arc(Vector2(center.x, 7), 5, PI, TAU, 15, Color("b59a64"), 2, true)
			draw_colored_polygon(PackedVector2Array([Vector2(center.x - 10, 14), Vector2(center.x, 7), Vector2(center.x + 10, 14)]), Color("b68b45"))
			draw_style_box(_pill(Color("5e3b12")), Rect2(center.x - 9, 14, 18, 24))
			draw_rect(Rect2(center.x - 5, 17, 10, 16), Color("ffc846"))
			draw_rect(Rect2(center.x - 2, 19, 4, 12), Color("fff6ab"))
			draw_line(Vector2(center.x, 14), Vector2(center.x, 36), Color("a47b35"), 1.5, true)
			draw_rect(Rect2(center.x - 10, 36, 20, 3), Color("c7a05a"))
		"laurel_left", "laurel_right":
			var mirrored := kind == "laurel_right"
			var branch := PackedVector2Array()
			for index in range(22):
				var t := index / 21.0
				var point := Vector2(13 + 40 * t * t, 4 + 92 * t)
				if mirrored:
					point.x = s.x - point.x
				branch.append(point)
			draw_polyline(branch, Color("6e5933"), 2, true)
			for index in range(7):
				var t := (index + 1) / 8.0
				var origin := Vector2(13 + 40 * t * t, 4 + 92 * t)
				var leaf := PackedVector2Array([origin, origin + Vector2(-18, -22), origin + Vector2(-16, -9), origin + Vector2(-8, 0)])
				if mirrored:
					for p in range(leaf.size()):
						leaf[p].x = s.x - leaf[p].x
				draw_colored_polygon(leaf, Color("5f4b29"))
				leaf.append(leaf[0])
				draw_polyline(leaf, Color("907143"), 0.8, true)

var pill: StyleBoxFlat
func _pill(color: Color) -> StyleBoxFlat:
	# Separate persistent style resources are required for deferred drawing.
	var key := color.to_html()
	if not _pill_styles.has(key):
		var style := StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(3)
		_pill_styles[key] = style
	return _pill_styles[key]

var _pill_styles: Dictionary = {}
