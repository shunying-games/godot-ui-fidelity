extends Control
## Moonwell Bastion: native Godot HUD over a shared authoritative simulation.
const BattleModel = preload("res://battle_model.gd")
const WorldView = preload("res://battle_world.gd")
const BattleIcon = preload("res://battle_icon.gd")
const DESIGN_SIZE := Vector2(1280, 720)
const CREAM := Color("f1e4c8")
const MUTED := Color("b4b3a5")
const BRASS := Color("c6a36a")

var model = BattleModel.new()
var selected_build_type := "ranger"
var textures: Dictionary = {}
var font: Font
var design_root: Control
var world: Control
var state: Dictionary = {}
var wave_label: Label
var lives_label: Label
var gold_label: Label
var crystal_label: Label
var pause_button: Button
var pause_caption: Label
var next_wave_button: Button
var next_hint: Label
var small_wave_label: Label
var wave_progress: ProgressBar
var status_label: Label
var cards: Dictionary = {}
var card_prices: Dictionary = {}
var context: Panel
var context_image: TextureRect
var context_title: Label
var context_detail: Label
var context_hint: Label
var upgrade_button: Button
var build_button: Button
var outcome_panel: Panel
var outcome_title: Label
var outcome_detail: Label
var last_revision := -1
var wood_style: StyleBoxTexture
var gold_style: StyleBoxTexture
var card_group := ButtonGroup.new()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	AudioServer.set_bus_mute(0, true)
	font = load("res://assets/Cinzel.ttf")
	for type_name in ["ranger", "ember", "frost", "beetle", "wood", "gold", "crest"]:
		textures[type_name] = load("res://assets/%s.png" % type_name)
	textures["map"] = load("res://assets/map.webp")
	textures["wood_ui"] = _resize_texture(textures["wood"], 0.35)
	textures["gold_ui"] = _resize_texture(textures["gold"], 0.5)
	wood_style = _texture_style(textures["wood_ui"], 14)
	gold_style = _texture_style(textures["gold_ui"], 20)
	state = model.snapshot()
	design_root = Control.new()
	design_root.name = "DesignCanvas"
	design_root.size = DESIGN_SIZE
	design_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(design_root)
	world = WorldView.new()
	world.name = "Battlefield"
	world.size = DESIGN_SIZE
	design_root.add_child(world)
	world.site_clicked.connect(_on_site_clicked)
	world.empty_clicked.connect(func(): _dispatch({"type": "clear_selection"}))
	_build_top_hud()
	_build_bottom_hud()
	_build_context()
	_build_outcome()
	get_viewport().size_changed.connect(_fit_canvas)
	_fit_canvas()
	_refresh()

func _resize_texture(texture: Texture2D, factor: float) -> ImageTexture:
	var image := texture.get_image()
	image.resize(roundi(image.get_width() * factor), roundi(image.get_height() * factor), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)

func _texture_style(texture: Texture2D, margin: float, tint := Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, margin)
		style.set_content_margin(side, margin * 0.6)
	style.modulate_color = tint
	return style

func _flat_style(fill: Color, border := Color.TRANSPARENT, width := 1, radius := 5) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style

