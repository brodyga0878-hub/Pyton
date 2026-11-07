extends SceneTree
const Gear=preload("res://scripts/source_landing_gear_session.gd")
func _initialize()->void:
 var output:Array=[];var context:={"flight_state_u8":0,"autopilot_phase_u8":0,"speed_s32":0}
 for sample in [{"rate":1,"iterations":2000},{"rate":100,"iterations":200}]:
  var gear:=Gear.new()
  if not gear.configure(false):quit(1);return
  var start:=Time.get_ticks_usec()
  for index in range(int(sample.iterations)):
   if not gear.advance_seconds(float(sample.rate)/60.0,context).ok:quit(1);return
  var elapsed:=Time.get_ticks_usec()-start
  output.append({"rate":sample.rate,"calls":sample.iterations,"total_usec":elapsed,"mean_usec":float(elapsed)/sample.iterations})
 print(JSON.stringify({"scope":"Desktop headless stable manual retracted gear session, no phone/GPU/FPS measurement","measurements":output}))
 quit()
