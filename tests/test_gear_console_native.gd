extends SceneTree
# Actual independent gear session -> console -> command -> visual consumer.
# This explicit presentation bridge is isolated from Main, save IO and world
# flight-state derivation; the actual Main integration has its own tests.
const Console=preload("res://scripts/flight_console.gd")
const Gear=preload("res://scripts/source_landing_gear_session.gd")
const Visual=preload("res://scripts/ship_visual.gd")
var console:Control
var visual:Node3D
var gear:RefCounted
var context:Dictionary={"flight_state_u8":0,"autopilot_phase_u8":0,"speed_s32":0}
var events:Array=[]
var evidence:Array=[]
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func frame()->void:await process_frame;await process_frame
func snapshot()->PackedByteArray:return var_to_bytes(gear.snapshot())
func refresh()->void:
	var actual:Dictionary=gear.state(context)
	console.configure_state({"gear_available":actual.initialized,"gear_enabled":actual.can_toggle,"gear_text":actual.command_label,"gear_status":actual.status_text,"gear_fraction":actual.extension_fraction,"simulation_paused":context.get("paused",false),"range_m":4000.0})
	visual.set_gear_fraction(actual.extension_fraction)
func route()->void:
	var result:Dictionary=gear.command_toggle(context);events.append(result);refresh()
func tap()->void:
	var point:Vector2=console.buttons.gear.get_global_rect().get_center()
	var event:=InputEventScreenTouch.new();event.index=173;event.position=point;event.pressed=true;root.push_input(event,true)
	event=InputEventScreenTouch.new();event.index=173;event.position=point;event.pressed=false;root.push_input(event,true);await frame()
func actual_source_cycle()->void:
	check(gear.configure(false),"Actual source gear session configures from the frozen extracted resource")
	var before:=snapshot();refresh();await frame();var actual:Dictionary=gear.state(context)
	check(snapshot()==before and actual.retracted and actual.f1014_raw_gear_flag and not actual.requested_down and console.buttons.gear.text.contains(actual.command_label),"UI consumes corrected raw request polarity without deriving it from landed or mutating source state")
	check(not visual._landed and not visual.landing_gear.visible,"Airborne source-retracted mechanism draws retracted")
	await tap();actual=gear.state(context)
	check(events.size()==1 and events[-1].ok and events[-1].accepted and actual.requested_down and actual.position_u16==0,"Actual720px gear touch changes source request exactly once without prematurely moving physical gear")
	before=snapshot();refresh()
	check(console.buttons.gear.text.contains(actual.status_text) and visual._gear_amount==0 and snapshot()==before,"Repeated rendering retains the readable request and physical source-retracted position without advancing the mechanism")
	var advance:Dictionary=gear.advance_seconds(1.0,context);before=snapshot();refresh();await frame();actual=gear.state(context)
	check(advance.ok and actual.moving and actual.extension_fraction>0 and actual.extension_fraction<1 and actual.requested_down,"Source F1008 fixed-step schedule produces a genuine partial deployment")
	check(visual._gear_amount==actual.extension_fraction and console.buttons.gear.get_node("Icon").fraction==actual.extension_fraction and snapshot()==before,"Authoritative session fraction reaches the3strut visual and console indicator without a second source update")
	visual._process(2.0);check(snapshot()==before and visual._gear_amount==actual.extension_fraction,"Render wall clock cannot move physical source gear or alter source clock state")
	advance=gear.advance_seconds(2.0,context);refresh();actual=gear.state(context)
	check(advance.ok and actual.deployed and actual.landing_ready and visual.landing_gear.scale.y==1 and not visual._landed,"Fully deployed source gear is visible in flight without falsely declaring the ship landed")
	await tap();actual=gear.state(context)
	check(events.size()==2 and events[-1].accepted and actual.retract_requested and actual.deployed and visual._gear_amount==1,"Retraction touch changes direction while retaining the physical fully-down position until source ticks advance")
	check(gear.advance_seconds(1.0,context).ok,"Actual source gear retracts under its own clock")
	refresh();actual=gear.state(context)
	check(actual.moving and actual.extension_fraction>0 and actual.extension_fraction<1 and visual._gear_amount==actual.extension_fraction,"Retraction displays the actual partial source position rather than a landed animation")
	evidence.append({"phase":"actual_source_gear_touch_cycle","touch_width":720,"source_fraction_after_retraction":actual.extension_fraction,"source_request_is_retract":actual.retract_requested,"visual_landed":visual._landed,"position_from_source":true})
func pauses_phase_and_readability()->void:
	context.paused=true;refresh();await frame();var before:=snapshot();var count:=events.size();await tap();console.buttons.gear.pressed.emit()
	check(console.buttons.gear.disabled and events.size()==count and snapshot()==before,"Actual paused session quote disables real touch and forced signal without changing source state")
	check(not gear.advance_seconds(1.0,context).accepted and snapshot()==before,"Source pause itself also rejects movement while UI is disabled")
	context.erase("paused");context.autopilot_phase_u8=0x24;refresh();await frame();before=snapshot();await tap()
	check(not gear.state(context).can_toggle and console.buttons.gear.disabled and events.size()==count and snapshot()==before,"Original blocked phase remains disabled without invented autopilot cancellation")
	context.autopilot_phase_u8=0;refresh()
	for width:int in [720,1440,1920]:
		console.size=Vector2(width,Console.HEIGHT);console._layout();await frame()
		var font:Font=console.buttons.gear.get_theme_font("font");var font_size:int=console.buttons.gear.get_theme_font_size("font_size")
		for line:String in console.buttons.gear.text.split("\n"):check(font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x<=console.buttons.gear.size.x-4,"Actual source RU command/status are readable at supported width"+str(width))
		check(console.buttons.gear.size.y>=64 and console.buttons.gear.size.x>=132,"Actual source command retains its phone touch target at width"+str(width))
	context.flight_state_u8=2;context.autopilot_phase_u8=0
	var result:Dictionary=gear.command_request(true,context);check(result.ok,"Explicit source automatic-context request fixture is accepted")
	check(gear.advance_seconds(1.0/60.0,context).ok,"Actual automatic source gear invocation advances")
	refresh();check(gear.state(context).retract_requested and context.flight_state_u8==2 and context.autopilot_phase_u8==0,"Retained F1008 automatic override does not become a synthetic break-autopilot UI action")
	evidence.append({"phase":"actual_quote_guards_and_caption","supported_widths":[720,1440,1920],"paused_touch_blocked":true,"blocked_phase_touch_rejected":true,"automatic_source_override_retained":true})
func run()->void:
	root.size=Vector2i(1920,720);console=Console.new();root.add_child(console);console.position=Vector2(0,480);console.size=Vector2(720,Console.HEIGHT);console.gear_requested.connect(route)
	gear=Gear.new();visual=Visual.new();visual.set_quality(0);root.add_child(visual);visual.configure({"id":"cobra","visual_span_m":42.0});visual.set_process(false);await frame()
	await actual_source_cycle();await pauses_phase_and_readability()
	print("GEAR CONSOLE NATIVE EVIDENCE: ",JSON.stringify(evidence))
	console.queue_free();visual.queue_free();await process_frame
	print("GEAR CONSOLE NATIVE TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
