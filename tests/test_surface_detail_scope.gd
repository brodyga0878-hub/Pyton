extends SceneTree
# Independent0.11.3 geometry snapshot plus real Main/material-cache contracts.
# Hashes are Godot4.6.3 array bytes, captured before this update from commit9241a47.
const Ship=preload("res://scripts/ship_visual.gd")
const Details=preload("res://scripts/surface_detail_library.gd")
const Settings=preload("res://scripts/device_settings.gd")
class MemorySettings extends Settings:
 func load_file()->bool:return false
const BASELINE_SOURCE_SHA256:="c36be88d2fdee83ad637abb1532449c9382d9eacc8508699d43d952a31eaf04c"
const BASELINE:={
	"cobra:100": {
		"gear": "996442f8ba3e71cc2e4895c99a09e895b34f36249a85879c856b635638672a18",
		"hull": "a03ddb4407c7cca2bb82d37fb5d4ac3e7f429bf946ddd76cbf9092d3b7528346",
		"triangles": 7534
	},
	"cobra:42": {
		"gear": "20c6703cb922a16bfca54361c98a5971fe7475ff825bdb9b8c8b0d6986a73dea",
		"hull": "e05a7c6942c23a89e15e2c5800f152ef91ff480fe9aca25c3e79a41468d896c0",
		"triangles": 7534
	},
	"cobra:8": {
		"gear": "afd3cbf988feb869d227c0fa42b20b25ccc1cf9b9e54df6df8731633990c5623",
		"hull": "b81350f6970010a75dd9a741ec0e27911c120df73ee856a7cf2d94ff78d6c9d9",
		"triangles": 7534
	},
	"eagle:100": {
		"gear": "644399cb7d422ea61ed704696fe55d84db7aad623191c56117d6d01adc2a28a6",
		"hull": "7832333dc44d016753752341c265285ad5f738c64c5f51960ae21b9a5cb9a293",
		"triangles": 7534
	},
	"eagle:26": {
		"gear": "3f954993ba60f035c468db1d3f17752d0ee443ab864cc425b51d03e836501bb4",
		"hull": "ab8c88ac23c7dc3d55f3122aea42c1db3618068db245ccb301827fb2033dfa6b",
		"triangles": 7534
	},
	"eagle:8": {
		"gear": "a004e36ab2cbe1f88b63b9ec43cc5b9d9f042ecc10e7636b7f94f218768d1594",
		"hull": "24e774189c077386aa3b15d3c4fbfb2ae3bc1d96b3f612a586d84a8599f46e13",
		"triangles": 7534
	},
	"shuttle:100": {
		"gear": "1ce7e0164ebdbf7408d295ce195fa7a7f954ae12c34008b1f326aca5d0c191c2",
		"hull": "083ef9b407e5ca7d0e13841f8426e386d0fe4e1704b3947185d74c4385069c12",
		"triangles": 7534
	},
	"shuttle:24": {
		"gear": "95d117761b4201e86a67e5c62ea2c579d44f4662dd794cad49500c252f026d26",
		"hull": "9196ec22208414b2299e4625f3e150aba06baaa240327e378a54c3f70c93112c",
		"triangles": 7534
	},
	"shuttle:8": {
		"gear": "1409a55c093fbd7a2e35771d720bbd8cf8f657dd9651d41e1c21089653868532",
		"hull": "ebba8bee6b3d42485f3eac5fc8712c3a91f4f1ec76819ff0fab67f5c47f116b0",
		"triangles": 7534
	}
}
var game:Node3D
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
 checks+=1
 if not value:failures+=1;push_error(message)
func digest(mesh:Mesh)->String:
 var surfaces:Array=[]
 for surface in range(mesh.get_surface_count()):surfaces.append(mesh.surface_get_arrays(surface))
 return var_to_bytes(surfaces).hex_encode().sha256_text()
func payload()->String:return JSON.stringify(game._payload())
func models()->Array:return [game.ship,game.nav,game.world,game.surface]
func normal_flight()->void:
 check(game.graphics_return.is_empty() and not game.space_environment.visible,"Ordinary flight hides decorative preview scenery")
 check(game.space_environment.asteroid_count==0 and game.space_environment.get_child_count()==0,"Texture update does not allocate a normal-space asteroid field")
