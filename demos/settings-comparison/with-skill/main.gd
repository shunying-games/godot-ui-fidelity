extends Control

# Mosslight Atelier: native controls over an original, vector-drawn workshop.
const SettingsModel = preload("res://settings_model.gd")
var model = SettingsModel.new()

const INK := Color("243d3b")
const MUTED := Color("68766a")
const PAPER := Color("f2ead6")
const SAGE := Color("4e6e55")
const BRASS := Color("ac8145")

var modal_layer: Control
var card: Panel
var header: Control
var heading: Label
var eyebrow: Label
var supporting: Label
var close_button: Button
var scroll: ScrollContainer
var body: Control
var audio_heading: Label
var access_heading: Label
var music_label: Label
var sfx_label: Label
var music_value: Label
var sfx_value: Label
var music_slider: HSlider
var sfx_slider: HSlider
var motion_toggle: CheckButton
var motion_label: Label
var motion_note: Label
var language_label: Label
var language_select: OptionButton
var audio_panel: Panel
var access_panel: Panel
var footer: Control
var footer_rule: ColorRect
var apply_button: Button
var cancel_button: Button
var footer_note: Label
var prefs_toggle: Button
var brew_button: Button
var brew_count: Label
var world_title: Label
var world_subtitle: Label
var world_status: Label
var world: Workshop
var _syncing := false
var _layout_pending := false

