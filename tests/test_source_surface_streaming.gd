extends SceneTree
const World=preload("res://scripts/planetary_system.gd")
const Galaxy=preload("res://scripts/galaxy.gd")
const Flight=preload("res://scripts/flight_model.gd")
const Surface=preload("res://scripts/surface_model.gd")
const Visual=preload("res://scripts/surface_visual.gd")
var checks:=0
var failures:=0
class ShiftedState extends RefCounted:
 var original:RefCounted
 func height_at(globe:RefCounted,x:float,z:float)->Dictionary:
  var result:Dictionary=original.height_at(globe,x,z).duplicate()
  if not result.is_empty():result.height=float(result.height)+2.0
  return result
func check(value:bool,message:String)->void:
 checks+=1
 if not value:
  failures+=1
  if failures<12:push_error(message)
func _init()->void:call_deferred("run")
func run()->void:
 var models:=[129,117]
 if "--stress-long" in OS.get_cmdline_user_args():models=[129] if "--earth-only" in OS.get_cmdline_user_args() else [117]
 for model in models:await review(model)
 print("SOURCE SURFACE STREAMING TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func review(model:int)->void:
 var world:=World.new();world.configure(Galaxy.new().get_system(Galaxy.SOL_ID),World.FULL_LAYOUT)
 var body:Dictionary={}
 for row:Dictionary in world.bodies:
  if int(row.model_index)==model and row.get("landable",false):body=row;break
 world.focus_id=str(body.id);world.selected_id=world.focus_id;world.site_id=""
 if model==129 and not "--stress-long" in OS.get_cmdline_user_args():
  for site:Dictionary in world.settlements:
   if str(site.parent)==world.focus_id and int(site.model_index)==84:world.site_id=str(site.id);break
 var ship:=Flight.new();ship.station_available=false;ship.source_motion_profile=true
 var surface:=Surface.new();check(surface.enter(ship,world,true),"Actual source surface enters for streaming "+str(model))
 if not surface.active:return
 if model==129 and "--stress-long" in OS.get_cmdline_user_args():
  surface.globe.latitude=0.31;surface.globe.longitude=0.42
  ship.position=Vector3(0,surface.height_at(0,0)+surface.clearance(ship)+100,0);surface.render_position=ship.position
 var snapshot:Dictionary=surface.globe.capture_worker_state()
 var worker:=Thread.new();check(worker.start(Visual._prepare_source_job.bind(snapshot,{"kind":surface.kind},"test",true))==OK,"CPU arrays prepare on actual isolated worker")
 while worker.is_alive():await process_frame
 var result:Variant=worker.wait_to_finish()
 check(result is Dictionary and result.get("ok",false),"Source worker returns complete valid arrays")
 if not result is Dictionary or not result.get("ok",false):return
 surface.source_render_packet=result.packet;surface.source_render_worker_state=result.state
 var view:=Visual.new();root.add_child(view)
 var source_before:Dictionary=surface.globe.cache_stats();var started:=Time.get_ticks_usec()
 view.configure(surface);var initial_usec:=Time.get_ticks_usec()-started
 check(surface.source_render_state!=null and view.source_ground_patch_context()!=null,"Visual and collision publish the same prepared source packet")
 check(surface.globe.cache_stats().source_samples==source_before.source_samples,"Initial scene publication performs zero native height queries")
 var cap:RefCounted=view.source_ground_patch_context()
 check(absf(cap.latitude-float(result.packet.frame.latitude))<1e-12 and cap.maximum_patch_extent()==float(result.packet.meshes[-1].outer),"Celestial cap follows actual rendered far frame and extent")
 var max_call_usec:=0;var max_pending:=0;var min_clearance:=INF;var minimum_cap_margin:=INF
 var wall_start:=Time.get_ticks_usec();var last:=wall_start;var steps:=0
 var duration:=110000000 if "--stress-long" in OS.get_cmdline_user_args() else (30000000 if "--stress-debug" in OS.get_cmdline_user_args() else 4000000)
 while Time.get_ticks_usec()-wall_start<duration:
  var now:=Time.get_ticks_usec();var dt:=minf(0.05,float(now-last)/1000000.0);last=now
  ship.position.x+=600.0*dt
  ship.position.y=surface.height_at(ship.position.x,ship.position.z)+surface.clearance(ship)+100.0
  ship.velocity=Vector3(600,0,0)
  if Vector2(ship.position.x,ship.position.z).length()>512.0:surface.recenter(ship)
  else:surface.render_position=ship.position;surface.render_velocity=ship.velocity
  var call_start:=Time.get_ticks_usec();view.configure(surface);max_call_usec=maxi(max_call_usec,Time.get_ticks_usec()-call_start)
  max_pending=maxi(max_pending,int(view.source_stream_stats().pending_jobs))
  check(int(view.source_stream_stats().pending_core_jobs)<=1 and int(view.source_stream_stats().pending_far_jobs)<=1,"Core and far preparation queues remain individually bounded")
  var hit:Dictionary=surface.source_render_state.height_at(surface.globe,ship.position.x,ship.position.z)
  if hit.is_empty() and failures==0:print(JSON.stringify({"first_miss_time":(Time.get_ticks_usec()-wall_start)/1000000.0,"frame":surface.frame_index,"ship":str(ship.position),"stats":view.source_stream_stats()}))
  check(not hit.is_empty(),"600m/s ship remains in its published exact core "+str(model))
  if not hit.is_empty():min_clearance=minf(min_clearance,ship.position.y-float(hit.height)-surface.clearance(ship))
  var rendered:RefCounted=view.source_ground_patch_context()
  var current_ll:Array=surface.geographic_position(ship)
  var delta:=pow(sin((float(current_ll[0])-float(rendered.latitude))*0.5),2)+cos(float(current_ll[0]))*cos(float(rendered.latitude))*pow(sin((float(current_ll[1])-float(rendered.longitude))*0.5),2)
  var separation:=2.0*asin(sqrt(clampf(delta,0.0,1.0)))
  var bound:=maxf(float(rendered.radius),float(rendered.source_policy.original_outer_bound_raw)*16785.0/16777216.0)
  minimum_cap_margin=minf(minimum_cap_margin,asin(clampf(float(rendered.extent)*0.9/bound,0.0,1.0))-separation)
  steps+=1;await process_frame
 ship.velocity=Vector3.ZERO;surface.render_velocity=Vector3.ZERO
 while int(view.source_stream_stats().pending_jobs)>0:
  var call_start:=Time.get_ticks_usec();view.configure(surface);max_call_usec=maxi(max_call_usec,Time.get_ticks_usec()-call_start);await process_frame
 check(max_pending<=2,"Streaming keeps at most one core and one far job")
 check(min_clearance>99.0 and surface.frame_index>1,"Nonzero rebases preserve visible/collision clearance at maximum speed")
 check(surface.globe.cache_stats().source_samples==source_before.source_samples,"Rendering and paired collision make zero main-thread native height queries across streaming")
 var after_cap:RefCounted=view.source_ground_patch_context()
 check(after_cap!=null and after_cap.source_record==cap.source_record,"Far refresh retains the actual source body context")
 check(minimum_cap_margin>=-0.00001,"Refreshed actual far context keeps the ship inside the verified celestial cutout")
 if "--stress-long" in OS.get_cmdline_user_args():check(int(view.source_stream_stats().far_jobs_finished)>1,"Continuous sixty-kilometre travel refreshes the far footprint repeatedly")
 print(JSON.stringify({"stream_model":model,"initial_publication_ms":initial_usec/1000.0,"maximum_configure_ms":max_call_usec/1000.0,"steps":steps,"stream_stats":view.source_stream_stats(),"minimum_clearance_m":min_clearance,"minimum_cap_margin_rad":minimum_cap_margin,"main_native_queries":surface.globe.cache_stats().source_samples-source_before.source_samples}))
 # Synthetic2m handoff isolates the parking/control protocol; source height
 # values are proved separately above and by the independent native tests.
 ship.position.y=surface.height_at(ship.position.x,ship.position.z)+surface.clearance(ship)+0.5;ship.velocity=Vector3.ZERO
 check(surface.touch_down(ship),"Ship parks before a pending geometry handoff")
 var parked:Dictionary=JSON.parse_string(JSON.stringify(surface.snapshot()))
 check(parked.get("terrain_contact") is Dictionary,"Parked source save includes only its verified contact triangle")
 var ship_copy:=Flight.new();check(ship_copy.restore(JSON.parse_string(JSON.stringify(ship.snapshot()))),"Parked ship data restores independently")
 ship_copy.source_motion_profile=true
 var restored:=Surface.new();restored.set_source_time(0.0)
 check(restored.restore(parked,ship_copy,world) and restored.landed,"Nonvertex parked source contact restores before any render packet")
 if restored.active and parked.has("terrain_contact"):
  check(absf(restored.altitude(ship_copy)-surface.altitude(ship))<0.1,"Saved triangle reproduces the actual published parked height")
  var bad:=parked.duplicate(true);bad.terrain_contact.vertices[0][1]+=1.0
  var before_restore:=restored.snapshot()
  check(not restored.restore(bad,ship_copy,world) and restored.snapshot()==before_restore,"Tampered contact vertex rejects atomically")
 surface.consume_render_frame_shift()
 var old_state:RefCounted=surface.source_render_state;var changed:=ShiftedState.new();changed.original=old_state
 var before_y:float=ship.position.y;var old_altitude:float=surface.altitude(ship);var old_hull:float=ship.hull;var old_docked:bool=ship.docked
 var old_world:=var_to_bytes(world.snapshot());var old_velocity:Vector3=ship.velocity
 surface.publish_source_render_state(changed)
 check(absf(ship.position.y-before_y-2.0)<0.001 and absf(surface.altitude(ship)-old_altitude)<0.005,"Atomic LOD handoff keeps parked physical clearance")
 check(surface.landed and not surface.taking_off and ship.hull==old_hull and ship.docked==old_docked and ship.velocity==old_velocity and var_to_bytes(world.snapshot())==old_world,"LOD correction preserves control/hull/time/sourceQ31 state")
 check(surface.consume_render_frame_shift().distance_to(Vector3.UP*2.0)<0.001 and surface.consume_render_frame_shift()==Vector3.ZERO,"Camera receives exactly one matching frame shift")
 check(surface.take_off(ship),"Parked ship can take off after geometry publication")
 surface.step(0.05,ship,Vector2.ZERO,0.0,1.0)
 check(not surface.landed and ship.velocity.y>0,"Phone lift remains usable after geometry publication")
 if restored.active and parked.has("terrain_contact"):
  var first:=ShiftedState.new();first.original=restored.source_render_state
  var before_altitude:float=restored.altitude(ship_copy)
  restored.publish_source_render_state(first)
  check(absf(restored.altitude(ship_copy)-before_altitude)<0.1 and restored.landed,"First cold publication after restore keeps parked clearance")
  check(restored.take_off(ship_copy),"Restored contact can take off after first cold publication")
  restored.step(0.05,ship_copy,Vector2.ZERO,0.0,1.0)
  check(not restored.landed and ship_copy.velocity.y>0,"Restored phone lift is not locked by a pending handoff")
 view.queue_free();await process_frame