func _panel(parent: Control, rect: Rect2, style: StyleBox, node_name := "") -> Panel:
	var panel := Panel.new()
	panel.name = node_name if not node_name.is_empty() else "Ornament"
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _label(parent: Control, rect: Rect2, text: String, font_size: int, color := CREAM, serif := true, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.position = rect.position
	label.size = rect.size
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_constant_override("shadow_offset_x", 0)
	if serif: label.add_theme_font_override("font", font)
	parent.add_child(label)
	return label

func _image(parent: Control, rect: Rect2, texture: Texture2D) -> TextureRect:
	var image := TextureRect.new()
	image.position = rect.position
	image.size = rect.size
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(image)
	return image

func _icon(parent: Control, rect: Rect2, kind: String, tint := Color.WHITE) -> Control:
	var icon := BattleIcon.new()
	icon.position = rect.position
	icon.size = rect.size
	icon.kind = kind
	icon.tint = tint
	parent.add_child(icon)
	return icon

func _button(parent: Control, rect: Rect2, node_name: String, text: String, callback: Callable, gilded := false, font_size := 17) -> Button:
	var button := Button.new()
	button.name = node_name
	button.position = rect.position
	button.size = rect.size
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", Color("fff3d5"))
	button.add_theme_color_override("font_pressed_color", Color("fff7db"))
	button.add_theme_color_override("font_disabled_color", Color("b7ad97"))
	var base: StyleBoxTexture = gold_style if gilded else wood_style
	button.add_theme_stylebox_override("normal", base)
	var hover := base.duplicate() as StyleBoxTexture
	hover.modulate_color = Color(1.18, 1.13, 1.02)
	button.add_theme_stylebox_override("hover", hover)
	var pressed := base.duplicate() as StyleBoxTexture
	pressed.modulate_color = Color(0.9, 0.98, 0.91)
	button.add_theme_stylebox_override("pressed", pressed)
	var disabled := base.duplicate() as StyleBoxTexture
	disabled.modulate_color = Color(0.53, 0.57, 0.55)
	button.add_theme_stylebox_override("disabled", disabled)
	var focus := _flat_style(Color.TRANSPARENT, Color(1, 0.87, 0.54, 0.95), 2, 8)
	focus.set_expand_margin_all(-4)
	button.add_theme_stylebox_override("focus", focus)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _build_top_hud() -> void:
	_panel(design_root, Rect2(-20, -12, 1320, 62), wood_style, "TopTimber")
	_panel(design_root, Rect2(0, 47, 1280, 2), _flat_style(Color("735a38"), Color.TRANSPARENT, 0, 0))
	_image(design_root, Rect2(15, -5, 72, 72), textures["crest"])
	_label(design_root, Rect2(97, 3, 380, 29), "MOONWELL BASTION", 24)
	_label(design_root, Rect2(98, 28, 350, 15), "THE LANTERN MARSH", 12, Color("c4b18a"))
	var wave_panel := _panel(design_root, Rect2(495, 5, 164, 39), wood_style, "WavePlaque")
	wave_label = _label(wave_panel, Rect2(10, 2, 144, 34), "", 18, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	var lives_panel := _panel(design_root, Rect2(668, 5, 119, 39), wood_style, "LivesPlaque")
	_icon(lives_panel, Rect2(15, 7, 25, 25), "shield")
	lives_label = _label(lives_panel, Rect2(44, 3, 69, 33), "", 18)
	_panel(design_root, Rect2(991, 10, 95, 28), _flat_style(Color(0.025, 0.025, 0.02, 0.78), Color(0.24, 0.2, 0.12, 0.6), 1, 11))
	_icon(design_root, Rect2(996, 11, 25, 25), "coin")
	gold_label = _label(design_root, Rect2(1029, 8, 53, 31), "", 20)
	_panel(design_root, Rect2(1105, 10, 91, 28), _flat_style(Color(0.025, 0.025, 0.02, 0.78), Color(0.24, 0.2, 0.12, 0.6), 1, 11))
	_icon(design_root, Rect2(1111, 10, 23, 28), "crystal")
	crystal_label = _label(design_root, Rect2(1145, 8, 45, 31), "", 20)
	pause_button = _button(design_root, Rect2(1220, 1, 51, 46), "PauseButton", "▶", _toggle_pause, false, 20)
	pause_button.add_theme_font_override("font", ThemeDB.fallback_font)
	pause_button.add_theme_constant_override("outline_size", 0)
	pause_caption = _label(pause_button, Rect2(0, 29, 51, 12), "RESUME", 8, CREAM, false, HORIZONTAL_ALIGNMENT_CENTER)
	pause_button.tooltip_text = "Resume battle · P"
	pause_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	var badge := _panel(design_root, Rect2(1148, 63, 111, 31), _flat_style(Color(0.025, 0.07, 0.075, 0.92), Color("9b8c70"), 2, 16), "BattleWaveBadge")
	small_wave_label = _label(badge, Rect2(5, 2, 101, 22), "", 12, CREAM, false, HORIZONTAL_ALIGNMENT_CENTER)
	wave_progress = ProgressBar.new()
	wave_progress.position = Vector2(17, 25)
	wave_progress.size = Vector2(77, 2)
	wave_progress.custom_minimum_size = Vector2(0, 2)
	wave_progress.show_percentage = false
	wave_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_progress.add_theme_stylebox_override("background", _flat_style(Color(0.17, 0.22, 0.21), Color.TRANSPARENT, 0, 1))
	wave_progress.add_theme_stylebox_override("fill", _flat_style(Color("79cbd1"), Color.TRANSPARENT, 0, 1))
	badge.add_child(wave_progress)
	var restart := _button(design_root, Rect2(1110, 64, 31, 29), "RestartButton", "↻", _restart, false, 19)
	restart.add_theme_font_override("font", ThemeDB.fallback_font)
	restart.tooltip_text = "Restart the battle · R"
	status_label = _label(design_root, Rect2(1087, 98, 170, 19), "", 11, Color("d7d8c4"), false, HORIZONTAL_ALIGNMENT_RIGHT)

func _build_bottom_hud() -> void:
	_panel(design_root, Rect2(-20, 605, 1320, 131), wood_style, "BottomTimber")
	_panel(design_root, Rect2(425, 570, 432, 155), wood_style, "TowerDeck")
	var objective := _panel(design_root, Rect2(14, 625, 259, 65), wood_style, "ObjectivePlaque")
	_icon(objective, Rect2(8, 7, 48, 51), "lantern")
	_label(objective, Rect2(66, 12, 188, 23), "DEFEND THE MOONWELL", 12)
	_label(objective, Rect2(66, 34, 188, 21), "Keep the lanterns burning.", 13, Color("e0ddd0"), false)
	var types := ["ranger", "ember", "frost"]
	var colors := [Color(0.1, 0.24, 0.16, 0.5), Color(0.3, 0.14, 0.045, 0.5), Color(0.06, 0.2, 0.28, 0.5)]
	card_group.allow_unpress = false
	for index in range(types.size()):
		var type_name: String = types[index]
		var button := _button(design_root, Rect2(442 + index * 140, 582, 118, 121), type_name.capitalize() + "Button", "", _choose_tower.bind(type_name), false, 16)
		button.toggle_mode = true
		button.button_group = card_group
		button.button_pressed = type_name == selected_build_type
		button.tooltip_text = "Choose %s, then click an empty stone pad" % type_name.capitalize()
		cards[type_name] = button
		var glow := _panel(button, Rect2(10, 10, 98, 65), _flat_style(colors[index], Color.TRANSPARENT, 0, 7))
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_image(button, Rect2(26, -6, 68, 87), textures[type_name])
		_label(button, Rect2(5, 76, 108, 22), type_name.to_upper(), 15, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
		_icon(button, Rect2(36, 98, 18, 18), "coin")
		card_prices[type_name] = _label(button, Rect2(60, 96, 48, 22), "", 17)
		var line := _panel(button, Rect2(13, 75, 92, 1), _flat_style(Color(0.55, 0.44, 0.25, 0.6), Color.TRANSPARENT, 0, 0))
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(design_root, Rect2(425, 704, 432, 14), "CHOOSE A TOWER  ·  CLICK AN EMPTY STONE PAD", 10, Color("b4ad99"), false, HORIZONTAL_ALIGNMENT_CENTER)
	next_wave_button = _button(design_root, Rect2(1028, 621, 237, 57), "NextWaveButton", "NEXT WAVE", _start_wave, true, 24)
	_icon(next_wave_button, Rect2(194, 13, 24, 30), "chevron", CREAM)
	next_hint = _label(design_root, Rect2(1028, 679, 237, 24), "", 13, Color("d0cbbc"), false, HORIZONTAL_ALIGNMENT_CENTER)
	next_wave_button.tooltip_text = "Deploy the next wave when the battlefield is clear · Space"

func _build_context() -> void:
	context = _panel(design_root, Rect2(16, 506, 348, 91), wood_style, "SelectedSiteContext")
	context_image = _image(context, Rect2(12, 7, 46, 76), textures["ranger"])
	context_title = _label(context, Rect2(70, 10, 264, 22), "", 14)
	context_detail = _label(context, Rect2(70, 34, 173, 20), "", 12, Color("ded5bd"), false)
	context_hint = _label(context, Rect2(70, 56, 166, 23), "", 11, MUTED, false)
	upgrade_button = _button(context, Rect2(238, 45, 98, 33), "UpgradeButton", "", _upgrade_selected, true, 12)
	upgrade_button.tooltip_text = "Improve this tower's damage, range and firing speed"
	build_button = _button(context, Rect2(238, 45, 98, 33), "BuildButton", "", _build_selected, true, 12)
	context.hide()

func _build_outcome() -> void:
	outcome_panel = _panel(design_root, Rect2(410, 235, 460, 220), wood_style, "OutcomePlaque")
	_image(outcome_panel, Rect2(192, 8, 76, 76), textures["crest"])
	outcome_title = _label(outcome_panel, Rect2(20, 82, 420, 35), "", 25, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	outcome_detail = _label(outcome_panel, Rect2(25, 121, 410, 29), "", 14, Color("c9c5b5"), false, HORIZONTAL_ALIGNMENT_CENTER)
	_button(outcome_panel, Rect2(129, 162, 202, 43), "OutcomeRestartButton", "RESTART BATTLE", _restart, true, 17)
	outcome_panel.hide()

func _fit_canvas() -> void:
	var viewport_size := get_viewport_rect().size
	var factor := minf(viewport_size.x / DESIGN_SIZE.x, viewport_size.y / DESIGN_SIZE.y)
	design_root.scale = Vector2.ONE * factor
	design_root.position = (viewport_size - DESIGN_SIZE * factor) * 0.5

func _process(delta: float) -> void:
	model.advance(delta)
	state = model.snapshot()
	if int(state["revision"]) != last_revision:
		_refresh()
	world.update_view(state, textures, selected_build_type, delta)

func _refresh() -> void:
	state = model.snapshot()
	last_revision = int(state["revision"])
	var paused := bool(state["paused"])
	var phase := str(state["phase"])
	wave_label.text = "WAVE %02d / %02d" % [state["wave_index"], state["total_waves"]]
	small_wave_label.text = "Wave %02d / %02d" % [state["wave_index"], state["total_waves"]]
	lives_label.text = "%d / 20" % state["lives"]
	gold_label.text = str(state["gold"])
	crystal_label.text = str(state["crystal"])
	pause_button.text = "▶" if paused else "Ⅱ"
	pause_caption.text = "RESUME" if paused else "PAUSE"
	pause_button.tooltip_text = ("Resume battle" if paused else "Pause battle") + " · P"
	next_wave_button.disabled = not bool(state["available_actions"]["can_start"])
	if phase == "active":
		next_hint.text = "Resume to defend." if paused else "Wave in progress."
		status_label.text = "PAUSED  ·  P TO RESUME" if paused else "%d beetles remaining" % (int(state["wave_alive"]) + int(state["wave_spawn_remaining"]))
	elif phase == "ready":
		next_hint.text = "Resume, then Space to deploy." if paused else "Space to deploy."
		status_label.text = "PREPARE YOUR DEFENSE"
	else:
		next_hint.text = "R to restart the battle."
		status_label.text = "BATTLE COMPLETE"
	wave_progress.value = float(state["wave_index"]) / float(state["total_waves"]) * 100.0
	for type_name in cards:
		var button: Button = cards[type_name]
		button.set_pressed_no_signal(type_name == selected_build_type)
		card_prices[type_name].text = str(state["build_costs"][type_name])
	_refresh_context()
	var terminal := phase == "won" or phase == "lost"
	outcome_panel.visible = terminal
	if terminal:
		outcome_title.text = "THE MOONWELL ENDURES" if phase == "won" else "THE LANTERNS HAVE FALLEN"
		outcome_detail.text = "All eight waves repelled. The marsh is safe." if phase == "won" else "Rebuild your defenses and hold the crossing."

func _refresh_context() -> void:
	var site_id := int(state["selected_site_id"])
	context.visible = site_id >= 0
	if site_id < 0:
		return
	var selected_tower: Dictionary = {}
	for tower in state["towers"]:
		if int(tower["id"]) == int(state["selected_tower_id"]): selected_tower = tower
	var paused := bool(state["paused"])
	var terminal := str(state["phase"]) in ["won", "lost"]
	upgrade_button.visible = not selected_tower.is_empty()
	build_button.visible = selected_tower.is_empty()
	if selected_tower.is_empty():
		var cost := int(state["build_costs"][selected_build_type])
		context_image.texture = textures[selected_build_type]
		context_title.text = "VACANT STONE PAD  ·  %02d" % (site_id + 1)
		context_detail.text = "%s  ·  %d gold" % [selected_build_type.capitalize(), cost]
		context_hint.text = "Resume to build" if paused else ("Battle complete" if terminal else "Click pad or Build")
		build_button.text = "BUILD %d" % cost
		build_button.disabled = not bool(state["available_actions"]["can_build_by_site"][site_id][selected_build_type])
	else:
		var cost := int(selected_tower["next_upgrade_cost"])
		context_image.texture = textures[str(selected_tower["type"])]
		context_title.text = "%s  ·  LEVEL %d" % [str(selected_tower["type"]).to_upper(), selected_tower["level"]]
		context_detail.text = "Damage %d  ·  Reach %d" % [selected_tower["damage"], selected_tower["range"]]
		context_hint.text = "Resume to upgrade" if paused else ("Maximum level" if cost == 0 else "Stronger, faster, farther")
		upgrade_button.text = "MAX LEVEL" if cost == 0 else "UPGRADE %d" % cost
		upgrade_button.disabled = not bool(state["available_actions"]["can_upgrade_by_tower"][selected_tower["id"]])

func _choose_tower(type_name: String) -> void:
	selected_build_type = type_name
	_refresh()

func _on_site_clicked(site_id: int) -> void:
	_dispatch({"type": "select_site", "site_id": site_id})
	var site: Dictionary = state["sites"][site_id]
	if int(site["occupied_tower_id"]) < 0 and bool(state["available_actions"]["can_build_by_site"][site_id][selected_build_type]):
		_dispatch({"type": "build", "site_id": site_id, "tower_type": selected_build_type})

func _dispatch(command: Dictionary) -> Dictionary:
	var result: Dictionary = model.dispatch(command)
	_refresh()
	return result

func _toggle_pause() -> void:
	_dispatch({"type": "set_paused", "paused": not bool(model.snapshot()["paused"])})

func _start_wave() -> void:
	_dispatch({"type": "start_wave"})

func _upgrade_selected() -> void:
	_dispatch({"type": "upgrade", "tower_id": int(model.snapshot()["selected_tower_id"])})

func _build_selected() -> void:
	var current: Dictionary = model.snapshot()
	if int(current["selected_site_id"]) >= 0:
		_dispatch({"type": "build", "site_id": current["selected_site_id"], "tower_type": selected_build_type})

func _restart() -> void:
	selected_build_type = "ranger"
	_dispatch({"type": "restart"})

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_P: _toggle_pause(); get_viewport().set_input_as_handled()
			KEY_R: _restart(); get_viewport().set_input_as_handled()
			KEY_SPACE: _start_wave(); get_viewport().set_input_as_handled()
			KEY_ESCAPE: _dispatch({"type": "clear_selection"}); get_viewport().set_input_as_handled()

func get_probe_state() -> Dictionary:
	var snapshot: Dictionary = model.snapshot()
	snapshot["ui"] = {"selected_build_type": selected_build_type, "context_visible": context != null and context.visible}
	return snapshot
