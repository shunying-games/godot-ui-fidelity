extends Node
## Passive evidence collector. Attach only after the candidate source is frozen.
## Never changes model state, focus, pointer position, or control properties.

const REQUIRED_NAMES := ["MusicSlider", "SfxSlider", "MotionToggle", "LanguageSelect", "ApplyButton", "CancelButton", "CloseButton", "BrewButton", "PrefsToggle"]
const MODAL_NAMES := ["MusicSlider", "SfxSlider", "MotionToggle", "LanguageSelect", "ApplyButton", "CancelButton", "CloseButton"]
const STATE_SCALARS := ["modal_open", "paused", "apply_count", "brew_count"]
const SETTING_KEYS := ["music", "sfx", "reduced_motion", "language"]

var _target: Node
var _elapsed := 0.0
var _sample_index := 0
var _last_payload: Dictionary = {}

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _publish()

func set_target(target: Node) -> void:
    _target = target

func _process(delta: float) -> void:
    _elapsed += delta
    if _elapsed >= 0.12:
        _elapsed = 0.0
        _publish()

func _find_target() -> Node:
    if is_instance_valid(_target):
        return _target
    var tree := get_tree()
    if tree.current_scene != null and tree.current_scene.has_method("get_probe_state"):
        _target = tree.current_scene
        return _target
    for child in tree.root.get_children():
        if child != self and child.has_method("get_probe_state"):
            _target = child
            return _target
    return null

func collect_snapshot() -> Dictionary:
    _sample_index += 1
    var viewport := get_viewport()
    var viewport_rect := viewport.get_visible_rect()
    var target := _find_target()
    var report := {
        "schema": "godot-ui-study-passive-v1",
        "sample_index": _sample_index,
        "viewport": {"rect": _rect(viewport_rect), "size": _v(viewport_rect.size), "window_size": _v(Vector2(get_window().size)), "canvas_transform": _transform(viewport.get_canvas_transform()), "final_transform": _transform(viewport.get_final_transform())},
        "state_available": false,
        "state": {},
        "controls": {},
        "missing_controls": [],
        "duplicate_control_names": [],
        "modal_controls_visible": {},
        "clickable_controls": [],
        "labels": [],
        "scroll_containers": [],
        "label_limit_reached": false
    }
    if target == null:
        return report
    report["root_type"] = target.get_class()
    if target is CanvasItem:
        report["root_transform"] = _transform(target.get_global_transform_with_canvas())
    if target.has_method("get_probe_state"):
        var observed: Variant = target.call("get_probe_state")
        if observed is Dictionary:
            report["state_available"] = true
            report["state"] = _state_only(observed)
    var nodes: Array[Node] = []
    _walk(target, nodes)
    var matches: Dictionary = {}
    for key in REQUIRED_NAMES:
        matches[key] = []
    for node in nodes:
        if node is Control:
            var control := node as Control
            var key := str(control.name)
            if matches.has(key):
                matches[key].append(control)
            if _is_clickable(control):
                var geometry := _geometry(control, viewport_rect)
                report["clickable_controls"].append({"name": _safe_text(key), "type": control.get_class(), "visible": geometry["visible"], "disabled": _disabled(control), "rect": geometry["rect"], "visible_rect": geometry["visible_rect"], "center": geometry["center"], "visible_center": geometry["visible_center"], "mouse_filter": control.mouse_filter, "focus_mode": control.focus_mode})
            if control is Label or control is RichTextLabel:
                if report["labels"].size() < 80:
                    report["labels"].append(_label(control, viewport_rect))
                else:
                    report["label_limit_reached"] = true
            if control is ScrollContainer:
                var sc := control as ScrollContainer
                report["scroll_containers"].append({"name": _safe_text(key), "geometry": _geometry(sc, viewport_rect), "horizontal": _range(sc.get_h_scroll_bar()), "vertical": _range(sc.get_v_scroll_bar())})
    for key in REQUIRED_NAMES:
        var found: Array = matches[key]
        if found.is_empty():
            report["missing_controls"].append(key)
        else:
            var samples: Array = []
            for control in found:
                samples.append(_control(control, viewport_rect))
            report["controls"][key] = samples[0] if samples.size() == 1 else samples
            if found.size() > 1:
                report["duplicate_control_names"].append(key)
        if key in MODAL_NAMES:
            report["modal_controls_visible"][key] = false if found.is_empty() else found.any(func(c: Control) -> bool: return c.is_visible_in_tree())
    return report

