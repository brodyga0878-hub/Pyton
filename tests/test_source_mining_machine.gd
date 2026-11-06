extends SceneTree

const Machine = preload("res://scripts/source_mining_machine.gd")
var checks := 0
var failures := 0


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)


func _initialize() -> void:
	var weekly_text := FileAccess.get_file_as_string("res://tests/fixtures/source_mining_weekly_native.json")
	var load_text := FileAccess.get_file_as_string("res://tests/fixtures/source_mining_load_native.json")
	var weekly: Dictionary = JSON.parse_string(weekly_text)
	var loading: Dictionary = JSON.parse_string(load_text)
	check(weekly_text.sha256_text() == "3d3cd01a636a925e2b97580e58f3448bac851b23d1b62d1fcd4d3bf74b785092", "Pinned independent actual F243 control fixture")
	check(load_text.sha256_text() == "f844c87d1d3eeb19c7a2855f599ddff6f5b41f9ae2c160232eebb4f7f71c8368", "Pinned independent actual F247/F252 control fixture")
	check(weekly.source_assembly_sha256 == Machine.SOURCE_ASM_SHA256 and weekly.f243_sha256 == Machine.F243_SHA256, "Exact reviewed source F243 instructions")
	check(loading.source_function_sha256["247"] == Machine.F247_SHA256 and loading.source_function_sha256["252"] == Machine.F252_SHA256, "Exact reviewed source F247/F252 instructions")
	check(weekly.case_count == 2816 and weekly.fresh_process_runs == 3 and weekly.reverse_order_repeat_cases == 2816 and weekly.record_guards_unchanged and weekly.non_hopper_reserve_record_bytes_unchanged, "Original F243 repeat/order and mutation boundary checks")
	check(loading.case_count == 990 and loading.fresh_process_runs == 3 and loading.reverse_order_repeat_cases == 990 and loading.record_guards_unchanged and loading.non_hopper_record_bytes_unchanged, "Original F247 repeat/order and mutation boundary checks")
	check(loading.commodity_map_original_executable_verified and loading.commodity_map_executable_offset == 778488, "F247 commodity table independently found uniquely in verified original EXE")
	for index in range(9):
		check(int(loading.commodity_map[index]) == int(Machine.COMMODITY_BY_PROSPECT[index]), "Original DATA5058 commodity mapping")
	var transitions := {}
	for row: Dictionary in weekly.cases:
		var machine := Machine.new()
		check(machine.configure(row.hopper_before, row.remaining_raw_before, 3), "Valid independent original weekly record configures")
		var result := machine.apply_weekly_event()
		check(result.ok and machine.hopper_tonnes() == int(row.hopper_after) and machine.remaining_raw() == int(row.remaining_raw_after), "Exact actual native F243 hopper/reserve result")
		check(int(result.produced_tonnes) == int(row.hopper_after) - int(row.hopper_before), "Actual native F243 production delta")
		transitions["%d:%d" % [int(row.hopper_before), int(row.remaining_raw_before)]] = row
	for row: Dictionary in loading.cases:
		var machine := Machine.new()
		check(machine.configure(row.hopper_before, 15, row.prospect), "Valid independent normal-MB4 F247 input configures")
		var result := machine.request_load(row.free_cargo_tonnes)
		check(result.ok and machine.hopper_tonnes() == int(row.hopper_after) and machine.remaining_raw() == 15, "Actual native F247 changes hopper only")
		check(int(result.loaded_tonnes) == int(row.cargo_used_added), "Exact actual native F247 inventory mass delta")
		for index in range(32):
			var amount := int(result.loaded_tonnes) if index == int(result.commodity_index) else 0
			check(amount == int(row.commodity_tonnes_added[index]), "Actual native F247 commodity-specific cargo delta")
		check(result.retrieval_animation_requested == row.retrieval_animation_requested and int(result.near_machine_flag_after) == int(row.near_machine_flag_after), "Actual native F247 empty-hopper retrieval request / near flag")
		check(int(result.message_ffcode) == int(row.message_ffcode), "Actual native F247 partial/full/empty/refused message")
	batch_controls(transitions)
	save_and_rejections()
	print("SOURCE MINING MACHINE TESTS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func batch_controls(transitions: Dictionary) -> void:
	for hopper in [0, 9, 10]:
		for reserve in [0, 1, 10, 127, 128, 255]:
			for count in [0, 1, 2, 7, 10, 127, 2147483647]:
				var expected_hopper: int = hopper
				var expected_reserve: int = reserve
				# Repeated independent original instruction outputs until fixed point;
				# the large-batch result does not use a second production formula.
				for _event in range(mini(count, 128)):
					var row: Dictionary = transitions["%d:%d" % [expected_hopper, expected_reserve]]
					if int(row.hopper_after) == expected_hopper and int(row.remaining_raw_after) == expected_reserve:
						break
					expected_hopper = int(row.hopper_after)
					expected_reserve = int(row.remaining_raw_after)
				var machine := Machine.new()
				check(machine.configure(hopper, reserve, 3), "Batch initial original state configures")
				var result := machine.apply_weekly_events(count)
				check(result.ok and machine.hopper_tonnes() == expected_hopper and machine.remaining_raw() == expected_reserve, "Bounded batch equals repeated independent original F243 transitions")
	var water := Machine.new()
	check(water.configure(0, 255, 2) and water.apply_weekly_events(2147483647).produced_tonnes == 0 and water.remaining_raw() == 255, "Signed0xff source reserve remains explicit, not invented infinite water")


func save_and_rejections() -> void:
	var machine := Machine.new()
	check(machine.snapshot().is_empty() and not machine.apply_weekly_event().ok and not machine.request_load(30).ok, "Unconfigured kernel cannot create production or inventory deltas")
	check(machine.configure(9, 127, 8), "Prepare source record before save")
	var original := machine.snapshot()
	var copy := Machine.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(original))) and copy.snapshot() == original, "Strict JSON-only versioned state restores exactly")
	check(copy.apply_weekly_event() == machine.apply_weekly_event() and copy.snapshot() == machine.snapshot(), "Reloaded record continues with same independent source transition")
	var before := machine.snapshot()
	for key in before:
		var missing := before.duplicate(true)
		missing.erase(key)
		check(not machine.restore(missing) and machine.snapshot() == before, "Missing source state field rejects atomically: " + key)
	var extra := before.duplicate(true)
	extra.untrusted_extra = 1
	check(not machine.restore(extra) and machine.snapshot() == before, "Unknown source state field rejects atomically")
	for key in ["schema", "profile", "source_assembly_sha256", "f243_sha256", "f247_sha256", "f252_sha256"]:
		var changed := before.duplicate(true)
		changed[key] = "wrong-source-or-revision"
		check(not machine.restore(changed) and machine.snapshot() == before, "Foreign source/version profile rejects atomically: " + key)
	for value in [null, true, false, "1", [], {}, -1, 1.5, NAN, INF, -INF, 2147483648]:
		check(not machine.apply_weekly_events(value).ok and machine.snapshot() == before, "Malformed event count rejects without partial production")
		check(not machine.request_load(value).ok and machine.snapshot() == before, "Malformed free cargo rejects without partial unloading")
	for field in ["hopper_tonnes", "remaining_raw", "prospect", "version"]:
		for value in [null, true, false, "1", [], {}, -1, 1.5, NAN, INF, 256]:
			var changed := before.duplicate(true)
			changed[field] = value
			check(not machine.restore(changed) and machine.snapshot() == before, "Malformed saved numeric field rejects atomically: " + field)
	check(machine.configure(10, 12, 6), "Prepare full mineral hopper")
	var first := machine.request_load(5)
	check(first.loaded_tonnes == 5 and not first.retrieval_animation_requested and machine.hopper_tonnes() == 5, "Partial cargo load retains uncollected physical hopper")
	var saved: Variant = JSON.parse_string(JSON.stringify(machine.snapshot()))
	check(copy.restore(saved) and copy.request_load(30) == machine.request_load(30), "Partly unloaded hopper continues across restart")
	check(copy.hopper_tonnes() == 0 and not copy.request_load(29).retrieval_animation_requested and copy.request_load(30).retrieval_animation_requested, "Empty source hopper requires another command and30t for retrieval request")
	check(copy.snapshot().size() == Machine.SNAPSHOT_KEYS.size(), "Snapshot contains only declared primitive source-kernel state")
