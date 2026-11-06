extends SceneTree
# Exercises the application restore boundary and actual InputEvent routing.
const SaveStore=preload("res://scripts/save_store.gd")
const Main=preload("res://scripts/main.gd")
const Stick=preload("res://scripts/touch_stick.gd")
const Hold=preload("res://scripts/hold_button.gd")
const Lever=preload("res://scripts/speed_lever.gd")
var checks:=0
var failures:=0
var controls:Array=[]
var directories:Array[String]=[]

func _init()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<20:push_error(message)
func near(a:float,b:float,tolerance:=0.0001)->bool:return absf(a-b)<tolerance
func json_copy(data:Dictionary)->Dictionary:return JSON.parse_string(JSON.stringify(data))
func store_for(name:String)->RefCounted:
	var store:=SaveStore.new();store.directory="user://save-touch-tests-%d-%s"%[OS.get_process_id(),name]
	directories.append(store.directory);return store
func put_text(path:String,content:String)->void:
	var file:=FileAccess.open(path,FileAccess.WRITE)
	check(file!=null,"Test fixture file opens: "+path)
	if file:file.store_string(content);file.close()
func cleanup()->void:
	for directory in directories:
		for file in ["slot0.json","slot1.json","slot0.json.tmp","slot1.json.tmp"]:
			if FileAccess.file_exists(directory+"/"+file):DirAccess.remove_absolute(directory+"/"+file)
		DirAccess.remove_absolute(directory)

func save_envelopes()->void:
	var store:=SaveStore.new();var payload:={"commander":"Командир Яр","credits":70123,"position":[1.25,-9.5,0.0]}
	var encoded:String=store.encode(payload,7);var decoded:Dictionary=store.decode(encoded)
	check(decoded.get("generation")==7 and decoded.get("payload",{}).get("commander")==payload.commander and decoded.payload.credits==70123 and near(decoded.payload.position[0],1.25),"Exact UTF-8 body survives a checksummed save round trip")
	var envelope:Dictionary=JSON.parse_string(encoded);var cases:Array=[];var bad:Dictionary
	bad=envelope.duplicate(true);bad.sha256="0".repeat(64);cases.append(bad)
	bad=envelope.duplicate(true);bad.body=bad.body.replace("70123","80123");cases.append(bad)
	bad=envelope.duplicate(true);bad.schema="unknown";cases.append(bad)
	bad=envelope.duplicate(true);bad.erase("body");cases.append(bad)
	for generation in [-1,1.5,1000000001,true,"7",null]:
		bad=envelope.duplicate(true);bad.generation=generation;cases.append(bad)
	for index in range(cases.size()):
		check(store.decode(JSON.stringify(cases[index])).is_empty(),"Invalid/tampered save envelope is rejected: %d"%index)
	check(store.decode("null").is_empty() and store.decode("[]").is_empty(),"Non-object outer JSON is rejected")
	bad=envelope.duplicate(true);bad.body="[]";bad.sha256=store._digest(bad.body)
	check(store.decode(JSON.stringify(bad)).is_empty(),"A correctly hashed non-object game payload is rejected")
	check(not store.decode(store.encode(payload,0)).is_empty() and not store.decode(store.encode(payload,1000000000)).is_empty(),"Backup generation zero and bounded last generation remain readable")

