extends Node3D

const AsteroidView = preload("res://scripts/asteroid_view.gd")
const MiningRig = preload("res://scripts/mining_rig.gd")
const MiningRigView = preload("res://scripts/mining_rig_view.gd")
const StarView = preload("res://scripts/star_view.gd")
const TrafficView = preload("res://scripts/traffic_view.gd")
const Catalog = preload("res://scripts/sector_catalog.gd")
const DockAccess = preload("res://scripts/dock_access.gd")
const Ground = preload("res://scripts/ground_port.gd")
const ShipSystems = preload("res://scripts/ship_systems.gd")
const Terrain = preload("res://scripts/surface_terrain.gd")
const AtmosphereView = preload("res://scripts/atmosphere_view.gd")
const FlightCamera = preload("res://scripts/flight_camera.gd")
const STAR_DISTANCE := 2700.0
const STATION_RADIAL_SEGMENTS := 20
const BACKDROP_ORBIT_SECONDS := 28800.0
const CLOUD_CYCLE_SECONDS := 1080.0
const CAMERA_SURFACE_CLEARANCE := 2.0
const REMOTE_RIG_VIEW_DISTANCE := 480.0
const FRAGMENT_VIEW_DISTANCE := 420.0
const FRAGMENT_ROLL_AXIS := Vector3(0.36, 0.80, 0.48)
const FRAGMENT_FINISH := {
	"ore": [Color("#a16652"), 0.68, 0.22],
	"crystal": [Color("#c394dd"), 0.31, 0.06],
	"ice": [Color("#8dc7e0"), 0.42, 0.05],
}
const BERTH_CAMERA_OFFSET := Vector3(8.4, 9.2, 24.0)
const BERTH_CAMERA_FOCUS := Vector3(0.0, 0.0, -15.0)
const GROUND_CAMERA_OFFSET := Vector3(8.4, -10.0, 21.0)
const GROUND_CAMERA_FOCUS := Vector3(0.0, 0.0, -2.0)
const DEPARTURE_CAMERA_BLEND_START := 16.0
const DEPARTURE_CAMERA_BLEND_END := 32.0
const GEAR_PAD_SIZE := Vector3(0.46, 0.32, 0.13)
const HATCH_HINGE_RADIUS := DockAccess.HATCH_RADIUS + 0.26
const HATCH_LEAF_RADIUS := DockAccess.HATCH_RADIUS + 0.12
const HATCH_HALF_DEPTH := 0.10

static var _panel_shader: Shader
static var _paint_panel_data: Texture2D
static var _brushed_panel_data: Texture2D
static var _hatch_panel_geometry: ArrayMesh
static var _fragment_shader: Shader


class DockHatch extends Node3D:
	var leaves: Array[Node3D] = []
	var signal_paint: StandardMaterial3D
	var _fraction := -1.0

	func sync(access: Dictionary) -> void:
		var fraction := clampf(float(access.get("open_fraction", 0.0)), 0.0, 1.0)
		if fraction != _fraction:
			_fraction = fraction
			for carrier: Node3D in leaves:
				carrier.rotation.y = -fraction * PI * 0.5
		var tint := Color("#f1876e")
		if access.get("ready", false):
			tint = Color("#75eac0")
		elif fraction > 0.0 or float(access.get("wait", 0.0)) > 0.0:
			tint = Color("#edb36c")
		if signal_paint.albedo_color != tint:
			signal_paint.albedo_color = tint

class HyperTransitOverlay extends Control:
	const TRAIL_COUNTS := [24, 40, 56]
	const COOL := Color("#8fe9f4")
	const WARM := Color("#ffc27a")

	var _progress := 0.0
	var _profile := 1
	var _trails := PackedVector2Array()
	var _highlights := PackedVector2Array()
	var _trails_color := PackedColorArray()
	var _highlights_color := PackedColorArray()

	func _ready() -> void:
		resized.connect(queue_redraw)

	func set_profile(profile: int) -> void:
		if _profile != profile:
			_profile = profile
			queue_redraw()

	func sync(active: bool, progress: float) -> void:
		if not active:
			hide()
			return
		if not visible or _progress != progress:
			_progress = progress
			show()
			queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.07, 0.13, 0.64))
		var count: int = TRAIL_COUNTS[_profile]
		_trails.resize(count * 2)
		_highlights.resize(count * 2)
		_trails_color.resize(count)
		_highlights_color.resize(count)
		var center := size * Vector2(0.53, 0.46)
		var extent := size * Vector2(0.66, 0.77)
		for index in range(count):
			var direction := Vector2.from_angle(float(index) * 2.39996323) * extent
			var reach := fposmod(float(index) * 0.61803399 + _progress * 3.2, 1.0)
			var radius := lerpf(0.11, 1.17, reach)
			var length := lerpf(0.034, 0.29, reach * reach)
			var head := center + direction * radius
			var pair := index * 2
			_trails[pair] = head - direction * length
			_trails[pair + 1] = head
			_highlights[pair] = head - direction * length * 0.30
			_highlights[pair + 1] = head
			var alpha := smoothstep(0.0, 0.26, reach) * (1.0 - smoothstep(0.80, 1.0, reach))
			var ink := WARM if index % 5 == 0 else COOL
			_trails_color[index] = Color(ink, alpha * 0.32)
			_highlights_color[index] = Color(ink, alpha * 0.86)
		# Two batches keep the effect independent of world objects and texture quality.
		draw_multiline_colors(_trails, _trails_color, 2.8)
		draw_multiline_colors(_highlights, _highlights_color, 1.6)

class CockpitCanopy extends Control:
	var _mix := 0.0

	func _ready() -> void:
		resized.connect(queue_redraw)

	func sync(amount: float) -> void:
		visible = amount > 0.001
		if visible and not is_equal_approx(_mix, amount):
			_mix = amount
			queue_redraw()

	func _draw() -> void:
		var shell := Color(0.021, 0.037, 0.056, 0.94 * _mix)
		var trim := Color(0.29, 0.45, 0.50, 0.78 * _mix)
		var small_side := minf(size.x, size.y * 2.0)
		var top_span := small_side * 0.116
		var pillar := small_side * 0.035
		for side in range(2):
			var edge_x := 0.0 if side == 0 else size.x
			var inward := 1.0 if side == 0 else -1.0
			var shoulder := Vector2(edge_x + inward * pillar, size.y * 0.25)
			var corner := Vector2(edge_x, size.y * 0.49)
			var roof := Vector2(edge_x + inward * top_span, 0.0)
			var bevel := Vector2(edge_x + inward * top_span * 0.66, size.y * 0.10)
			draw_colored_polygon(PackedVector2Array([Vector2(edge_x, 0.0), roof, bevel, shoulder, corner]), shell)
			draw_polyline(PackedVector2Array([roof, bevel, shoulder, corner]), trim, 2.0, true)
		var nose := PackedVector2Array([
			Vector2(0.0, size.y * 0.94), size * Vector2(0.24, 0.965), size * Vector2(0.45, 0.936),
			size * Vector2(0.55, 0.936), size * Vector2(0.76, 0.965), size * Vector2(1.0, 0.94),
		])
		draw_polyline(nose, trim, 2.0, true)
		nose.append(size)
		nose.append(Vector2(0.0, size.y))
		draw_colored_polygon(nose, shell)

var camera: Camera3D
var _camera_director := FlightCamera.new()
var _preferred_camera_mode := FlightCamera.Mode.EXTERIOR
var _exterior_position := Vector3.ZERO
var _cockpit_canopy: CockpitCanopy
var _ship: Node3D
var _ship_hull_id := ShipSystems.STARTER_HULL
var _landing_gear: Node3D
var _gear_struts: Array[MeshInstance3D] = []
var _gear_joints: Array[Vector3] = []
var _gear_feet: Array[Vector3] = []
var _gear_pads: MultiMesh
var _gear_progress := -1.0
var _jet: MeshInstance3D
var _jet_material: ShaderMaterial
var _lighting: Environment
var _sunlight: DirectionalLight3D
var _fill: DirectionalLight3D
var _sector: Node3D
var _system_id := -1
var _star_id := -1
var _gas_giant_id := -1
var _stars: MeshInstance3D
var _star: Node3D
var _stellar_views: Dictionary[int, Node3D] = {}
var _companion_id := -1
var _backdrop_planet: Node3D
var _backdrop_material: ShaderMaterial
var _backdrop_orbit_offset := Vector3.ZERO
var _backdrop_orbit_axis := Vector3.UP
var _mining_rig: Node3D
var _fragment_views: Dictionary[int, MeshInstance3D] = {}
var _cargo_pod_views: Dictionary[int, Node3D] = {}
var _fragment_meshes: Dictionary[String, ArrayMesh] = {}
var _fragment_paints: Dictionary[String, ShaderMaterial] = {}
var _mining_beam: Node3D
var _mining_beam_halo: MeshInstance3D
var _mining_impact: MeshInstance3D
var _combat_projectile: Node3D
var _combat_projectile_trail: MeshInstance3D
var _traffic: Node3D
var _atmosphere: Node3D
var _hyper_transit: HyperTransitOverlay
var _surface_guide: MeshInstance3D
var _surface_guide_paint: StandardMaterial3D
var _surface_guide_site := -1
var _surface_guide_point := Vector3.INF
var _surface_guide_normal := Vector3.ZERO
var _navigation_corridor: MeshInstance3D
var _surface_views: Dictionary[int, Node3D] = {}
var _stations: Dictionary[int, Node3D] = {}
var _dock_hatches: Dictionary[int, DockHatch] = {}
var _approaches: Dictionary[int, Node3D] = {}
var _gate_materials: Dictionary[int, StandardMaterial3D] = {}
var _last_position := Vector3.INF
var _last_berth := -1
var _last_landed_basis := Basis.IDENTITY
var _departure_view_port := -1
var _camera_up := Vector3.UP
var _flight_time := 0.0
var _visual_profile := 1
var _ship_fittings: Array[Node3D] = []
var _sector_fittings: Array[Node3D] = []
var _ship_finishes: Array[ShaderMaterial] = []
var _sector_finishes: Array[ShaderMaterial] = []

func build() -> void:
	if is_instance_valid(camera):
		return
	var space := WorldEnvironment.new()
	_lighting = Environment.new()
	_lighting.background_mode = Environment.BG_COLOR
	_lighting.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_lighting.ambient_light_energy = 0.53
	space.environment = _lighting
	add_child(space)

	_sunlight = DirectionalLight3D.new()
	_sunlight.light_energy = 1.22
	add_child(_sunlight)
	_fill = DirectionalLight3D.new()
	_fill.rotation_degrees = Vector3(16.0, 145.0, 0.0)
	_fill.light_energy = 0.39
	add_child(_fill)

	_build_ship_model(_ship_hull_id)
	_mining_rig = MiningRigView.new()
	add_child(_mining_rig)
	_build_mining_pulse()
	_build_combat_projectile()
	_traffic = TrafficView.new()
	add_child(_traffic)
	_traffic.set_visual_profile(_visual_profile)
	_atmosphere = AtmosphereView.new()
	add_child(_atmosphere)
	_surface_guide_paint = _light(Color("#edb36c"))
	_surface_guide_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_surface_guide = _mesh(self, ArrayMesh.new(), _surface_guide_paint, Vector3.ZERO)
	_surface_guide.hide()
	_build_navigation_corridor()
	camera = Camera3D.new()
	camera.fov = 67.0
	camera.near = 0.2
	camera.far = 8000.0
	add_child(camera)
	camera.make_current()
	var transit_layer := CanvasLayer.new()
	transit_layer.layer = 0
	add_child(transit_layer)
	_cockpit_canopy = CockpitCanopy.new()
	_cockpit_canopy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transit_layer.add_child(_cockpit_canopy)
	_cockpit_canopy.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cockpit_canopy.hide()
	_hyper_transit = HyperTransitOverlay.new()
	_hyper_transit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	transit_layer.add_child(_hyper_transit)
	_hyper_transit.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hyper_transit.hide()
	set_visual_profile(_visual_profile)