class Workshop extends Control:
	var _draw_styles: Dictionary = {}
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		var w := size.x
		var h := size.y
		draw_rect(Rect2(Vector2.ZERO, size), Color("102a30"))
		# Broad, quiet pools of moonlight across the plaster.
		for i in range(18):
			var t := float(i) / 18.0
			draw_circle(Vector2(w * 0.75, h * 0.25), 90.0 + t * maxf(w, h) * 0.65, Color(0.16, 0.32, 0.34, 0.012))
		var floor_y := h * 0.76
		draw_rect(Rect2(0, floor_y, w, h - floor_y), Color("142e31"))
		for i in range(8):
			var y := floor_y + float(i) * 38.0
			draw_line(Vector2(0, y), Vector2(w, y), Color(0.34, 0.44, 0.39, 0.1), 1.0)
		# Tall arched window: measured native vectors, always behind input.
		var win := Rect2(w * 0.71, h * 0.14, minf(w * 0.21, 245.0), h * 0.41)
		draw_style_box(_box(Color("233f43"), Color("6c7760"), 75, 3), win.grow(7))
		draw_style_box(_box(Color("45615e"), Color("8b9274"), 70, 1), win)
		draw_circle(win.position + Vector2(win.size.x * 0.66, win.size.y * 0.28), win.size.x * 0.14, Color("d9ddad"))
		draw_circle(win.position + Vector2(win.size.x * 0.70, win.size.y * 0.25), win.size.x * 0.13, Color("45615e"))
		for i in range(10):
			var star := win.position + Vector2(win.size.x * (0.15 + fmod(i * 0.213, 0.76)), win.size.y * (0.14 + fmod(i * 0.157, 0.66)))
			draw_circle(star, 1.4, Color("d5cfaa"))
		draw_line(Vector2(win.get_center().x, win.position.y + 5), Vector2(win.get_center().x, win.end.y), Color("243e3c"), 6)
		draw_line(Vector2(win.position.x, win.position.y + win.size.y * 0.55), Vector2(win.end.x, win.position.y + win.size.y * 0.55), Color("243e3c"), 6)
		# Shelves, stacked field journals and translucent specimen bottles.
		var shelf_x := w * 0.07
		var shelf_w := minf(w * 0.24, 294.0)
		for tier in range(2):
			var sy := h * (0.34 + tier * 0.2)
			draw_rect(Rect2(shelf_x - 12, sy, shelf_w + 24, 12), Color("5c5b42"))
			draw_line(Vector2(shelf_x - 12, sy), Vector2(shelf_x + shelf_w + 12, sy), Color("8b835b"), 2)
			for j in range(5):
				var bx := shelf_x + j * shelf_w / 5.0 + 5
				var bh := 36.0 + fmod(j * 17.0 + tier * 13, 35.0)
				var tint := Color("668d78") if j % 2 == 0 else Color("ad8c59")
				draw_style_box(_box(Color(tint, 0.5), Color(tint, 0.8), 7, 1), Rect2(bx, sy - bh, 25, bh))
				draw_rect(Rect2(bx + 5, sy - bh - 8, 15, 10), Color("88734e"))
				draw_rect(Rect2(bx + 4, sy - bh * 0.58, 17, 14), Color("b5b58b"))
		# Hanging ivy and an herbal drying rail.
		for side in range(2):
			var vine_x := 25.0 if side == 0 else w - 31.0
			for j in range(9):
				var pos := Vector2(vine_x + sin(j * 0.9) * 12.0, h * 0.12 + j * 26.0)
				if j < 8:
					draw_line(pos, Vector2(vine_x + sin((j + 1) * 0.9) * 12.0, pos.y + 26.0), Color("5d7658"), 2)
				_leaf(pos, -0.7 if j % 2 == 0 else 0.8, 12, Color("507451"))
		# A worn workbench and a brass-rimmed cauldron anchor the playfield.
		var table_y := h * 0.81
		draw_rect(Rect2(w * 0.11, table_y, w * 0.78, 24), Color("594f37"))
		draw_line(Vector2(w * 0.11, table_y), Vector2(w * 0.89, table_y), Color("9a865a"), 3)
		var cx := w * 0.5
		var cy := table_y - 32.0
		for i in range(5):
			draw_circle(Vector2(cx, cy - 4), 56.0 + i * 14, Color(0.48, 0.68, 0.43, 0.025))
		draw_style_box(_box(Color("1d3334"), Color("7b8861"), 28, 3), Rect2(cx - 72, cy - 24, 144, 69))
		draw_ellipse_like(Vector2(cx, cy - 18), Vector2(72, 16), Color("b29c60"))
		draw_ellipse_like(Vector2(cx, cy - 19), Vector2(62, 10), Color("8dba7d"))
		for i in range(4):
			var sx := cx - 31.0 + i * 21
			draw_polyline(PackedVector2Array([Vector2(sx, cy - 41), Vector2(sx + 5, cy - 57), Vector2(sx - 3, cy - 73)]), Color(0.68, 0.79, 0.6, 0.28), 2.0, true)
		draw_line(Vector2(w * 0.23, table_y + 24), Vector2(w * 0.22, h), Color("403f30"), 16)
		draw_line(Vector2(w * 0.77, table_y + 24), Vector2(w * 0.78, h), Color("403f30"), 16)
		# A sprig and open notebook complete the quiet workshop context.
		var pot := Vector2(w * 0.83, table_y - 2)
		draw_style_box(_box(Color("76664b"), Color("9b8860"), 6, 1), Rect2(pot.x - 20, pot.y - 33, 40, 33))
		for i in range(5):
			var tip := pot + Vector2(-29.0 + i * 14.0, -70.0 - sin(i * 1.4) * 17.0)
			draw_line(pot + Vector2(0, -29), tip, Color("7e9b68"), 2)
			_leaf(tip, -0.5 + i * 0.3, 13, Color("7a9864"))
	func _leaf(pos: Vector2, angle: float, extent: float, color: Color) -> void:
		var direction := Vector2(cos(angle), sin(angle))
		var normal := Vector2(-direction.y, direction.x)
		draw_colored_polygon(PackedVector2Array([pos - direction * extent, pos + normal * extent * 0.45, pos + direction * extent, pos - normal * extent * 0.45]), color)
	func draw_ellipse_like(center: Vector2, radius: Vector2, color: Color) -> void:
		var points := PackedVector2Array()
		for i in range(48):
			var angle := TAU * i / 48.0
			points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
		draw_colored_polygon(points, color)
	func _box(fill: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
		var key := "%s:%s:%d:%d" % [fill.to_html(), border.to_html(), radius, width]
		if not _draw_styles.has(key):
			var result := StyleBoxFlat.new()
			result.bg_color = fill
			result.border_color = border
			result.set_border_width_all(width)
			result.set_corner_radius_all(radius)
			_draw_styles[key] = result
		return _draw_styles[key]

func _ready() -> void:
	get_viewport().gui_embed_subwindows = true
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_theme()
	_build_workshop()
	_build_modal()
	get_viewport().size_changed.connect(_request_layout)
	model.open_settings()
	_sync_controls()
	_layout()
	call_deferred("_settled_layout")

func _build_theme() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font_size = 16
	ui_theme.set_color("font_color", "Label", INK)
	ui_theme.set_color("font_color", "Button", INK)
	ui_theme.set_color("font_hover_color", "Button", INK)
	ui_theme.set_color("font_pressed_color", "Button", INK)
	ui_theme.set_color("font_focus_color", "Button", INK)
	var focus := _style(Color(0, 0, 0, 0), BRASS, 7, 2)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	ui_theme.set_stylebox("focus", "Button", focus)
	ui_theme.set_stylebox("focus", "OptionButton", focus)
	ui_theme.set_stylebox("focus", "CheckButton", focus)
	var rail := _style(Color("d1cfb9"), Color("c5c4ac"), 3, 0)
	rail.content_margin_top = 2
	rail.content_margin_bottom = 2
	var fill := _style(SAGE, SAGE, 3, 0)
	fill.content_margin_top = 2
	fill.content_margin_bottom = 2
	ui_theme.set_stylebox("slider", "HSlider", rail)
	ui_theme.set_stylebox("grabber_area", "HSlider", fill)
	ui_theme.set_stylebox("grabber_area_highlight", "HSlider", fill)
	ui_theme.set_stylebox("focus", "HSlider", focus)
	ui_theme.set_icon("grabber", "HSlider", _svg_texture('<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22"><circle cx="11" cy="11" r="9" fill="#f7efdb" stroke="#647b55" stroke-width="2"/><circle cx="11" cy="11" r="3" fill="#a77d42"/></svg>'))
	ui_theme.set_icon("grabber_highlight", "HSlider", _svg_texture('<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24"><circle cx="12" cy="12" r="10" fill="#fff9e8" stroke="#ac8145" stroke-width="2"/><circle cx="12" cy="12" r="3" fill="#a77d42"/></svg>'))
	ui_theme.set_icon("checked", "CheckButton", _toggle_icon(true))
	ui_theme.set_icon("unchecked", "CheckButton", _toggle_icon(false))
	ui_theme.set_icon("checked_disabled", "CheckButton", _toggle_icon(true))
	ui_theme.set_icon("unchecked_disabled", "CheckButton", _toggle_icon(false))
	ui_theme.set_stylebox("normal", "CheckButton", _style(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 6, 0))
	ui_theme.set_stylebox("hover", "CheckButton", _style(Color(0.36, 0.47, 0.32, 0.065), Color(0, 0, 0, 0), 6, 0))
	ui_theme.set_stylebox("pressed", "CheckButton", _style(Color(0.36, 0.47, 0.32, 0.11), Color(0, 0, 0, 0), 6, 0))
	ui_theme.set_constant("h_separation", "CheckButton", 12)
	ui_theme.set_stylebox("panel", "PopupMenu", _style(PAPER, Color("a99e7e"), 8, 1))
	ui_theme.set_stylebox("hover", "PopupMenu", _style(Color("d7dfc7"), Color("9aab85"), 4, 0))
	ui_theme.set_color("font_color", "PopupMenu", INK)
	ui_theme.set_color("font_hover_color", "PopupMenu", INK)
	ui_theme.set_constant("v_separation", "PopupMenu", 16)
	ui_theme.set_font_size("font_size", "PopupMenu", 16)
	theme = ui_theme

func _build_workshop() -> void:
	world = Workshop.new()
	world.name = "MoonlitWorkshop"
	add_child(world)
	world_title = _label("Mosslight Atelier", 30, Color("e3dfbd"))
	add_child(world_title)
	world_subtitle = _label("BOTANICAL ALCHEMY  /  NIGHTFALL", 11, Color("a3b59a"))
	world_subtitle.add_theme_constant_override("outline_size", 0)
	add_child(world_subtitle)
	world_status = _label("The kettle is warm. Make something wonderful.", 14, Color("acbda8"))
	add_child(world_status)
	prefs_toggle = _button("PrefsToggle", "Preferences", false)
	prefs_toggle.add_theme_color_override("font_color", Color("e4dfc1"))
	prefs_toggle.add_theme_color_override("font_hover_color", Color("fff5d4"))
	prefs_toggle.add_theme_stylebox_override("normal", _style(Color("25413f"), Color("63705b"), 9, 1))
	prefs_toggle.add_theme_stylebox_override("hover", _style(Color("36554a"), Color("9b9b70"), 9, 1))
	prefs_toggle.pressed.connect(_open_settings)
	add_child(prefs_toggle)
	brew_button = _button("BrewButton", "Brew moonleaf tea", true)
	brew_button.pressed.connect(_brew)
	add_child(brew_button)
	brew_count = _label("0 brews this evening", 13, Color("b9c5ad"))
	brew_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(brew_count)

func _build_modal() -> void:
	modal_layer = Control.new()
	modal_layer.name = "SettingsModal"
	modal_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.07, 0.075, 0.57)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(dim)
	card = Panel.new()
	card.name = "ParchmentPanel"
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var paper_style := _style(PAPER, Color("b9ad88"), 17, 1)
	paper_style.shadow_color = Color(0, 0.025, 0.025, 0.47)
	paper_style.shadow_size = 22
	paper_style.shadow_offset = Vector2(0, 12)
	card.add_theme_stylebox_override("panel", paper_style)
	modal_layer.add_child(card)
	header = Control.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(header)
	eyebrow = _label("M O S S L I G H T   A T E L I E R", 10, BRASS)
	header.add_child(eyebrow)
	heading = _label("A little more your own", 30, INK)
	header.add_child(heading)
	supporting = _label("Set the mood for your next discovery.", 14, MUTED)
	supporting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(supporting)
	close_button = _button("CloseButton", "×", false)
	close_button.tooltip_text = "Close without applying (Esc)"
	close_button.add_theme_font_size_override("font_size", 25)
	close_button.add_theme_stylebox_override("normal", _style(Color("e7dfc9"), Color("d4c9ab"), 22, 1))
	close_button.add_theme_stylebox_override("hover", _style(Color("dcd7bd"), BRASS, 22, 1))
	close_button.pressed.connect(_cancel_settings)
	card.add_child(close_button)
	scroll = ScrollContainer.new()
	scroll.name = "SettingsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.follow_focus = true
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	card.add_child(scroll)
	body = Control.new()
	body.name = "SettingsContent"
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(body)
	audio_panel = Panel.new()
	audio_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	audio_panel.add_theme_stylebox_override("panel", _style(Color("f8f2e2"), Color("ded5bc"), 10, 1))
	body.add_child(audio_panel)
	access_panel = Panel.new()
	access_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	access_panel.add_theme_stylebox_override("panel", _style(Color("e8e6d1"), Color("d5d6bc"), 10, 1))
	body.add_child(access_panel)
	audio_heading = _label("SOUND & ATMOSPHERE", 11, BRASS)
	body.add_child(audio_heading)
	music_label = _label("Music", 16, INK)
	music_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(music_label)
	sfx_label = _label("Sound effects", 16, INK)
	sfx_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(sfx_label)
	music_value = _label("60%", 15, SAGE)
	music_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(music_value)
	sfx_value = _label("80%", 15, SAGE)
	sfx_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(sfx_value)
	music_slider = _slider("MusicSlider")
	music_slider.value_changed.connect(_music_changed)
	body.add_child(music_slider)
	sfx_slider = _slider("SfxSlider")
	sfx_slider.value_changed.connect(_sfx_changed)
	body.add_child(sfx_slider)
	access_heading = _label("COMFORT & LANGUAGE", 11, BRASS)
	body.add_child(access_heading)
	motion_toggle = CheckButton.new()
	motion_toggle.name = "MotionToggle"
	motion_toggle.custom_minimum_size = Vector2(0, 44)
	motion_toggle.tooltip_text = "Use less decorative motion and fewer transition effects"
	motion_toggle.toggled.connect(_motion_changed)
	body.add_child(motion_toggle)
	motion_label = _label("Reduced motion", 16, INK)
	motion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(motion_label)
	motion_note = _label("A quieter kind of magic.", 12, MUTED)
	body.add_child(motion_note)
	language_label = _label("Language", 14, MUTED)
	body.add_child(language_label)
	language_select = OptionButton.new()
	language_select.name = "LanguageSelect"
	language_select.custom_minimum_size = Vector2(0, 44)
	language_select.add_item("English")
	language_select.add_item("Extended labels")
	language_select.add_theme_font_size_override("font_size", 15)
	language_select.add_theme_color_override("font_color", INK)
	language_select.add_theme_color_override("font_hover_color", INK)
	language_select.add_theme_color_override("font_pressed_color", INK)
	language_select.add_theme_stylebox_override("normal", _style(Color("faf5e7"), Color("b9bca4"), 7, 1, 13))
	language_select.add_theme_stylebox_override("hover", _style(Color("fff9eb"), BRASS, 7, 1, 13))
	language_select.add_theme_stylebox_override("pressed", _style(Color("dedfc6"), SAGE, 7, 1, 13))
	language_select.item_selected.connect(_language_changed)
	body.add_child(language_select)
	footer = Control.new()
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(footer)
	footer_rule = ColorRect.new()
	footer_rule.color = Color("d6cbb0")
	footer_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(footer_rule)
	footer_note = _label("Changes take effect when applied.", 12, MUTED)
	footer.add_child(footer_note)
	cancel_button = _button("CancelButton", "Cancel", false)
	cancel_button.pressed.connect(_cancel_settings)
	footer.add_child(cancel_button)
	apply_button = _button("ApplyButton", "Apply settings", true)
	apply_button.pressed.connect(_apply_settings)
	footer.add_child(apply_button)
	var order: Array[Control] = [close_button, music_slider, sfx_slider, motion_toggle, language_select, cancel_button, apply_button]
	for i in range(order.size()):
		order[i].focus_next = order[i].get_path_to(order[(i + 1) % order.size()])
		order[i].focus_previous = order[i].get_path_to(order[(i - 1 + order.size()) % order.size()])

