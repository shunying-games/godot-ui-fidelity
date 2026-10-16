extends Control

const BattleModel = preload("res://battle_model.gd")
const BattleView = preload("res://battle_view.gd")
const UIOrnament = preload("res://ui_ornament.gd")
const WOOD = preload("res://assets/wood.png")
const GOLD = preload("res://assets/gold.png")
const CREST = preload("res://assets/crest.png")
const FONT = preload("res://assets/Cinzel.ttf")
const ACTORS = {
	"ranger": preload("res://assets/ranger.png"),
	"ember": preload("res://assets/ember.png"),
	"frost": preload("res://assets/frost.png"),
}
const CREAM := Color("f6ebce")
const MUTED := Color("b6b3a4")
const BRASS := Color("ba9655")
const CANVAS := Vector2(1280, 720)

var model = BattleModel.new()
var selected_build_type := "ranger"
var composition: Control
var battle_view: Node2D
var state: Dictionary
var wave_label: Label
var lives_label: Label
var gold_label: Label
var crystal_label: Label
var pause_button: Button
var next_button: Button
var next_hint: Label
var paused_label: Label
var mini_wave: Label
var mini_progress: Control
var context_panel: Panel
var context_title: Label
var context_detail: Label
var context_hint: Label
var upgrade_button: Button
var build_button: Button
var restart_button: Button
var context_action_label: Label
var build_action_label: Label
var outcome_panel: Panel
var outcome_title: Label
var outcome_detail: Label
var cards: Dictionary = {}
var button_art: Dictionary = {}
var wood_texture: Texture2D
var gold_texture: Texture2D
var _last_revision := -1
var _hover_site := -1
var _last_pointer := Vector2(-1000, -1000)
var _text_settle_pending := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	wood_texture = _small_texture(WOOD)
	gold_texture = _small_texture(GOLD)
	state = model.snapshot()
	composition = Control.new()
	composition.name = "Composition"
	composition.size = CANVAS
	composition.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(composition)
	battle_view = BattleView.new()
	battle_view.name = "Battlefield"
	composition.add_child(battle_view)
	_make_hud()
	_layout_canvas()
	get_viewport().size_changed.connect(_layout_canvas)
	_sync_state()
	# Native focus remains available without painting an unsolicited opening focus ring.
	set_process(true)

