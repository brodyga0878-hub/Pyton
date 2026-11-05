extends SceneTree
const Surface=preload("res://scripts/surface_model.gd")
const Visual=preload("res://scripts/surface_visual.gd")
const Sphere=preload("res://scripts/spherical_terrain.gd")
const Celestial=preload("res://scripts/celestial_renderer.gd")
const World=preload("res://scripts/planetary_system.gd")
const GalaxyData=preload("res://scripts/galaxy.gd")
const Ship=preload("res://scripts/flight_model.gd")
const Settings=preload("res://scripts/device_settings.gd")
class MemorySettings extends Settings:
 func load_file()->bool:return false
class Synthetic extends RefCounted:
 const GRID_WIDTH:=64.0
 const GRID_CELLS:=4
 var kind:="rock"
 var site_name:=""
 var seed_value:=77
 var globe:RefCounted=null
 func raw_height_at(x:float,z:float)->float:return sin(x*0.04)*cos(z*0.07)*5.0
 func pad_position()->Vector3:return Vector3(10,0,-10)
 func buildings()->Array[AABB]:return []
const BASELINE:={
 "celestial": {
  "handcrafted_analytic_rebuild_v1": {
   "economy": "111a0400029dbef248c372c995a506dd4707ccadfa7e28b497c149e1f2a7ec19",
   "normal": "c897b5b4eb93910046d47c42d4a2209460f2ae338382831846ee428b5e93eae0",
   "preview": "96a0ce54b57bfb2833f5ed1e82284a1e6b30a37e0b415ed1cafa687a17c27d67",
   "returned": "435c8f40dffc141fe6eb883b9c9964073b6aa009ea056b9bce48a684ccedd5fc"
  },
  "reconstructed_solar_v1": {
   "economy": "052a770c9ab0764ed2185efef6431489c6d5e89f35112e20da8236d1765dd40c",
   "normal": "ced00b00178d0216c3dc2b868dfbb8d5bc49a3908c390fec62d793b533ac5d63",
   "preview": "ca7815c460e190e7639ee031a946077d0ec37fcae853586e46d7abb10a5b12ec",
   "returned": "259f8a6611bf2e2eff657b2ed671fe5c3e7b17211e43e3afb455940aaf263892"
  }
 },
 "commit": "fad822558bf9be6a54e8be242473a5cceb6d0cad",
 "spherical": [
  {
   "body": "earth",
   "geometry": "b827749868af5646be00557ec15748c4a28adfd32df7fd62c8b9f5e1eed585a7",
   "key_changed_on_rebase": true,
   "kind": "earth",
   "layout": "handcrafted_analytic_rebuild_v1",
   "mesh_children": 11,
   "physics": "66e78b98d49e4d059d15ebb9aad3dfd7a8ae59518c46f8684f946db449ff83ac",
   "rebased_geometry": "9389d15c700943fc1b8601b6b057660c211c1a030737d1b95dad95b1b2f1b94c",
   "rebased_physics": "8ebfdbbfbecd0d47875308f1817b616f501ba05f290ec89949839d4787bafcac",
   "site": "",
   "transition_geometry": "07b92183f2f7b997582aa91471b6c6e35344d5cad016c5daa6c2ec66b0602209"
  },
  {
   "body": "mercury",
   "geometry": "259e7f72f8d9b1e9f8fcf75bb14db70b8961690aa6706844fe9d7c3a6a7f97ea",
   "key_changed_on_rebase": true,
   "kind": "rock",
   "layout": "handcrafted_analytic_rebuild_v1",
   "mesh_children": 11,
   "physics": "2244c04350edfc823aea560993f3cb0c16d2a3eeda1b8b934c2ea0d4d8829b07",
   "rebased_geometry": "a57e1ab645375a8b4f13ceb4ce131f6de976cb261f4b0089acf20cd06e2ae762",
   "rebased_physics": "45ef4c63c6bf93def7a43847a4518b52aac6aa703aabc21337b47954c869994a",
   "site": "",
   "transition_geometry": "82d02d72c24b17a36ef0cc398b7304af3b76bc7f03bd2e45c68c496a3170d8a6"
  },
  {
   "body": "venus",
   "geometry": "64c83002793d9492a2c51a61ad2e24ad6b434677f750d673406a3317f42b87f0",
   "key_changed_on_rebase": true,
   "kind": "desert",
   "layout": "handcrafted_analytic_rebuild_v1",
   "mesh_children": 11,
   "physics": "50f00381da07497eb7dbf7b9b36abe4b000446ed1b4b6362bd56cba0fd6b7ad0",
   "rebased_geometry": "3da74230114f051c65dff5483439a74d2297595e574f47caad49b0e770646861",
   "rebased_physics": "0de8d50f5507566b039bac5be4d43515271b0db2a2b2b7865629c96564ef9db8",
   "site": "",
   "transition_geometry": "5c98457f322878811fe8b6553e83bc7310be5d7a58bf1a05759606aa9f5fbe43"
  },
  {
   "body": "pluto",
   "geometry": "21bc4db4c751edf297b6a36ba71096f1926267b09a7ab3d666b297676fb589f9",
   "key_changed_on_rebase": true,
   "kind": "ice",
   "layout": "reconstructed_solar_v1",
   "mesh_children": 11,
   "physics": "50449327c917060af21ede771d6070a859a4d47ed104739cee7ce3e8c885e0e0",
   "rebased_geometry": "2f8f262bcd601f69c5a2bee9941c27ad44ebb70a34a8c3a3ca3521497288e198",
   "rebased_physics": "146e928c83f8e290b3f4ec3823cddafe96e13bf721e93e7b67094583197a8ebf",
   "site": "",
   "transition_geometry": "c769322e53da4c062a20c63c975b4082431b8596b7afe51a2933c4a7d96d815c"
  },
  {
   "body": "earth",
   "geometry": "1b135b22dbdfd5a3c05061a44411c5ae049d2d338e6eedcdd759131fea63dab2",
   "key_changed_on_rebase": true,
   "kind": "earth",
   "layout": "handcrafted_analytic_rebuild_v1",
   "mesh_children": 6,
   "physics": "833796ca61c4c9f2cfa2cdbf41ef3a8508810f3c54b76f48f126c4f4fc50f563",
   "rebased_geometry": "71715d8a7157ec8ff6f24a79d6e20576f691724a6aaaec8bd2ce5b9ecba1aaef",
   "rebased_physics": "4c788ce57f229e3033aae7c32a265622ab25c1f538ddc7ec4b03670d60c0a0cb",
   "site": "site10",
   "transition_geometry": "57808877d0033fc33a4939eaa684acd822b6009c444bd01d8711da8ed8078f97"
  }
 ],
 "synthetic": {
  "desert": "d73f3277e1396e6f1bae11ebe6a1f4469d3059b5f9926ede516869fa80edbd90",
  "earth": "2af26fb7cefaebde485c1b264024a2c45e0b84c45868fc020cf3c4b9609d7812",
  "ice": "1c608abf5f21a463af5dc7f63d22e2fa86fe93e4f4acc426ef275da4f7a0d7b9",
  "rock": "b6434aedafe620acc443d45ab82b8ccbcea6e695fa2722db9eb5dd8af72b997d"
 }
}
const ORIGINAL_SOURCES:={
 "surface_visual.gd": "e75eca8b5e06909860905a710166dc1ae38e708dcdcf1e910f17a8aa3c7598e9",
 "celestial_renderer.gd": "34b34f12f6772c8347e40b435d530536b230106bf73b4c8c1ef8f99dee93dd0c"
}
func digest(value:Variant)->String:return var_to_bytes(value).hex_encode().sha256_text()
func geometry(visual:Node3D)->Array:
 var rows:Array=[]
 for child in visual.get_children():
  if child is MeshInstance3D:
   var surfaces:Array=[]
   for index in range(child.mesh.get_surface_count()):surfaces.append(child.mesh.surface_get_arrays(index))
   rows.append(["mesh",digest(surfaces),child.transform,child.visible,child.get_meta("terrain_layer",false)])
  elif child is Label3D:rows.append(["label",child.transform,child.text,child.font_size,child.pixel_size,child.billboard,child.visible])
 return rows
