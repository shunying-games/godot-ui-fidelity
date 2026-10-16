extends SceneTree
## Validate only the passive evidence tool; never claim candidate UI acceptance.
class SyntheticRoot extends Control:
    var model = preload("res://battle_model.gd").new()
    func get_probe_state() -> Dictionary:
        var result: Dictionary = model.snapshot()
        result["ui"] = {"selected_build_type": "ranger"}
        return result

var failures := 0
var checks := 0

func _initialize() -> void:
    call_deferred("run_checks")

func check(condition: bool) -> void:
    checks += 1
    if not condition:
        failures += 1
        push_error("Passive probe check failed: " + str(checks))

func run_checks() -> void:
    var target := SyntheticRoot.new()
    root.add_child(target)
    var script: Script = load(get_script().resource_path.get_base_dir().path_join("probe.gd"))
    var probe: Node = script.new()
    probe.set_target(target)
    root.add_child(probe)
    await process_frame
    var before: Dictionary = target.model.snapshot()
    var evidence: Dictionary = probe.collect_snapshot()
    check(evidence["state_available"])
    check(evidence["state"]["gold"] == 360)
    check(evidence["state"]["sites"][0]["position"] == [510.0, 206.0])
    check(evidence["state"]["ui"]["selected_build_type"] == "ranger")
    check(target.model.snapshot() == before)
    check(evidence["missing_controls"].size() == 7)
    check(JSON.parse_string(JSON.stringify(evidence)) is Dictionary)
    check(probe._safe_text("res://example.gd") == "[path omitted]")
    print("BATTLE_PROBE checks=" + str(checks) + " failures=" + str(failures) + "; candidate_ui_acceptance=false")
    quit(0 if failures == 0 else 1)