func _small_texture(source: Texture2D) -> Texture2D:
	var picture := source.get_image()
	picture.resize(roundi(source.get_width() * 0.25), roundi(source.get_height() * 0.25), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(picture)

func _layout_canvas() -> void:
	var viewport_size := get_viewport_rect().size
	var factor: float = minf(viewport_size.x / CANVAS.x, viewport_size.y / CANVAS.y)
	composition.scale = Vector2.ONE * factor
	composition.position = (viewport_size - CANVAS * factor) * 0.5

func _panel_style(material: String = "wood", tint: Color = Color.WHITE) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = gold_texture if material == "gold" else wood_texture
	for edge in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(edge, 10.0)
		style.set_content_margin(edge, 12.0)
	style.modulate_color = tint
	return style

func _flat_style(fill: Color, border: Color = Color.TRANSPARENT, thickness: int = 1, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(thickness)
	style.set_corner_radius_all(radius)
	return style

func _panel(parent: Node, rectangle: Rect2, material: String = "wood", tint: Color = Color.WHITE) -> Panel:
	var panel := Panel.new()
	panel.position = rectangle.position
	panel.size = rectangle.size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _panel_style(material, tint))
	parent.add_child(panel)
	return panel

func _label(parent: Node, text_value: String, rectangle: Rect2, font_size: int = 18, color: Color = CREAM, serif: bool = true, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	if serif:
		label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.015, 0.02, 0.02, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = text_value
	label.set_meta("design_rect", rectangle)
	label.position = rectangle.position
	label.size = rectangle.size
	parent.add_child(label)
	return label

func _button(parent: Node, node_name: String, rectangle: Rect2, material: String = "wood") -> Button:
	var button := Button.new()
	button.name = node_name
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_stylebox_override("normal", _panel_style(material))
	button.add_theme_stylebox_override("hover", _panel_style(material, Color(1.19, 1.13, 1.0)))
	button.add_theme_stylebox_override("pressed", _panel_style(material, Color(0.76, 0.73, 0.61)))
	button.add_theme_stylebox_override("disabled", _panel_style(material, Color(0.52, 0.54, 0.51)))
	var focus := _flat_style(Color.TRANSPARENT, Color("f8d88b"), 2, 8)
	focus.draw_center = false
	focus.set_expand_margin_all(1.0)
	button.add_theme_stylebox_override("focus", focus)
	button.position = rectangle.position
	button.size = rectangle.size
	parent.add_child(button)
	return button

func _picture(parent: Node, texture: Texture2D, rectangle: Rect2, color: Color = Color.WHITE) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.modulate = color
	picture.position = rectangle.position
	picture.size = rectangle.size
	parent.add_child(picture)
	return picture

func _icon(parent: Node, kind: String, rectangle: Rect2) -> Control:
	var icon := UIOrnament.new()
	icon.kind = kind
	icon.position = rectangle.position
	icon.size = rectangle.size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(icon)
	return icon

func _make_hud() -> void:
	# A single measured canvas keeps all art, actors and native hit regions aligned.
	var header := _panel(composition, Rect2(-14, -14, 1308, 64))
	header.name = "Header"
	var footer := _panel(composition, Rect2(-15, 604, 1310, 132))
	footer.name = "Footer"
	var dock := _panel(composition, Rect2(412, 569, 456, 154))
	dock.name = "TowerDock"
	_icon(composition, "laurel_left", Rect2(365, 613, 61, 102))
	_icon(composition, "laurel_right", Rect2(855, 613, 61, 102))
	_picture(composition, CREST, Rect2(18, -7, 65, 65))
	_label(composition, "MOONWELL BASTION", Rect2(96, 4, 358, 28), 22)
	_label(composition, "THE LANTERN MARSH", Rect2(97, 27, 345, 17), 11, Color("d8c7a1"))

	var wave_box := _panel(composition, Rect2(495, 3, 164, 42))
	wave_label = _label(wave_box, "", Rect2(8, 4, 148, 32), 17, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	var lives_box := _panel(composition, Rect2(665, 3, 122, 42))
	_icon(lives_box, "shield", Rect2(17, 9, 24, 27))
	lives_label = _label(lives_box, "", Rect2(47, 4, 68, 32), 17)

	var gold_box := Panel.new()
	gold_box.position = Vector2(987, 10)
	gold_box.size = Vector2(96, 29)
	gold_box.mouse_filter = Control.MOUSE_FILTER_STOP
	gold_box.add_theme_stylebox_override("panel", _flat_style(Color(0.015, 0.025, 0.025, 0.86), Color(0.3, 0.24, 0.14, 0.75), 1, 10))
	composition.add_child(gold_box)
	_icon(gold_box, "coin", Rect2(8, 3, 23, 23))
	gold_label = _label(gold_box, "", Rect2(39, 1, 52, 27), 18, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	var crystal_box := Panel.new()
	crystal_box.position = Vector2(1097, 10)
	crystal_box.size = Vector2(96, 29)
	crystal_box.mouse_filter = Control.MOUSE_FILTER_STOP
	crystal_box.add_theme_stylebox_override("panel", _flat_style(Color(0.015, 0.025, 0.025, 0.86), Color(0.2, 0.29, 0.27, 0.75), 1, 10))
	composition.add_child(crystal_box)
	_icon(crystal_box, "crystal", Rect2(8, 2, 21, 25))
	crystal_label = _label(crystal_box, "", Rect2(40, 1, 50, 27), 18, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)

	pause_button = _button(composition, "PauseButton", Rect2(1218, 2, 47, 44))
	var pause_symbol := _icon(pause_button, "resume", Rect2(11, 10, 25, 25))
	pause_symbol.name = "PauseSymbol"
	pause_button.pressed.connect(_toggle_pause)
	paused_label = _label(composition, "", Rect2(509, 53, 265, 21), 11, Color("ede1b9"), false, HORIZONTAL_ALIGNMENT_CENTER)
	var mini_box := Panel.new()
	mini_box.position = Vector2(1148, 64)
	mini_box.size = Vector2(107, 31)
	mini_box.mouse_filter = Control.MOUSE_FILTER_STOP
	mini_box.add_theme_stylebox_override("panel", _flat_style(Color(0.02, 0.055, 0.06, 0.92), Color("a5997a"), 1, 15))
	composition.add_child(mini_box)
	mini_wave = _label(mini_box, "", Rect2(5, 1, 97, 23), 11, Color("d9e8e7"), false, HORIZONTAL_ALIGNMENT_CENTER)
	mini_progress = _icon(mini_box, "wave_progress", Rect2(17, 25, 73, 3))
	restart_button = _button(composition, "RestartButton", Rect2(1158, 103, 97, 29))
	_label(restart_button, "RESTART · R", Rect2(5, 2, 87, 24), 10, Color("d5c6a5"), false, HORIZONTAL_ALIGNMENT_CENTER)
	restart_button.tooltip_text = "Restart the demo battle [R]"
	restart_button.pressed.connect(_restart)

	var objective := _panel(composition, Rect2(15, 625, 258, 64))
	_icon(objective, "lantern", Rect2(24, 12, 30, 42))
	_label(objective, "DEFEND THE MOONWELL", Rect2(68, 10, 182, 23), 12)
	_label(objective, "Keep the lanterns burning.", Rect2(68, 31, 182, 21), 12, Color("e1e0d4"), false)
	_label(composition, "Select a tower, then an empty stone circle.", Rect2(18, 696, 340, 16), 10, Color("b4b7ac"), false)

	var tower_types := ["ranger", "ember", "frost"]
	for index in range(tower_types.size()):
		var tower_type: String = tower_types[index]
		var button := _button(composition, tower_type.capitalize() + "Button", Rect2(441 + index * 140, 582, 121, 122))
		button.toggle_mode = true
		button.tooltip_text = "Select %s. Click an empty stone circle to build." % tower_type.capitalize()
		button.pressed.connect(_choose_build.bind(tower_type))
		var art := _picture(button, ACTORS[tower_type], Rect2(25, -3, 72, 79))
		art.name = "TowerArt"
		var title := _label(button, tower_type.to_upper(), Rect2(5, 73, 111, 20), 12, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
		_icon(button, "coin", Rect2(35, 96, 17, 17))
		var cost := _label(button, str(state["build_costs"][tower_type]), Rect2(59, 91, 46, 26), 17)
		var selection := Panel.new()
		selection.position = Vector2(2, 2)
		selection.size = Vector2(117, 118)
		selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var edge_style := _flat_style(Color.TRANSPARENT, Color("e2c78b"), 2, 10)
		edge_style.draw_center = false
		selection.add_theme_stylebox_override("panel", edge_style)
		button.add_child(selection)
		cards[tower_type] = {"button": button, "cost": cost, "art": art, "selection": selection, "title": title}

	next_button = _button(composition, "NextWaveButton", Rect2(1025, 622, 240, 54), "gold")
	_label(next_button, "NEXT WAVE", Rect2(25, 7, 176, 40), 23, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	_icon(next_button, "chevron", Rect2(202, 18, 16, 21))
	next_button.pressed.connect(_next_wave)
	next_hint = _label(composition, "", Rect2(1019, 680, 250, 24), 12, Color("dddacb"), false, HORIZONTAL_ALIGNMENT_CENTER)

	# Site context lives below the route, clear of every placement pad.
	context_panel = _panel(composition, Rect2(17, 500, 304, 93))
	context_panel.name = "SelectionContext"
	context_title = _label(context_panel, "", Rect2(15, 9, 273, 23), 14)
	context_detail = _label(context_panel, "", Rect2(15, 33, 273, 19), 11, Color("d7d6c3"), false)
	context_hint = _label(context_panel, "", Rect2(15, 60, 157, 23), 10, Color("c6bf9e"), false)
	upgrade_button = _button(context_panel, "UpgradeButton", Rect2(178, 52, 113, 32), "gold")
	context_action_label = _label(upgrade_button, "", Rect2(6, 2, 101, 27), 11, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	upgrade_button.pressed.connect(_upgrade)
	build_button = _button(context_panel, "BuildButton", Rect2(178, 52, 113, 32), "gold")
	build_action_label = _label(build_button, "", Rect2(6, 2, 101, 27), 11, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	build_button.pressed.connect(_build_selected)
	context_panel.visible = false

	outcome_panel = _panel(composition, Rect2(430, 238, 420, 180))
	outcome_panel.name = "BattleOutcome"
	outcome_title = _label(outcome_panel, "", Rect2(18, 21, 384, 43), 26, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	outcome_detail = _label(outcome_panel, "", Rect2(28, 70, 364, 26), 14, Color("e1d7b8"), false, HORIZONTAL_ALIGNMENT_CENTER)
	var return_button := _button(outcome_panel, "OutcomeRestartButton", Rect2(105, 111, 210, 47), "gold")
	_label(return_button, "DEFEND AGAIN", Rect2(10, 3, 190, 40), 18, CREAM, true, HORIZONTAL_ALIGNMENT_CENTER)
	return_button.pressed.connect(_restart)
	outcome_panel.visible = false

func _process(delta: float) -> void:
	model.advance(delta)
	if int(model.snapshot()["revision"]) != _last_revision:
		_sync_state()
	var pointer := composition.get_global_transform().affine_inverse() * get_global_mouse_position()
	if pointer != _last_pointer:
		_last_pointer = pointer
		_hover_site = _site_at(pointer)
		battle_view.hover_site = _hover_site
		battle_view.queue_redraw()
	_update_card_visuals()

func _sync_state() -> void:
	state = model.snapshot()
	_last_revision = int(state["revision"])
	battle_view.state = state
	battle_view.queue_redraw()
	wave_label.text = "WAVE %02d / %02d" % [state["wave_index"], state["total_waves"]]
	lives_label.text = "%d / 20" % state["lives"]
	gold_label.text = str(state["gold"])
	crystal_label.text = str(state["crystal"])
	mini_wave.text = "Wave %02d / %02d" % [state["wave_index"], state["total_waves"]]
	mini_progress.progress_value = float(state["wave_index"]) / float(state["total_waves"])
	mini_progress.queue_redraw()
	var paused: bool = state["paused"]
	var symbol = pause_button.get_node("PauseSymbol")
	symbol.kind = "resume" if paused else "pause"
	symbol.queue_redraw()
	pause_button.tooltip_text = "Resume battle [P]" if paused else "Pause battle [P]"
	paused_label.text = "BATTLE PAUSED  ·  P TO RESUME" if paused else ""
	var phase: String = state["phase"]
	next_button.disabled = not bool(state["available_actions"]["can_start"])
	if phase == "active":
		next_hint.text = "Wave in progress"
	elif phase == "ready":
		next_hint.text = "Resume to deploy" if paused else "Space to deploy."
	else:
		next_hint.text = "The marsh is safe." if phase == "won" else "The moonwell has fallen."
	next_button.tooltip_text = "Start the next wave [Space]" if not next_button.disabled else next_hint.text
	_set_children_tint(next_button, Color(0.75, 0.75, 0.68) if next_button.disabled else Color.WHITE)
	_update_context()
	outcome_panel.visible = phase in ["won", "lost"]
	if outcome_panel.visible:
		outcome_title.text = "THE MARSH ENDURES" if phase == "won" else "THE LANTERN FADES"
		outcome_detail.text = "All eight waves repelled. The moonwell shines." if phase == "won" else "Rally your towers and defend the moonwell again."
	_update_card_visuals()
	_queue_text_settle()

func _queue_text_settle() -> void:
	if not _text_settle_pending:
		_text_settle_pending = true
		call_deferred("_settle_text_geometry")

func _settle_text_geometry() -> void:
	_text_settle_pending = false
	_settle_labels_in(composition)

func _settle_labels_in(parent: Node) -> void:
	for child in parent.get_children():
		if child is Label and child.has_meta("design_rect"):
			var rectangle: Rect2 = child.get_meta("design_rect")
			child.position = rectangle.position
			child.size = rectangle.size
		_settle_labels_in(child)

func _set_children_tint(parent: Control, tint: Color) -> void:
	for child in parent.get_children():
		if child is CanvasItem:
			child.modulate = tint

func _update_card_visuals() -> void:
	for tower_type in cards:
		var card: Dictionary = cards[tower_type]
		var button: Button = card["button"]
		button.set_pressed_no_signal(tower_type == selected_build_type)
		card["selection"].visible = tower_type == selected_build_type
		card["cost"].add_theme_color_override("font_color", CREAM if int(state["gold"]) >= int(state["build_costs"][tower_type]) else Color("c79479"))
		card["art"].modulate = Color(1.12, 1.09, 0.98) if button.is_hovered() else Color.WHITE

func _update_context() -> void:
	var site_id: int = state["selected_site_id"]
	context_panel.visible = site_id >= 0
	if site_id < 0:
		return
	var tower := _tower_for_site(site_id)
	if tower.is_empty():
		context_title.text = "%s  ·  SITE %02d" % [selected_build_type.to_upper(), site_id + 1]
		context_detail.text = "Place this tower on the selected stone circle."
		context_hint.text = "Resume to build" if state["paused"] else "Ready to place" if state["available_actions"]["can_build_by_site"][site_id][selected_build_type] else "Need more gold"
		build_action_label.text = "BUILD  %d" % state["build_costs"][selected_build_type]
		build_button.disabled = not bool(state["available_actions"]["can_build_by_site"][site_id][selected_build_type])
		build_button.visible = true
		upgrade_button.visible = false
		_set_children_tint(build_button, Color(0.68, 0.68, 0.62) if build_button.disabled else Color.WHITE)
	else:
		context_title.text = "%s  ·  LEVEL %d" % [str(tower["type"]).to_upper(), tower["level"]]
		context_detail.text = "Damage %d   ·   Range %d   ·   %.2fs attack" % [roundi(tower["damage"]), roundi(tower["range"]), tower["interval"]]
		build_button.visible = false
		upgrade_button.visible = int(tower["level"]) < 3
		if int(tower["level"]) >= 3:
			context_hint.text = "Maximum level reached"
		else:
			context_hint.text = "Resume to upgrade" if state["paused"] else "Strengthen this tower" if tower["can_upgrade"] else "Need more gold"
			context_action_label.text = "UPGRADE  %d" % tower["next_upgrade_cost"]
			upgrade_button.disabled = not bool(tower["can_upgrade"])
			_set_children_tint(upgrade_button, Color(0.68, 0.68, 0.62) if upgrade_button.disabled else Color.WHITE)

func _tower_for_site(site_id: int) -> Dictionary:
	for tower in state["towers"]:
		if int(tower["site_id"]) == site_id:
			return tower
	return {}

func _choose_build(tower_type: String) -> void:
	selected_build_type = tower_type
	_update_card_visuals()
	_update_context()

func _dispatch(command: Dictionary) -> void:
	model.dispatch(command)
	_sync_state()

func _toggle_pause() -> void:
	_dispatch({"type": "set_paused", "paused": not bool(state["paused"])})

func _next_wave() -> void:
	_dispatch({"type": "start_wave"})

func _upgrade() -> void:
	var tower_id: int = state["selected_tower_id"]
	if tower_id >= 0:
		_dispatch({"type": "upgrade", "tower_id": tower_id})

func _build_selected() -> void:
	var site_id: int = state["selected_site_id"]
	if site_id >= 0:
		_dispatch({"type": "build", "site_id": site_id, "tower_type": selected_build_type})

func _restart() -> void:
	selected_build_type = "ranger"
	_dispatch({"type": "restart"})

func _site_at(point: Vector2) -> int:
	# World hit testing uses the model's frozen ground locations, in the same canvas.
	for site in state["sites"]:
		if point.distance_to(site["position"]) <= float(site["build_radius"]):
			return int(site["id"])
	# The illustrated top of an occupied tower is also a useful selection target.
	for tower in state["towers"]:
		var texture: Texture2D = ACTORS[tower["type"]]
		var height: float = minf(144.0, float(tower["position"].y) - 56.0)
		var width := height * texture.get_width() / texture.get_height()
		var rectangle := Rect2(tower["position"] - Vector2(width * 0.5, height), Vector2(width, height))
		if rectangle.has_point(point):
			return int(tower["site_id"])
	return -1

func _input(event: InputEvent) -> void:
	if not is_instance_valid(composition):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_P:
				_toggle_pause()
				get_viewport().set_input_as_handled()
			KEY_R:
				_restart()
				get_viewport().set_input_as_handled()
			KEY_SPACE:
				_next_wave()
				get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var point: Vector2 = composition.get_global_transform().affine_inverse() * event.position
		if not Rect2(Vector2.ZERO, CANVAS).has_point(point):
			return
		var site_id := _site_at(point)
		if site_id >= 0:
			var site: Dictionary = state["sites"][site_id]
			_dispatch({"type": "select_site", "site_id": site_id})
			if int(site["occupied_tower_id"]) < 0 and bool(state["available_actions"]["can_build_by_site"][site_id][selected_build_type]):
				_dispatch({"type": "build", "site_id": site_id, "tower_type": selected_build_type})
		else:
			_dispatch({"type": "clear_selection"})
		get_viewport().set_input_as_handled()

func get_probe_state() -> Dictionary:
	var snapshot: Dictionary = model.snapshot()
	snapshot["ui"] = {
		"selected_build_type": selected_build_type,
		"build_type": selected_build_type,
		"context_visible": context_panel.visible if is_instance_valid(context_panel) else false,
	}
	return snapshot
