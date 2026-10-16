extends SceneTree

const Model = preload("res://battle_model.gd")
var passed := 0
var failed := 0

func _initialize() -> void:
	test_initial_and_snapshot_copy()
	test_pause_contract()
	test_atomic_economy()
	test_start_and_real_combat()
	test_determinism()
	test_restart()
	test_terminal_replays()
	print("Shared battle model: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("FAIL: " + label)

func same(actual: Variant, expected: Variant, label: String) -> void:
	check(actual == expected, "%s (expected %s; got %s)" % [label, str(expected), str(actual)])

func gameplay(state: Dictionary) -> Dictionary:
	var copy: Dictionary = state.duplicate(true)
	copy.erase("revision")
	return copy

func test_initial_and_snapshot_copy() -> void:
	var model = Model.new()
	var state: Dictionary = model.snapshot()
	same(state["phase"], "active", "initial active phase")
	same(state["paused"], true, "initial paused capture")
	same(state["gold"], 360, "initial gold")
	same(state["crystal"], 12, "initial crystal")
	same(state["lives"], 20, "initial lives")
	same(state["wave_index"], 3, "initial wave")
	same(state["total_waves"], 8, "bounded waves")
	same(state["sites"].size(), 6, "six shared build sites")
	same(state["towers"].size(), 2, "two real initial towers")
	same(state["enemies"].size(), 3, "three real initial beetles")
	same(state["wave_spawn_remaining"], 7, "wave has real remaining spawns")
	same(state["selected_site_id"], -1, "initial selection empty")
	for index in range(3):
		same(state["enemies"][index]["path_progress"], [110.0, 230.0, 360.0][index], "initial beetle progress %d" % index)
	same(state["sites"][0]["position"], Vector2(510, 206), "ranger site position")
	same(state["sites"][4]["position"], Vector2(693, 401), "ember site position")
	same(model.path_position(0.0), Vector2(90, 230), "path source")
	same(model.path_position(100000.0), Vector2(1080, 252), "path endpoint clamp")
	state["towers"][0]["level"] = 99
	state["sites"][0]["position"] = Vector2.ZERO
	state["resources"]["gold"] = -999
	state["enemies"].clear()
	var fresh: Dictionary = model.snapshot()
	same(fresh["towers"][0]["level"], 1, "snapshot tower copy")
	same(fresh["sites"][0]["position"], Vector2(510, 206), "snapshot site copy")
	same(fresh["gold"], 360, "snapshot resources copy")
	same(fresh["enemies"].size(), 3, "snapshot enemies copy")

func test_pause_contract() -> void:
	var model = Model.new()
	var before: Dictionary = model.snapshot()
	model.advance(12.0)
	same(model.snapshot(), before, "pause freezes complete snapshot")
	for command in [{"type": "start_wave"}, {"type": "build", "site_id": 1, "tower_type": "ranger"}, {"type": "upgrade", "tower_id": 0}]:
		same(model.dispatch(command)["reason"], "paused", "pause rejects gameplay command")
	same(model.snapshot(), before, "rejected paused commands do not mutate")
	check(model.dispatch({"type": "select_site", "site_id": 4})["ok"], "selection allowed while paused")
	same(model.snapshot()["selected_tower_id"], 1, "paused selection resolves tower")
	check(model.dispatch({"type": "clear_selection"})["ok"], "selection can clear while paused")
	same(model.dispatch({"type": "set_paused", "paused": "false"})["reason"], "invalid_pause_value", "pause requires bool")
	check(model.dispatch({"type": "set_paused", "paused": false})["ok"], "resume succeeds")
	model.advance(0.1)
	same(model.snapshot()["tick"], 6, "resume has no paused catch-up")
	model.dispatch({"type": "set_paused", "paused": true})
	before = model.snapshot()
	model.advance(5.0)
	same(model.snapshot(), before, "active pause freezes combat and projectiles")

func test_atomic_economy() -> void:
	var model = Model.new()
	model.reset_ready()
	same(model.dispatch({"type": "build", "site_id": 1, "tower_type": "ranger"})["ok"], true, "affordable build succeeds")
	var state: Dictionary = model.snapshot()
	same(state["gold"], 280, "one build debit")
	same(state["towers"].size(), 3, "one build instance")
	same(state["selected_site_id"], 1, "build selects site")
	var before: Dictionary = state
	same(model.dispatch({"type": "build", "site_id": 1, "tower_type": "ranger"})["reason"], "occupied", "duplicate build rejected")
	same(model.snapshot(), before, "duplicate build atomic")
	same(model.dispatch({"type": "build", "site_id": 99, "tower_type": "ranger"})["reason"], "unknown_site", "unknown site rejected")
	same(model.dispatch({"type": "build", "site_id": 2, "tower_type": "unknown"})["reason"], "unknown_tower_type", "unknown tower rejected")
	same(model.dispatch({"type": "upgrade", "tower_id": 99})["reason"], "unknown_tower", "unknown upgrade rejected")
	same(model.snapshot(), before, "invalid commands leave complete state unchanged")
	check(model.dispatch({"type": "upgrade", "tower_id": 2})["ok"], "first upgrade succeeds")
	same(model.snapshot()["gold"], 180, "first upgrade costs 100")
	check(model.dispatch({"type": "upgrade", "tower_id": 2})["ok"], "second upgrade succeeds")
	state = model.snapshot()
	same(state["gold"], 20, "second upgrade costs 160")
	same(state["towers"][2]["level"], 3, "level reaches maximum 3")
	check(float(state["towers"][2]["damage"]) > 26.0, "upgrade changes authoritative damage")
	before = state
	same(model.dispatch({"type": "upgrade", "tower_id": 2})["reason"], "maximum_level", "max level rejected")
	same(model.dispatch({"type": "build", "site_id": 2, "tower_type": "frost"})["reason"], "insufficient_gold", "unaffordable build rejected")
	same(model.dispatch({"type": "upgrade", "tower_id": 0})["reason"], "insufficient_gold", "unaffordable upgrade rejected")
	same(model.snapshot(), before, "failed purchases never debit or change state")
	check(not state["available_actions"]["can_build_by_site"][2]["frost"], "UI availability agrees with affordability")
	check(not state["available_actions"]["can_upgrade_by_tower"][2], "UI availability agrees with maximum level")
	same(model.dispatch({"type": "unknown"})["reason"], "unknown_command", "unknown command rejected")

func test_start_and_real_combat() -> void:
	var model = Model.new()
	model.reset_ready()
	check(model.snapshot()["available_actions"]["can_start"], "ready offers next wave")
	check(model.dispatch({"type": "start_wave"})["ok"], "start begins next wave")
	same(model.snapshot()["wave_index"], 3, "start increments wave once")
	var before: Dictionary = model.snapshot()
	same(model.dispatch({"type": "start_wave"})["reason"], "wave_unavailable", "duplicate start rejected")
	same(model.snapshot(), before, "duplicate start no state mutation")
	model.advance(0.1)
	check(model.snapshot()["enemies"].size() > 0, "wave spawns real enemies")
	model.reset()
	model.dispatch({"type": "set_paused", "paused": false})
	model.advance(0.1)
	var state: Dictionary = model.snapshot()
	check(float(state["enemies"][0]["path_progress"]) > 110.0, "enemy advances along path")
	check(state["projectiles"].size() > 0, "real tower attacks create projectiles")
	var projectile_start: Vector2 = state["projectiles"][0]["position"]
	model.advance(0.1)
	state = model.snapshot()
	check(state["projectiles"].size() > 0 and Vector2(state["projectiles"][0]["position"]).distance_to(projectile_start) > 1.0, "projectiles move in simulation")
	model.advance(12.0)
	check(model.snapshot()["gold"] > 360, "combat kills award actual gold")
	model.advance(-1.0)
	model.advance(NAN)
	check(model.snapshot()["gold"] >= 0, "invalid time input is ignored")

func test_determinism() -> void:
	var model_a = Model.new()
	var model_b = Model.new()
	model_a.dispatch({"type": "set_paused", "paused": false})
	model_b.dispatch({"type": "set_paused", "paused": false})
	model_a.advance(8.0)
	for index in range(480):
		model_b.advance(1.0 / 60.0)
	same(gameplay(model_a.snapshot()), gameplay(model_b.snapshot()), "fixed step matches one large versus 480 small advances")
	var model_c = Model.new()
	model_c.dispatch({"type": "set_paused", "paused": false})
	for index in range(80):
		model_c.advance(0.035)
		model_c.advance(0.065)
	same(gameplay(model_a.snapshot()), gameplay(model_c.snapshot()), "irregular rendering deltas preserve replay")

func test_restart() -> void:
	var model = Model.new()
	var initial: Dictionary = gameplay(model.snapshot())
	model.dispatch({"type": "select_site", "site_id": 0})
	model.dispatch({"type": "set_paused", "paused": false})
	model.dispatch({"type": "upgrade", "tower_id": 0})
	model.advance(4.0)
	check(model.dispatch({"type": "restart"})["ok"], "restart succeeds")
	same(gameplay(model.snapshot()), initial, "restart restores declared paused capture including actors/resources/events/selection")

func test_terminal_replays() -> void:
	var winning = Model.new()
	winning.reset_ready()
	for site_id in [1, 2, 3, 5]:
		winning.dispatch({"type": "build", "site_id": site_id, "tower_type": "ranger"})
	for wave in range(3, 9):
		var ready: Dictionary = winning.snapshot()
		for tower in ready["towers"]:
			while winning.dispatch({"type": "upgrade", "tower_id": tower["id"]})["ok"]:
				pass
		check(winning.dispatch({"type": "start_wave"})["ok"], "winning replay starts wave %d" % wave)
		winning.advance(90.0)
	same(winning.snapshot()["phase"], "won", "bounded all-wave replay can win")
	same(winning.snapshot()["wave_index"], 8, "win stops at final wave")
	check(winning.snapshot()["lives"] > 0, "winning defense preserves lives")
	same(winning.dispatch({"type": "start_wave"})["reason"], "wave_unavailable", "cannot start wave 9")
	var lost = Model.new()
	lost.reset_ready()
	for index in range(6):
		if lost.snapshot()["phase"] != "ready":
			break
		lost.dispatch({"type": "start_wave"})
		lost.advance(90.0)
	var loss: Dictionary = lost.snapshot()
	same(loss["phase"], "lost", "unreinforced all-wave replay can lose")
	same(loss["lives"], 0, "leaks exhaust lives without negative value")
	lost.advance(10.0)
	same(lost.snapshot(), loss, "terminal loss stops gameplay")
	same(lost.dispatch({"type": "build", "site_id": 1, "tower_type": "ranger"})["reason"], "game_over", "terminal purchase rejected")
	check(lost.dispatch({"type": "restart"})["ok"], "restart works after loss")
	same(lost.snapshot()["phase"], "active", "loss restart restores active fixture")
	same(lost.snapshot()["paused"], true, "loss restart restores pause")