func physics(surface:RefCounted,ship:RefCounted,world:RefCounted)->String:
 var samples:Array=[]
 for point in [Vector2(-1950,-1900),Vector2.ZERO,Vector2(64,96),Vector2(501,-650),Vector2(1750,1800),Vector2(8000,2000)]:
  samples.append([point,surface.raw_height_at(point.x,point.y),surface.height_at(point.x,point.y),surface.globe.sample(point.x,point.y)])
 return digest([surface.snapshot(),ship.snapshot(),world.snapshot(),samples,surface.pad_position(),surface.collision_radii(ship),surface.globe.flat_sites,surface.globe.source_site_coordinates,surface.globe.city_profiles,surface.city_data.get("triangles",[]),surface.city_data.get("bounds",AABB())])
func celestial_data(renderer:Node3D,world:RefCounted)->String:
 var rows:Array=[]
 for id in renderer.visuals:
  var entry:Dictionary=renderer.visuals[id];var node:MeshInstance3D=entry.mesh
  var values:Array=[id,entry.anchor.transform,entry.anchor.visible,node.transform,node.cast_shadow,digest(node.mesh.surface_get_arrays(0))]
  for key in ["body_kind","inhabited","land","ocean","seed_offset","sun_direction_world","view_coverage","coverage_invert","detail_level"]:values.append(node.material_override.get_shader_parameter(key))
  for kind in ["air","rings"]:
   if not entry.has(kind):values.append(null);continue
   var child:MeshInstance3D=entry[kind]
   values.append([kind,child.transform,child.visible,child.cast_shadow,digest(child.mesh.surface_get_arrays(0))])
   for key in ["sun_direction_world","sun_direction_local","view_coverage","coverage_invert","detail_level","atmosphere_color","ring_color"]:values.append(child.material_override.get_shader_parameter(key))
  rows.append(values)
 # Since0.11.9, separately native-verified derived record metadata is appended.
 # Exclude only these new fields from the frozen0.11.7 presentation fingerprint;
 # retain every original field, transform, mesh, light and source-template byte.
 var bodies:Array=world.bodies.duplicate(true);var sites:Array=world.settlements.duplicate(true)
 for record in bodies+sites:
  for key in ["runtime_record_hex","runtime_record_source","runtime_record_domain","source_record_domain"]:record.erase(key)
 return digest([bodies,sites,world.snapshot(),rows])
