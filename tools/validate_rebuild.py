#!/usr/bin/env python3
"""Run a curated set of current rebuilt suites, once each, with bounded logs.

This checks standalone logic and native-reference controls. App smoke, Android
package verification, and physical-device validation remain separate checks.
The recovered-history tree is never scanned or imported: the one selected pad
test is loaded explicitly, and the terrain tool builds an isolated project.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import dataclasses
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
import selectors
import shutil
import signal
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[1]
COUNTS = re.compile(r'(?<!\d)(\d+)\s+checks,\s*(\d+)\s+failures\b')
DIAGNOSTIC = re.compile(
    r'(?:SCRIPT ERROR:|^\s*ERROR:|ObjectDB instances leaked|Leaked instance:|'
    r'resources still in use at exit|WARNING:[^\n]*\bleak(?:ed|s)?\b|'
    r'RID allocations[^\n]*(?:leak|exit))', re.I | re.M)


@dataclasses.dataclass(frozen=True)
class Suite:
    name: str
    script: str
    scope: str
    kind: str = 'godot'
    timeout: int = 180
    optional: bool = False
    user_args: tuple[str, ...] = ()


SUITES = [
    Suite('source_jet_fuel', 'tests/test_source_jet_fuel.gd', 'Uploaded DOS F929/F938 tail/F289, bounded F1007 cooling/F152 cadence versus independent native instructions; explicit JJFFE counterfactual differences.', timeout=300),
    Suite('source_fuel_scoop', 'tests/test_source_fuel_scoop.gd', 'Exact F1033/F1034 raw atmosphere/equipment/cargo/cooldown/stellar heat branches versus729 native cases; geometry is controlled independently.', timeout=300),
    Suite('source_fuel_contact', 'tests/test_source_fuel_contact.gd', 'Read-only source gas/star F574/F581/F1876 natural field and current-world SI/frame adapter versus330 independently executed native contacts.', timeout=300),
    Suite('source_fuel_session', 'tests/test_source_fuel_session.gd', 'Separate persisted jet tank, DOS selective nozzles, cargo refuelling, original cadence, hardware mass/mounting, legacy v3 upgrades and atomic pending quote rules.', timeout=300),
    Suite('fuel_services_view', 'tests/test_fuel_services_view.gd', 'Embedded fuel UI layout and explicit runtime commands distinct from dock workshop transactions.', timeout=300),
    Suite('fuel_services_native_view', 'tests/test_fuel_services_native_view.gd', 'Actual Navigation fuel and equipment operations through phone touch controls, directional depletion recovery and old source-profile hardware.', timeout=300),
    Suite('source_fuel_main', 'tests/test_source_fuel_main.gd', 'Actual Main fuel cadence, source movement/save continuation, automatic star/gas scooping, UI recovery, old v40 saves, pause and stale-input boundaries.', timeout=600, user_args=('--rebuild-capture',)),
    Suite('source_fuel_flight', 'tests/test_source_fuel_flight.gd', 'Actual Flight and Surface selective uploaded-DOS nozzle gating, ballistic inertia/gravity and explicit phone powered-impulse fuel adapter; independent source fuel/session tests are separate.', timeout=300),
    Suite('source_hyperdrive', 'tests/test_source_hyperdrive.gd', 'Original F833/F899..F903/F1521 arithmetic versus5453 native safe controls plus11 original fault domains; immutable raw evaluator and source-spec quotes.', timeout=300),
    Suite('source_hyperdrive_navigation', 'tests/test_source_hyperdrive_navigation.gd', 'Explicit v3 source inventory/capacity, quoted pending jumps and exact-once consumption/time, strict restore and atomic dock workshop services; legacy adapters remain separate.', timeout=300),
    Suite('hyperdrive_services_view', 'tests/test_hyperdrive_services_view.gd', 'Embedded phone equipment UI, copied service quotes, responsive actions, pointer release and fixture command routing; fixture prices do not prove original markets.', timeout=300),
    Suite('hyperdrive_services_native_view', 'tests/test_hyperdrive_services_native_view.gd', 'Actual source Navigation/session through equipment touch actions, capacity/fuel handover, military jump/waste and immediate post-migration service; dock flags are business fixtures.', timeout=300),
    Suite('source_hyperdrive_map', 'tests/test_source_hyperdrive_map.gd', 'Actual source route/model/background worker preserve the same F833 distance, F903 fuel and Q16 duration as live Navigation, without editing the session.', timeout=300),
    Suite('source_hyperdrive_main', 'tests/test_source_hyperdrive_main.gd', 'Actual Main route/charge/cancel/save continuation, military fuel/waste, stale service inputs, explicit legacy migration with durable private backup and atomic invalid-v3 rejection.', timeout=300, user_args=('--rebuild-capture',)),
    Suite('source_system_information', 'tests/test_source_system_information.gd', 'Original DOS information strings, policy, numeric and body pages versus1570 independently executed native cases plus actual World isolation.', timeout=300),
    Suite('system_information_view', 'tests/test_system_information_view.gd', 'Information UI layout, touch scrolling, copied inputs, source counter forwarding and unavailable states with an explicitly labelled fixture provider.', timeout=300),
    Suite('system_information_native_view', 'tests/test_system_information_native_view.gd', 'Actual original Sol/Alpha Centauri information through the real UI, exact counters, ground-port adapter and unknown knowledge guard.', timeout=300),
    Suite('map_information_actions', 'tests/test_map_information_actions.gd', 'Actual map information buttons, responsive action geometry, input release and unchanged travel/selection behavior.', timeout=300),
    Suite('system_information_main', 'tests/test_system_information_main.gd', 'Actual Main information modal, source-state isolation, retained parent map/menu, background/cancellation/exit and time-acceleration interruption policy.', timeout=300, user_args=('--rebuild-capture',)),
    Suite('navigation_main', 'tests/test_navigation_main.gd', 'Actual Main graphical map selection/confirmation, forecast isolation, raw save continuation, phone roll, clock scheduling and legacy opt-in boundaries.', timeout=600, user_args=('--rebuild-capture',)),
    Suite('galactic_map_model', 'tests/test_galactic_map_model.gd', 'Original F853 galaxy overview, source sectors/search/distance and independent native density controls.', timeout=300),
    Suite('galactic_map_view', 'tests/test_galactic_map_view.gd', 'Actual galaxy screen worker lifecycle, pan/zoom/search, touch and explicit jump confirmation.', timeout=300),
    Suite('system_map', 'tests/test_system_map.gd', 'Original system hierarchy, sampled source orbits, isolated time forecast, moving ports and graphical map controls.', timeout=600),
    Suite('flight_time_controller', 'tests/test_flight_time_controller.gd', 'Original timer control native references plus bounded nominal-SI scheduler, safety and exact executed-step acknowledgement.', timeout=300),
    Suite('rotating_dock_dynamics', 'tests/test_rotating_dock_dynamics.gd', 'Actual station rotation, relative contact velocity, conservative angular CCD, source docking and legacy restore.', timeout=300),
    Suite('source_motion_pipeline', 'tests/test_source_motion_pipeline.gd', 'Original F598..F603/F607/F1512 persistent raw body and Q16 fraction transitions against independent native cases.', timeout=300),
    Suite('source_motion_bridge', 'tests/test_source_motion_bridge.gd', 'Fixed natural-parent Cobra raw motion SI boundary, precise fractional continuation and strict restore; excludes automatic frame selection.', timeout=300),
    Suite('source_motion_main_continuation', 'tests/test_source_motion_main_continuation.gd', 'Actual Main three rotated savepoints retain exact next raw body, Q16 fraction, IEEE64 clock, ship pose and velocity.', timeout=300, user_args=('--rebuild-capture',)),
    Suite('source_frame_kinematics', 'tests/test_source_frame_kinematics.gd', 'Standalone original F572/F573 integer rotating-frame primitives versus720 native cases; not automatic F570/F606 frame selection.', timeout=300),
    Suite('classic_console_main', 'tests/test_classic_console_main.gd', 'Actual Main console hooks, principal cameras, session pause, independent fingers, offpad takeoff and pending-jump/save boundaries.', timeout=300, user_args=('--rebuild-capture',)),
    Suite('flight_projection', 'tests/test_flight_projection.gd', 'Actual Main Mercury arrival, independent perspective angular scale, off-axis flight-window centre, safe-area/resize/FOV/principal views and preserved source/legacy state.', timeout=300, user_args=('--rebuild-capture',)),
    Suite('source_console_pause', 'tests/test_source_console_pause.gd', 'Actual Worldv4 pending terrain worker publication is deferred during console pause and resumes without losing physical contact.', timeout=600, user_args=('--rebuild-capture',)),
    Suite('source_mining_machine', 'tests/test_source_mining_machine.gd', 'Standalone original MB4 weekly/loading transitions versus independently executed native controls; deployment and gameplay inventory integration remain future work.', timeout=300),
    Suite('source_asteroid_mesh_spike', 'tools/source_asteroid_mesh_check.gd', 'Original model112 mesh vertices versus native F1470/F1478 and geometric ray hits; not live asteroid landing or original F582/F583 collision proof.', timeout=300),
    Suite('source_packet_clip', 'tests/test_source_surface_packet_clip.gd', 'Actual117 coarse/fine overlap and packet-shader clip contracts; rendered pixel controls are verified separately.', timeout=300),
    Suite('source_full_startup', 'tests/test_source_full_startup.gd', 'Actual normal startup selects Worldv4/native navigation and restores a private native save; no player progress access.', timeout=300, user_args=('--source-startup-isolated',)),
    Suite('source_surface_streaming', 'tests/test_source_surface_streaming.gd', 'Actual Earth/117 worker mesh publication, coherent core collision and bounded high-speed geographic streaming.', timeout=600),
    Suite('source_render_packet', 'tests/test_source_surface_render_packet.gd', 'Worker-only source height mesh buffers, bounded far LOD and published core geometry.', timeout=600),
    Suite('source_render_state', 'tests/test_source_surface_render_state.gd', 'Exact vertical collision queries against the published source core after geographic rebasing.', timeout=300),
    Suite('source_surface_contact_patch', 'tests/test_source_surface_contact_patch.gd', 'Saved nonvertex source contact independently verifies all three original triangle vertices before restoring the published physical height.', timeout=300),
    Suite('source_surface_cap', 'tests/test_source_surface_cap.gd', 'Actual source117 coarse globe overlap, opt-in near patch coverage and retained far horizon.', timeout=300),
    Suite('source_high_gravity', 'tests/test_source_high_gravity_surface.gd', 'Actual23m/s² port with source Cobra controls, manual takeoff, clock and ascent saves.', timeout=600),
    Suite('source_orbit_surface_guard', 'tests/test_source_orbit_surface_guard.gd', 'Actual Earth/117 terrain height guards preserve real20km departures without phantom sphere damage.', timeout=600),
    Suite('source_generated_worlds', 'tests/test_source_generated_worlds.gd', 'Complete source Worldv4, native body/port frames and explicit original-source caller corrections.', timeout=600),
    Suite('source_galaxy_population', 'tests/test_source_galaxy_population.gd', 'All4231 valid native-header systems through actual runtime construction/catalogue with documented caller corrections.', timeout=600),
    Suite('source_surface_integration', 'tests/test_source_surface_integration.gd', 'Native source terrain/force frame, actual117 and ground-port entry, geography, ascent, load and return.', timeout=600),
    Suite('source_station_session', 'tests/test_source_station_session.gd', 'Actual selected station context, spin/door persistence and isolated World-before-Flight restore.', timeout=600),
    Suite('source_underground_controller', 'tests/test_source_underground_controller.gd', 'Exact96 static237 replay and atomic worker/state/collider publication.', timeout=600),
    Suite('source_enclosed_city_visual', 'tests/test_source_enclosed_city_visual.gd', 'Actual96/237 rendering retains immutable city meshes while updating hatch poses.', timeout=300),
    Suite('source_celestial_renderer', 'tests/test_source_celestial_renderer.gd', 'Native body pose/light, source-height global LOD, bounded asynchronous publication and local overlap.', timeout=600),
    Suite('source_cobra_control', 'tests/test_source_ship_control_profile.gd', 'Original F601 six-axis Cobra thrust versus native controls with explicit conservative mobile policy.', timeout=300),
    Suite('source_port_refuel', 'tests/test_source_port_refuel.gd', 'Actual selected source-port basic refuel without synthetic training market.', timeout=300),
    Suite('source_main_full', 'tests/test_source_main_full.gd', 'Actual Main native jump/cancel/save, physical station dock/refuel/launch, offpad takeoff and enclosed96 touch/save/launch.', timeout=600, user_args=('--rebuild-capture',)),
    Suite('source_model_mesh', 'tests/test_source_model_mesh.gd', 'Preserved full mesh suite with independently regenerated original vertex fixture.', timeout=300),
    Suite('source_model_vertices', 'tests/test_source_model_vertices_native.gd', 'All1392 original leaf coordinates against108 independent native instruction cases.', timeout=300),
    Suite('source_galaxy', 'tests/test_source_galaxy.gd', 'Actual original sector density, buffers, coordinates and RNG against504 native sectors/4243 positions.', timeout=300),
    Suite('source_definition', 'tests/test_source_system_definition.gd', 'Actual F830 names and F860 source headers against4234 independent native callers.', timeout=300),
    Suite('source_names', 'tests/test_source_planet_names.gd', 'Original populated-body names and text expansion against native contexts.', timeout=300),
    Suite('source_settlements', 'tests/test_source_settlement_builder.gd', 'Full128-record ground/orbital settlement constructors and original names/RNG.', timeout=300),
    Suite('source_classifier_full', 'tests/test_source_body_classifier_full.gd', 'Complete populated planetary classifier callbacks versus native records and globals.', timeout=300),
    Suite('source_system_builder', 'tests/test_source_system_builder.gd', 'Actual full F877/F878/F897 system hierarchy and F868/F869/F871 metadata.', timeout=600),
    Suite('source_world_catalogue', 'tests/test_source_world_catalogue.gd', 'Runtime128-record hierarchy, original descriptors and native-system adapter.', timeout=300),
    Suite('source_ground_surface', 'tests/test_source_ground_surface.gd', 'Actual F879 placement and F574 ground collision against independent original instructions.', timeout=600),
    Suite('source_surface_terrain', 'tests/test_source_surface_terrain.gd', 'Shared native height adapter, all17natural models,21ports and explicit117caller correction.', timeout=600),
    Suite('source_physics_bridge', 'tests/test_source_physics_bridge.gd', 'Sampled F603 acceleration with explicit nominal-day SI unit policy.', timeout=300),
    Suite('source_station_geometry', 'tests/test_source_station_geometry.gd', 'Actual69 and72..80 geometry, source contact/door/spin, special Polaris and swept hull controls.', timeout=600),
    Suite('source_docking_flight', 'tests/test_source_docking_flight.gd', 'Physical source-station docking/launch and opt-in flightv5 restore.', timeout=300),
    Suite('source_underground', 'tests/test_source_underground_port.gd', 'Original96 enclosed hangar, hatch geometry, vertical path and source reservation controls.', timeout=600),
    Suite('native_navigation', 'tests/test_native_navigation.gd', 'Paged original-coordinate navigation with bounded cache and atomicv2 saves.', timeout=300),
    Suite('block10_legacy', 'tests/test_block10_integration.gd', 'Immutable published0.11.11 v1/v2/v3 world, port, surface and save controls.', timeout=600),
    Suite('math', 'tests/test_rebuilt_ffe_math.gd', 'Reconstructed source integer and packed arithmetic, independent native controls.'),
    Suite('body_initializer', 'tests/test_rebuilt_body_initializer.gd', 'Complete original F882 packed-record initialization versus 1424 native contexts; isolated from the live analytic world and ephemerides.'),
    Suite('body_rotation', 'tests/test_rebuilt_body_rotation.gd', 'Exact F880 initialization/F866 orientation slice with F1675/F1914/F1521 versus 1542 native contexts; excludes full F866, original clock epoch, animations and orbital updates.'),
    Suite('stellar_factory', 'tests/test_stellar_body_factory.gd', 'Bounded original F881 stellar-name domain plus F882/remnant callbacks/F894 against 760 independent native contexts; excludes planetary generation, brown-dwarf naming and live-world integration.'),
    Suite('planetary_classifier', 'tests/test_planetary_classifier.gd', 'Original bounded F883..887 planetary classification versus 3060 native controls; supported paths match full records/RNG, naming and settlement paths reject atomically.'),
    Suite('source_body_factory', 'tests/test_source_body_factory.gd', 'Original F881 all23 mass-bin dispatch, supported ordinal planet names, exact records/counters and atomic unsupported helpers; no full procedural hierarchy.', timeout=300),
    Suite('source_clock', 'tests/test_source_clock.gd', 'Original F1357 calendar, F1363 display time and explicit elapsed-days bridge to the verified3250 epoch.'),
    Suite('source_world_bridge', 'tests/test_source_world_bridge.gd', 'Native F878 handcrafted runtime-record conversion, all11 source-world integration and independent unchanged0.11.8 physical layouts, saves and calendar HUD.', timeout=300, user_args=('--rebuild-capture',)),
    Suite('source_orbit', 'tests/test_source_orbit.gd', 'Pinned JJFFE integer orbital rate, phase and coordinate procedures against independent native instruction controls; not full original gravity or dynamics.', timeout=300),
    Suite('source_orbit_integration', 'tests/test_source_orbit_integration.gd', 'All11 versioned orbital worlds, native coordinate hierarchy, preserved0.11.9 v1 saves, stable source epoch and actual Main transitions.', timeout=300, user_args=('--rebuild-capture',)),
    Suite('source_gravity', 'tests/test_source_gravity.gd', 'Original raw F603 velocity/fraction updates, F880 a4 and F1511/F1512 drift against independent native instructions; no live SI force migration.', timeout=300),
    Suite('source_physics_integration', 'tests/test_source_physics_integration.gd', 'Immutable0.11.10 v1/v2 worlds, new versioned native orbital-port frames and actual Main/save/report integration.', timeout=300, user_args=('--rebuild-capture',)),
    Suite('orbital_port_surface', 'tests/test_orbital_port_surface.gd', 'Orbital-port to surface transition clears stale orbital anchors atomically, preserves geography and restores post-ascent saves.', timeout=300, user_args=('--rebuild-capture',)),
    Suite('worlds', 'tests/test_rebuilt_worlds.gd', 'Handcrafted original records and explicit analytic world/navigation adapter.'),
    Suite('flight', 'tests/test_rebuilt_flight.gd', 'Rebuilt flight, phone steering inputs, adapted training economy, atomic flight saves.'),
    Suite('cities', 'tests/test_rebuilt_cities.gd', 'Source3 city geometry, pad selection, collision, landing/takeoff/restore integration.'),
    Suite('city_runtime', 'tests/test_source_city_runtime.gd', 'Original city runtime and analytic ellipsoid collision controls.'),
    Suite('city_view', 'tests/test_source_city_view.gd', 'City rendering lifetime and presentation contract with synthetic geometry.'),
    Suite('triangle_ccd', 'tests/test_segment_triangle.gd', 'Independent triangle/edge/vertex swept ellipsoid collision controls.'),
    Suite('ground_pads', 'recovered-history/ground_harness/tests/test_source_ground_pads.gd', 'Preserved test explicitly loaded against current scripts and regenerated native F650 controls.'),
    Suite('terrain_native', 'tools/data_validate_terrain.py', 'Isolated preserved terrain research modules versus 336 raw and 630 native caller controls; not live terrain integration.', kind='python', timeout=300),
    Suite('save_touch', 'tests/test_rebuilt_save_touch.gd', 'Current complete save-store decoding, atomic writes/fallback and multi-finger phone input/release behavior; separate from app/device smoke.'),
    Suite('app_transitions', 'tests/test_rebuilt_app_transitions.gd', 'Actual Main transition locks, pending-save resume and asynchronous New Moscow entry; capture mode disables user progress loading/writing.', user_args=('--rebuild-capture',)),
    Suite('graphics_ship', 'tests/test_ship_graphics.gd', 'Authored detailed ship geometry, normal/span contracts, cache/lifecycle, exhaust, and landing gear; not the complete original ship catalogue or device rendering.'),
    Suite('graphics_environment', 'tests/test_graphics_space_environment.gd', 'Batched orbital-station geometry, deterministic asteroid placement, clear approach/planet-view cones and distance/quality LOD; visual scenery only.'),
    Suite('graphics_integration', 'tests/test_graphics_integration.gd', 'Actual Main graphics-flight entry/return, isolated original progress/save bytes, save-failure guard, controls/quality and native city return; private test save directory.', user_args=('--rebuild-capture',)),
    Suite('material_library', 'tests/test_material_library.gd', 'Original PBR map import, dimensions, shared-resource lifetime and material binding contracts; not visual-quality or phone-performance proof.'),
    Suite('space_materials', 'tests/test_space_material_bindings.gd', 'Real hull/station material map assignments, palette/finish and quality isolation on existing geometry.'),
    Suite('world_materials', 'tests/test_world_materials.gd', 'City palette and mesh preservation, real terrain/fallback maps and quality propagation.'),
    Suite('world_terrain_shader', 'tests/test_world_terrain_shader.gd', 'Independent unchanged terrain vertex/procedural/coverage shader blocks and three-map material contract.'),
    Suite('world_planet_shader', 'tests/test_world_planet_shader.gd', 'Independent unchanged planetary geography, gas/star branches, shader vertices and three-map contract.'),
    Suite('world_surface_invariants', 'tests/test_world_surface_invariants.gd', 'Independent 0.11.7 terrain meshes/physics and planetary presentation controls, current source and explicitly marked legacy Solar fixtures.', timeout=300, user_args=('--rebuild-capture',)),
    Suite('city_material_roles', 'tests/test_city_material_roles.gd', 'Render-only source city surface classification against transformed source planes and original F650 pad targets.', timeout=300),
    Suite('city_surface_shader', 'tests/test_city_surface_shader.gd', 'Bounded three-sampler city atlas contract and unchanged source painter vertex shader.'),
    Suite('city_surface_invariants', 'tests/test_city_surface_invariants.gd', 'Independent 0.11.6 fingerprints of all ten real city roots, source palette, geometry and physics; only render role metadata may change.', timeout=300, user_args=('--rebuild-capture',)),
    Suite('graphics_scope', 'tests/test_graphics_scope.gd', 'Actual Main normal flight excludes decorative asteroid scenery, preserves flight/navigation/surface data and restores optional graphics preview.', user_args=('--rebuild-capture',)),
    Suite('surface_detail_scope', 'tests/test_surface_detail_scope.gd', 'Bespoke hull projection/profile isolation, independent0.11.3 geometry fingerprints, actual Main gameplay and progress preservation.', user_args=('--rebuild-capture',)),
    Suite('station_finish', 'tests/test_station_finish.gd', 'Dedicated industrial station maps, quality/finish settings and independent unchanged mesh fingerprints.'),
    Suite('offpad_takeoff', 'tests/test_offpad_takeoff.gd', 'Healthy manual off-pad landings, positive lift departure, restore, slopes, surviving impacts and destroyed-hull rejection.'),
    Suite('surface_action_controls', 'tests/test_surface_action_controls.gd', 'Actual phone surface actions, stale held inputs, independent second-finger takeoff, focus/report lifecycle and explicit destroyed-hull feedback.', user_args=('--rebuild-capture',)),
    Suite('touch_actions', 'tests/test_touch_action_button.gd', 'Independent action-button pointers, cancel/outside/disabled cases and emulated-mouse deduplication.'),
    Suite('flight_console', 'tests/test_flight_console.gd', 'Classic instrument panel values, actual working command signals and phone layout bounds.'),
    Suite('departure_cycle', 'tests/test_departure_cycle.gd', 'Healthy automatic ground-to-orbit departure, v6 save/resume, cancellation and real source-city to training-dock cycle.', timeout=300, user_args=('--rebuild-capture',)),
    Suite('training_dock_services', 'tests/test_training_dock_services.gd', 'Read-only real-model training service quotes and atomic repair/market/refuel/delivery/exchange transactions.'),
    Suite('dock_services_view', 'tests/test_dock_services_view.gd', 'Actual quoted dock-service rows, touch commands, visible unavailable reasons and original-port gating.'),
    Suite('dock_service_actions', 'tests/test_dock_service_actions.gd', 'Real Main service commands, current-context revalidation, touch/scroll lifecycle and game-state preservation.', user_args=('--rebuild-capture',)),
    Suite('diagnostics', 'tests/test_game_diagnostics.gd', 'Bounded persistent diagnostics, real isolated engine/script errors, archive CRC/hash/retention, session markers and explicit save opt-in.'),
    Suite('report_export', 'tests/test_report_export.gd', 'Checked multiblock ZIP export, errors/cancel/retry, source preservation; Android SAF separately source-verified, physical device untested.'),
    Suite('bug_report_ui', 'tests/test_bug_report_ui.gd', 'Actual Main report buttons, report description/context/save opt-in, verified export callback, direct retry and original progress isolation.', user_args=('--rebuild-capture',)),
]


class Inspector:
    """Inspect the entire output while storing only bounded context and counts."""

    def __init__(self, max_bytes: int):
        self.max_bytes = max_bytes
        self.prefix = bytearray()
        self.tail = bytearray()
        self.total_bytes = 0
        self.pending = ''
        self.counts: list[tuple[int, int]] = []
        self.diagnostics: list[str] = []

    def line(self, value: str):
        for match in COUNTS.finditer(value):
            self.counts.append((int(match[1]), int(match[2])))
        if DIAGNOSTIC.search(value) and value.strip() not in self.diagnostics and len(self.diagnostics) < 20:
            self.diagnostics.append(value.strip()[:1000])

    def feed(self, raw: bytes):
        self.total_bytes += len(raw)
        prefix_limit = self.max_bytes*3//4
        tail_limit = self.max_bytes-prefix_limit
        if len(self.prefix) < prefix_limit:
            take = min(len(raw), prefix_limit-len(self.prefix))
            self.prefix.extend(raw[:take])
            raw_for_tail = raw[take:]
        else:
            raw_for_tail = raw
        self.tail.extend(raw_for_tail)
        if len(self.tail) > tail_limit:
            del self.tail[:-tail_limit]
        # Diagnostics are matched before line buffering is bounded. Godot's
        # summaries/diagnostics are ASCII, so split UTF8 does not affect them.
        value = self.pending+raw.decode('utf-8', errors='replace')
        lines = value.split('\n')
        self.pending = lines.pop()
        for line in lines:
            self.line(line)
        if len(self.pending) > 16384:
            self.line(self.pending[:-1024])
            self.pending = self.pending[-1024:]

    def finish(self):
        if self.pending:
            self.line(self.pending)
            self.pending = ''

    def log(self) -> str:
        omitted = self.total_bytes-len(self.prefix)-len(self.tail)
        middle = ('\n... %d output bytes omitted; diagnostics inspected throughout ...\n' % omitted).encode() if omitted > 0 else b''
        return (self.prefix+middle+self.tail).decode('utf-8', errors='replace')


def fingerprint(path: Path) -> dict:
    raw = path.read_bytes()
    return {'path': str(path.relative_to(PROJECT)), 'bytes': len(raw), 'sha256': hashlib.sha256(raw).hexdigest()}


def engine_version(value: str) -> str:
    # Startup font-cache diagnostics can appear on stderr before --version.
    # Compare the actual version line, not the unrelated combined probe output.
    candidates = [line.strip() for line in value.splitlines()
                  if re.fullmatch(r'\d+\.\d+(?:\.[A-Za-z0-9_+-]+)*', line.strip())]
    if len(candidates) != 1:
        raise ValueError('Godot did not return one unambiguous engine version')
    return candidates[0]


def run_suite(suite: Suite, godot: str, output: Path, max_bytes: int) -> dict:
    script = PROJECT/suite.script
    result = {'name': suite.name, 'scope': suite.scope, 'status': 'failed', 'checks': 0, 'failures': 0,
              'executed_utc': dt.datetime.now(dt.timezone.utc).isoformat()}
    if not script.is_file():
        result.update(status='unavailable' if suite.optional else 'failed', reason='Suite file is unavailable: '+suite.script)
        return result
    result['suite_source'] = fingerprint(script)
    command = ([sys.executable, str(script), '--godot', godot] if suite.kind == 'python' else
               [godot, '--headless', '--path', str(PROJECT), '--script', 'res://'+suite.script])
    if suite.user_args:
        command.extend(['--', *suite.user_args])
    state = output/'state'/suite.name
    environment = dict(os.environ, XDG_DATA_HOME=str(state/'data'), XDG_CACHE_HOME=str(state/'cache'),
                       XDG_CONFIG_HOME=str(state/'config'))
    result['command'] = command
    inspector = Inspector(max_bytes)
    started = time.monotonic()
    timed_out = False
    process = None
    try:
        process = subprocess.Popen(command, cwd=PROJECT, env=environment, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, start_new_session=True)
        with selectors.DefaultSelector() as poller:
            poller.register(process.stdout, selectors.EVENT_READ)
            while poller.get_map():
                remaining = suite.timeout-(time.monotonic()-started)
                if remaining <= 0:
                    timed_out = True
                    os.killpg(process.pid, signal.SIGKILL)
                    break
                for key, _ in poller.select(timeout=min(remaining, 0.25)):
                    raw = os.read(key.fileobj.fileno(), 8192)
                    if not raw:
                        poller.unregister(key.fileobj)
                    else:
                        inspector.feed(raw)
            if timed_out:
                # The process group was killed; draining the pipe cannot wait
                # for an orphaned terrain Godot child to finish by itself.
                for raw in iter(lambda: process.stdout.read(8192), b''):
                    inspector.feed(raw)
        result['exit_code'] = process.wait(timeout=5)
    except (OSError, subprocess.SubprocessError) as error:
        result['reason'] = str(error)
    finally:
        if process is not None:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait(timeout=5)
            if process.stdout is not None:
                process.stdout.close()
    inspector.finish()
    result['duration_seconds'] = round(time.monotonic()-started, 3)
    result['timed_out'] = timed_out
    result['output_bytes'] = inspector.total_bytes
    result['log_truncated'] = inspector.total_bytes > max_bytes
    result['diagnostics'] = inspector.diagnostics
    log = output/'logs'/(suite.name+'.log')
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(inspector.log(), encoding='utf-8')
    result['log'] = str(log)
    result['summary_lines'] = len(inspector.counts)
    if len(inspector.counts) == 1:
        result['checks'], result['failures'] = inspector.counts[0]
    problems = []
    if timed_out:
        problems.append('Suite exceeded %d seconds' % suite.timeout)
    if result.get('exit_code') != 0:
        problems.append('Process did not exit successfully')
    if len(inspector.counts) != 1:
        problems.append('Expected exactly one current checks/failures summary, got %d' % len(inspector.counts))
    elif result['checks'] <= 0 or result['failures'] != 0:
        problems.append('No positive passing check count')
    if inspector.diagnostics:
        problems.append('Engine error or leaked resource diagnostic')
    if fingerprint(script) != result['suite_source']:
        problems.append('Suite source changed during its execution')
    if result.get('reason'):
        problems.append(result['reason'])
    if problems:
        result['reason'] = '; '.join(problems)
    else:
        result['status'] = 'passed'
    return result


def limitations() -> list[dict]:
    items = [{
        'scope': 'Full original model-mesh leaf native controls',
        'status': 'unavailable' if not (PROJECT/'tests/fixtures/model_vertices_reference.json').is_file() else 'not_in_this_curated_run',
        'reason': 'The leaf fixture has been independently regenerated from original instructions; consult source_model_mesh/source_model_vertices suite results for actual execution coverage.' if (PROJECT/'tests/fixtures/model_vertices_reference.json').is_file() else 'Independent original leaf fixture is unavailable.',
    }]
    items.append({'scope': 'Android installation, on-device rendering and physical Samsung S23 Ultra', 'status': 'separate_validation',
                  'reason': 'This runner includes isolated desktop Main scene tests; APK packaging, rendered GPU controls and physical-device behavior require their separate evidence.'})
    return items


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--suite', action='append', choices=[suite.name for suite in SUITES], help='Run a named subset; repeated names are deduplicated.')
    parser.add_argument('--jobs', type=int, default=3)
    parser.add_argument('--output', type=Path, default=PROJECT/'build/validation')
    parser.add_argument('--summary', type=Path, default=PROJECT/'build/validation-summary.json')
    parser.add_argument('--extend', action='store_true', help='Add only new/unavailable/failed named suites to this same-day report without rerunning passed suites.')
    parser.add_argument('--log-max-kib', type=int, default=128)
    parser.add_argument('--list', action='store_true', help='List the explicit suites without executing any tests.')
    args = parser.parse_args()
    if args.list:
        print(json.dumps([dict(dataclasses.asdict(suite), available=(PROJECT/suite.script).is_file()) for suite in SUITES], indent=2))
        return 0
    if not 1 <= args.jobs <= 8 or not 8 <= args.log_max_kib <= 1024:
        parser.error('--jobs must be 1..8 and --log-max-kib must be 8..1024')
    godot = shutil.which(args.godot)
    if godot is None:
        parser.error('Godot executable is unavailable: '+args.godot)
    selected = [suite for suite in SUITES if not args.suite or suite.name in args.suite]
    previous = None
    if args.extend:
        if not args.suite or not args.summary.is_file():
            parser.error('--extend requires --suite and an existing --summary')
        previous = json.loads(args.summary.read_text(encoding='utf-8'))
        if previous.get('project') != str(PROJECT) or previous.get('schema') != 1:
            parser.error('Existing summary belongs to another project or schema')
        previous_time = dt.datetime.fromisoformat(previous['started_utc'])
        age = (dt.datetime.now(dt.timezone.utc)-previous_time).total_seconds()
        if age < 0 or age > 86400:
            parser.error('--extend accepts only a current report from the last 24 hours; historical totals cannot be imported')
        for row in previous['suites']:
            if row['status'] == 'passed' and row['name'] in args.suite:
                parser.error('Passed suite %s would run twice; select only newly added, unavailable or failed suites' % row['name'])
            if row['status'] == 'passed' and fingerprint(PROJECT/row['suite_source']['path']) != row['suite_source']:
                parser.error('Previously tested suite source changed: %s; start a fresh relevant validation run' % row['name'])
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    probe_state = output/'state'/'runner'
    for name in ['data', 'cache', 'config']:
        (probe_state/name).mkdir(parents=True, exist_ok=True)
    probe_env = dict(os.environ, XDG_DATA_HOME=str(probe_state/'data'), XDG_CACHE_HOME=str(probe_state/'cache'),
                     XDG_CONFIG_HOME=str(probe_state/'config'))
    version = engine_version(subprocess.run([godot, '--version'], env=probe_env, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, timeout=10, check=True).stdout)
    if previous is not None and engine_version(previous.get('godot_version', '')) != version:
        parser.error('Existing summary used another Godot version; start a fresh validation run')
    started_utc = dt.datetime.now(dt.timezone.utc).isoformat()
    started = time.monotonic()
    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as executor:
        futures = {executor.submit(run_suite, suite, godot, output, args.log_max_kib*1024): suite for suite in selected}
        for future in concurrent.futures.as_completed(futures):
            suite = futures[future]
            try:
                result = future.result()
            except Exception as error:
                result = {'name': suite.name, 'scope': suite.scope, 'status': 'failed', 'checks': 0, 'failures': 0,
                          'reason': 'Validation infrastructure error: '+str(error)}
            results[suite.name] = result
            print('%s: %s; %d checks, %d failures%s' %
                  (suite.name, result['status'], result['checks'], result['failures'],
                   '; '+result['reason'] if result.get('reason') else ''), flush=True)
    executed_names = [suite.name for suite in selected]
    if previous is not None:
        old = {row['name']: row for row in previous['suites']}
        old.update(results)
        results = old
    ordered = [results[suite.name] for suite in SUITES if suite.name in results]
    unavailable = [row['name'] for row in ordered if row['status'] == 'unavailable']
    failed = [row['name'] for row in ordered if row['status'] == 'failed']
    # A missing optional new suite is a visible coverage limitation, not a pass.
    batch_duration = round(time.monotonic()-started, 3)
    batches = [] if previous is None else previous.get('validation_batches', [{'started_utc': previous['started_utc'],
                 'duration_seconds': previous['duration_seconds'],
                 'requested_suites': [row['name'] for row in previous['suites']],
                 'executed_suites': [row['name'] for row in previous['suites'] if row.get('command')]}])
    batches.append({'started_utc': started_utc, 'duration_seconds': batch_duration,
                    'requested_suites': executed_names,
                    'executed_suites': [name for name in executed_names if results[name].get('command')]})
    coverage = limitations()
    if all(any(row['name'] == name and row['status'] == 'passed' for row in ordered)
           for name in ('source_model_mesh', 'source_model_vertices')):
        coverage[0].update(status='passed', reason='Both unchanged preserved mesh controls and direct independently regenerated original vertex controls passed in this report.')
    report = {'schema': 1, 'scope': 'Current rebuilt standalone suites and native-reference controls only; historical totals excluded. Per-suite execution times identify bounded supplemental runs; this is not an atomic repository snapshot.',
              'started_utc': previous['started_utc'] if previous else started_utc,
              'updated_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
              'duration_seconds': round(sum(batch['duration_seconds'] for batch in batches), 3), 'validation_batches': batches,
              'godot_version': version, 'project': str(PROJECT), 'jobs': args.jobs,
              'status': 'failed' if failed else 'passed_with_coverage_limitations' if unavailable or any(item['status'] == 'unavailable' for item in coverage) else 'passed',
              'passed_suites': sum(row['status'] == 'passed' for row in ordered),
              'failed_suites': failed, 'unavailable_suites': unavailable,
              'checks': sum(row['checks'] for row in ordered), 'failures': sum(row['failures'] for row in ordered),
              'suites': ordered, 'coverage_limitations': coverage}
    args.summary.parent.mkdir(parents=True, exist_ok=True)
    args.summary.write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('Validation %s: %d current checks; %d passed suites; %d failed; %d unavailable. Report: %s' %
          (report['status'], report['checks'], report['passed_suites'], len(failed), len(unavailable), args.summary), flush=True)
    return 1 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