func _load_sector(id: int) -> void:
	if is_instance_valid(_sector):
		remove_child(_sector)
		_sector.queue_free()
	_stations.clear()
	_dock_hatches.clear()
	_approaches.clear()
	_gate_materials.clear()
	_surface_views.clear()
	_stellar_views.clear()
	_fragment_views.clear()
	_cargo_pod_views.clear()
	_sector_fittings.clear()
	_sector_finishes.clear()
	_system_id = id
	_star_id = Catalog.star_for(id)
	_gas_giant_id = Catalog.gas_giant_for(id)
	_backdrop_planet = null
	_backdrop_material = null
	var local_stars := Catalog.stars_for(id)
	_companion_id = int(local_stars[1]) if local_stars.size() > 1 else -1
	_last_position = Vector3.INF
	_departure_view_port = -1

	var cool := id == Catalog.VELAR_SYSTEM
	var fringe := id == Catalog.FRINGE_SYSTEM
	_lighting.background_color = Color("#07091a") if cool else Color("#050910")
	_lighting.ambient_light_color = Color("#8eaae5") if cool else Color("#99b8d0")
	_sunlight.light_color = Color("#b6dbff") if cool else Color("#ffefd9")
	_fill.rotation_degrees = Vector3(16.0, 145.0, 0.0)
	_fill.light_color = Color("#c8a6ee") if cool else Color("#84c8ff")
	_fill.light_energy = 0.39
	if fringe:
		_lighting.background_color = Color("#091511")
		_lighting.ambient_light_color = Color("#8da99a")
		_sunlight.light_color = Color("#ffe3ad")
		_fill.light_color = Color("#81cdb0")

	_sector = Node3D.new()
	add_child(_sector)
	_build_stars(cool, fringe)
	if _companion_id < 0 or _gas_giant_id >= 0:
		_build_gas_giant(cool, fringe)
	for site_id: int in local_stars:
		var site := Catalog.site(site_id)
		var star := StarView.new()
		star.name = "Star_%d" % site_id
		_sector.add_child(star)
		star.set_visual_profile(_visual_profile)
		star.setup(site, Catalog.SCOOP_INNER, Catalog.SCOOP_OUTER, bool(site.get("cool_star", cool)))
		_stellar_views[site_id] = star
	_star = _stellar_views[_star_id]
	if _companion_id >= 0:
		_sunlight.light_color = Color.WHITE.lerp(Catalog.site(_star_id).accent, 0.48)
		_fill.light_color = Color.WHITE.lerp(Catalog.site(_companion_id).accent, 0.50)

	for site_id: int in Catalog.ports_for(id):
		var site := Catalog.site(site_id)
		var station := Node3D.new()
		_sector.add_child(station)
		_stations[site_id] = station
		if Ground.is_port(site_id):
			var enclosed := Ground.is_hangar(site_id)
			station.name = "GroundPort_%d" % site_id
			_build_ground_port(station, enclosed, site.accent)
			if enclosed:
				_dock_hatches[site_id] = _build_dock_hatch(station, true)
		else:
			_build_station(station, site_id, site.accent)
			_dock_hatches[site_id] = _build_dock_hatch(station)
		var approach := Node3D.new()
		_sector.add_child(approach)
		_approaches[site_id] = approach
		_gate_materials[site_id] = _build_approach(approach)
	for site_id: int in Catalog.mines_for(id):
		var body := AsteroidView.new()
		_sector.add_child(body)
		body.set_visual_profile(_visual_profile)
		body.build(Catalog.site(site_id), site_id)
		_surface_views[site_id] = body
	set_visual_profile(_visual_profile)


func set_visual_profile(profile: int) -> void:
	_visual_profile = clampi(profile, 0, 2)
	for fittings in [_ship_fittings, _sector_fittings]:
		for item: Node3D in fittings:
			item.visible = _visual_profile >= int(item.get_meta("minimum_profile"))
	for finishes in [_ship_finishes, _sector_finishes]:
		for finish: ShaderMaterial in finishes:
			finish.set_shader_parameter("finish_quality", _visual_profile)
	for finish: ShaderMaterial in _fragment_paints.values():
		finish.set_shader_parameter("detail_quality", _visual_profile)
	if is_instance_valid(_mining_beam_halo):
		_mining_beam_halo.visible = _visual_profile > 0
	if _backdrop_material != null:
		_backdrop_material.set_shader_parameter("cloud_quality", _visual_profile)
	# A profile also applies to every newly loaded surface, star and NPC.
	for body: Node3D in _surface_views.values():
		body.set_visual_profile(_visual_profile)
	for star: Node3D in _stellar_views.values():
		star.set_visual_profile(_visual_profile)
	if is_instance_valid(_traffic):
		_traffic.set_visual_profile(_visual_profile)
	if is_instance_valid(_atmosphere):
		_atmosphere.set_visual_profile(_visual_profile)
	if is_instance_valid(_hyper_transit):
		_hyper_transit.set_profile(_visual_profile)


func select_camera_mode(mode: int) -> bool:
	if mode < 0 or mode >= FlightCamera.MODE_NAMES.size() or mode == _preferred_camera_mode:
		return false
	_preferred_camera_mode = mode
	return true


func shows_forward_aim() -> bool:
	return _camera_director.shows_forward_aim()