func _publish() -> void:
    if not is_inside_tree():
        return
    _last_payload = collect_snapshot()
    if OS.has_feature("web"):
        var literal := JSON.stringify(JSON.stringify(_last_payload))
        JavaScriptBridge.eval("(function(){var e=document.getElementById('ui-study-probe');if(!e){e=document.createElement('script');e.id='ui-study-probe';e.type='application/json';document.body.appendChild(e);}e.textContent=" + literal + ";})()", true)

func _walk(node: Node, output: Array[Node]) -> void:
    output.append(node)
    for child in node.get_children():
        _walk(child, output)

func _control(control: Control, viewport_rect: Rect2) -> Dictionary:
    var result := _geometry(control, viewport_rect)
    result["type"] = control.get_class()
    result["mouse_filter"] = control.mouse_filter
    result["focus_mode"] = control.focus_mode
    result["disabled"] = _disabled(control)
    result["minimum_size"] = _v(control.get_combined_minimum_size())
    result["parent_transforms"] = _parents(control)
    if control is BaseButton:
        result["pressed"] = control.button_pressed
    if control is Button:
        result["text"] = _safe_text(control.text)
        result["text_metrics"] = _font_metrics(control, control.text)
        result["text_flags"] = _properties(control, ["clip_text", "text_overrun_behavior", "autowrap_mode"])
    if control is Range:
        result["range"] = _range(control)
    if control is Slider:
        result["editable"] = control.editable
        result["scrollable"] = control.scrollable
    if control is OptionButton:
        var option := control as OptionButton
        result["selected"] = option.selected
        result["options"] = []
        for index in range(option.item_count):
            result["options"].append({"index": index, "text": _safe_text(option.get_item_text(index)), "disabled": option.is_item_disabled(index)})
        var popup := option.get_popup()
        result["popup"] = {"visible": popup.visible, "position": _v(Vector2(popup.position)), "size": _v(Vector2(popup.size)), "embedded": popup.is_embedded()}
    var child_labels: Array = []
    var descendants: Array[Node] = []
    _walk(control, descendants)
    for node in descendants:
        if node != control and (node is Label or node is RichTextLabel) and child_labels.size() < 6:
            child_labels.append(_label(node, viewport_rect))
    if not child_labels.is_empty():
        result["child_labels"] = child_labels
    return result

func _geometry(control: Control, viewport_rect: Rect2) -> Dictionary:
    var transform := control.get_global_transform_with_canvas()
    var points := [transform * Vector2.ZERO, transform * Vector2(control.size.x, 0), transform * control.size, transform * Vector2(0, control.size.y)]
    var bounds := Rect2(points[0], Vector2.ZERO)
    for point in points:
        bounds = bounds.expand(point)
    var visible_rect := bounds.intersection(viewport_rect)
    var clipped_by: Array = []
    var parent := control.get_parent()
    while parent != null:
        if parent is Control and parent.clip_contents:
            var parent_bounds := _bounds(parent)
            visible_rect = visible_rect.intersection(parent_bounds)
            clipped_by.append(_safe_text(str(parent.name)))
        parent = parent.get_parent()
    var visible := control.is_visible_in_tree()
    if not visible:
        visible_rect = Rect2()
    var center := transform * (control.size * 0.5)
    return {"visible": visible, "local_size": _v(control.size), "rect": _rect(bounds), "visible_rect": _rect(visible_rect), "center": _v(center), "visible_center": _v(visible_rect.get_center()) if visible_rect.has_area() else null, "center_in_viewport": viewport_rect.has_point(center), "corners": points.map(func(p: Vector2) -> Array: return _v(p)), "global_transform": _transform(transform), "clipped_by": clipped_by, "modulate_alpha": _number(control.modulate.a), "self_modulate_alpha": _number(control.self_modulate.a), "z_index": control.z_index}

func _bounds(control: Control) -> Rect2:
    var transform := control.get_global_transform_with_canvas()
    var bounds := Rect2(transform * Vector2.ZERO, Vector2.ZERO)
    for point in [Vector2(control.size.x, 0), control.size, Vector2(0, control.size.y)]:
        bounds = bounds.expand(transform * point)
    return bounds