func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	world.position = Vector2.ZERO
	world.size = viewport_size
	world.queue_redraw()
	var compact := viewport_size.x < 600
	var short := viewport_size.y < 500 and viewport_size.x >= 600
	_rect(world_title, Rect2(28 if compact else 44, 26 if compact else 34, maxf(230, viewport_size.x - 230), 42))
	world_title.add_theme_font_size_override("font_size", 23 if compact else 30)
	_rect(world_subtitle, Rect2(30 if compact else 46, 69 if compact else 79, viewport_size.x - 60, 22))
	_rect(world_status, Rect2(46, viewport_size.y - 46, viewport_size.x - 92, 24))
	world_status.visible = not compact and not short
	_rect(prefs_toggle, Rect2(viewport_size.x - (132 if compact else 175), 24 if compact else 37, 116 if compact else 131, 44))
	_rect(brew_button, Rect2((viewport_size.x - 224) / 2.0, viewport_size.y - 104, 224, 48))
	_rect(brew_count, Rect2((viewport_size.x - 240) / 2.0, viewport_size.y - 49, 240, 24))
	_rect(modal_layer, Rect2(Vector2.ZERO, viewport_size))
	var margin := 12.0 if short else 16.0
	var panel_width := minf(760 if short else 624, viewport_size.x - margin * 2)
	var panel_height := minf(366 if short else 650, viewport_size.y - margin * 2)
	_rect(card, Rect2((viewport_size.x - panel_width) / 2.0, (viewport_size.y - panel_height) / 2.0, panel_width, panel_height))
	var inset := 22.0 if compact else 30.0
	if short:
		inset = 24.0
	var content_width := panel_width - inset * 2
	var header_height := 116.0 if compact else 120.0
	if short:
		header_height = 85.0
	_rect(header, Rect2(inset, 0, content_width, header_height))
	_rect(eyebrow, Rect2(0, 23 if short else 27, content_width - 46, 16))
	eyebrow.add_theme_font_size_override("font_size", 9 if compact else 10)
	heading.add_theme_font_size_override("font_size", 24 if compact else (25 if short else 30))
	_rect(heading, Rect2(0, 41 if short else 47, content_width - 38, 37))
	_rect(supporting, Rect2(0, 79 if not short else 0, content_width, 28))
	supporting.visible = not short
	_rect(close_button, Rect2(panel_width - inset - 32, 22 if not short else 18, 44, 44))
	var footer_height := 88.0 if compact else 91.0
	if short:
		footer_height = 69.0
	var body_height := panel_height - header_height - footer_height
	_rect(scroll, Rect2(inset, header_height, content_width, body_height))
	var body_width := content_width - (12.0 if scroll.get_v_scroll_bar().visible else 0.0)
	var is_extended := int(model.draft.language) == 1
	var total_height := _layout_body(body_width, short, is_extended)
	body.custom_minimum_size = Vector2(0, total_height)
	body.size = Vector2(body_width, total_height)
	_rect(footer, Rect2(inset, panel_height - footer_height, content_width, footer_height))
	_rect(footer_rule, Rect2(0, 10 if short else 14, content_width, 1))
	footer_note.visible = not compact and not short
	_rect(footer_note, Rect2(0, 35, content_width - 290, 30))
	var button_width := (content_width - 12) / 2.0 if compact else 132.0
	var apply_width := button_width if compact else 148.0
	var buttons_y := 25.0 if short else 29.0
	_rect(apply_button, Rect2(content_width - apply_width, buttons_y, apply_width, 46))
	_rect(cancel_button, Rect2(content_width - apply_width - button_width - 12, buttons_y, button_width, 46))