func set_navigation_corridor(guide: Dictionary) -> void:
	_navigation_corridor.visible = not guide.is_empty()
	if guide.is_empty():
		return
	var start: Vector3 = guide.start
	var path: Vector3 = guide.end - start
	var axis := path.normalized()
	var up := Vector3.RIGHT if absf(axis.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var width: float = guide.half_width
	var frame := Basis.looking_at(-axis, up).scaled_local(Vector3(width, width, path.length()))
	_navigation_corridor.transform = Transform3D(frame, start)


func sync(sim: RefCounted, delta: float) -> void:
	if not is_instance_valid(camera):
		build()
	if _system_id != int(sim.system_id):
		_load_sector(sim.system_id)
	var jump_status: Dictionary = sim.jump_progress_status()
	var transit := bool(jump_status.is_transit)
	_hyper_transit.sync(transit, float(jump_status.progress))
	_sector.visible = not transit
	_traffic.visible = not transit
	_atmosphere.visible = not transit
	var hull_id := str(sim.ship.hull_id)
	if hull_id != _ship_hull_id:
		_build_ship_model(hull_id)
		set_visual_profile(_visual_profile)
	var position_now: Vector3 = sim.position
	var docked := int(sim.docked) >= 0
	var surface_id := int(sim.landed_site)
	var landed := surface_id >= 0
	var settled := docked or landed
	var berth := int(sim.docked) if docked else surface_id
	var ground_berth := docked and Ground.is_port(berth)
	var body_attached := landed or ground_berth
	var ship_orientation: Basis = sim.attitude()
	var heading := Basis.IDENTITY if docked and not ground_berth else ship_orientation
	var epoch := float(sim.orbit_time)
	var remote_rig: Dictionary = sim.remote_rig_status()
	var rig_deployed := bool(remote_rig.active)
	var rig_in_view := false
	if rig_deployed and bool(remote_rig.same_system):
		var rig_point: Vector3 = remote_rig.point
		rig_in_view = position_now.distance_squared_to(rig_point) <= REMOTE_RIG_VIEW_DISTANCE * REMOTE_RIG_VIEW_DISTANCE
	var departure: Dictionary = sim.departure_status()
	if docked:
		_departure_view_port = int(departure.port) if departure.phase == "transit" else -1
	elif landed:
		_departure_view_port = -1
	elif Ground.is_port(_last_berth) and not Ground.is_hangar(_last_berth):
		_departure_view_port = _last_berth
	_ship.position = position_now
	_ship.basis = ship_orientation
	_sync_landing_gear(sim.gear_extension)
	for site_id: int in _surface_views:
		var body := _surface_views[site_id]
		body.position = sim.target_position(site_id)
		body.basis = Terrain.spin_basis(site_id, epoch)
		var field_direction: Vector3 = sim.landing_direction if site_id == surface_id else Vector3.ZERO
		if rig_in_view and site_id == int(remote_rig.site):
			field_direction = remote_rig.direction
		body.sync(position_now, site_id == int(sim.target), not settled, field_direction)
	var thrust := clampf(float(sim.throttle), 0.0, 1.0)
	_flight_time += delta
	_jet.visible = transit or (not settled and thrust > 0.01)
	var plume_length := 1.35 if transit else (0.45 + thrust * 0.85) * (1.45 if sim.boost else 1.0)
	_jet.scale = Vector3(1.0, plume_length, 1.0)
	_jet_material.set_shader_parameter("pulse", 0.69 if transit else 0.59 + sin(_flight_time * 31.0) * 0.08)

	var camera_offset := BERTH_CAMERA_OFFSET if docked else Vector3(0.0, 3.4, 10.5)
	var focal_offset := BERTH_CAMERA_FOCUS if docked else Vector3(0.0, 2.0, -30.0)
	var up := heading.y
	if ground_berth:
		camera_offset = GROUND_CAMERA_OFFSET
		focal_offset = GROUND_CAMERA_FOCUS
	elif landed:
		camera_offset = Vector3(-8.4, -13.5, 12.5)
		focal_offset = Vector3(2.8, 2.0, -3.2)
		up = heading.z
	var desired := position_now + heading * camera_offset
	var chase_weight := 1.0
	var departure_frame := Basis.IDENTITY
	var ground_departure := Ground.is_port(_departure_view_port)
	if _departure_view_port >= 0:
		var axis: Vector3 = sim.station_axis(_departure_view_port)
		var opening: Vector3 = sim.dock_hatch_position(_departure_view_port)
		if ground_departure and not Ground.is_hangar(_departure_view_port):
			opening = sim.docking_position(_departure_view_port)
		var from_hatch := position_now - opening
		var ahead := from_hatch.dot(axis)
		if not docked and (ahead < 0.0 or ahead >= DEPARTURE_CAMERA_BLEND_END or from_hatch.slide(axis).length_squared() >= 576.0):
			_departure_view_port = -1
		else:
			var up_axis := Vector3.RIGHT if absf(axis.dot(Vector3.UP)) > 0.95 else Vector3.UP
			departure_frame = Ground.basis(_departure_view_port, epoch) if ground_departure else Basis.looking_at(-axis, up_axis)
			chase_weight = 0.0 if docked else smoothstep(DEPARTURE_CAMERA_BLEND_START, DEPARTURE_CAMERA_BLEND_END, ahead)
			# The ordinary chase offset places the camera behind the ship, inside the hatch just after release.
			var departure_offset := GROUND_CAMERA_OFFSET if ground_departure else BERTH_CAMERA_OFFSET
			desired = (position_now + departure_frame * departure_offset).lerp(desired, chase_weight)
			var camera_rotation := departure_frame.get_rotation_quaternion().slerp(heading.get_rotation_quaternion(), chase_weight)
			up = Basis(camera_rotation).y
	var cut := not _last_position.is_finite()
	if not cut:
		cut = position_now.distance_squared_to(_last_position) > 144.0
	var jump := delta <= 0.0 or cut
	var blend := 1.0 - exp(-delta * 14.0)
	var camera_start := _exterior_position
	if not jump and settled and berth == _last_berth:
		if body_attached:
			var ground_turn := ship_orientation * _last_landed_basis.transposed()
			camera_start = position_now + ground_turn * (camera_start - _last_position)
			_camera_up = ground_turn * _camera_up
		else:
			camera_start += position_now - _last_position
	var chase_origin := desired if jump else camera_start.lerp(desired, blend)
	_exterior_position = _surface_safe_camera(chase_origin, sim)
	if not settled:
		var close_follow := smoothstep(0.0, 7.0, _exterior_position.distance_to(chase_origin))
		focal_offset = focal_offset.lerp(Vector3(0.0, 0.4, -2.5), close_follow)
	var focal_direction := heading * focal_offset
	if chase_weight < 1.0:
		var travel := float(departure.progress) if docked else 1.0
		var dock_focus := GROUND_CAMERA_FOCUS if ground_departure else BERTH_CAMERA_FOCUS.lerp(Vector3(0.0, 0.0, -7.5), travel)
		focal_direction = (departure_frame * dock_focus).lerp(focal_direction, chase_weight)
	var look_target := position_now + focal_direction
	var sight := (look_target - _exterior_position).normalized()
	var blended_up := _camera_up.lerp(up, blend).normalized()
	_camera_up = up if jump or blended_up.is_zero_approx() else blended_up
	if absf(sight.dot(_camera_up)) > 0.995:
		_camera_up = up if absf(sight.dot(up)) < 0.995 else heading.x
	var exterior := Transform3D(Basis.looking_at(sight, _camera_up), _exterior_position)
	var freighter := hull_id == ShipSystems.FREIGHTER_HULL
	# Keep the established framing during the automatic berth operation.
	var forced_exterior := settled or transit
	_camera_director.select(FlightCamera.Mode.EXTERIOR if forced_exterior else _preferred_camera_mode)
	var shot_cut := cut or (forced_exterior and _camera_director.transitioning())
	camera.transform = _camera_director.sample(_ship.transform, exterior, delta, freighter, shot_cut)
	camera.fov = _camera_director.field_of_view
	_ship.visible = _camera_director.shows_hull()
	_cockpit_canopy.sync(_camera_director.cockpit_mix)
	_stars.position = camera.position
	for site_id: int in _stellar_views:
		var star := _stellar_views[site_id]
		star.position = sim.target_position(site_id)
		star.update_approach(camera.global_position, position_now, int(sim.target) == site_id and not settled, bool(sim.scoop_active_at(site_id)))
	var primary_strength := 1.45 if _companion_id < 0 else 1.10
	_update_stellar_light(_sunlight, _star.position, position_now, primary_strength)
	if _companion_id >= 0:
		_update_stellar_light(_fill, _stellar_views[_companion_id].position, position_now, 0.65)
	if _gas_giant_id >= 0:
		_backdrop_planet.position = sim.target_position(_gas_giant_id)
		var light_direction := (_star.position - _backdrop_planet.position).normalized()
		_backdrop_material.set_shader_parameter("light_direction", light_direction)
	elif _backdrop_planet != null:
		var backdrop_phase := TAU * fposmod(float(sim.orbit_time), BACKDROP_ORBIT_SECONDS) / BACKDROP_ORBIT_SECONDS
		_backdrop_planet.position = _star.position + _backdrop_orbit_offset.rotated(_backdrop_orbit_axis, backdrop_phase)
	if _visual_profile > 0 and _backdrop_material != null:
		_backdrop_material.set_shader_parameter("weather_phase", fposmod(float(sim.orbit_time), CLOUD_CYCLE_SECONDS) / CLOUD_CYCLE_SECONDS)
	_last_position = position_now
	_last_berth = berth
	_last_landed_basis = ship_orientation if body_attached else Basis.IDENTITY

	var guidance: Dictionary = sim.docking_guidance()
	for site_id: int in _stations:
		var operational: bool = sim.station_operational(site_id)
		var ground := Ground.is_port(site_id)
		var axis: Vector3 = sim.station_axis(site_id)
		var up_axis := Vector3.RIGHT if absf(axis.dot(Vector3.UP)) > 0.95 else Vector3.UP
		var station_frame := Ground.basis(site_id, epoch) if ground else Basis.looking_at(-axis, up_axis) * Basis(Vector3.BACK, sim.station_angle(site_id))
		var contact: Vector3 = sim.docking_position(site_id)
		_stations[site_id].visible = operational
		_stations[site_id].position = contact if ground else sim.target_position(site_id)
		_stations[site_id].basis = station_frame
		if _dock_hatches.has(site_id):
			var hatch := _dock_hatches[site_id]
			var hatch_position: Vector3 = sim.dock_hatch_position(site_id)
			hatch.position = station_frame.transposed() * (hatch_position - _stations[site_id].position)
			hatch.sync(sim.dock_access_status(site_id))
		var corridor_length: float = (sim.target_gate(site_id) - contact).dot(axis)
		_approaches[site_id].position = contact
		_approaches[site_id].basis = station_frame.scaled_local(Vector3(1.0, 1.0, corridor_length))
		_approaches[site_id].visible = operational and not settled and corridor_length > 0.0 \
			and int(guidance.port) == site_id and bool(guidance.near) and bool(guidance.in_front)
		_gate_materials[site_id].albedo_color = Color("#75eac0") if bool(guidance.get("ok", false)) else Color("#edb36c")
	_sync_surface_guide(sim, settled)
	_mining_rig.visible = rig_in_view or (not rig_deployed and _ship.visible)
	if rig_in_view:
		var rig_pose: Transform3D = sim.remote_rig_transform()
		var phase := MiningRig.DRILLING if bool(remote_rig.working) else MiningRig.READY
		_mining_rig.sync(rig_pose, rig_pose, phase, float(remote_rig.get("progress", 1.0)), float(sim.elapsed))
	elif not rig_deployed:
		var deposit: Transform3D = sim.surface_deposit() if landed else _ship.global_transform
		_mining_rig.sync(_ship.global_transform, deposit, int(sim.mining.phase) if landed else MiningRig.STOWED, sim.mining.progress(), float(sim.elapsed))
	_sync_fragments(sim.local_fragments(), position_now, float(sim.orbit_time))
	_sync_cargo_pods([] if transit else sim.local_cargo_pods(), position_now, epoch)
	_sync_mining_pulse({} if transit else sim.orbital_mining_beam())
	_sync_combat_projectile({} if transit or settled else sim.combat_status())
	_traffic.sync(sim.traffic_contacts(), sim.combat_beams())
	_atmosphere.sync(sim, camera, settled)
	# Compatibility supports ordinary distance fog; keep it local and subtle.
	# It never covers the CanvasLayer instruments and is absent outside air.
	var haze: Dictionary = _atmosphere.local_haze()
	_lighting.fog_enabled = bool(haze.get("inside", false))
	if _lighting.fog_enabled:
		_lighting.fog_light_color = haze.color
		_lighting.fog_light_energy = 0.48
		_lighting.fog_density = float(haze.density) * 0.0015
		_lighting.fog_sky_affect = 0.0


func _sync_fragments(fragments: Array, pilot_position: Vector3, epoch: float) -> void:
	var active_sites: Array[int] = []
	for fragment: Dictionary in fragments:
		var site := int(fragment.site)
		var resource := str(fragment.resource)
		var world: Vector3 = fragment.position
		active_sites.append(site)
		if not _fragment_views.has(site):
			var piece := _mesh(_sector, _fragment_shape(resource), _fragment_paint(resource), world)
			piece.name = "Fragment_%d" % site
			_fragment_views[site] = piece
		var piece := _fragment_views[site]
		piece.position = world
		piece.visible = pilot_position.distance_squared_to(world) <= FRAGMENT_VIEW_DISTANCE * FRAGMENT_VIEW_DISTANCE
		var turn := fposmod(epoch, 13.8) * (TAU / 13.8) + float(site) * 1.37
		piece.basis = Basis(FRAGMENT_ROLL_AXIS, turn)
	for site: int in _fragment_views.keys():
		if site in active_sites:
			continue
		var piece := _fragment_views[site]
		_sector.remove_child(piece)
		piece.queue_free()
		_fragment_views.erase(site)


func _sync_cargo_pods(pods: Array, pilot_position: Vector3, epoch: float) -> void:
	var present: Array[int] = []
	for pod: Dictionary in pods:
		var id := int(pod.id)
		var at: Vector3 = pod.position
		present.append(id)
		if not _cargo_pod_views.has(id):
			_cargo_pod_views[id] = _build_cargo_pod(id)
		var view := _cargo_pod_views[id]
		view.position = at
		view.basis = Basis(Vector3(1.0, 0.6, 0.2).normalized(), fposmod(epoch, 21.0) * TAU / 21.0 + float(id % 12))
		view.visible = at.distance_squared_to(pilot_position) <= FRAGMENT_VIEW_DISTANCE * FRAGMENT_VIEW_DISTANCE
	for id: int in _cargo_pod_views.keys():
		if id not in present:
			_cargo_pod_views[id].hide()
			_cargo_pod_views[id].queue_free()
			_cargo_pod_views.erase(id)


func _build_cargo_pod(id: int) -> Node3D:
	var pod := Node3D.new()
	pod.name = "CargoPod_%d" % id
	_sector.add_child(pod)
	var shell := BoxMesh.new()
	shell.size = Vector3(2.1, 1.8, 3.2)
	_mesh(pod, shell, _surface(Color("#b67a42"), 0.35, 0.56), Vector3.ZERO)
	_box_batch(pod, _surface(Color("#3a4a55"), 0.55, 0.4), [
		[Vector3(0.0, 0.0, -1.16), Vector3(2.24, 1.92, 0.24)],
		[Vector3(0.0, 0.0, 1.16), Vector3(2.24, 1.92, 0.24)],
	])
	_box_batch(pod, _light(Color("#81eadb")), [
		[Vector3(0.0, 0.0, -1.64), Vector3(0.84, 0.20, 0.08)],
		[Vector3(0.0, 0.0, 1.64), Vector3(0.84, 0.20, 0.08)],
	])
	return pod


func _fragment_shape(resource: String) -> ArrayMesh:
	if _fragment_meshes.has(resource):
		return _fragment_meshes[resource]
	var geometry := SurfaceTool.new()
	geometry.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges := PackedVector3Array([
		Vector3(1.53, 0.03, 0.10), Vector3(0.76, 0.12, 1.07), Vector3(-0.73, -0.10, 1.25),
		Vector3(-1.40, 0.19, 0.24), Vector3(-0.81, -0.12, -1.05), Vector3(0.54, 0.27, -1.29),
	])
	var top := Vector3(0.33, 1.24, 0.29)
	var base := Vector3(-0.18, -0.83, -0.31)
	if resource != "ore":
		for index in range(edges.size()):
			edges[index] *= Vector3(0.74, 1.0, 0.86)
		top.y = 1.62
		base.y = -1.28
	for index in range(edges.size()):
		var following := (index + 1) % edges.size()
		var left := float(index) / edges.size()
		var right := float(index + 1) / edges.size()
		var middle := (left + right) * 0.5
		_facet(geometry, top, edges[index], edges[following], Vector2(middle, 0.0), Vector2(left, 0.5), Vector2(right, 0.5))
		_facet(geometry, base, edges[following], edges[index], Vector2(middle, 1.0), Vector2(right, 0.5), Vector2(left, 0.5))
	var mesh := geometry.commit()
	_fragment_meshes[resource] = mesh
	return mesh


func _fragment_paint(resource: String) -> ShaderMaterial:
	if _fragment_paints.has(resource):
		return _fragment_paints[resource]
	if _fragment_shader == null:
		_fragment_shader = Shader.new()
		_fragment_shader.code = """
shader_type spatial;
render_mode diffuse_burley;
uniform vec4 mineral_tint : source_color;
uniform sampler2D mineral_data : filter_linear_mipmap, repeat_enable;
uniform float roughness_base;
uniform float metal_base;
uniform int detail_quality;

void fragment() {
	vec3 color = mineral_tint.rgb;
	float roughness = roughness_base;
	if (detail_quality > 0) {
		vec3 texel = texture(mineral_data, UV * vec2(3.5, 1.5)).rgb;
		color *= mix(0.62, 1.42, texel.r);
		color = mix(color, mineral_tint.rgb * 1.65, smoothstep(0.65, 0.86, texel.g) * 0.30);
		roughness += (texel.b - 0.5) * 0.22;
	}
	ALBEDO = color;
	ROUGHNESS = clamp(roughness, 0.18, 0.95);
	METALLIC = metal_base;
	EMISSION = color * 0.22;
}
"""
	var paint := ShaderMaterial.new()
	paint.shader = _fragment_shader
	var finish: Array = FRAGMENT_FINISH.get(resource, FRAGMENT_FINISH.ore)
	paint.set_shader_parameter("mineral_tint", finish[0])
	paint.set_shader_parameter("roughness_base", finish[1])
	paint.set_shader_parameter("metal_base", finish[2])
	paint.set_shader_parameter("mineral_data", load("res://assets/materials/rock_ice.png" if resource == "ice" else "res://assets/materials/rock_basalt.png"))
	paint.set_shader_parameter("detail_quality", _visual_profile)
	_fragment_paints[resource] = paint
	return paint


func _build_mining_pulse() -> void:
	_mining_beam = Node3D.new()
	_mining_beam.name = "MiningPulse"
	add_child(_mining_beam)
	_cylinder(_mining_beam, _light(Color("#fff0b5")), Vector3.ZERO, 0.24, 0.24, 1.0, 6)
	var glow := _light(Color(1.0, 0.66, 0.16, 0.38))
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mining_beam_halo = _cylinder(_mining_beam, glow, Vector3.ZERO, 0.49, 0.49, 1.0, 6)
	_mining_beam.hide()
	var flash := SphereMesh.new()
	flash.radius = 0.9
	flash.height = 1.8
	flash.radial_segments = 7
	flash.rings = 4
	_mining_impact = _mesh(self, flash, glow, Vector3.ZERO)
	_mining_impact.hide()


func _sync_mining_pulse(shot: Dictionary) -> void:
	_mining_beam.hide()
	_mining_impact.hide()
	if shot.is_empty() or float(shot.remaining) <= 0.0:
		return
	var start: Vector3 = shot.start
	var finish: Vector3 = shot.end
	var offset := finish - start
	var distance := offset.length()
	if not is_finite(distance) or distance < 0.1:
		return
	var direction := offset / distance
	var up := Vector3.RIGHT if absf(direction.y) > 0.97 else Vector3.UP
	var fade := lerpf(0.18, 1.0, smoothstep(0.0, 0.11, float(shot.remaining)))
	_mining_beam.position = (start + finish) * 0.5
	_mining_beam.basis = Basis.looking_at(direction, up).scaled_local(Vector3(fade, fade, distance))
	_mining_beam.show()
	_mining_impact.position = finish
	_mining_impact.scale = Vector3.ONE * fade
	_mining_impact.visible = _visual_profile > 0

func _build_combat_projectile() -> void:
	_combat_projectile = Node3D.new()
	_combat_projectile.name = "CombatProjectile"
	add_child(_combat_projectile)
	var body := CapsuleMesh.new()
	body.radius = 0.43
	body.height = 2.18
	body.radial_segments = 10
	body.rings = 4
	var shell := _mesh(_combat_projectile, body, _light(Color("#ffd199")), Vector3.ZERO)
	shell.rotation_degrees.x = 90.0
	var glow := _light(Color(1.0, 0.34, 0.17, 0.60))
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_combat_projectile_trail = _cylinder(_combat_projectile, glow, Vector3(0.0, 0.0, 3.24), 0.02, 0.62, 4.3, 8)
	_combat_projectile.hide()


func _sync_combat_projectile(status: Dictionary) -> void:
	_combat_projectile.visible = bool(status.get("projectile", false))
	if not _combat_projectile.visible:
		return
	var position_now: Vector3 = status.position
	var velocity: Vector3 = status.velocity
	if not position_now.is_finite() or not velocity.is_finite():
		_combat_projectile.hide()
		return
	var direction := Vector3.FORWARD if velocity.is_zero_approx() else velocity.normalized()
	var up := Vector3.RIGHT if absf(direction.y) > 0.97 else Vector3.UP
	_combat_projectile.position = position_now
	_combat_projectile.basis = Basis.looking_at(direction, up)
	var exhaust_scale := clampf(velocity.length() / 48.0, 0.65, 1.7)
	_combat_projectile_trail.scale.y = exhaust_scale
	_combat_projectile_trail.position.z = 1.09 + 2.15 * exhaust_scale


func _update_stellar_light(light: DirectionalLight3D, source: Vector3, observer: Vector3, strength: float) -> void:
	var light_travel := observer - source
	var distance_squared := light_travel.length_squared()
	if distance_squared > 1.0:
		var incoming := light_travel.normalized()
		var up := Vector3.BACK if absf(incoming.y) > 0.96 else Vector3.UP
		light.basis = Basis.looking_at(incoming, up)
	light.light_energy = strength * lerpf(0.25, 1.0, 1.0 / (1.0 + distance_squared / 2250000.0))


func _sync_landing_gear(progress: float) -> void:
	if progress == _gear_progress:
		return
	_gear_progress = progress
	_landing_gear.visible = progress > 0.0
	if not _landing_gear.visible:
		return
	var travel := lerpf(0.02, 1.0, smoothstep(0.0, 1.0, progress))
	for index in range(_gear_struts.size()):
		var joint := _gear_joints[index]
		var foot := joint.lerp(_gear_feet[index], travel)
		var axis := foot - joint
		var axes := Basis.looking_at(axis) * Basis(Vector3.RIGHT, PI * 0.5)
		_gear_struts[index].transform = Transform3D(axes.scaled_local(Vector3(1.0, travel, 1.0)), (joint + foot) * 0.5)
		var angle := PI * 0.5 + TAU * float(index) / 3.0
		var pad_axes := Basis(Vector3.BACK, angle).scaled_local(GEAR_PAD_SIZE)
		_gear_pads.set_instance_transform(index, Transform3D(pad_axes, foot))


func _sync_surface_guide(sim: RefCounted, settled: bool) -> void:
	var status: Dictionary = sim.surface_status()
	var site := int(sim.target)
	_surface_guide.visible = not settled and float(sim.jump_seconds_left) <= 0.0 and _surface_views.has(site) \
		and bool(status.get("guide", false)) and bool(status.get("near", false)) \
		and not bool(status.get("pad", false)) and float(status.get("altitude", INF)) <= 90.0
	if not _surface_guide.visible:
		return
	var ground: Vector3 = status.ground_point
	var normal: Vector3 = status.surface_normal
	if not ground.is_finite() or not normal.is_finite() or normal.length_squared() < 0.5:
		_surface_guide.hide()
		return
	var body := _surface_views[site]
	var spin := body.basis
	var inverse_spin := spin.transposed()
	normal = (inverse_spin * normal).normalized()
	var center := inverse_spin * (ground - body.position)
	var reference := Vector3.RIGHT if absf(normal.dot(Vector3.UP)) > 0.95 else Vector3.UP
	var axes := Basis.looking_at(-normal, reference)
	# Cache body-local geometry so ground rotation only changes the transform.
	if _surface_guide_site != site or center.distance_squared_to(_surface_guide_point) > 0.01 \
			or normal.dot(_surface_guide_normal) < 0.99999:
		var geometry := SurfaceTool.new()
		geometry.begin(Mesh.PRIMITIVE_TRIANGLES)
		geometry.set_normal(Vector3.BACK)
		for quadrant in range(4):
			var previous := PackedVector3Array()
			for step in range(7):
				var angle := quadrant * TAU * 0.25 + PI * 0.08 + float(step) * PI * 0.34 / 6.0
				var radial := Vector2(cos(angle), sin(angle))
				var row := PackedVector3Array()
				for radius: float in [2.45, 2.55]:
					var direction := (center + axes * Vector3(radial.x * radius, radial.y * radius, 0.0)).normalized()
					# Sample the existing physical surface; this is a visual ribbon,
					# with no displacement, new terrain, depth override or collider.
					var point := Terrain.point(site, direction) + direction * 0.28
					row.append(axes.transposed() * (point - center))
				if not previous.is_empty():
					for vertex: Vector3 in [previous[0], previous[1], row[0], previous[1], row[1], row[0]]:
						geometry.add_vertex(vertex)
				previous = row
		geometry.index()
		_surface_guide.mesh = geometry.commit()
		_surface_guide_site = site
		_surface_guide_point = center
		_surface_guide_normal = normal
	_surface_guide.position = ground
	_surface_guide.basis = spin * axes
	_surface_guide_paint.albedo_color = Color("#75eac0") if bool(status.ok) else Color("#edb36c")


func _surface_safe_camera(at: Vector3, sim: RefCounted) -> Vector3:
	# The chase offset points into the rock during the first moment of an outward launch.
	for site_id: int in _surface_views:
		var body := _surface_views[site_id]
		var center := body.position
		var relative := at - center
		var outer := float(Catalog.site(site_id).radius) * Terrain.MAX_RADIUS_FACTOR + CAMERA_SURFACE_CLEARANCE
		if relative.length_squared() >= outer * outer:
			continue
		var direction := body.basis.z if relative.is_zero_approx() else relative.normalized()
		var local_direction := body.basis.transposed() * direction
		var threshold := Terrain.radius_at(site_id, local_direction) + CAMERA_SURFACE_CLEARANCE
		if relative.length_squared() < threshold * threshold:
			at = center + direction * threshold
	if _gas_giant_id >= 0:
		var center: Vector3 = sim.target_position(_gas_giant_id)
		var offset := at - center
		var limit := float(Catalog.site(_gas_giant_id).radius) + CAMERA_SURFACE_CLEARANCE
		if offset.length_squared() < limit * limit:
			var outward := Vector3.BACK if offset.is_zero_approx() else offset.normalized()
			at = center + outward * limit
	return at


func _mesh(parent: Node3D, primitive: Mesh, paint: Material, at: Vector3) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = primitive
	item.material_override = paint
	item.position = at
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(item)
	return item


func _surface(color: Color, metallic := 0.25, roughness := 0.65) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = metallic
	paint.roughness = roughness
	return paint


func _panel_finish(color: Color, metallic: float, roughness: float, seams: Vector2, ship := false, specular := 0.43) -> ShaderMaterial:
	if _panel_shader == null:
		_panel_shader = Shader.new()
		_panel_shader.code = """
shader_type spatial;
render_mode diffuse_burley;
uniform vec4 paint : source_color;
uniform float metal = 0.3;
uniform float rough = 0.6;
uniform float base_specular = 0.43;
uniform vec2 seams = vec2(2.0, 3.0);
uniform int finish_quality = 1;
// Packed linear material data: R tone, G height, B roughness.
uniform sampler2D panel_data : filter_linear_mipmap, repeat_enable;
uniform vec2 panel_repeat = vec2(2.0, 2.0);
uniform float rough_center = 0.52;
uniform float bump_depth = 0.003;

void fragment() {
	vec3 surface = paint.rgb;
	float micro_roughness = rough;
	float surface_metal = metal;
	if (finish_quality > 0) {
		vec2 cell = UV * seams;
		vec2 edge = 0.5 - abs(fract(cell) - 0.5);
		float spacing = min(edge.x, edge.y);
		float pixel = max(fwidth(cell.x), fwidth(cell.y));
		float fade = 1.0 - smoothstep(0.09, 0.37, pixel);
		float seam = (1.0 - smoothstep(0.014, 0.042 + pixel * 0.45, spacing)) * fade;
		float ridge = (1.0 - smoothstep(0.006, 0.021 + pixel * 0.45, abs(spacing - 0.060))) * fade;
		float variation = sin(dot(floor(cell), vec2(7.1, 5.3))) * 0.063 * fade;
		surface *= 1.0 + variation + ridge * 0.12 - seam * 0.36;
		micro_roughness += seam * 0.17 - ridge * 0.08;
		// The economy profile never enters this branch or samples a map.
		vec3 detail = texture(panel_data, UV * panel_repeat).rgb;
		float fidelity = finish_quality > 1 ? 1.0 : 0.62;
		float wear = (detail.r - 0.5) * fidelity;
		float abrasion = (1.0 - smoothstep(0.36, 0.50, detail.r * 0.56 + detail.g * 0.44)) * fidelity;
		float bare = abrasion * (0.33 + ridge * 0.27);
		surface *= 1.0 + wear * 0.47;
		surface = mix(surface, mix(surface * 0.64, vec3(0.33, 0.39, 0.42), 0.43), bare);
		micro_roughness += (detail.b - rough_center) * fidelity * 0.45 - bare * 0.11;
		surface_metal = mix(metal, max(metal, 0.60), bare);
		if (finish_quality > 1) {
			// Surface-gradient bump also works on the custom hull, which has
			// UVs and normals but no tangent stream. One filtered sample only.
			float height = detail.g - 0.5 + ridge * 0.042 - seam * 0.08;
			vec3 n = normalize(NORMAL);
			vec3 sx = dFdx(VERTEX);
			vec3 sy = dFdy(VERTEX);
			float hx = dFdx(height);
			float hy = dFdy(height);
			vec3 r1 = cross(sy, n);
			vec3 r2 = cross(n, sx);
			float jacobian = dot(sx, r1);
			if (abs(jacobian) > 0.000000001) {
				vec3 bump = bump_depth * sign(jacobian) * (hx * r1 + hy * r2) / abs(jacobian);
				// Keep rigid panel highlights stable even at grazing angles.
				bump *= min(1.0, 0.15 / max(length(bump), 0.000001));
				NORMAL = normalize(n - bump);
			}
		}
	}
	ALBEDO = surface;
	METALLIC = surface_metal;
	ROUGHNESS = clamp(micro_roughness, 0.16, 0.96);
	SPECULAR = base_specular;
}
"""
	var finish := ShaderMaterial.new()
	finish.shader = _panel_shader
	finish.set_shader_parameter("paint", color)
	finish.set_shader_parameter("metal", metallic)
	finish.set_shader_parameter("rough", roughness)
	finish.set_shader_parameter("base_specular", specular)
	finish.set_shader_parameter("seams", seams)
	if _paint_panel_data == null:
		_paint_panel_data = load("res://assets/materials/metal_paint.png") as Texture2D
	if _brushed_panel_data == null:
		_brushed_panel_data = load("res://assets/materials/metal_brushed.png") as Texture2D
	var brushed := metallic >= 0.45 or roughness >= 0.65
	finish.set_shader_parameter("panel_data", _brushed_panel_data if brushed else _paint_panel_data)
	finish.set_shader_parameter("panel_repeat", Vector2(2.0, 3.0) if ship else Vector2(3.0, 2.0))
	finish.set_shader_parameter("rough_center", 0.32 if brushed else 0.52)
	finish.set_shader_parameter("bump_depth", 0.0045 if ship else 0.014)
	if ship:
		_ship_finishes.append(finish)
	else:
		_sector_finishes.append(finish)
	return finish


func _fitting(parent: Node3D, minimum: int) -> Node3D:
	var layer := Node3D.new()
	layer.set_meta("minimum_profile", minimum)
	parent.add_child(layer)
	if parent == _ship:
		_ship_fittings.append(layer)
	else:
		_sector_fittings.append(layer)
	return layer


func _light(color: Color) -> StandardMaterial3D:
	var paint := _surface(color)
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return paint


func _box_batch(parent: Node3D, paint: Material, shapes: Array) -> MultiMesh:
	if shapes.is_empty():
		return null
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = paint
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = shapes.size()
	for index in range(shapes.size()):
		var shape: Array = shapes[index]
		var size: Vector3 = shape[1]
		var axes := Basis(Vector3.BACK, float(shape[2])) if shape.size() > 2 else Basis.IDENTITY
		batch.set_instance_transform(index, Transform3D(axes.scaled_local(size), shape[0]))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = batch
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return batch


func _cylinder(parent: Node3D, paint: Material, at: Vector3, radius_front: float, radius_back: float, length: float, segments := STATION_RADIAL_SEGMENTS) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius_front
	cylinder.bottom_radius = radius_back
	cylinder.height = length
	cylinder.radial_segments = segments
	cylinder.rings = 1
	var item := _mesh(parent, cylinder, paint, at)
	item.rotation.x = PI * 0.5
	return item


func _ring(parent: Node3D, paint: Material, at: Vector3, radius: float, thickness: float, segments := 32) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = radius - thickness * 0.5
	ring.outer_radius = radius + thickness * 0.5
	ring.rings = segments
	ring.ring_segments = 6
	var item := _mesh(parent, ring, paint, at)
	item.rotation.x = PI * 0.5


func _build_station(station: Node3D, index: int, accent: Color) -> void:
	var primary := Color("#8c9bab") if index == 0 else Color("#969692").lerp(accent, 0.16)
	var ceramic := _panel_finish(primary, 0.28, 0.56, Vector2(5, 3))
	var graphite := _panel_finish(Color("#2a3b49"), 0.51, 0.68, Vector2(4, 2))
	var panels := _panel_finish(Color("#234a68") if index == 0 else Color("#483d4d").lerp(accent, 0.15), 0.35, 0.50, Vector2(4, 3))
	var glow := _light(accent)
	_cylinder(station, ceramic, Vector3(0, 0, -4), 7.4, 9.1, 8.8, 24)
	_cylinder(station, graphite, Vector3(0, 0, 0.45), 6.9, 7.5, 1.4, 24)
	_cylinder(station, _light(Color("#080f19")), Vector3(0, 0, 1.25), 5.14, 5.14, 0.13, 22)
	_ring(station, ceramic, Vector3(0, 0, 1.65), 5.9, 1.0, 36)
	_ring(station, glow, Vector3(0, 0, 1.95), 5.8, 0.16, 36)
	_ring(station, graphite, Vector3(0, 0, -6.65), 8.0, 0.7, 36)
	_build_dock_fittings(station, ceramic, graphite, glow)
	if index in [3, 10]:
		_build_ring_station(station, glow)
		return

	var struts: Array = []
	var plates: Array = []
	var lamps: Array = []
	var stripes: Array = []
	var arms := 4 if index == 0 else 3
	for arm in range(arms):
		var angle := TAU * float(arm) / float(arms) + (PI * 0.5 if index == 0 else PI * 0.16)
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		var tangent := Vector3(-radial.y, radial.x, 0.0)
		if index == 0:
			struts.append([radial * 13.0 + Vector3(0, 0, -4), Vector3(14.0, 2.45, 3.15), angle])
			for side: float in [-1.0, 1.0]:
				var panel := radial * 16.6 + tangent * side * 4.0 + Vector3(0, 0, -4.3)
				plates.append([panel, Vector3(10.6, 5.6, 0.7), angle])
				for bar in range(5):
					var line := panel + radial * (float(bar) - 2.0) * 2.1 + Vector3(0, 0, 0.42)
					stripes.append([line, Vector3(0.13, 5.52, 0.08), angle])
		else:
			struts.append([radial * 12.5 + Vector3(0, 0, -6), Vector3(12.4, 4.0, 4.0), angle])
			var pod := radial * 17.0 + Vector3(0, 0, -4)
			_cylinder(station, ceramic, pod, 4.1, 4.75, 9.0, 20)
			_ring(station, glow, pod + Vector3(0, 0, 4.3), 3.78, 0.12, 24)
			stripes.append([radial * 13.0 + Vector3(0, 0, -3.91), Vector3(6.1, 1.15, 0.1), angle])
		lamps.append([radial * 20.4 + Vector3(0, 0, -2.9), Vector3(1.2, 0.34, 0.4), angle])
		lamps.append([radial * 6.9 + Vector3(0, 0, 1.19), Vector3(0.65, 1.95, 0.18), angle])
		# Asymmetric radial marks make bay rotation readable at a glance.
		if arm == 0:
			lamps.append([radial * 3.25 + Vector3(0, 0, 1.98), Vector3(3.75, 0.26, 0.08), angle])
	for panel_index in range(16):
		var angle := TAU * float(panel_index) / 16.0
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		stripes.append([radial * 7.38 + Vector3(0, 0, -1.38), Vector3(0.17, 1.2, 0.75), angle])
	_box_batch(station, ceramic, struts)
	_box_batch(station, panels, plates)
	_box_batch(station, graphite, stripes)
	_box_batch(station, glow, lamps)


func _build_dock_fittings(station: Node3D, ceramic: Material, graphite: Material, glow: Material) -> void:
	var collar := _fitting(station, 1)
	_ring(collar, graphite, Vector3(0, 0, 2.05), 6.58, 0.37, 40)
	_ring(collar, ceramic, Vector3(0, 0, -2.85), 8.34, 0.23, 40)
	var panels: Array = []
	var brackets: Array = []
	var lamps: Array = []
	var louvers: Array = []
	for index in range(12):
		var angle := TAU * index / 12.0
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		panels.append([radial * 7.65 + Vector3(0, 0, -0.85), Vector3(0.41, 1.18, 1.64), angle])
		brackets.append([radial * 6.56 + Vector3(0, 0, 2.27), Vector3(0.58, 0.99, 0.25), angle])
		if index % 3 == 0:
			lamps.append([radial * 6.64 + Vector3(0, 0, 2.41), Vector3(0.24, 0.76, 0.055), angle])
		for slot in range(3):
			var depth := -4.1 - float(slot) * 0.37
			louvers.append([radial * (8.40 + float(slot) * 0.07) + Vector3(0, 0, depth), Vector3(0.23, 0.93, 0.12), angle])
	_box_batch(collar, ceramic, brackets)
	_box_batch(collar, graphite, panels)
	_box_batch(collar, glow, lamps)
	_box_batch(_fitting(station, 2), graphite, louvers)


func _build_ground_port(ground: Node3D, enclosed: bool, accent: Color) -> void:
	var alloy := _panel_finish(Color("#617282"), 0.40, 0.67, Vector2(4, 3))
	var graphite := _panel_finish(Color("#394b58"), 0.28, 0.71, Vector2(4, 4))
	var markers := _light(accent)
	var deck_radius := Ground.DECK_RADIUS - (1.6 if enclosed else 0.3)
	var deck := Ground.DECK_HEIGHT
	_cylinder(ground, alloy, Vector3(0, 0, deck - 1.23), deck_radius, deck_radius - 0.65, 2.45, 8)
	_cylinder(ground, graphite, Vector3(0, 0, deck - 0.04), deck_radius - 0.38, deck_radius - 0.38, 0.12, 8)
	var lights: Array = []
	var supports: Array = []
	for step in range(8):
		var angle := TAU * step / 8.0
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		lights.append([radial * (deck_radius - 1.15) + Vector3(0, 0, deck + 0.065), Vector3(0.28, 1.28, 0.09), angle])
		if not enclosed:
			supports.append([radial * (deck_radius - 2.30) + Vector3(0, 0, -4.9), Vector3(3.30, 2.10, 6.20), angle])
	if enclosed:
		var roof_z := Ground.HANGAR_TOP - 0.48
		_mesh(ground, _ground_hangar_shell(roof_z), alloy, Vector3.ZERO)
		_ring(ground, graphite, Vector3(0, 0, roof_z + 0.04), 8.33, 0.21, 32)
		for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
			var radial := Vector3(cos(angle), sin(angle), 0.0)
			lights.append([radial * 9.86 + Vector3(0, 0, roof_z + 0.12), Vector3(0.36, 2.18, 0.08), angle])
			lights.append([radial * 10.90 + Vector3(0, 0, roof_z - 1.41), Vector3(0.14, 1.62, 0.14), angle])
	else:
		# Landing marks leave a clear central patch for the ship and its gear.
		var paint := _light(Color("#dcebe7"))
		var deck_marks: Array = []
		for side: float in [-1.0, 1.0]:
			deck_marks.append([Vector3(side * 3.88, 0, deck + 0.05), Vector3(0.30, 5.80, 0.030)])
			deck_marks.append([Vector3(0, side * 4.40, deck + 0.05), Vector3(3.35, 0.28, 0.030)])
			for index in range(3):
				var stripe := side * (4.6 + 0.42 * index)
				deck_marks.append([Vector3(stripe, side * 5.50, deck + 0.05), Vector3(0.11, 1.25, 0.030), side * -0.5])
			lights.append([Vector3(side * 5.12, -4.55, deck + 0.35), Vector3(0.44, 0.64, 0.60)])
		_box_batch(ground, paint, deck_marks)
	_box_batch(ground, alloy, supports)
	_box_batch(ground, markers, lights)


func _ground_hangar_shell(roof_z: float) -> ArrayMesh:
	# The roof leaves the actual hatch aperture clear as the four leaves open.
	var geometry := SurfaceTool.new()
	geometry.begin(Mesh.PRIMITIVE_TRIANGLES)
	const ROOF_SEGMENTS := 24
	var rows := [
		Vector2(Ground.HANGAR_APERTURE + 0.54, 0.0), Vector2(10.35, 0.0),
		Vector2(Ground.DECK_RADIUS, -1.15), Vector2(Ground.DECK_RADIUS, -Ground.FOUNDATION_DEPTH - roof_z),
	]
	for index in range(ROOF_SEGMENTS):
		var first := Vector2.from_angle(TAU * index / ROOF_SEGMENTS)
		var next := Vector2.from_angle(TAU * (index + 1) / ROOF_SEGMENTS)
		for row in range(rows.size() - 1):
			var inner: Vector2 = rows[row]
			var outer: Vector2 = rows[row + 1]
			var a := Vector3(first.x * inner.x, first.y * inner.x, roof_z + inner.y)
			var b := Vector3(next.x * inner.x, next.y * inner.x, roof_z + inner.y)
			var c := Vector3(next.x * outer.x, next.y * outer.x, roof_z + outer.y)
			var d := Vector3(first.x * outer.x, first.y * outer.x, roof_z + outer.y)
			_facet(geometry, a, b, c, Vector2.ZERO, Vector2.RIGHT, Vector2.ONE)
			_facet(geometry, a, c, d, Vector2.ZERO, Vector2.ONE, Vector2.DOWN)
	geometry.index()
	return geometry.commit()


func _build_dock_hatch(station: Node3D, ground := false) -> DockHatch:
	var hatch := DockHatch.new()
	hatch.name = "DockHatch"
	hatch.signal_paint = _light(Color("#f1876e"))
	station.add_child(hatch)
	var steel := _surface(Color("#526878"), 0.46, 0.49)
	var dark := _surface(Color("#23323f"), 0.51, 0.60)
	var stripe := _light(Color("#efb881"))
	_ring(hatch, dark, Vector3(0, 0, -0.10), 5.30, 1.20, 32)
	_ring(hatch, steel, Vector3(0, 0, 0.32), 5.00, 0.64, 32)
	var supports: Array = []
	var signals: Array = []
	for quarter in range(4):
		var angle := PI * 0.25 + float(quarter) * PI * 0.5
		var radial := Vector3(cos(angle), sin(angle), 0)
		if not ground:
			supports.append([radial * 5.6 + Vector3(0, 0, -6.0), Vector3(0.54, 0.48, 12.0), angle])
		signals.append([radial * 5.42 + Vector3(0, 0, 0.68), Vector3(0.20, 0.78 if quarter == 0 else 0.51, 0.10), angle])
		var holder := Node3D.new()
		holder.rotation.z = angle
		hatch.add_child(holder)
		var hinge := Node3D.new()
		hinge.position.x = HATCH_HINGE_RADIUS
		holder.add_child(hinge)
		hatch.leaves.append(hinge)
		_mesh(hinge, _hatch_sector_mesh(), steel, Vector3.ZERO)
		_box_batch(hinge, dark, [[Vector3(-1.65, 0, 0.11), Vector3(3.7, 0.59, 0.13)]])
		_box_batch(hinge, stripe, [
			[Vector3(-1.72, -0.11, 0.19), Vector3(0.78, 0.12, 0.03), -0.47],
			[Vector3(-2.48, -0.11, 0.19), Vector3(0.78, 0.12, 0.03), -0.47],
		])
	_box_batch(hatch, steel, supports)
	_box_batch(hatch, hatch.signal_paint, signals)
	return hatch


func _hatch_sector_mesh() -> ArrayMesh:
	if _hatch_panel_geometry != null:
		return _hatch_panel_geometry
	var outline := PackedVector2Array([Vector2(-HATCH_HINGE_RADIUS, 0)])
	for segment in range(9):
		var angle := lerpf(-PI * 0.25 + 0.003, PI * 0.25 - 0.003, float(segment) / 8.0)
		outline.append(Vector2.from_angle(angle) * HATCH_LEAF_RADIUS - Vector2(HATCH_HINGE_RADIUS, 0))
	var front := PackedVector3Array()
	var rear := PackedVector3Array()
	for point in outline:
		front.append(Vector3(point.x, point.y, HATCH_HALF_DEPTH))
		rear.append(Vector3(point.x, point.y, -HATCH_HALF_DEPTH))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var uv := Vector2.ZERO
	for point in range(1, outline.size() - 1):
		_facet(tool, front[0], front[point + 1], front[point], uv, uv, uv)
		_facet(tool, rear[0], rear[point], rear[point + 1], uv, uv, uv)
	for point in range(outline.size()):
		var next := (point + 1) % outline.size()
		_facet(tool, front[point], front[next], rear[next], uv, uv, uv)
		_facet(tool, front[point], rear[next], rear[point], uv, uv, uv)
	_hatch_panel_geometry = tool.commit()
	return _hatch_panel_geometry


func _build_ring_station(station: Node3D, glow: StandardMaterial3D) -> void:
	var pale := _panel_finish(Color("#8498b6"), 0.36, 0.58, Vector2(12, 2))
	var shade := _panel_finish(Color("#35425a"), 0.38, 0.72, Vector2(8, 3))
	_ring(station, shade, Vector3(0, 0, -4.8), 17.9, 2.7, 44)
	_ring(station, pale, Vector3(0, 0, -3.1), 17.9, 1.3, 44)
	_ring(station, glow, Vector3(0, 0, -2.35), 17.8, 0.16, 44)
	var pylons: Array = []
	var lamps: Array = []
	var radiators: Array = []
	for index in range(8):
		var angle := TAU * float(index) / 8.0 + PI * 0.125
		var radial := Vector3(cos(angle), sin(angle), 0.0)
		var tangent := Vector3(-radial.y, radial.x, 0.0)
		pylons.append([radial * 12.5 + Vector3(0, 0, -3.8), Vector3(11.0, 0.9, 1.4), angle])
		radiators.append([radial * 18.2 + Vector3(0, 0, -4.2), Vector3(4.2, 2.6, 1.22), angle])
		lamps.append([radial * 18.5 + Vector3(0, 0, -2.98), Vector3(2.12, 0.26, 0.12), angle])
		if index in [0, 4]:
			for side: float in [-1.0, 1.0]:
				radiators.append([radial * 20.3 + tangent * side * 3.6 + Vector3(0, 0, -5.6), Vector3(5.8, 1.35, 1.48), angle])
	_box_batch(station, pale, pylons)
	_box_batch(station, shade, radiators)
	_box_batch(station, glow, lamps)


func _build_approach(approach: Node3D) -> StandardMaterial3D:
	var paint := _light(Color("#edb36c"))
	var markers: Array = []
	# Four open brackets taper from the real approach gate to the contact.
	# Local Z is normalized here; sync stretches it to the actual moving corridor.
	# A single unshaded batch stays legible without bloom, overlays or a filled tunnel.
	for step in range(4):
		var depth := float(step) / 3.0
		var width := lerpf(3.6, 7.4, depth)
		var length := lerpf(1.05, 1.75, depth)
		var stroke := lerpf(0.085, 0.14, depth)
		for x: float in [-1.0, 1.0]:
			for y: float in [-1.0, 1.0]:
				markers.append([Vector3(x * (width - length * 0.5), y * width, depth), Vector3(length, stroke, 0.002)])
				markers.append([Vector3(x * width, y * (width - length * 0.5), depth), Vector3(stroke, length, 0.002)])
		# The upper key makes the rotating frame unambiguous even for a square gate.
		markers.append([Vector3(0, width + 0.60, depth), Vector3(length * 0.70, stroke * 1.7, 0.002)])
	_box_batch(approach, paint, markers)
	return paint


func _build_navigation_corridor() -> void:
	var geometry := SurfaceTool.new()
	geometry.begin(Mesh.PRIMITIVE_LINES)
	for depth: float in [0.0, 0.20, 0.44, 0.72, 1.0]:
		var span := lerpf(1.0, 0.66, depth)
		var inside := span * 0.62
		for x: float in [-1.0, 1.0]:
			for y: float in [-1.0, 1.0]:
				geometry.add_vertex(Vector3(x * inside, y * span, depth))
				geometry.add_vertex(Vector3(x * span, y * span, depth))
				geometry.add_vertex(Vector3(x * span, y * span, depth))
				geometry.add_vertex(Vector3(x * span, y * inside, depth))
	for x: float in [-1.0, 1.0]:
		geometry.add_vertex(Vector3(x, -1.0, 0.0))
		geometry.add_vertex(Vector3(x * 0.66, -0.66, 1.0))
	_navigation_corridor = _mesh(self, geometry.commit(), _light(Color("#73c3be")), Vector3.ZERO)
	_navigation_corridor.name = "NavigationCorridor"
	_navigation_corridor.hide()


func _sectioned_shell(parent: Node3D, paint: Material, sections: Array[Vector3], at := Vector3.ZERO) -> void:
	# An octagonal cross section keeps a clear silhouette without hard box edges.
	var outline := PackedVector2Array([
		Vector2(1, 0.64), Vector2(0.71, 1), Vector2(-0.71, 1), Vector2(-1, 0.64),
		Vector2(-1, -0.64), Vector2(-0.71, -1), Vector2(0.71, -1), Vector2(1, -0.64),
	])
	var rows: Array[PackedVector3Array] = []
	for section: Vector3 in sections:
		var row := PackedVector3Array()
		for point: Vector2 in outline:
			row.append(Vector3(point.x * section.y, point.y * section.z, section.x))
		rows.append(row)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var first := sections[0].x
	var length := sections[-1].x - first
	for row in range(rows.size() - 1):
		var v0 := (sections[row].x - first) / length
		var v1 := (sections[row + 1].x - first) / length
		for edge in range(outline.size()):
			var next := (edge + 1) % outline.size()
			var u0 := float(edge) / outline.size()
			var u1 := float(edge + 1) / outline.size()
			var a := rows[row][edge]
			var b := rows[row + 1][edge]
			var c := rows[row + 1][next]
			var d := rows[row][next]
			_facet(tool, a, b, c, Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1))
			_facet(tool, a, c, d, Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v0))
	for edge in range(outline.size()):
		var next := (edge + 1) % outline.size()
		var uv0 := outline[edge] * 0.5 + Vector2(0.5, 0.5)
		var uv1 := outline[next] * 0.5 + Vector2(0.5, 0.5)
		_facet(tool, Vector3(0, 0, first), rows[0][edge], rows[0][next], Vector2(0.5, 0.5), uv0, uv1)
		_facet(tool, Vector3(0, 0, sections[-1].x), rows[-1][next], rows[-1][edge], Vector2(0.5, 0.5), uv1, uv0)
	_mesh(parent, tool.commit(), paint, at)


