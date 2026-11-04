extends SceneTree
# Geometry/resource contract for new artwork; no claim about original FFE hulls.
const Ship=preload("res://scripts/ship_visual.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:failures+=1;push_error(message)
func run()->void:
	var profiles:Array=[{"id":"cobra","visual_span_m":42.0},{"id":"eagle","visual_span_m":26.0},{"id":"shuttle","visual_span_m":24.0}]
	for profile in profiles:
		var ship:=Ship.new();root.add_child(ship);ship.configure(profile)
		var pristine:Dictionary=profile.duplicate(true)
		for quality in range(3):
			ship.set_quality(quality)
			var mesh:Mesh=ship.hull_mesh.mesh;var bounds: AABB=mesh.get_aabb()
			check(mesh.get_surface_count()<=12 and mesh.get_surface_count()>=8,"Batched material draw surfaces remain bounded")
			check(int(ship.geometry_stats.triangles)>1000 and int(ship.geometry_stats.triangles)<18000,"Authored hull has useful detail with bounded triangle cost")
			check(bounds.size.x<=float(profile.visual_span_m)*1.03 and bounds.size.z<=float(profile.visual_span_m)*1.25,"New solid artwork fits the established flight envelope")
			check(bounds.position.z<0 and bounds.end.z>0 and bounds.size.y<float(profile.visual_span_m)*0.4,"Hull preserves forward axis and manageable vertical extent")
			check(ship.get_child_count()<=5,"Batched art does not create hundreds of scene nodes")
			var finite_geometry:=true;var has_upward_face:=false;var has_downward_face:=false
			for surface in range(mesh.get_surface_count()):
				var arrays:=mesh.surface_get_arrays(surface);var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
				finite_geometry=finite_geometry and vertices.size()%3==0 and vertices.size()==normals.size() and mesh.surface_get_material(surface)!=null
				for i in range(vertices.size()):
					finite_geometry=finite_geometry and vertices[i].is_finite() and normals[i].is_finite() and absf(normals[i].length()-1)<0.002
					if normals[i].y>0.8:has_upward_face=true
					if normals[i].y< -0.8:has_downward_face=true
			check(finite_geometry,"All cached triangles/materials and normals are finite and complete")
			check(has_upward_face and has_downward_face,"Armour and belly outward faces both exist")
			ship.set_thrust(1);ship._process(0.5)
			check(ship._exhausts.size()==2 and ship._exhausts[0].position.is_finite() and ship._exhausts[0].scale.y>1,"Twin exhaust responds to actual throttle")
			ship.set_thrust(NAN);ship._process(1)
			check(ship._thrust==0 and ship._exhausts[0].scale.is_finite(),"Invalid visual throttle cannot poison rendering transforms")
			check(ship._exhausts[0].material_override!=ship._exhausts[1].material_override,"Individual jets do not mutate shared material power")
		var gear_floor:float=ship.landing_gear.mesh.get_aabb().position.y
		check(absf(gear_floor+float(profile.visual_span_m)*0.14+2.0)<0.001,"Landing feet match the existing physical ground-clearance plane")
		ship.set_landed(true);ship._process(1)
		check(ship.landing_gear.visible and absf(ship.landing_gear.scale.y-1)<0.001,"Gear extends when grounded")
		ship.set_landed(false);ship._process(1)
		check(not ship.landing_gear.visible,"Gear retracts during flight without changing the hull mesh")
		check(profile==pristine,"Graphics configuration never mutates a flight profile")
		var cached_mesh:Mesh=ship.hull_mesh.mesh;ship.configure(profile)
		check(ship.hull_mesh.mesh==cached_mesh,"Repeated configuration reuses immutable hull geometry")
		check(ship.get_child_count()<=5,"Repeated configuration does not accumulate live nodes")
		print("SHIP GRAPHICS %s: %d triangles, %d surfaces"%[profile.id,ship.geometry_stats.triangles,ship.geometry_stats.material_surfaces])
		ship.queue_free();await process_frame
	print("SHIP GRAPHICS TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