var checks:=0
var failures:=0
var packs:Script
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(message)
func mesh_refs(view:Node3D)->Array:
 var refs:Array=[]
 for child in view.get_children():
  if child is MeshInstance3D:refs.append(child.mesh)
 return refs
func loaded_world_maps()->Array:
 var found:Array=[]
 for kind in ["earth","rock","desert","ice"]:
  for channel in ["albedo","normal","orm"]:
   var path:String="res://assets/world_surfaces/"+kind+"/"+channel+".png"
   if ResourceLoader.has_cached(path):found.append(path)
 return found
func assert_ground_maps(view:Node3D,kind:String,quality:int)->void:
 var material:ShaderMaterial
 var count:=0
 for child in view.get_children():
  if not child.get_meta("terrain_layer",false):continue
  count+=1
  if material==null:material=child.material_override
  check(child.material_override==material,"Central terrain and far rings retain their one shared material")
 if material==null:check(false,"Expected an actual terrain material");return
 check(count>=1 and int(material.get_shader_parameter("detail_level"))==quality,"Quality propagates to the existing terrain and all rings")
 for channel in ["albedo","normal","orm"]:
  var expected:Texture2D=null if quality==0 else packs.texture(kind,channel)
  check(material.get_shader_parameter("material_"+channel)==expected,"Terrain retains the correct %s %s binding at quality%d"%[kind,channel,quality])
