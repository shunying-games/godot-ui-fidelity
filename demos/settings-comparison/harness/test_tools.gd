extends SceneTree
## Tests only the shared model and synthetic controls, never a candidate.

class SyntheticRoot extends Control:
    var model: RefCounted
    func get_probe_state() -> Dictionary:
        return model.snapshot()

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, description: String) -> void:
    _checks += 1
    if not condition:
        _failures.append(description)
        push_error(description)

func _run() -> void:
    var directory: String = get_script().resource_path.get_base_dir()
    var model_script: Script = load(directory.path_join("../shared/settings_model.gd").simplify_path())
    var probe_script: Script = load(directory.path_join("probe.gd"))
    if model_script == null or probe_script == null:
        quit(2)
        return
    var model: RefCounted = model_script.new()
    _check(model.snapshot()["saved"]["music"] == 60.0, "initial music is 60")
    _check(model.snapshot()["saved"]["sfx"] == 80.0, "initial effects is 80")
    model.brew()
    _check(model.brew_count == 1, "unpaused closed model permits brew")
    model.open_settings()
    _check(model.modal_open and model.paused, "open pauses model")
    model.draft["music"] = 35.0
    model.draft["language"] = 1
    _check(model.saved["music"] == 60.0, "draft edits do not alter saved")
    model.open_settings()
    _check(model.draft["music"] == 35.0, "duplicate open preserves draft")
    model.brew()
    _check(model.brew_count == 1, "modal model blocks brew")
    var snapshot: Dictionary = model.snapshot()
    snapshot["draft"]["music"] = 7.0
    snapshot["saved"]["sfx"] = 8.0
    _check(model.draft["music"] == 35.0 and model.saved["sfx"] == 80.0, "snapshot nested dictionaries are copies")
    model.cancel_settings()
    _check(not model.modal_open and not model.paused, "cancel restores unpaused state")
    _check(model.draft == model.saved and model.saved["music"] == 60.0, "cancel discards draft")
    _check(model.apply_count == 0, "cancel does not apply")
    model.open_settings()
    model.draft["music"] = 42.0
    model.draft["reduced_motion"] = true
    model.draft["language"] = 1
    model.apply_settings()
    _check(model.saved["music"] == 42.0 and model.saved["reduced_motion"] and model.saved["language"] == 1, "apply commits settings")
    _check(model.apply_count == 1 and not model.modal_open, "apply closes once")
    model.apply_settings()
    _check(model.apply_count == 1, "duplicate apply while closed is inert")
    model.paused = true
    model.open_settings()
    model.cancel_settings()
    _check(model.paused, "cancel restores a prior pause")
    model.open_settings()
    model.apply_settings()
    _check(model.paused, "apply restores a prior pause")
    model.brew()
    _check(model.brew_count == 1, "prior pause blocks brew after modal closes")
    var synthetic := SyntheticRoot.new()
    synthetic.name = "SyntheticRoot"
    synthetic.model = model
    synthetic.size = Vector2(390, 844)
    root.size = Vector2i(390, 844)
    root.add_child(synthetic)
    var clipping := Control.new()
    clipping.name = "SyntheticClip"
    clipping.position = Vector2(10, 20)
    clipping.size = Vector2(120, 80)
    clipping.clip_contents = true
    synthetic.add_child(clipping)
    var slider := HSlider.new()
    slider.name = "MusicSlider"
    slider.position = Vector2(30, 40)
    slider.size = Vector2(180, 44)
    slider.min_value = 0
    slider.max_value = 100
    slider.value = 42
    clipping.add_child(slider)
    var label := Label.new()
    label.name = "SyntheticLabel"
    label.text = "Synthetic label"
    label.position = Vector2(200, 120)
    label.size = Vector2(150, 30)
    synthetic.add_child(label)
    var probe: Node = probe_script.new()
    probe.set_target(synthetic)
    root.add_child(probe)
    await process_frame
    await process_frame
    var before: Dictionary = model.snapshot()
    var evidence: Dictionary = probe.collect_snapshot()
    _check(evidence["state_available"], "probe sees model snapshot method")
    _check(evidence["state"] == before and model.snapshot() == before, "probe is passive")
    _check(evidence["viewport"]["size"] == [390.0, 844.0], "probe reports requested viewport")
    _check(evidence["controls"]["MusicSlider"]["range"]["value"] == 42.0, "probe reports actual slider value")
    var geometry: Dictionary = evidence["controls"]["MusicSlider"]
    _check(geometry["rect"]["x"] == 40.0 and geometry["rect"]["y"] == 60.0, "probe includes parent transform")
    _check(geometry["visible_rect"]["width"] == 90.0 and geometry["visible_rect"]["height"] == 40.0, "probe intersects clipping parent")
    _check(evidence["missing_controls"].size() == 8, "probe detects absent required controls")
    _check(evidence["labels"].size() == 1, "probe exposes actual Label geometry")
    _check(evidence["clickable_controls"].size() == 1, "probe exposes actual clickable controls")
    _check(probe._safe_text("res://private.gd") == "[path omitted]", "probe filters resource locations")
    print("SHARED_TOOL_TESTS checks=" + str(_checks) + " failures=" + str(_failures.size()) + "; candidate_ui_acceptance=false")
    quit(0 if _failures.is_empty() else 1)
