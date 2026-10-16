extends Control

const SettingsModel = preload("res://settings_model.gd")
const INK = Color("203a37")
const MUTED = Color("6c7868")
const PAPER = Color("f2eedc")
const SAGE = Color("537567")
const BRASS = Color("a67b3a")

var model = SettingsModel.new()
var overlay: Control
var modal: PanelContainer
var content_scroll: ScrollContainer
var content_columns: BoxContainer
var sound_section: VBoxContainer
var comfort_section: VBoxContainer
var heading: Label
var subtitle: Label
var music_label: Label
var sfx_label: Label
var motion_label: Label
var music_value: Label
var sfx_value: Label
var music_slider: HSlider
var sfx_slider: HSlider
var motion_toggle: CheckButton
var language_select: OptionButton
var footer: HBoxContainer
var footer_note: Label
var apply_button: Button
var cancel_button: Button
var close_button: Button
var prefs_toggle: Button
var brew_button: Button
var brew_caption: Label
var world_title: Label
var world_eyebrow: Label
var world_note: Label
var brew_card: PanelContainer
var corner_note: Label
var syncing := false
var narrow := false
var compact := false

func _ready() -> void:
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _make_theme()
    _build_world()
    _build_modal()
    resized.connect(_layout)
    _layout()
    _open_settings()

func get_probe_state() -> Dictionary:
    return model.snapshot()

func _style(fill: Color, radius: int = 12, border: Color = Color.TRANSPARENT, width: int = 0) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = fill
    s.corner_radius_top_left = radius
    s.corner_radius_top_right = radius
    s.corner_radius_bottom_left = radius
    s.corner_radius_bottom_right = radius
    s.border_color = border
    s.set_border_width_all(width)
    s.content_margin_left = 18
    s.content_margin_right = 18
    s.content_margin_top = 8
    s.content_margin_bottom = 8
    return s

func _make_theme() -> void:
    var t := Theme.new()
    t.default_font_size = 16
    t.set_color("font_color", "Label", INK)
    t.set_color("font_color", "Button", INK)
    t.set_color("font_hover_color", "Button", INK)
    t.set_color("font_pressed_color", "Button", INK)
    t.set_stylebox("normal", "Button", _style(Color("e6e8d9"), 9, Color("c7cdb8"), 1))
    t.set_stylebox("hover", "Button", _style(Color("dce4ce"), 9, SAGE, 1))
    t.set_stylebox("pressed", "Button", _style(Color("ccd8bf"), 9, SAGE, 1))
    t.set_stylebox("focus", "Button", _style(Color.TRANSPARENT, 9, BRASS, 2))
    for state in ["normal", "hover", "pressed", "focus"]:
        t.set_stylebox(state, "OptionButton", t.get_stylebox(state, "Button"))
    t.set_color("font_color", "OptionButton", INK)
    t.set_color("font_hover_color", "OptionButton", INK)
    t.set_color("font_pressed_color", "OptionButton", INK)
    t.set_constant("h_separation", "OptionButton", 10)
    var track := _style(Color("d6dac6"), 3)
    track.content_margin_top = 3
    track.content_margin_bottom = 3
    var fill := _style(SAGE, 3)
    fill.content_margin_top = 3
    fill.content_margin_bottom = 3
    t.set_stylebox("slider", "HSlider", track)
    t.set_stylebox("grabber_area", "HSlider", fill)
    t.set_stylebox("grabber_area_highlight", "HSlider", _style(Color("719784"), 3))
    t.set_icon("grabber", "HSlider", _knob_texture(Color("fff9e8")))
    t.set_icon("grabber_highlight", "HSlider", _knob_texture(Color("f9dfa4")))
    t.set_icon("grabber_disabled", "HSlider", _knob_texture(Color("cbd1bd")))
    t.set_constant("grabber_offset", "HSlider", 0)
    t.set_stylebox("focus", "HSlider", _style(Color.TRANSPARENT, 6, BRASS, 2))
    t.set_stylebox("panel", "PopupMenu", _style(PAPER, 10, Color("b6bea4"), 1))
    t.set_color("font_color", "PopupMenu", INK)
    t.set_color("font_hover_color", "PopupMenu", PAPER)
    t.set_stylebox("hover", "PopupMenu", _style(SAGE, 4))
    t.set_constant("v_separation", "PopupMenu", 22)
    theme = t