func _parents(control: Control) -> Array:
    var result: Array = []
    var node := control.get_parent()
    while node != null and result.size() < 10:
        if node is CanvasItem:
            var entry := {"name": _safe_text(str(node.name)), "type": node.get_class(), "transform": _transform(node.get_transform()), "global_transform": _transform(node.get_global_transform_with_canvas()), "visible": node.is_visible_in_tree()}
            if node is Control:
                entry["size"] = _v(node.size)
                entry["clip_contents"] = node.clip_contents
            result.append(entry)
        elif node is CanvasLayer:
            result.append({"name": _safe_text(str(node.name)), "type": "CanvasLayer", "layer": node.layer, "transform": _transform(node.transform)})
        node = node.get_parent()
    return result

func _label(control: Control, viewport_rect: Rect2) -> Dictionary:
    var geometry := _geometry(control, viewport_rect)
    var result := {"name": _safe_text(str(control.name)), "type": control.get_class(), "text": _safe_text(control.text), "visible": geometry["visible"], "rect": geometry["rect"], "visible_rect": geometry["visible_rect"], "minimum_size": _v(control.get_combined_minimum_size()), "clipped_by": geometry["clipped_by"]}
    if control is Label:
        result["lines"] = control.get_line_count()
        result["visible_lines"] = control.get_visible_line_count()
        result["clip_text"] = control.clip_text
        result["autowrap_mode"] = control.autowrap_mode
        result["text_overrun_behavior"] = control.text_overrun_behavior
        result["text_metrics"] = _font_metrics(control, control.text)
    elif control is RichTextLabel:
        result["content_size"] = [_number(control.get_content_width()), _number(control.get_content_height())]
        result["scroll_active"] = control.scroll_active
    return result

func _font_metrics(control: Control, value: String) -> Dictionary:
    var font := control.get_theme_font("font")
    var font_size := control.get_theme_font_size("font_size")
    if font == null:
        return {}
    var maximum_width := 0.0
    for line in value.split("\n"):
        maximum_width = maxf(maximum_width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
    return {"font_size": font_size, "unwrapped_max_line_width": _number(maximum_width), "font_height": _number(font.get_height(font_size)), "estimate_only": true}

func _properties(object: Object, names: Array) -> Dictionary:
    var available: Dictionary = {}
    for entry in object.get_property_list():
        available[entry.name] = true
    var result: Dictionary = {}
    for key in names:
        if available.has(key):
            result[key] = object.get(key)
    return result

func _range(control: Range) -> Dictionary:
    return {"minimum": _number(control.min_value), "maximum": _number(control.max_value), "step": _number(control.step), "value": _number(control.value), "page": _number(control.page), "ratio": _number(control.ratio)}

func _is_clickable(control: Control) -> bool:
    return control is BaseButton or control is Slider or control is ScrollBar

func _disabled(control: Control) -> bool:
    if control is BaseButton:
        return control.disabled
    if control is Slider:
        return not control.editable
    return false

func _state_only(observed: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for key in STATE_SCALARS:
        if observed.has(key) and (observed[key] is bool or observed[key] is int or observed[key] is float):
            result[key] = observed[key]
    for section in ["saved", "draft"]:
        if observed.get(section) is Dictionary:
            var settings: Dictionary = {}
            for key in SETTING_KEYS:
                if observed[section].has(key) and (observed[section][key] is bool or observed[section][key] is int or observed[section][key] is float):
                    settings[key] = observed[section][key]
            result[section] = settings
    return result

func _safe_text(value: String) -> String:
    # Never publish resource/file locations if accidentally used as UI text.
    if "res://" in value or "user://" in value or "/Users/" in value or "/private/" in value or "/tmp/" in value or "file://" in value:
        return "[path omitted]"
    return value.left(180)

func _v(value: Vector2) -> Array:
    return [_number(value.x), _number(value.y)]

func _rect(value: Rect2) -> Dictionary:
    return {"x": _number(value.position.x), "y": _number(value.position.y), "width": _number(value.size.x), "height": _number(value.size.y)}

func _transform(value: Transform2D) -> Dictionary:
    return {"x": _v(value.x), "y": _v(value.y), "origin": _v(value.origin)}

func _number(value: float) -> float:
    return snappedf(value, 0.001)