func _facet(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv0: Vector2, uv1: Vector2, uv2: Vector2) -> void:
	var normal := (c - a).cross(b - a).normalized()
	tool.set_normal(normal)
	tool.set_uv(uv0)
	tool.add_vertex(a)
	tool.set_normal(normal)
	tool.set_uv(uv1)
	tool.add_vertex(b)
	tool.set_normal(normal)
	tool.set_uv(uv2)
	tool.add_vertex(c)


func _build_ship_model(hull_id: String) -> void:
	if is_instance_valid(_ship):
		remove_child(_ship)
		_ship.queue_free()
	_ship_fittings.clear()
	_ship_finishes.clear()
	_gear_struts.clear()
	_gear_joints.clear()
	_gear_feet.clear()
	_gear_progress = -1.0
	_ship_hull_id = hull_id
	_ship = Node3D.new()
	add_child(_ship)
	if hull_id == ShipSystems.FREIGHTER_HULL:
		_ship.name = "FreighterHull"
		_build_freighter()
	else:
		_build_ship()


func _build_ship() -> void:
	var shell := _panel_finish(Color("#c2c8c6"), 0.35, 0.48, Vector2(7.0, 3.0), true)
	var graphite := _panel_finish(Color("#354853"), 0.49, 0.58, Vector2(4.0, 3.0), true)
	var cargo := _panel_finish(Color("#be7548"), 0.31, 0.51, Vector2(6.0, 2.0), true)
	var bare_metal := _panel_finish(Color("#778b96"), 0.61, 0.32, Vector2(4, 2), true, 0.5)
	var ice := _light(Color("#8df8e6"))
	var warm := _light(Color("#fbb768"))
	var canopy := _surface(Color("#214f70"), 0.38, 0.18)
	canopy.emission_enabled = true
	canopy.emission = Color("#16415c")
	canopy.emission_energy_multiplier = 0.26
	_sectioned_shell(_ship, shell, [
		Vector3(-1.58, 0.16, 0.12), Vector3(-1.43, 0.30, 0.21), Vector3(-0.48, 0.55, 0.39),
		Vector3(0.19, 0.59, 0.42), Vector3(1.18, 0.62, 0.50), Vector3(1.44, 0.56, 0.44),
	])
	_sectioned_shell(_ship, graphite, [
		Vector3(-1.44, 0.22, 0.08), Vector3(-0.30, 0.52, 0.18), Vector3(1.00, 0.64, 0.23), Vector3(1.37, 0.54, 0.19),
	], Vector3(0, -0.34, 0))
	_sectioned_shell(_ship, graphite, [
		Vector3(-1.34, 0.21, 0.052), Vector3(-0.86, 0.38, 0.22), Vector3(-0.27, 0.41, 0.25), Vector3(0.23, 0.30, 0.14),
	], Vector3(0, 0.33, 0))
	_sectioned_shell(_ship, canopy, [
		Vector3(-1.30, 0.18, 0.05), Vector3(-0.84, 0.34, 0.18), Vector3(-0.29, 0.36, 0.20), Vector3(0.13, 0.26, 0.107),
	], Vector3(0, 0.40, 0))
	_cylinder(_ship, graphite, Vector3(0, 0.02, 1.48), 0.48, 0.59, 0.51, 16)
	_cylinder(_ship, _surface(Color("#131e27"), 0.22, 0.80), Vector3(0, 0.02, 1.69), 0.35, 0.35, 0.08, 20)
	_cylinder(_ship, ice, Vector3(0, 0.02, 1.74), 0.25, 0.27, 0.072, 20)
	_ring(_ship, bare_metal, Vector3(0, 0.02, 1.75), 0.41, 0.12, 28)
	_ring(_ship, ice, Vector3(0, 0.02, 1.79), 0.30, 0.045, 28)
	var trim := _fitting(_ship, 1)
	var detail := _fitting(_ship, 2)
	var plates: Array = []
	var lights: Array = []
	var retaining_straps: Array = []
	var radiator_slots: Array = []
	var service_slots: Array = []
	for side: float in [-1.0, 1.0]:
		_sectioned_shell(_ship, graphite, [
			Vector3(-0.62, 0.27, 0.055), Vector3(-0.25, 0.63, 0.09), Vector3(0.88, 0.85, 0.12), Vector3(1.45, 0.56, 0.06),
		], Vector3(side * 0.94, -0.145, 0))
		_sectioned_shell(_ship, cargo, [
			Vector3(-0.59, 0.19, 0.16), Vector3(-0.41, 0.33, 0.24), Vector3(1.12, 0.34, 0.28), Vector3(1.42, 0.26, 0.22),
		], Vector3(side * 1.16, -0.11, 0))
		_cylinder(_ship, graphite, Vector3(side * 1.16, -0.11, 1.43), 0.21, 0.27, 0.18, 14)
		_cylinder(_ship, ice, Vector3(side * 1.16, -0.11, 1.54), 0.126, 0.14, 0.054, 14)
		plates.append([Vector3(side * 0.61, 0.29, 0.70), Vector3(0.33, 0.16, 0.95), side * -0.25])
		plates.append([Vector3(side * 1.64, -0.06, 0.93), Vector3(0.18, 0.14, 0.53), side * 0.10])
		lights.append([Vector3(side * 1.64, 0.025, 0.91), Vector3(0.12, 0.033, 0.43)])
		retaining_straps.append([Vector3(side * 1.16, 0.178, 0.81), Vector3(0.45, 0.035, 0.12)])
		retaining_straps.append([Vector3(side * 1.16, 0.141, -0.24), Vector3(0.43, 0.035, 0.12)])
		for slot in range(4):
			radiator_slots.append([Vector3(side * 0.61, 0.378, 0.47 + float(slot) * 0.15), Vector3(0.24, 0.045, 0.052), side * -0.25])
		for slot in range(3):
			service_slots.append([Vector3(side * 1.17, 0.182, 0.22 + float(slot) * 0.16), Vector3(0.34, 0.033, 0.045)])
	_box_batch(_ship, graphite, plates)
	_box_batch(_ship, ice, lights)
	_box_batch(trim, bare_metal, retaining_straps)
	_box_batch(trim, bare_metal, radiator_slots)
	_box_batch(detail, warm, service_slots)
	_ring(trim, graphite, Vector3(0, 0.02, 1.77), 0.47, 0.045, 30)
	_build_ship_gear(shell, graphite)
	_build_ship_jet(Vector3(0, 0.02, 2.33))