func _knob_texture(color: Color) -> ImageTexture:
    var img := Image.create(24, 24, false, Image.FORMAT_RGBA8)
    img.fill(Color.TRANSPARENT)
    for y in range(24):
        for x in range(24):
            var d := Vector2(x + 0.5, y + 0.5).distance_to(Vector2(12, 12))
            if d <= 11:
                img.set_pixel(x, y, SAGE if d > 8.5 else color)
    return ImageTexture.create_from_image(img)

func _label(text: String, font_size: int = 16, color: Color = INK) -> Label:
    var l := Label.new()
    l.text = text
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

func _button(text: String, control_name: String) -> Button:
    var b := Button.new()
    b.name = control_name
    b.text = text
    b.custom_minimum_size = Vector2(44, 48)
    b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    return b

func _build_world() -> void:
    world_eyebrow = _label("BOTANICAL ALCHEMY  /  NIGHT 07", 12, Color("a8c7af"))
    add_child(world_eyebrow)
    world_title = _label("Mosslight Atelier", 34, Color("f5ecd3"))
    add_child(world_title)
    world_note = _label("A little patience. A little moonlight.", 15, Color("bbcab4"))
    add_child(world_note)
    prefs_toggle = _button("Preferences", "PrefsToggle")
    prefs_toggle.tooltip_text = "Open preferences"
    prefs_toggle.add_theme_stylebox_override("normal", _style(Color("233f3b"), 10, Color("657b5e"), 1))
    prefs_toggle.add_theme_stylebox_override("hover", _style(Color("36554b"), 10, Color("a2b28a"), 1))
    prefs_toggle.add_theme_color_override("font_color", Color("f2ecd8"))
    prefs_toggle.add_theme_color_override("font_hover_color", Color("fff5d5"))
    prefs_toggle.pressed.connect(_open_settings)
    add_child(prefs_toggle)
    brew_card = PanelContainer.new()
    brew_card.add_theme_stylebox_override("panel", _style(Color("183530eb"), 15, Color("5b7360"), 1))
    add_child(brew_card)
    var brew_box := VBoxContainer.new()
    brew_box.add_theme_constant_override("separation", 8)
    brew_card.add_child(brew_box)
    brew_box.add_child(_label("ON THE WORKBENCH", 11, Color("b7c49d")))
    brew_box.add_child(_label("Moonflower tonic", 24, Color("f4ebd5")))
    brew_caption = _label("Ready to steep · 0 tonics brewed", 13, Color("b8c7af"))
    brew_box.add_child(brew_caption)
    brew_button = _button("Brew a tonic   →", "BrewButton")
    brew_button.pressed.connect(_brew)
    brew_box.add_child(brew_button)
    corner_note = _label("THE GREENHOUSE  ·  AFTER HOURS", 11, Color("9fb7a0"))
    add_child(corner_note)