func _layout_body(width: float, horizontal: bool, extended: bool) -> float:
	var gap := 16.0
	var col_width := (width - gap) / 2.0 if horizontal else width
	var pad := 16.0
	var usable := col_width - pad * 2
	var audio_label_width := usable - 50
	var label_height := _wrapped_height(music_label.text, audio_label_width, 16)
	var sfx_height := _wrapped_height(sfx_label.text, audio_label_width, 16)
	var y := 17.0
	_rect(audio_heading, Rect2(pad, y, usable, 20))
	y += 32
	_rect(music_label, Rect2(pad, y, audio_label_width, label_height))
	_rect(music_value, Rect2(col_width - pad - 43, y, 43, label_height))
	y += label_height
	_rect(music_slider, Rect2(pad, y, usable, 44))
	y += 53
	_rect(sfx_label, Rect2(pad, y, audio_label_width, sfx_height))
	_rect(sfx_value, Rect2(col_width - pad - 43, y, 43, sfx_height))
	y += sfx_height
	_rect(sfx_slider, Rect2(pad, y, usable, 44))
	y += 52
	var audio_height := y
	_rect(audio_panel, Rect2(0, 0, col_width, audio_height))
	var access_x := col_width + gap if horizontal else 0.0
	var access_y := 0.0 if horizontal else audio_height + 14
	_rect(access_heading, Rect2(access_x + pad, access_y + 17, usable, 20))
	var motion_height := maxf(44, _wrapped_height(motion_label.text, usable - 64, 16))
	var my := access_y + 42
	_rect(motion_toggle, Rect2(access_x + pad - 4, my, usable + 8, motion_height))
	_rect(motion_label, Rect2(access_x + pad, my, usable - 64, motion_height))
	motion_note.visible = not horizontal
	var note_height := 0.0 if horizontal else 22.0
	_rect(motion_note, Rect2(access_x + pad, my + motion_height, usable, 20))
	var ly := my + motion_height + note_height + 13
	_rect(language_label, Rect2(access_x + pad, ly, usable, 22))
	_rect(language_select, Rect2(access_x + pad, ly + 25, usable, 44))
	var access_height := ly - access_y + 82
	_rect(access_panel, Rect2(access_x, access_y, col_width, maxf(audio_height, access_height) if horizontal else access_height))
	if horizontal:
		_rect(audio_panel, Rect2(0, 0, col_width, maxf(audio_height, access_height)))
		return maxf(audio_height, access_height) + 3
	return access_y + access_height + 3

