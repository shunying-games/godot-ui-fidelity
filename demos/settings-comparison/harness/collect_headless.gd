extends SceneTree
## Geometry diagnostic only. Run against a frozen candidate copy.
## Never simulates pointer/keyboard input or claims rendered UI acceptance.

var _sizes: Array[Vector2i] = [Vector2i(1280, 800), Vector2i(390, 844), Vector2i(844, 390)]
var _output := ""
var _minimum_frames := 12

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--sizes="):
            _sizes.clear()
            for item in arg.trim_prefix("--sizes=").split(","):
                var pair := item.split("x")
                if pair.size() != 2 or not pair[0].is_valid_int() or not pair[1].is_valid_int():
                    push_error("Invalid --sizes; expected WIDTHxHEIGHT entries")
                    quit(2)
                    return
                var dimensions := Vector2i(int(pair[0]), int(pair[1]))
                if dimensions.x < 1 or dimensions.y < 1:
                    quit(2)
                    return
                _sizes.append(dimensions)
        elif arg.begins_with("--out="):
            _output = arg.trim_prefix("--out=")
        elif arg.begins_with("--frames="):
            _minimum_frames = clampi(int(arg.trim_prefix("--frames=")), 6, 120)
    var probe_script: Script = load(get_script().resource_path.get_base_dir().path_join("probe.gd"))
    if probe_script == null:
        quit(2)
        return
    var scene_path: String = ProjectSettings.get_setting("application/run/main_scene", "")
    var packed: PackedScene = load(scene_path)
    if packed == null:
        push_error("Configured main scene did not load")
        quit(2)
        return
    root.size = _sizes[0]
    var app := packed.instantiate()
    root.add_child(app)
    current_scene = app
    var probe: Node = probe_script.new()
    probe.set_target(app)
    root.add_child(probe)
    var samples: Array = []
    for dimensions in _sizes:
        root.size = dimensions
        var previous := ""
        var stable_frames := 0
        var frames := 0
        var snapshot: Dictionary = {}
        while frames < _minimum_frames + 60:
            await process_frame
            frames += 1
            snapshot = probe.collect_snapshot()
            var fingerprint := JSON.stringify({"viewport": snapshot["viewport"], "controls": snapshot["controls"], "labels": snapshot["labels"], "scroll_containers": snapshot["scroll_containers"]})
            stable_frames = stable_frames + 1 if fingerprint == previous else 0
            previous = fingerprint
            if frames >= _minimum_frames and stable_frames >= 3:
                break
        samples.append({"requested_size": [dimensions.x, dimensions.y], "settled_frames": frames, "stable_for_three_frames": stable_frames >= 3, "snapshot": snapshot})
    var report := {"schema": "godot-ui-study-headless-v1", "rendered_acceptance": false, "purpose": "settled geometry diagnostic only", "samples": samples}
    var serialized := JSON.stringify(report, "  ")
    if _output.is_empty():
        print(serialized)
    else:
        var file := FileAccess.open(_output, FileAccess.WRITE)
        if file == null:
            push_error("Could not open requested geometry output")
            quit(2)
            return
        file.store_string(serialized + "\n")
        file.close()
        print("HEADLESS_GEOMETRY_WRITTEN; rendered_acceptance=false; samples=" + str(samples.size()))
    quit(0)
