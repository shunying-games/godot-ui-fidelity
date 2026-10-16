extends RefCounted

var saved := {"music": 60.0, "sfx": 80.0, "reduced_motion": false, "language": 0}
var draft: Dictionary = saved.duplicate(true)
var modal_open := false
var paused := false
var pause_before := false
var apply_count := 0
var brew_count := 0

func open_settings() -> void:
    if modal_open:
        return
    pause_before = paused
    paused = true
    draft = saved.duplicate(true)
    modal_open = true

func cancel_settings() -> void:
    if not modal_open:
        return
    draft = saved.duplicate(true)
    modal_open = false
    paused = pause_before

func apply_settings() -> void:
    if not modal_open:
        return
    saved = draft.duplicate(true)
    apply_count += 1
    modal_open = false
    paused = pause_before

func brew() -> void:
    if not modal_open and not paused:
        brew_count += 1

func snapshot() -> Dictionary:
    return {"saved": saved.duplicate(true), "draft": draft.duplicate(true),
        "modal_open": modal_open, "paused": paused, "apply_count": apply_count,
        "brew_count": brew_count}