func _wrapped_height(text: String, width: float, font_size: int) -> float:
	var font := ThemeDB.fallback_font
	var words := text.split(" ")
	var lines := 1
	var current := ""
	for word in words:
		var next := word if current.is_empty() else current + " " + word
		if font.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and not current.is_empty():
			lines += 1
			current = word
		else:
			current = next
	return maxf(24, float(lines) * 23.0)

func _request_layout() -> void:
	if not _layout_pending:
		_layout_pending = true
		call_deferred("_settled_layout")

func _settled_layout() -> void:
	_layout_pending = false
	_layout()
	await get_tree().process_frame
	if is_inside_tree():
		_layout()

func _sync_controls() -> void:
	_syncing = true
	music_slider.value = float(model.draft.music)
	sfx_slider.value = float(model.draft.sfx)
	motion_toggle.button_pressed = bool(model.draft.reduced_motion)
	language_select.select(int(model.draft.language))
	music_value.text = "%d%%" % int(model.draft.music)
	sfx_value.text = "%d%%" % int(model.draft.sfx)
	var extended := int(model.draft.language) == 1
	music_label.text = "Background music volume during exploration" if extended else "Music"
	sfx_label.text = "Sound effects volume for tools and discoveries" if extended else "Sound effects"
	motion_label.text = "Reduce decorative motion and transition effects" if extended else "Reduced motion"
	modal_layer.visible = bool(model.modal_open)
	prefs_toggle.disabled = bool(model.modal_open)
	brew_button.disabled = bool(model.modal_open) or bool(model.paused)
	brew_count.text = "%d brew%s this evening" % [model.brew_count, "" if model.brew_count == 1 else "s"]
	_syncing = false
	_request_layout()