func _build_modal() -> void:
    overlay = Control.new()
    overlay.name = "SettingsOverlay"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(overlay)
    var dim := ColorRect.new()
    dim.color = Color(0.025, 0.075, 0.067, 0.60)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(dim)
    modal = PanelContainer.new()
    modal.name = "PreferencesPanel"
    var skin := _style(PAPER, 20, Color("c2c7a9"), 1)
    skin.shadow_color = Color(0, 0, 0, 0.35)
    skin.shadow_size = 22
    skin.shadow_offset = Vector2(0, 9)
    skin.content_margin_left = 0
    skin.content_margin_right = 0
    skin.content_margin_top = 0
    skin.content_margin_bottom = 0
    modal.add_theme_stylebox_override("panel", skin)
    overlay.add_child(modal)
    modal.minimum_size_changed.connect(func(): _fit_panel.call_deferred())
    var margin := MarginContainer.new()
    margin.name = "Interior"
    margin.add_theme_constant_override("margin_left", 28)
    margin.add_theme_constant_override("margin_right", 28)
    margin.add_theme_constant_override("margin_top", 22)
    margin.add_theme_constant_override("margin_bottom", 22)
    modal.add_child(margin)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 16)
    margin.add_child(stack)
    var title_row := HBoxContainer.new()
    title_row.add_theme_constant_override("separation", 12)
    stack.add_child(title_row)
    var titles := VBoxContainer.new()
    titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    titles.add_theme_constant_override("separation", 4)
    title_row.add_child(titles)
    titles.add_child(_label("MAKE YOURSELF AT HOME", 11, BRASS))
    heading = _label("A moment of quiet", 31)
    titles.add_child(heading)
    close_button = _button("×", "CloseButton")
    close_button.custom_minimum_size = Vector2(44, 44)
    close_button.add_theme_font_size_override("font_size", 26)
    close_button.tooltip_text = "Close and discard changes (Escape)"
    close_button.pressed.connect(_cancel)
    title_row.add_child(close_button)
    subtitle = _label("Set the mood for your next small discovery.", 15, MUTED)
    subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(subtitle)
    var line := HSeparator.new()
    var line_style := StyleBoxLine.new()
    line_style.color = Color("cbd0b9")
    line_style.thickness = 1
    line.add_theme_stylebox_override("separator", line_style)
    stack.add_child(line)
    content_scroll = ScrollContainer.new()
    content_scroll.name = "SettingsScroll"
    content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    content_scroll.follow_focus = true
    content_scroll.add_theme_constant_override("scrollbar_h_separation", 8)
    stack.add_child(content_scroll)
    content_columns = BoxContainer.new()
    content_columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content_columns.add_theme_constant_override("separation", 24)
    content_scroll.add_child(content_columns)
    sound_section = VBoxContainer.new()
    sound_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    sound_section.add_theme_constant_override("separation", 9)
    content_columns.add_child(sound_section)
    sound_section.add_child(_label("SOUND & ATMOSPHERE", 11, BRASS))
    music_label = _label("Music", 16)
    music_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sound_section.add_child(music_label)
    var music_row := HBoxContainer.new()
    music_row.add_theme_constant_override("separation", 14)
    sound_section.add_child(music_row)
    music_slider = _make_slider("MusicSlider")
    music_slider.tooltip_text = "Music volume"
    music_row.add_child(music_slider)
    music_value = _label("60%", 16, SAGE)
    music_value.custom_minimum_size.x = 45
    music_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    music_row.add_child(music_value)
    music_slider.value_changed.connect(_music_changed)
    sfx_label = _label("Sound effects", 16)
    sfx_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    sound_section.add_child(sfx_label)
    var sfx_row := HBoxContainer.new()
    sfx_row.add_theme_constant_override("separation", 14)
    sound_section.add_child(sfx_row)
    sfx_slider = _make_slider("SfxSlider")
    sfx_slider.tooltip_text = "Sound effects volume"
    sfx_row.add_child(sfx_slider)
    sfx_value = _label("80%", 16, SAGE)
    sfx_value.custom_minimum_size.x = 45
    sfx_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    sfx_row.add_child(sfx_value)
    sfx_slider.value_changed.connect(_sfx_changed)
    comfort_section = VBoxContainer.new()
    comfort_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    comfort_section.add_theme_constant_override("separation", 10)
    content_columns.add_child(comfort_section)
    comfort_section.add_child(_label("YOUR WORKSHOP", 11, BRASS))
    var motion_row := HBoxContainer.new()
    motion_row.add_theme_constant_override("separation", 12)
    comfort_section.add_child(motion_row)
    var motion_text := VBoxContainer.new()
    motion_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    motion_text.add_theme_constant_override("separation", 3)
    motion_row.add_child(motion_text)
    motion_label = _label("Reduced motion", 16)
    motion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    motion_text.add_child(motion_label)
    motion_text.add_child(_label("A gentler pace for the senses.", 12, MUTED))
    motion_toggle = CheckButton.new()
    motion_toggle.name = "MotionToggle"
    motion_toggle.custom_minimum_size = Vector2(62, 48)
    motion_toggle.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    motion_toggle.tooltip_text = "Enable reduced motion"
    motion_toggle.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, 8))
    motion_toggle.add_theme_stylebox_override("hover", _style(Color("e1e5d2"), 8))
    motion_toggle.add_theme_stylebox_override("focus", _style(Color.TRANSPARENT, 8, BRASS, 2))
    motion_toggle.toggled.connect(_motion_changed)
    motion_row.add_child(motion_toggle)
    var language_row := HBoxContainer.new()
    language_row.add_theme_constant_override("separation", 14)
    comfort_section.add_child(language_row)
    var lang_label := _label("Language", 16)
    lang_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    language_row.add_child(lang_label)
    language_select = OptionButton.new()
    language_select.name = "LanguageSelect"
    language_select.custom_minimum_size = Vector2(176, 48)
    language_select.add_item("English")
    language_select.add_item("Extended labels")
    language_select.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    language_select.item_selected.connect(_language_changed)
    language_row.add_child(language_select)
    footer = HBoxContainer.new()
    footer.add_theme_constant_override("separation", 10)
    stack.add_child(footer)
    footer_note = _label("A calmer kind of magic.", 12, MUTED)
    footer_note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    footer.add_child(footer_note)
    cancel_button = _button("Cancel", "CancelButton")
    cancel_button.custom_minimum_size.x = 96
    cancel_button.pressed.connect(_cancel)
    footer.add_child(cancel_button)
    apply_button = _button("Apply", "ApplyButton")
    apply_button.custom_minimum_size.x = 128
    apply_button.add_theme_stylebox_override("normal", _style(SAGE, 9, Color("3b6150"), 1))
    apply_button.add_theme_stylebox_override("hover", _style(Color("3e6655"), 9, Color("2d5444"), 1))
    apply_button.add_theme_stylebox_override("pressed", _style(Color("315344"), 9))
    apply_button.add_theme_color_override("font_color", Color("fff9e8"))
    apply_button.add_theme_color_override("font_hover_color", Color("fff9e8"))
    apply_button.add_theme_color_override("font_pressed_color", Color("fff9e8"))
    apply_button.pressed.connect(_apply)
    footer.add_child(apply_button)

