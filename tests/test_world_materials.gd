extends SceneTree
# Render adapters must leave compiled geometry/palette and physical terrain alone.
const Visual=preload("res://scripts/source_model_visual.gd")
const SurfaceVisual=preload("res://scripts/surface_visual.gd")
const Materials=preload("res://scripts/material_library.gd")
const CityMaterials=preload("res://scripts/city_surface_library.gd")
const WorldMaterials=preload("res://scripts/world_surface_library.gd")
const Units=preload("res://scripts/source_units.gd")
class FakeSurface extends RefCounted:
 const GRID_WIDTH:=32.0
 const GRID_CELLS:=2
 var kind:="rock"
 var site_name:="Test"
 var seed_value:=4
 var globe:RefCounted=null
 func raw_height_at(_x:float,_z:float)->float:return 0.0
 func pad_position()->Vector3:return Vector3.ZERO
 func buildings()->Array[AABB]:return [AABB(Vector3(200,0,200),Vector3(20,40,20))]
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func _init()->void:call_deferred("run")
func face(rgb:Array,offset:int,unlit:=false)->Dictionary:
 return {"vertices":[[0,0,0],[1000000,0,0],[0,0,1000000]],"material_base":{"rgb4_base":rgb,"unlit":unlit},"offset":offset,"instance_path":"material-contract"}
func run()->void:
 var compiled:Dictionary={"ok":true,"model_index":89,"triangles_raw":[face([4,4,4],0),face([2,2,2],1),face([6,1,1],2),face([8,8,8],3),face([1,8,4],4,true)],"source_events":[]}
 var immutable:=JSON.stringify(compiled)
 var visual:=Visual.new();root.add_child(visual)
 check(visual.configure(compiled),"Source visual accepts synthetic original faces")
 check(JSON.stringify(compiled)==immutable,"Material classification does not mutate source packets")
 check(visual.triangle_count==5,"All original triangles retained")
 var source_bounds:=visual.local_bounds
 var expected:Vector3=Visual.DEFAULT_CONVERSION*Vector3(1000000,0,0)*Units.METRES_PER_RAW
 var lit:MeshInstance3D=visual.get_node("SourceLit")
 var arrays:Array=lit.mesh.surface_get_arrays(0)
 var positions:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var palette:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
 check(positions[1].is_equal_approx(expected),"Source conversion still controls vertex position")
 var expected_colour:Color=Visual.palette_colour([4,4,4]).srgb_to_linear()
 check(absf(palette[0].r-expected_colour.r)<=1.0/255.0 and absf(palette[0].g-expected_colour.g)<=1.0/255.0 and absf(palette[0].b-expected_colour.b)<=1.0/255.0 and is_equal_approx(palette[0].a,0.0),"Original source linear RGB retained with unlit encoded separately")
 var slots:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
 for index in range(4):check(is_equal_approx(slots[index*3].y,float(index)),"Provisional palette/orientation slot %d assigned without source vertex changes"%index)
 for channel in ["albedo","normal","orm"]:
  check(CityMaterials.texture(channel)!=null and lit.material_override.get_shader_parameter("city_"+channel)==CityMaterials.texture(channel),"City uses padded four-role %s atlas"%channel)
 var original_mesh:Mesh=lit.mesh
 visual.set_quality(0)
 check(int(lit.material_override.get_shader_parameter("detail_level"))==0 and lit.mesh==original_mesh and visual.local_bounds==source_bounds,"Low quality changes material only and retains original mesh/bounds")
 for channel in ["albedo","normal","orm"]:check(lit.material_override.get_shader_parameter("city_"+channel)==null,"Low city quality releases material reference to %s atlas"%channel)
 visual.set_quality(2)
 check(lit.mesh==original_mesh and lit.material_override.get_shader_parameter("city_albedo")==CityMaterials.texture("albedo"),"High city quality rebinds shared atlas without rebuilding source mesh")
 var unlit:MeshInstance3D=visual.get_node("SourceUnlit")
 var unlit_colours:PackedColorArray=unlit.mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR]
 check(is_equal_approx(unlit_colours[0].a,1.0),"Original unlit flags retained")
 var surface:=FakeSurface.new()
 var terrain:=SurfaceVisual.new();root.add_child(terrain);terrain.configure(surface)
 var ground:MeshInstance3D=terrain.get_child(0)
 var ground_mesh:Mesh=ground.mesh
 var ground_arrays:Array=ground_mesh.surface_get_arrays(0)
 check(ground.material_override.get_shader_parameter("material_albedo")==WorldMaterials.texture("rock","albedo"),"Rock terrain has dedicated natural albedo texture")
 check(ground.material_override.get_shader_parameter("material_normal")==WorldMaterials.texture("rock","normal"),"Rock terrain has dedicated natural normal texture")
 check(ground.material_override.get_shader_parameter("material_orm")==WorldMaterials.texture("rock","orm"),"Rock terrain has dedicated natural packed AO/roughness/metallic texture")
 var pad_found:=false;var building_found:=false
 for child in terrain.get_children():
  if child is MeshInstance3D and child.material_override is ShaderMaterial:
   if child.material_override.shader==terrain.PadShader:
    pad_found=child.material_override.get_shader_parameter("material_albedo")==Materials.texture("asphalt","albedo")
   if child.material_override.shader==terrain.BuildingShader:
    building_found=child.material_override.get_shader_parameter("material_albedo")==Materials.texture("concrete","albedo")
 check(pad_found and building_found,"Existing fallback pad/building receive asphalt and concrete maps")
 terrain.set_view_coverage(0.35)
 check(ground.material_override.shader==terrain.TransitionShader and ground.material_override.get_shader_parameter("material_albedo")==WorldMaterials.texture("rock","albedo"),"Transition retains the same terrain texture resources")
 terrain.set_view_coverage(1.0);terrain.set_quality(0)
 check(ground.mesh==ground_mesh and ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]==ground_arrays[Mesh.ARRAY_VERTEX] and ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]==ground_arrays[Mesh.ARRAY_NORMAL],"Coverage and material quality do not change terrain coordinates/normals")
 check(int(ground.material_override.get_shader_parameter("detail_level"))==0,"Low terrain quality disables map shading branch")
 surface.kind="ice";terrain.configure(surface)
 ground=terrain.get_child(0)
 check(ground.material_override.get_shader_parameter("material_albedo")==null,"New ice terrain at low quality keeps its maps unbound")
 terrain.set_quality(2)
 check(ground.material_override.get_shader_parameter("material_albedo")==WorldMaterials.texture("ice","albedo"),"Existing ice terrain selects dedicated ice texture pack")
 visual.queue_free();terrain.queue_free();await process_frame
 print("WORLD MATERIAL TESTS: %d checks, %d failures; synthetic render adapter geometry only"%[checks,failures])
 quit(1 if failures else 0)