func _open_settings() -> void:
	model.open_settings()
	_sync_controls()
	scroll.scroll_vertical = 0
	music_slider.grab_focus()

func _cancel_settings() -> void:
	if not model.modal_open:
		return
	model.cancel_settings()
	_sync_controls()
	prefs_toggle.grab_focus()

func _apply_settings() -> void:
	if not model.modal_open:
		return
	model.apply_settings()
	_sync_controls()
	prefs_toggle.grab_focus()

func _brew() -> void:
	model.brew()
	_sync_controls()

func _music_changed(value: float) -> void:
	if not _syncing and model.modal_open:
		model.draft.music = value
		music_value.text = "%d%%" % int(value)

func _sfx_changed(value: float) -> void:
	if not _syncing and model.modal_open:
		model.draft.sfx = value
		sfx_value.text = "%d%%" % int(value)

func _motion_changed(value: bool) -> void:
	if not _syncing and model.modal_open:
		model.draft.reduced_motion = value

func _language_changed(index: int) -> void:
	if not _syncing and model.modal_open:
		model.draft.language = index
		_sync_controls()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and model.modal_open:
		_cancel_settings()
		get_viewport().set_input_as_handled()

func get_probe_state() -> Dictionary:
	return model.snapshot()

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label

func _slider(node_name: String) -> HSlider:
	var slider := HSlider.new()
	slider.name = node_name
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size = Vector2(0, 44)
	slider.focus_mode = Control.FOCUS_ALL
	slider.scrollable = false
	return slider