func economy_boot()->void:
 # First operation in a fresh process: do not clear the cache to hide a prior
 # allocation. An injected settings fixture avoids reading/writing preferences.
 check(Details._textures.is_empty(),"Detailed hull resource cache starts empty in the fresh test process")
 game=load("res://scenes/main.tscn").instantiate()
 var settings:=MemorySettings.new();settings.quality=0;game.settings=settings
 root.add_child(game);game.set_process(false);game.set_physics_process(false)
 check(game.automated and not game.saving_enabled,"Economy startup uses the real controller with progress persistence disabled")
 check(game.player._quality==0,"Saved economy quality reaches the player before initial visual configuration")
 check(Details._textures.is_empty(),"Initial economy boot never loads detailed ship atlas resources")
 var material:ShaderMaterial=game.player._material("frame")
 check(material.get_shader_parameter("hull_enabled")!=true and material.get_shader_parameter("hull_albedo")==null,"Initial economy material has no authored atlas binding")
 check(int(material.get_shader_parameter("detail_level"))==0,"Initial economy material receives the correct shader detail profile")
 normal_flight()
 game.queue_free();await process_frame
 check(Details._textures.is_empty(),"Economy scene teardown retains a completely unallocated detailed hull cache")
func atlas_binding(material:ShaderMaterial,id:String,extent:Vector2,enabled:=true)->void:
 check((material.get_shader_parameter("hull_enabled")==true)==enabled,"Atlas selection matches authored hull surface role")
 if not enabled:return
 for channel in ["albedo","normal","orm"]:
  check(material.get_shader_parameter("hull_"+channel)==Details.texture(id,channel),"Current ship binds its own "+id+" "+channel+" map")
 check(material.get_shader_parameter("hull_extent").is_equal_approx(extent),"Object projection matches current ship profile and physical span")
func geometry_preserved()->void:
 for key in BASELINE:
  var parts:PackedStringArray=key.split(":")
  var id:String=parts[0];var span:=float(parts[1])
  var ship:=Ship.new();root.add_child(ship);ship.configure({"id":id,"visual_span_m":span})
  check(digest(ship.hull_mesh.mesh)==BASELINE[key].hull,"Existing hull vertex/normal/UV/index arrays equal frozen0.11.3: "+key)
  check(digest(ship.landing_gear.mesh)==BASELINE[key].gear,"Existing landing-gear arrays equal frozen0.11.3: "+key)
  check(int(ship.geometry_stats.triangles)==7534,"Atlas adds no hull triangles: "+key)
  var first:Array=ship.hull_mesh.mesh.surface_get_arrays(0)
  var vertices:PackedVector3Array=first[Mesh.ARRAY_VERTEX]
  # Recorded physical landmarks from the frozen frame mesh, not a duplicate
  # of projection_extent/atlas_uv implementation. Different profiles stretch
  # these vertices; the authored image locations must stay exactly attached.
  check(Details.atlas_uv(id,span,vertices[0]).is_equal_approx(Vector2(0.5,0.095238095238)),"Frame nose keeps recorded atlas landmark across shape and span: "+key)
  check(Details.atlas_uv(id,span,vertices[2]).is_equal_approx(Vector2(0.333333333333,0.190476190476)),"Left bow keeps recorded atlas landmark across shape and span: "+key)
  ship.queue_free();await process_frame