func assert_planet_maps(view:Node3D,world:RefCounted,quality:int)->void:
 for id in view.visuals:
  var material:ShaderMaterial=view.visuals[id].mesh.material_override
  var kind:=str(world.by_id[id].kind)
  var textured:=quality>0 and kind in ["earth","rock","desert","ice"]
  var correct:=int(material.get_shader_parameter("detail_level"))==quality
  for channel in ["albedo","normal","orm"]:
   var expected:Texture2D=packs.texture(kind,channel) if textured else null
   correct=correct and material.get_shader_parameter("material_"+channel)==expected
  check(correct,"Planet %s/%s uses only its own surface pack; gas/stars never bind one"%[str(id),kind])
func cold_start()->void:
 check(loaded_world_maps().is_empty(),"Fresh process starts without any detailed world maps cached")
 var metadata:Dictionary=packs.metadata()
 check(int(metadata.get("resolution",0))==1024 and loaded_world_maps().is_empty(),"Reading genuine world material metadata loads no images")
 var game:Node3D=load("res://scenes/main.tscn").instantiate()
 var settings:=MemorySettings.new();settings.quality=0;game.settings=settings
 root.add_child(game);game.set_process(false);game.set_physics_process(false);await process_frame
 check(game.automated and not game.saving_enabled,"Actual cold Main disables user progress access through capture mode")
 check(loaded_world_maps().is_empty(),"Actual Main economy startup loads no detailed world maps")
 assert_planet_maps(game.celestial,game.world,0)
 game.queue_free();await process_frame
 var surface:=Synthetic.new();surface.kind="earth"
 var view:=Visual.new();view.set_quality(0);root.add_child(view);view.configure(surface)
 var refs:=mesh_refs(view);var original:=geometry(view)
 check(loaded_world_maps().is_empty(),"Cold economy ground creation also avoids all world maps")
 assert_ground_maps(view,"earth",0)
 view.set_quality(2)
 var found:=loaded_world_maps()
 check(found.size()==3 and found.all(func(path:String)->bool:return path.contains("/earth/")),"First high-quality earth ground loads only its three maps")
 check(mesh_refs(view)==refs and geometry(view)==original,"Lazy texture binding does not replace a mesh or alter its arrays")
 assert_ground_maps(view,"earth",2)
 view.set_quality(0);assert_ground_maps(view,"earth",0)
 check(mesh_refs(view)==refs and geometry(view)==original,"Downgrading quality releases bindings without replacing geometry")
 check(loaded_world_maps().size()==3,"Already-used shared resources may remain cached after lowering quality")
 view.queue_free();await process_frame