func _button(node_name: String, text: String, primary: bool) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(44, 44)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_stylebox_override("normal", _style(SAGE if primary else Color("eee7d3"), Color("415c46") if primary else Color("b8b59a"), 8, 1, 12))
	button.add_theme_stylebox_override("hover", _style(Color("607f5f") if primary else Color("e2e1c8"), BRASS, 8, 1, 12))
	button.add_theme_stylebox_override("pressed", _style(Color("3b5844") if primary else Color("d4d5ba"), BRASS, 8, 1, 12))
	button.add_theme_stylebox_override("disabled", _style(Color("345048") if primary else Color("d4d0bc"), Color("66765b"), 8, 1, 12))
	button.add_theme_color_override("font_disabled_color", Color("87977f"))
	if primary:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, Color("fff6df"))
	return button

func _style(fill: Color, border: Color, radius: int, border_width: int, padding: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	return style

func _svg_texture(svg: String) -> ImageTexture:
	var image := Image.new()
	image.load_svg_from_string(svg)
	return ImageTexture.create_from_image(image)

func _toggle_icon(enabled: bool) -> ImageTexture:
	var track := "#4e6e55" if enabled else "#bbc1a6"
	var knob_x := "32" if enabled else "12"
	return _svg_texture('<svg xmlns="http://www.w3.org/2000/svg" width="46" height="26"><rect x="1" y="1" width="44" height="24" rx="12" fill="%s"/><circle cx="%s" cy="13" r="9" fill="#fff7e3"/></svg>' % [track, knob_x])

func _rect(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size