func _make_slider(control_name: String) -> HSlider:
    var slider := HSlider.new()
    slider.name = control_name
    slider.min_value = 0
    slider.max_value = 100
    slider.step = 1
    slider.custom_minimum_size = Vector2(80, 44)
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
    return slider

func _layout() -> void:
    if not is_instance_valid(modal):
        return
    narrow = size.x < 550
    compact = size.y < 500
    world_eyebrow.position = Vector2(40 if not narrow else 22, 29)
    world_eyebrow.visible = not compact
    world_title.position = Vector2(40 if not narrow else 22, 49 if not compact else 20)
    world_title.add_theme_font_size_override("font_size", 34 if not narrow else 28)
    world_note.position = Vector2(42 if not narrow else 24, 96)
    world_note.visible = not compact
    prefs_toggle.position = Vector2(size.x - 180, 35 if not compact else 20)
    prefs_toggle.size = Vector2(140, 48)
    if narrow:
        prefs_toggle.position = Vector2(size.x - 161, 134)
    brew_card.position = Vector2(40 if not narrow else 22, size.y - (202 if not compact else 183))
    brew_card.size = Vector2(310 if not narrow else size.x - 44, 168)
    corner_note.position = Vector2(size.x - 300, size.y - 30)
    corner_note.visible = not narrow and not compact
    _fit_panel()
    var margin := modal.get_node("Interior") as MarginContainer
    var inset := 20 if narrow or compact else 28
    margin.add_theme_constant_override("margin_left", inset)
    margin.add_theme_constant_override("margin_right", inset)
    margin.add_theme_constant_override("margin_top", 14 if compact else 22)
    margin.add_theme_constant_override("margin_bottom", 14 if compact else 22)
    var stack := margin.get_child(0) as VBoxContainer
    stack.add_theme_constant_override("separation", 9 if compact else 16)
    heading.add_theme_font_size_override("font_size", 25 if narrow or compact else 31)
    subtitle.visible = not compact
    content_columns.vertical = not compact
    content_columns.add_theme_constant_override("separation", 22 if not compact else 28)
    footer_note.visible = not narrow and not compact
    if narrow:
        cancel_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        apply_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    else:
        cancel_button.size_flags_horizontal = Control.SIZE_FILL
        apply_button.size_flags_horizontal = Control.SIZE_FILL
    queue_redraw()