func review_surface(world:RefCounted,row:Dictionary,record:=false)->Dictionary:
 var id:=str(row.body);var site:=str(row.site)
 world.focus_id=id;world.selected_id=id;world.site_id=site
 var ship:=Ship.new();ship.docked=false;ship.velocity=Vector3.ZERO
 var surface:=Surface.new()
 var entered:bool=surface.enter(ship,world,true)
 if not entered:push_error("Cannot enter "+id+":"+surface.message);return {}
 surface.extended_flight=true
 var view:=Visual.new();root.add_child(view);view.configure(surface)
 var first:=geometry(view);var first_physics:=physics(surface,ship,world)
 var first_key:=surface.terrain_key();var refs:=mesh_refs(view)
 var material:ShaderMaterial=view.get_child(0).material_override
 var origin:Variant=material.get_shader_parameter("material_origin")
 if not record:
  for quality in [0,1,2]:
   view.set_quality(quality);view.configure(surface)
   assert_ground_maps(view,str(surface.kind),quality)
   check(mesh_refs(view)==refs and geometry(view)==first,"Terrain quality/cache reuse leaves all vertices, normals, colours and indices intact")
   check(physics(surface,ship,world)==first_physics,"Material binding leaves actual height, samples, native city pads and collision unchanged")
 view.set_view_coverage(0.35)
 var transition:=geometry(view)
 if not record:
  assert_ground_maps(view,str(surface.kind),2)
  check(material.get_shader_parameter("material_origin")==origin,"Coverage shader changes preserve body-fixed texture phase")
  check(mesh_refs(view)==refs,"Near-to-orbit coverage uses existing terrain meshes")
 view.set_view_coverage(1.0)
 ship.position.x+=900;ship.position.z-=700;surface.recenter(ship);view.configure(surface)
 var rebased:=geometry(view);var rebased_physics:=physics(surface,ship,world)
 var value:={"body":id,"kind":surface.kind,"site":site,"layout":world.layout_mode,"geometry":digest(first),"transition_geometry":digest(transition),"rebased_geometry":digest(rebased),"physics":first_physics,"rebased_physics":rebased_physics,"mesh_children":first.size(),"key_changed_on_rebase":first_key!=surface.terrain_key()}
 if not record:
  for field in ["kind","layout","geometry","transition_geometry","rebased_geometry","physics","rebased_physics","mesh_children","key_changed_on_rebase"]:
   check(value[field]==row[field],"Independent0.11.7 %s/%s/%s baseline matches %s"%[str(surface.kind),id,site,field])
  assert_ground_maps(view,str(surface.kind),2)
 view.queue_free();await process_frame
 return value
func review_celestial(world:RefCounted,record:=false)->Dictionary:
 var renderer:=Celestial.new();root.add_child(renderer);renderer.configure(world)
 var captures:Dictionary={}
 var refs:Array=[]
 for entry in renderer.visuals.values():refs.append(entry.mesh.mesh)
 renderer.update_view(0.125,Vector3(123,55,-2000));captures.normal=celestial_data(renderer,world)
 if not record:assert_planet_maps(renderer,world,2)
 renderer.set_quality(0);renderer.update_view(3.5,Vector3(-600,130,2050));captures.economy=celestial_data(renderer,world)
 if not record:assert_planet_maps(renderer,world,0)
 renderer.set_quality(2);renderer.set_surface_transition(true,0.35);renderer.update_view(1.25,world.local_meters("earth",1.25)+Vector3(1000,25000,1000));captures.preview=celestial_data(renderer,world)
 if not record:
  assert_planet_maps(renderer,world,2)
  var after:Array=[]
  for entry in renderer.visuals.values():after.append(entry.mesh.mesh)
  check(refs==after,"Quality and pre-existing preview LOD retain original sphere resource identities")
 renderer.set_surface_transition(false,0.0);renderer.update_view(1.25,Vector3(123,55,-2000));captures.returned=celestial_data(renderer,world)
 if not record:
  var expected:Dictionary=BASELINE.celestial[world.layout_mode]
  for state in ["normal","economy","preview","returned"]:check(captures[state]==expected[state],"Independent0.11.7 planet poses, meshes, spin, sunlight, rings, source data and coverage: %s/%s"%[world.layout_mode,state])
 renderer.queue_free();await process_frame
 return captures