func cache_isolation()->void:
 var ships:Array=[];var materials:Array=[];var shapes:Array=[Vector2(42,42),Vector2(23.4,31.2),Vector2(19.68,23.04)]
 var ids:Array=["cobra","eagle","shuttle"];var spans:Array=[42.0,26.0,24.0]
 for i in range(ids.size()):
  var ship:=Ship.new();root.add_child(ship);ship.configure({"id":ids[i],"visual_span_m":spans[i]});ships.append(ship)
  var material:ShaderMaterial=ship._material("frame");materials.append(material)
  for group in ["frame","armour","navy"]:atlas_binding(ship._material(group),ids[i],shapes[i])
  for group in ["edge","gold","copper","rubber"]:atlas_binding(ship._material(group),ids[i],shapes[i],false)
 check(materials[0]!=materials[1] and materials[1]!=materials[2] and materials[0]!=materials[2],"Different ship profiles cannot share mutable atlas projection materials")
 check(Details.texture("cobra","albedo")!=Details.texture("eagle","albedo") and Details.texture("eagle","albedo")!=Details.texture("shuttle","albedo"),"Three authored profiles use different original atlas resources")
 var first:Node3D=ships[0];var old_mesh:Mesh=first.hull_mesh.mesh
 first.configure({"id":"cobra","visual_span_m":42.0})
 check(first._material("frame")==materials[0] and first.hull_mesh.mesh==old_mesh,"Repeated profile configuration reuses cached material and immutable mesh")
 first.configure({"id":"cobra","visual_span_m":100.0})
 check(first._material("frame")!=materials[0],"Different physical span receives an independent projection material")
 atlas_binding(materials[0],"cobra",Vector2(42,42))
 first.set_quality(0)
 check(int(first._material("frame").get_shader_parameter("detail_level"))==0,"Economy shader profile keeps its own detail level")
 check(first._material("frame").get_shader_parameter("hull_enabled")!=true,"Economy profile uses generic maps without per-ship atlas binding")
 check(first._material("frame").get_shader_parameter("hull_albedo")==null,"Economy material does not hold the detailed hull atlas resource")
 for i in range(ids.size()):atlas_binding(materials[i],ids[i],shapes[i])
 check(int(materials[0].get_shader_parameter("detail_level"))==2,"Changing another configuration cannot lower high-quality cached detail")
 for ship in ships:ship.queue_free()
 await process_frame
func real_main_scope()->void:
 game=load("res://scenes/main.tscn").instantiate();game.settings=MemorySettings.new();root.add_child(game);game.set_process(false);game.set_physics_process(false)
 check(game.automated and not game.saving_enabled,"Actual Main suppresses user persistence in capture/test mode")
 var generation:int=game.saves.sequence;var save_directory:String=game.saves.directory
 normal_flight()
 for id in ["cobra","eagle","shuttle"]:
  game.ship.ship_id=id;game._apply_system()
  var before:=payload();var identities:=models();var geometry:=digest(game.player.hull_mesh.mesh)
  for quality in [0,1,2]:
   game.settings.quality=quality;game._apply_settings();game._sync_scene()
   check(payload()==before and models()==identities,"Visual quality preserves all four real game models for "+id)
   check((game.player._material("frame").get_shader_parameter("hull_enabled")==true)==(quality>0),"Actual Main enables authored hull detail only for medium/high quality: "+id)
   if quality>0:check(game.player._material("frame").get_shader_parameter("hull_albedo")==Details.texture(id,"albedo"),"Actual Main uses the selected profile atlas for "+id)
   else:check(game.player._material("frame").get_shader_parameter("hull_albedo")==null,"Actual economy material avoids per-ship atlas resources for "+id)
   normal_flight()
  check(digest(game.player.hull_mesh.mesh)==geometry,"Same-quality real-game hull still matches after all quality switches: "+id)
  var material:ShaderMaterial=game.player._material("frame")
  check(Details.bind_hull(material,id,float(game.ship.profile().visual_span_m)),"Authored atlas can rebind existing material without scene reconstruction")
  check(payload()==before and models()==identities and digest(game.player.hull_mesh.mesh)==geometry,"Rebinding maps preserves all game data and mesh arrays: "+id)
 game.ship.position=game.ship.STATION;game.ship.velocity=Vector3.ZERO;game.ship.target_speed=0
 game._dock_action()
 check(game.ship.docked and game.ship.DOCK_RADIUS==100.0 and game.ship.DOCK_SPEED==12.0,"Original docking action and physical limits still work after all profile material switches")
 check(game._payload().schema=="starfrontier-rebuild-game-v1" and game.saves.SCHEMA=="starfrontier-rebuild-save-v1","Texture update keeps existing serialization schemas")
 check(not game.saving_enabled and game.saves.sequence==generation and game.saves.directory==save_directory,"All real-scene material checks leave persistence disabled and unchanged")
 game.queue_free();await process_frame
func run()->void:
 if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("Requires -- --rebuild-capture");quit(1);return
 await economy_boot();await geometry_preserved();await cache_isolation();await real_main_scope()
 print("SURFACE DETAIL SCOPE TESTS: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