func _fit_panel() -> void:
    var modal_width: float = minf(size.x - (32 if narrow else 64), 688)
    if compact:
        modal_width = minf(size.x - 40, 780)
    var modal_height: float = minf(size.y - (32 if narrow else 48), 650)
    if compact:
        modal_height = size.y - 28
    modal.size = Vector2(modal_width, modal_height)
    modal.position = (size - modal.size) / 2

func _open_settings() -> void:
    model.open_settings()
    syncing = true
    music_slider.value = model.draft.music
    sfx_slider.value = model.draft.sfx
    motion_toggle.button_pressed = model.draft.reduced_motion
    language_select.select(model.draft.language)
    syncing = false
    _refresh_text()
    overlay.show()
    content_scroll.scroll_vertical = 0
    music_slider.call_deferred("grab_focus")

func _cancel() -> void:
    model.cancel_settings()
    overlay.hide()
    prefs_toggle.grab_focus()

func _apply() -> void:
    model.apply_settings()
    overlay.hide()
    prefs_toggle.grab_focus()

func _brew() -> void:
    model.brew()
    brew_caption.text = "Ready to steep · %d tonics brewed" % model.brew_count

func _music_changed(value: float) -> void:
    if not syncing:
        model.draft.music = value
    music_value.text = "%d%%" % int(value)

func _sfx_changed(value: float) -> void:
    if not syncing:
        model.draft.sfx = value
    sfx_value.text = "%d%%" % int(value)

func _motion_changed(value: bool) -> void:
    if not syncing:
        model.draft.reduced_motion = value

func _language_changed(index: int) -> void:
    if not syncing:
        model.draft.language = index
    _refresh_text()

func _refresh_text() -> void:
    var extended: bool = int(model.draft.language) == 1
    music_label.text = "Background music volume during exploration" if extended else "Music"
    sfx_label.text = "Sound effects volume for tools and discoveries" if extended else "Sound effects"
    motion_label.text = "Reduce decorative motion and transition effects" if extended else "Reduced motion"
    music_value.text = "%d%%" % int(model.draft.music)
    sfx_value.text = "%d%%" % int(model.draft.sfx)

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and model.modal_open:
        _cancel()
        get_viewport().set_input_as_handled()