func save_slots()->void:
	var store:RefCounted=store_for("slots")
	check(store.write({"version":1,"credits":100}),"First atomic slot is written")
	var older:=FileAccess.get_file_as_string(store.directory+"/slot1.json")
	check(store.write({"version":1,"credits":200}) and store.sequence==2,"Second generation alternates to the other slot")
	check(FileAccess.get_file_as_string(store.directory+"/slot1.json")==older,"Newest write preserves the previous complete generation")
	var accept:=func(payload:Dictionary)->Dictionary:return payload if payload.get("version")==1 else {}
	var reader:RefCounted=SaveStore.new();reader.directory=store.directory
	check(reader.load_valid(accept).get("credits")==200 and reader.sequence==2,"Restart selects the newest accepted generation")
	var damaged:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(store.directory+"/slot0.json"));damaged.sha256="f".repeat(64)
	put_text(store.directory+"/slot0.json",JSON.stringify(damaged))
	check(reader.load_valid(accept).get("credits")==100 and reader.sequence==1,"Corrupted newest save falls back to the complete older generation")
	check(reader.write({"version":1,"credits":300}) and reader.sequence==2,"Saving after fallback replaces the corrupt slot")
	check(FileAccess.get_file_as_string(store.directory+"/slot1.json")==older,"Repair after fallback still preserves its known-good predecessor")
	put_text(store.directory+"/slot1.json.tmp",store.encode({"version":1,"credits":999},999))
	check(reader.load_valid(accept).get("credits")==300 and reader.sequence==2,"A leftover interrupted-write temporary file is never considered committed")
	check(reader.write({"version":2,"credits":400}),"A semantic rejection fixture has a valid outer checksum")
	check(reader.load_valid(accept).get("credits")==300 and reader.sequence==2,"Correct hash with incompatible payload falls back through the validator")
	var before0:=FileAccess.get_file_as_string(store.directory+"/slot0.json")
	var before1:=FileAccess.get_file_as_string(store.directory+"/slot1.json")
	check(not reader.write({"version":1,"oversize":"x".repeat(2000001)}) and not reader.last_error.is_empty(),"A written temporary body beyond the read limit fails verification")
	check(reader.sequence==2 and FileAccess.get_file_as_string(store.directory+"/slot0.json")==before0 and FileAccess.get_file_as_string(store.directory+"/slot1.json")==before1,"Failed write changes neither sequence nor either committed slot")
	check(reader.load_valid(accept).get("credits")==300,"Committed save remains recoverable after a failed write")
	var empty:RefCounted=store_for("rejected");check(empty.write({"version":8}),"All-rejected fixture writes")
	var untouched:RefCounted=SaveStore.new();untouched.directory=empty.directory;untouched.sequence=11
	check(untouched.load_valid(accept).is_empty() and untouched.sequence==11,"No accepted candidate cannot advance the in-memory generation")

func complete_state_boundary()->void:
	# Keep Main outside the tree so no renderer, UI, startup load or autosave runs.
	var app:=Main.new();app._new_models();app.saving_enabled=false
	app.ship.credits=71234;app.ship.autopilot=true;app.nav.message="Оставить навигацию";app.world.message="Оставить мир"
	var original_ship:RefCounted=app.ship;var original_nav:RefCounted=app.nav
	var original_world:RefCounted=app.world;var original_surface:RefCounted=app.surface
	var before:=JSON.stringify(app._payload());var saved:Dictionary=json_copy(app._payload())
	var bad:=saved.duplicate(true);bad.flight.credits=99999;bad.surface.version=0
	check(app._decode_state(bad).is_empty(),"Application rejects a late surface error after flight/navigation/world have decoded")
	check(JSON.stringify(app._payload())==before and app.ship==original_ship and app.nav==original_nav and app.world==original_world and app.surface==original_surface,"Rejected complete restore changes no live model or snapshot")
	check(app.ship.autopilot and app.nav.message=="Оставить навигацию" and app.world.message=="Оставить мир","Rejected staged restore also preserves live transient flags and messages")
	var accepted:Dictionary=app._decode_state(saved)
	check(not accepted.is_empty() and app.ship==original_ship and JSON.stringify(app._payload())==before,"Successful validation is staged and cannot mutate live state before commit")
	check(accepted.ship!=original_ship and accepted.nav!=original_nav and accepted.world!=original_world and accepted.surface!=original_surface,"All four accepted candidate models are independent objects")
	var store:RefCounted=store_for("complete")
	check(store.write(saved) and store.write(bad),"Complete fallback fixtures have valid disk envelopes")
	var recovered:Dictionary=store.load_valid(app._decode_state)
	check(not recovered.is_empty() and recovered.ship.credits==71234 and store.sequence==1,"Late invalid newest game state falls back to an earlier complete state")
	check(app.ship==original_ship and app.ship.credits==71234 and app.ship.autopilot,"Candidate fallback never partially installs a rejected ship")
	app._commit_state(recovered)
	check(app.ship==recovered.ship and app.nav==recovered.nav and app.world==recovered.world and app.surface==recovered.surface,"Commit installs all four already validated model objects together")
	check(not app.ship.autopilot and app.ship.credits==71234,"Commit rebuilds transient guidance instead of trusting the save")
	app.free()

