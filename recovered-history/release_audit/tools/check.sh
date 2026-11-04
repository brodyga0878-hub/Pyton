#!/bin/sh
set -eu
APP_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
TEST_DATA=$(mktemp -d)
trap 'rm -rf "$TEST_DATA"' EXIT HUP INT TERM
export XDG_DATA_HOME="$TEST_DATA/data"
export XDG_CACHE_HOME="$TEST_DATA/cache"
python3 -m unittest discover -s "$APP_ROOT/tests" -p 'test_*.py' -v
run_godot() {
    if timeout 45 godot "$@" > "$TEST_DATA/engine.log" 2>&1; then
        cat "$TEST_DATA/engine.log"
        if rg -q '^(SCRIPT ERROR:|ERROR:)|ObjectDB instances leaked|RID allocations of type' "$TEST_DATA/engine.log"; then
            return 1
        fi
    else
        result=$?
        cat "$TEST_DATA/engine.log"
        return "$result"
    fi
}
for suite in test_flight test_touch test_galaxy test_navigation test_map test_planetary test_system_ui test_ships test_combat test_surface test_economy test_campaign test_journal_library test_release_models test_hold_buttons test_mobile_controls test_ship_registry test_original_worlds test_ffe_math test_settlement_travel test_formation_kernel test_city_collision test_body_initializer test_sterile_climate test_sterile_system test_world_inputs test_galaxy_worlds test_inhabited_world_rules test_original_names test_named_inhabited_rules test_inhabited_system test_special_system test_procedural_flight test_adapter_records test_world_presentation test_global_surface test_surface_orbit_link test_vertical_flight; do
    run_godot --headless --path "$APP_ROOT" --script "res://tests/$suite.gd"
done
run_godot --headless --audio-driver Dummy --path "$APP_ROOT" -- --smoke
run_godot --headless --audio-driver Dummy --path "$APP_ROOT" -- --travel-smoke
run_godot --headless --audio-driver Dummy --path "$APP_ROOT" -- --migration-smoke

run_godot --headless --audio-driver Dummy --path "$APP_ROOT" -- --system-smoke

run_godot --headless --audio-driver Dummy --path "$APP_ROOT" -- --ship-smoke

run_godot --headless --audio-driver Dummy --path "$APP_ROOT" -- --stage5-smoke

run_godot --headless --audio-driver Dummy --path "$APP_ROOT" -- --economy-smoke

run_godot --headless --audio-driver Dummy --path "$APP_ROOT" -- --campaign-smoke

run_godot --headless --audio-driver Dummy --path "$APP_ROOT" -- --release-smoke

run_godot --headless --audio-driver Dummy --path "$APP_ROOT" -- --worlds-smoke

run_godot --headless --audio-driver Dummy --path "$APP_ROOT" -- --ports-smoke

run_godot --headless --audio-driver Dummy --path "$APP_ROOT" -- --city-collision-smoke

run_godot --headless --audio-driver Dummy --path "$APP_ROOT" -- --procedural-flight-smoke

run_godot --headless --audio-driver Dummy --path "$APP_ROOT" -- --global-surface-smoke

run_godot --headless --audio-driver Dummy --path "$APP_ROOT" -- --surface-orbit-smoke

run_godot --headless --audio-driver Dummy --path "$APP_ROOT" -- --vertical-flight-smoke