func _draw() -> void:
    var w := size.x
    var h := size.y
    draw_rect(Rect2(Vector2.ZERO, size), Color("102b2b"))
    var moon := Vector2(w * 0.76, h * 0.24)
    for i in range(6, 0, -1):
        draw_circle(moon, 46 + i * 18, Color(0.49, 0.66, 0.56, 0.012))
    draw_circle(moon, 44, Color("d5d9b6"))
    draw_circle(moon + Vector2(16, -8), 40, Color("193934"))
    # Tall greenhouse glazing gives the world depth around the parchment sheet.
    for i in range(6):
        var x := w * 0.28 + i * w * 0.145
        draw_line(Vector2(x, 0), Vector2(x, h * 0.75), Color("31524a"), 3, true)
    draw_line(Vector2(0, h * 0.36), Vector2(w, h * 0.36), Color("2f5148"), 3, true)
    draw_line(Vector2(0, h * 0.66), Vector2(w, h * 0.66), Color("3a5b4c"), 6, true)
    for i in range(19):
        var star := Vector2(fmod(float(i * 173 + 90), w), fmod(float(i * 71 + 32), maxf(h * 0.57, 1)))
        draw_circle(star, 1.3 if i % 3 else 2, Color("b4c49a8a"))
    # Shelves, specimen jars, and trailing plants are all vector scenery.
    draw_rect(Rect2(0, h * 0.72, w, h * 0.28), Color("183630"))
    draw_rect(Rect2(0, h * 0.72, w, 13), Color("6a6242"))
    draw_line(Vector2(0, h * 0.72 + 14), Vector2(w, h * 0.72 + 14), Color("262e27"), 4)
    for i in range(5):
        var p := Vector2(w - 70 - i * 59, h * 0.72)
        var jar_h: float = 48 + (i % 3) * 14
        draw_style_box(_style(Color("7eac8a32"), 8, Color("82a38875"), 1), Rect2(p - Vector2(15, jar_h), Vector2(30, jar_h)))
        draw_rect(Rect2(p - Vector2(12, jar_h + 5), Vector2(24, 7)), Color("9d8c5c"))
        draw_circle(p - Vector2(0, 18), 7, Color("b1b77277"))
    _draw_plant(Vector2(w - 42, h * 0.72), 1.3, false)
    _draw_plant(Vector2(55, h * 0.60), 1.0, true)
    var cauldron := Vector2(w * 0.53, h * 0.72 - 34)
    draw_circle(cauldron + Vector2(0, 24), 67, Color("0e2420"))
    draw_arc(cauldron, 65, 0, PI, 48, Color("536950"), 5, true)
    _paint_ellipse(cauldron, Vector2(66, 16), Color("73895b"))
    _paint_ellipse(cauldron - Vector2(0, 3), Vector2(58, 10), Color("aac281"))
    for i in range(3):
        var sx: float = cauldron.x - 24 + i * 25
        var pts := PackedVector2Array([Vector2(sx, cauldron.y - 22), Vector2(sx - 7, cauldron.y - 44), Vector2(sx + 5, cauldron.y - 66), Vector2(sx, cauldron.y - 86)])
        draw_polyline(pts, Color("b6d2a835"), 3, true)

func _paint_ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
    var pts := PackedVector2Array()
    for i in range(49):
        var angle := TAU * i / 48.0
        pts.append(center + Vector2(cos(angle), sin(angle)) * radius)
    draw_colored_polygon(pts, color)

func _draw_plant(base: Vector2, scale_factor: float, lean_right: bool) -> void:
    var direction := 1 if lean_right else -1
    draw_style_box(_style(Color("665f42"), 4), Rect2(base - Vector2(20, 28) * scale_factor, Vector2(40, 28) * scale_factor))
    var stem := base - Vector2(0, 28) * scale_factor
    for i in range(7):
        var next := stem + Vector2(direction * (3 + i), -21) * scale_factor
        draw_line(stem, next, Color("6e946b"), 2.5, true)
        var side := -1 if i % 2 else 1
        var leaf_tip := next + Vector2(side * 26, -14) * scale_factor
        var leaf := PackedVector2Array([next, next + Vector2(side * 6, -19) * scale_factor, leaf_tip, next + Vector2(side * 21, 1) * scale_factor])
        draw_colored_polygon(leaf, Color("50785b") if side < 0 else Color("729264"))
        stem = next