func _build_freighter() -> void:
	var shell := _panel_finish(Color("#adb7af"), 0.36, 0.48, Vector2(7, 3), true)
	var frame := _panel_finish(Color("#394b53"), 0.52, 0.55, Vector2(4, 2), true)
	var ochre := _panel_finish(Color("#b7854d"), 0.29, 0.56, Vector2(6, 3), true)
	var cream := _panel_finish(Color("#c4ad82"), 0.29, 0.58, Vector2(6, 3), true)
	var steel := _panel_finish(Color("#81949b"), 0.62, 0.34, Vector2(5, 2), true)
	var exhaust := _light(Color("#9af7ed"))
	var caution := _light(Color("#ffd182"))
	var glass := _surface(Color("#244d65"), 0.36, 0.16)
	glass.emission_enabled = true
	glass.emission = Color("#183b52")
	glass.emission_energy_multiplier = 0.29
	_sectioned_shell(_ship, frame, [
		Vector3(-2.32, 0.30, 0.14), Vector3(-1.72, 0.61, 0.33), Vector3(-1.03, 0.81, 0.49),
		Vector3(1.64, 0.88, 0.49), Vector3(2.13, 0.69, 0.43),
	], Vector3(0, -0.17, 0))
	_sectioned_shell(_ship, shell, [
		Vector3(-2.21, 0.25, 0.17), Vector3(-1.68, 0.55, 0.36), Vector3(-1.04, 0.64, 0.43),
		Vector3(0.28, 0.58, 0.41), Vector3(0.62, 0.39, 0.32),
	], Vector3(0, 0.54, 0))
	_sectioned_shell(_ship, glass, [
		Vector3(-2.05, 0.24, 0.08), Vector3(-1.54, 0.49, 0.29), Vector3(-0.98, 0.53, 0.34),
		Vector3(-0.37, 0.44, 0.25),
	], Vector3(0, 0.66, 0))
	_cylinder(_ship, frame, Vector3(0, -0.18, 2.10), 0.63, 0.64, 0.41, 20)
	_cylinder(_ship, _surface(Color("#18262d"), 0.28, 0.72), Vector3(0, -0.18, 2.33), 0.51, 0.51, 0.10, 20)
	_cylinder(_ship, exhaust, Vector3(0, -0.18, 2.39), 0.34, 0.34, 0.08, 20)
	_ring(_ship, steel, Vector3(0, -0.18, 2.42), 0.53, 0.13, 28)
	_ring(_ship, exhaust, Vector3(0, -0.18, 2.44), 0.40, 0.05, 24)

	var pylons: Array = []
	var braces: Array = []
	var locks: Array = []
	var fins: Array = []
	var lamps: Array = []
	for side: float in [-1.0, 1.0]:
		var bay_x := side * 1.42
		var engine_x := side * 2.36
		var container_shape: Array[Vector3] = [
			Vector3(-1.37, 0.60, 0.31), Vector3(-1.22, 0.68, 0.36),
			Vector3(1.41, 0.68, 0.36), Vector3(1.58, 0.56, 0.29),
		]
		_sectioned_shell(_ship, ochre, container_shape, Vector3(bay_x, -0.02, 0))
		_sectioned_shell(_ship, cream, container_shape, Vector3(bay_x, 0.73, 0))
		_sectioned_shell(_ship, frame, [
			Vector3(-0.78, 0.25, 0.24), Vector3(-0.36, 0.35, 0.31),
			Vector3(1.89, 0.35, 0.34), Vector3(2.12, 0.28, 0.28),
		], Vector3(engine_x, -0.49, 0))
		_cylinder(_ship, steel, Vector3(engine_x, -0.49, 2.21), 0.31, 0.35, 0.17, 14)
		_cylinder(_ship, exhaust, Vector3(engine_x, -0.49, 2.34), 0.21, 0.21, 0.07, 16)
		pylons.append([Vector3(side * 1.60, -0.46, 0.28), Vector3(1.80, 0.29, 2.70)])
		pylons.append([Vector3(side * 0.87, -0.47, 1.58), Vector3(1.12, 0.23, 0.78)])
		for end: float in [-1.18, 1.28]:
			braces.append([Vector3(bay_x, 0.32, end), Vector3(1.45, 1.65, 0.13)])
			locks.append([Vector3(bay_x, 1.16, end), Vector3(0.38, 0.13, 0.19)])
		for tier: float in [-0.02, 0.73]:
			locks.append([Vector3(bay_x, tier, 1.62), Vector3(0.60, 0.23, 0.11)])
			lamps.append([Vector3(bay_x + side * 0.37, tier + 0.18, 1.58), Vector3(0.15, 0.072, 0.035)])
		for row in range(5):
			fins.append([Vector3(engine_x, -0.145, 0.1 + float(row) * 0.25), Vector3(0.48, 0.064, 0.10)])
	_box_batch(_ship, frame, pylons)
	_box_batch(_ship, steel, braces)
	var trim := _fitting(_ship, 1)
	_box_batch(trim, frame, locks)
	_box_batch(trim, caution, lamps)
	_box_batch(_fitting(_ship, 2), steel, fins)
	_build_ship_gear(shell, frame)
	_build_ship_jet(Vector3(0, -0.18, 2.95), 0.44)