func live_main()->void:
 var game:Node3D=load("res://scenes/main.tscn").instantiate();var settings:=MemorySettings.new();settings.quality=2;game.settings=settings
 root.add_child(game);game.set_process(false);game.set_physics_process(false);await process_frame
 game.active=true;game.world.focus_id="earth";game.world.selected_id="earth";game.world.site_id="site10";game._apply_system();await game._enter_surface()
 check(game.surface.active and int(game.surface.city_data.profile.model_index)==84,"Actual Main still enters native New Moscow84")
 if not game.surface.active:game.queue_free();await process_frame;return
 game._sync_scene();var original:=digest(game._payload());var physical:=physics(game.surface,game.ship,game.world)
 var terrain:=geometry(game.ground_view);var refs:=mesh_refs(game.ground_view)
 var city:Node3D=game.city_view.current_visual();var city_refs:=mesh_refs(city);var city_transform:Transform3D=city.global_transform
 for quality in [0,1,2]:
  game.settings.quality=quality;game._apply_settings();game._sync_scene()
  check(digest(game._payload())==original and physics(game.surface,game.ship,game.world)==physical,"Actual Main material choices do not change flight, navigation, saves or surface physics")
  check(geometry(game.ground_view)==terrain and mesh_refs(game.ground_view)==refs,"Actual Main quality retains original terrain/ring arrays and resources")
  check(game.city_view.current_visual()==city and mesh_refs(city)==city_refs and city.global_transform==city_transform,"World material update leaves native city placement and cached geometry intact")
  assert_ground_maps(game.ground_view,"earth",quality);assert_planet_maps(game.celestial,game.world,quality)
 check(game.automated and not game.saving_enabled,"Actual Main checks never enable user progress persistence")
 game.queue_free();await process_frame
func record_baseline()->void:
 for name in ORIGINAL_SOURCES:
  if FileAccess.get_file_as_string("res://scripts/"+name).sha256_text()!=ORIGINAL_SOURCES[name]:push_error("Baseline recording requires original0.11.7 source: "+name);quit(1);return
 var report:={"commit":BASELINE.commit,"synthetic":{},"spherical":[],"celestial":{}}
 for kind in ["earth","rock","desert","ice"]:
  var surface:=Synthetic.new();surface.kind=kind;var view:=Visual.new();root.add_child(view);view.configure(surface)
  report.synthetic[kind]=digest(geometry(view));view.queue_free();await process_frame
 var galaxy:=GalaxyData.new();var world:=World.new()
 for row in BASELINE.spherical:
  world.configure(galaxy.get_system(GalaxyData.SOL_ID),str(row.layout));report.spherical.append(await review_surface(world,row,true))
 for layout in [World.SOURCE_LAYOUT,World.SOLAR_LAYOUT]:
  world.configure(galaxy.get_system(GalaxyData.SOL_ID),layout);report.celestial[layout]=await review_celestial(world,true)
 DirAccess.make_dir_recursive_absolute("res://build")
 var file:=FileAccess.open("res://build/world-surface-baseline.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
 print("WORLD SURFACE BASELINE CAPTURED: original0.11.7 source only");quit()
func run()->void:
 if "--world-baseline-capture" in OS.get_cmdline_user_args():await record_baseline();return
 if not "--rebuild-capture" in OS.get_cmdline_user_args():push_error("World invariants require --rebuild-capture");quit(1);return
 packs=load("res://scripts/world_surface_library.gd")
 await cold_start()
 for kind in ["earth","rock","desert","ice"]:
  var surface:=Synthetic.new();surface.kind=kind;var view:=Visual.new();root.add_child(view);view.configure(surface)
  check(digest(geometry(view))==BASELINE.synthetic[kind],"Independent0.11.7 synthetic %s surface preserves every mesh array and primitive"%kind)
  assert_ground_maps(view,kind,2);view.queue_free();await process_frame
 var galaxy:=GalaxyData.new();var world:=World.new()
 for row in BASELINE.spherical:
  world.configure(galaxy.get_system(GalaxyData.SOL_ID),str(row.layout));await review_surface(world,row)
 for layout in [World.SOURCE_LAYOUT,World.SOLAR_LAYOUT]:
  world.configure(galaxy.get_system(GalaxyData.SOL_ID),layout);await review_celestial(world)
 await live_main()
 print("WORLD SURFACE INVARIANT TESTS: %d checks, %d failures; independent0.11.7 mesh/physics and real Main, no phone claim"%[checks,failures]);quit(1 if failures else 0)