func at(control:Control,point:Vector2)->Vector2:return control.get_global_transform_with_canvas()*point
func touch(index:int,point:Vector2,pressed:=true,canceled:=false)->void:
	var event:=InputEventScreenTouch.new();event.index=index;event.position=point;event.pressed=pressed;event.canceled=canceled;root.push_input(event,true)
func drag(index:int,point:Vector2)->void:
	var event:=InputEventScreenDrag.new();event.index=index;event.position=point;root.push_input(event,true)
func mouse(point:Vector2,pressed:=true)->void:
	var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event,true)
func motion(point:Vector2,buttons:int)->void:
	var event:=InputEventMouseMotion.new();event.position=point;event.button_mask=buttons;root.push_input(event,true)

func phone_controls()->void:
	var layer:=CanvasLayer.new();layer.transform=Transform2D(0.07,Vector2(25,30));root.add_child(layer)
	var container:=Control.new();container.position=Vector2(50,25);container.scale=Vector2(1.3,0.8);container.rotation=-0.11;layer.add_child(container)
	var stick:=Stick.new();stick.size=Vector2(200,200);stick.position=Vector2(10,20);container.add_child(stick)
	var lever:=Lever.new();lever.size=Vector2(80,240);lever.position=Vector2(320,20);container.add_child(lever)
	var hold:=Hold.new();hold.size=Vector2(120,80);hold.position=Vector2(440,20);hold.text="ПОДЪЁМ";container.add_child(hold)
	controls=[stick,lever,hold]
	var lever_events:Array=[];var held_events:Array=[]
	lever.target_changed.connect(func(value:float):lever_events.append(value))
	hold.state_changed.connect(func(value:bool):held_events.append(value))
	check(stick.is_visible_in_tree() and stick.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Actual controls are ready for viewport input routing")
	touch(1,at(stick,Vector2(136,100)))
	var response:=pow((0.5-stick.deadzone)/(1-stick.deadzone),1.5)
	check(stick.pointer_id==1 and near(stick.knob.x,0.5) and near(stick.knob.y,0) and near(stick.value.x,response),"Stick maps viewport coordinates through canvas/rotation/nonuniform scale before response shaping")
	touch(2,at(lever,Vector2(40,20)));touch(3,at(hold,Vector2(60,40)))
	check(stick.pointer_id==1 and lever.pointer_id==2 and hold.pointer_id==3 and hold.held and near(lever.value,600),"Three independent fingers can steer, set speed and lift at once")
	drag(2,at(lever,Vector2(40,220)))
	check(near(lever.value,-100,0.001) and near(stick.value.x,response) and hold.held,"Throttle drag changes only its owning control")
	touch(9,at(stick,Vector2(20,20)));drag(9,at(stick,Vector2(0,0)));touch(9,Vector2.ZERO,false)
	check(stick.pointer_id==1 and near(stick.value.x,response),"An unrelated finger cannot steal, steer or release an occupied stick")
	touch(1,Vector2(-100,-100),false)
	check(stick.pointer_id==-1 and stick.value==Vector2.ZERO and hold.held and lever.pointer_id==2,"Release outside bounds neutralizes only its owning stick")
	drag(3,Vector2(-200,-200));touch(3,Vector2(-200,-200),false)
	check(not hold.held and held_events==[true,false],"Hold remains captured outside bounds and emits exactly one matching release")
	touch(2,Vector2.ZERO,false)
	check(lever.pointer_id==-1 and near(lever.value,-100,0.001) and lever_events.size()==2,"Throttle release retains the chosen setpoint without emitting a new command")
	touch(4,at(stick,Vector2(104,100)))
	check(stick.value==Vector2.ZERO,"Phone stick deadzone filters small accidental motion")
	drag(4,at(stick,Vector2(600,100)))
	check(near(stick.value.x,1) and near(stick.value.y,0),"Drag outside stick clamps to finite full deflection")
	stick.input_allowed=false
	check(stick.pointer_id==-1 and stick.value==Vector2.ZERO,"Disabling phone input immediately releases steering")
	touch(5,at(stick,Vector2(172,100)));check(stick.pointer_id==-1,"Disabled input cannot acquire a new finger")
	stick.input_allowed=true;drag(4,at(stick,Vector2(172,100)));check(stick.value==Vector2.ZERO,"A stale drag cannot reactivate steering after resume")
	touch(5,at(stick,Vector2(172,100)));stick.hide()
	check(stick.pointer_id==-1 and stick.value==Vector2.ZERO,"Hiding a captured control immediately clears its pointer")
	stick.show();drag(5,at(stick,Vector2(172,100)));check(stick.value==Vector2.ZERO,"A hidden/re-shown control needs a fresh touch")
	touch(6,at(hold,Vector2(60,40)));touch(6,at(hold,Vector2(60,40)),true,true)
	check(not hold.held and hold.pointer_id==-1 and held_events==[true,false,true,false],"Android cancellation releases a hold even when a canceled event carries pressed=true")
	var synthetic:=InputEventMouseButton.new();synthetic.device=-1;synthetic.button_index=MOUSE_BUTTON_LEFT;synthetic.pressed=true;synthetic.position=at(stick,Vector2(172,100));root.push_input(synthetic,true)
	check(stick.pointer_id==-1 and stick.value==Vector2.ZERO,"Synthetic mouse arriving before a real touch cannot occupy the steering control")
	mouse(at(stick,Vector2(172,100)))
	check(stick.pointer_id==-2 and near(stick.value.x,1),"Desktop mouse capture follows the same transformed coordinates")
	var synthetic_motion:=InputEventMouseMotion.new();synthetic_motion.device=-1;synthetic_motion.button_mask=MOUSE_BUTTON_MASK_LEFT;synthetic_motion.position=at(stick,Vector2(100,28));root.push_input(synthetic_motion,true)
	check(stick.pointer_id==-2 and near(stick.value.x,1),"Synthetic touch-to-mouse motion cannot steer a real desktop mouse capture")
	touch(7,at(stick,Vector2(100,28)));check(stick.pointer_id==-2 and near(stick.value.x,1),"A new touch cannot steal an active mouse-owned control")
	motion(at(stick,Vector2(100,28)),MOUSE_BUTTON_MASK_LEFT)
	check(near(stick.value.x,0) and near(stick.value.y,-1),"Captured mouse drag preserves viewport-to-control mapping")
	motion(at(stick,Vector2(172,100)),0)
	check(stick.pointer_id==-1 and stick.value==Vector2.ZERO,"Mouse motion with no held button repairs a missed outside-window release")
	touch(8,at(stick,Vector2(172,100)));mouse(at(stick,Vector2(100,28)))
	check(stick.pointer_id==8 and near(stick.value.x,1),"An emulated or real mouse press cannot steal a touch capture")
	stick.release_pointer();mouse(Vector2.ZERO,false)
	# Exercise the same application pause handler used by Android, without startup.
	var app:=Main.new();app.stick=stick;app.lever=lever;app.holds=[hold];app.saving_enabled=false
	hold.state_changed.connect(func(value:bool):app.lift_up=value)
	touch(10,at(stick,Vector2(172,100)));touch(11,at(lever,Vector2(40,120)));touch(12,at(hold,Vector2(60,40)))
	check(app.lift_up and hold.held and stick.pointer_id==10 and lever.pointer_id==11,"Application pause fixture starts with simultaneous controls active")
	var speed:float=lever.value;var commands:=lever_events.size()
	app._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	check(not app.active and not app.lift_up and not hold.held and stick.value==Vector2.ZERO and stick.pointer_id==-1 and lever.pointer_id==-1,"Android application pause releases every captured finger and momentary flight input")
	check(near(lever.value,speed) and lever_events.size()==commands,"Pausing does not issue an unintended throttle command")
	app._notification(Node.NOTIFICATION_APPLICATION_RESUMED);drag(10,at(stick,Vector2(172,100)));drag(12,at(hold,Vector2(60,40)))
	check(app.active and stick.value==Vector2.ZERO and not app.lift_up,"Resume cannot replay pre-pause finger drags")
	touch(13,at(hold,Vector2(60,40)));hold.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not hold.held and hold.pointer_id==-1,"Control-level focus loss also releases momentary input")
	touch(14,at(hold,Vector2(60,40)));paused=true
	check(not hold.held and hold.pointer_id==-1,"SceneTree pause releases captured input before processing stops")
	paused=false;lever.display_value(123)
	check(near(lever.value,123) and lever_events.size()==commands,"Displaying model speed does not masquerade as a user throttle change")
	app.holds=[];app.stick=null;app.lever=null;app.free();controls=[];layer.free()

func run()->void:
	save_envelopes();save_slots();complete_state_boundary();phone_controls();cleanup()
	print("REBUILT SAVE/TOUCH TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