func _build_ship_gear(shell: Material, graphite: Material) -> void:
	_landing_gear = Node3D.new()
	_landing_gear.name = "LandingGear"
	_landing_gear.visible = false
	_ship.add_child(_landing_gear)
	var legs: Array = []
	for index in range(3):
		var angle := PI * 0.5 + TAU * float(index) / 3.0
		var radius := Vector3(cos(angle), sin(angle), 0.0)
		var joint := radius * 0.38 + Vector3(0, 0, -0.75)
		var foot := radius * 1.32 + Vector3(0, 0, -3.92)
		var strut := _cylinder(_landing_gear, shell, (joint + foot) * 0.5, 0.066, 0.1, joint.distance_to(foot), 6)
		strut.basis = Basis.looking_at(foot - joint) * Basis(Vector3.RIGHT, PI * 0.5)
		_gear_struts.append(strut)
		_gear_joints.append(joint)
		_gear_feet.append(foot)
		legs.append([foot, GEAR_PAD_SIZE, angle])
	_gear_pads = _box_batch(_landing_gear, graphite, legs)


func _build_ship_jet(at: Vector3, radius := 0.35) -> void:
	var flow := Shader.new()
	flow.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform float pulse = 0.6;
varying float tail;
void vertex() {
	tail = 1.0 - clamp(VERTEX.y / 1.6 + 0.5, 0.0, 1.0);
}
void fragment() {
	ALBEDO = mix(vec3(0.16, 0.56, 0.83), vec3(0.55, 0.94, 1.0), tail);
	ALPHA = pulse * tail * tail;
}
"""
	_jet_material = ShaderMaterial.new()
	_jet_material.shader = flow
	var flare := CylinderMesh.new()
	flare.top_radius = 0.05
	flare.bottom_radius = radius
	flare.height = 1.6
	flare.radial_segments = 10
	flare.rings = 1
	_jet = _mesh(_ship, flare, _jet_material, at)
	_jet.rotation.x = PI * 0.5


func _build_stars(cool: bool, fringe: bool) -> void:
	var generator := RandomNumberGenerator.new()
	generator.seed = 86507 if fringe else (64871 if cool else 22361)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(1730):
		var vertical := generator.randf_range(-1.0, 1.0)
		var longitude := generator.randf_range(0.0, TAU)
		var equator := sqrt(1.0 - vertical * vertical)
		var direction := Vector3(cos(longitude) * equator, vertical, sin(longitude) * equator)
		var horizontal := direction.cross(Vector3.UP).normalized()
		var upright := direction.cross(horizontal).normalized()
		var size := generator.randf_range(1.17, 3.0)
		var amount := generator.randf_range(0.25, 0.72)
		if index % 43 == 0:
			size *= 1.75
			amount = 0.93
		var tint := Color(amount * 0.82, amount * 0.90, amount)
		if index % 7 == 0:
			tint = Color(amount, amount * 0.83, amount * 0.71)
		var center := direction * STAR_DISTANCE
		var vertices: Array[Vector3] = [
			center + horizontal * size, center + upright * size,
			center - horizontal * size, center - upright * size
		]
		for corner in [0, 1, 2, 0, 2, 3]:
			mesh.set_color(tint)
			mesh.add_vertex(vertices[corner])
	var paint := _light(Color.WHITE)
	paint.vertex_color_use_as_albedo = true
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	_stars = _mesh(_sector, mesh.commit(), paint, Vector3.ZERO)


func _build_gas_giant(cool: bool, fringe: bool) -> void:
	_backdrop_planet = Node3D.new()
	_sector.add_child(_backdrop_planet)
	var physical := _gas_giant_id >= 0
	_backdrop_planet.name = "GasGiant_%d" % _gas_giant_id if physical else "DistantGasGiant"
	if not physical:
		var display_scale := 1.65 if cool else 1.0
		var initial_center := Vector3(1125, -330, -3370) if cool else Vector3(-1450, -475, -2900)
		if fringe:
			display_scale = 1.18
			initial_center = Vector3(1480, -620, -2570)
		var star_center: Vector3 = Catalog.site(_star_id).center
		_backdrop_planet.scale = Vector3.ONE * display_scale
		_backdrop_orbit_offset = initial_center * display_scale - star_center
		_backdrop_orbit_axis = _backdrop_orbit_offset.cross(Vector3.UP).normalized()

	var sphere := SphereMesh.new()
	sphere.radius = float(Catalog.site(_gas_giant_id).radius) if physical else 870.0
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 56
	sphere.rings = 26
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded;
uniform bool cool = false;
uniform bool fringe = false;
uniform sampler2D cloud_detail : repeat_enable, filter_linear_mipmap_anisotropic;
uniform int cloud_quality = 1;
uniform float weather_phase = 0.0;
uniform vec3 light_direction = vec3(-0.6, 0.46, 0.72);
varying vec3 surface_point;
float strata(vec3 p) {
	return sin(p.x * 21.0 + sin(p.z * 9.0) * 0.65) * cos(p.z * 18.0 + p.y * 13.0);
}
void vertex() {
	surface_point = normalize(VERTEX);
}
void fragment() {
	vec3 p = normalize(surface_point);
	float latitude = p.y + p.x * 0.23 + strata(p) * 0.009;
	float warp = sin(p.z * 10.0 + p.x * 13.0) * 0.52;
	float breakup = 0.0;
	float wisps = 0.0;
	float cloud_shadow = 0.0;
	if (cloud_quality > 0) {
		// Integer repeats and full-tile phase wraps meet across the sphere seam.
		// Fade noise into the continuous latitude bands at the two poles.
		float polar_fade = smoothstep(0.012, 0.12, min(UV.y, 1.0 - UV.y));
		vec2 bands_uv = vec2(UV.x * 4.0 + weather_phase, UV.y * 13.0);
		bands_uv += vec2(p.y * 0.12, sin(p.x * 6.0 + p.z * 7.0) * 0.18);
		vec3 storm = texture(cloud_detail, bands_uv).rgb;
		float fold = storm.r * 0.61 + storm.g * 0.39;
		warp += (storm.g - 0.5) * 2.34 * polar_fade;
		breakup = (fold - 0.5) * 0.32 * polar_fade;
		wisps = smoothstep(0.48, 0.66, storm.b + (fold - 0.5) * 0.17) * polar_fade * 0.24;
		cloud_shadow = (1.0 - smoothstep(0.33, 0.53, fold)) * polar_fade;
		if (cloud_quality > 1) {
			vec2 fine_uv = vec2(UV.x * 9.0 - weather_phase * 2.0, UV.y * 24.0) + storm.rg * 0.13;
			vec3 fine = texture(cloud_detail, fine_uv).rgb;
			breakup += (fine.r - 0.5) * 0.19 * polar_fade;
			wisps += smoothstep(0.50, 0.76, fine.g * 0.76 + storm.b * 0.31) * polar_fade * 0.31;
		}
	}
	float ribbons = sin(latitude * 26.0 + warp);
	float details = sin(latitude * 112.0 + sin(p.x * 25.0) * 1.5) * 0.1;
	float m = smoothstep(-0.86, 0.87, ribbons * 0.60 + details + sin(latitude * 8.0) * 0.34 + breakup);
	vec3 low = cool ? vec3(0.13, 0.20, 0.46) : vec3(0.09, 0.27, 0.37);
	vec3 high = cool ? vec3(0.44, 0.68, 0.71) : vec3(0.65, 0.43, 0.30);
	if (fringe) {
		low = vec3(0.09, 0.24, 0.18);
		high = vec3(0.78, 0.60, 0.34);
	}
	vec3 bands = mix(low, high, m);
	bands = mix(bands, high * vec3(1.16, 1.12, 1.07), wisps * (0.38 + 0.62 * m));
	bands *= 1.0 - cloud_shadow * 0.18;
	float day = smoothstep(-0.23, 0.89, dot(p, normalize(light_direction)));
	float rim = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 4.0);
	vec3 haze = fringe ? vec3(0.56, 0.63, 0.28) : (cool ? vec3(0.26, 0.44, 0.70) : vec3(0.17, 0.36, 0.44));
	ALBEDO = bands * (0.105 + day * 0.75) + rim * haze * (0.15 + day * 0.75);
}
"""
	_backdrop_material = ShaderMaterial.new()
	_backdrop_material.shader = shader
	_backdrop_material.set_shader_parameter("cool", cool)
	_backdrop_material.set_shader_parameter("fringe", fringe)
	_backdrop_material.set_shader_parameter("light_direction", Vector3(0.65, 0.54, 0.63) if cool else Vector3(-0.6, 0.46, 0.72))
	_backdrop_material.set_shader_parameter("cloud_detail", preload("res://assets/materials/cloud_bands.png"))
	_mesh(_backdrop_planet, sphere, _backdrop_material, Vector3.ZERO)
	if physical:
		# The live atmosphere is rendered at the density and size used in flight.
		return
	var air := SphereMesh.new()
	air.radius = 894.0
	air.height = 1788.0
	air.radial_segments = 48
	air.rings = 22
	var halo := Shader.new()
	halo.code = """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never;
uniform bool cool = false;
uniform bool fringe = false;
void fragment() {
	float rim = 1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0);
	ALBEDO = fringe ? vec3(0.55, 0.76, 0.48) : (cool ? vec3(0.36, 0.59, 0.91) : vec3(0.22, 0.46, 0.58));
	ALPHA = smoothstep(0.54, 0.80, rim) * (1.0 - smoothstep(0.83, 1.0, rim)) * 0.38;
}
"""
	var air_material := ShaderMaterial.new()
	air_material.shader = halo
	air_material.set_shader_parameter("cool", cool)
	air_material.set_shader_parameter("fringe", fringe)
	_mesh(_fitting(_backdrop_planet, 1), air, air_material, Vector3.ZERO)
	if cool:
		_build_planet_ring()


func _build_planet_ring() -> void:
	var disc := QuadMesh.new()
	disc.size = Vector2(3210.0, 3210.0)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
void fragment() {
	vec2 radial = UV * 2.0 - 1.0;
	float radius = length(radial);
	if (radius < 0.63 || radius > 0.988) {
		discard;
	}
	float rim = smoothstep(0.63, 0.69, radius) * (1.0 - smoothstep(0.955, 0.988, radius));
	float bands = 0.61 + 0.22 * sin(radius * 155.0) + 0.16 * sin(radius * 423.0);
	float gap = smoothstep(0.005, 0.024, abs(radius - 0.833));
	float light = 0.52 + 0.43 * smoothstep(-0.8, 0.92, radial.x - radial.y * 0.4);
	ALBEDO = mix(vec3(0.42, 0.42, 0.67), vec3(0.56, 0.78, 0.87), bands) * light;
	ALPHA = bands * rim * gap * 0.55;
}
"""
	var paint := ShaderMaterial.new()
	paint.shader = shader
	var ring := _mesh(_backdrop_planet, disc, paint, Vector3.ZERO)
	ring.basis = Basis(Vector3.FORWARD, -0.37) * Basis(Vector3.RIGHT, 1.12)
