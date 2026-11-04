extends RefCounted
const PATH:="user://device_settings.json"
var fps:=60
var quality:=2
var sensitivity:=1.0
var deadzone:=0.12
var invert_y:=false
var reading_size:=20
var orbital_gravity:=true
var show_fps:=false
func snapshot() -> Dictionary:
	return {"version":1,"fps":fps,"quality":quality,"sensitivity":sensitivity,"deadzone":deadzone,"invert_y":invert_y,"reading_size":reading_size,"orbital_gravity":orbital_gravity,"show_fps":show_fps}
func restore(data: Dictionary) -> bool:
	if data.get("version",0)!=1:return false
	for name in ["fps","quality","sensitivity","deadzone","reading_size"]:
		if not (data.get(name) is int or data.get(name) is float) or not is_finite(float(data[name])):return false
	if data.fps!=30 and data.fps!=60 and data.fps!=90 and data.fps!=120:return false
	if data.quality<0 or data.quality>2 or data.quality!=floorf(data.quality):return false
	if data.sensitivity<0.5 or data.sensitivity>2 or data.deadzone<0.05 or data.deadzone>0.3:return false
	if data.reading_size<16 or data.reading_size>26 or data.reading_size!=floorf(data.reading_size):return false
	for name in ["invert_y","orbital_gravity","show_fps"]:
		if not data.get(name) is bool:return false
	fps=int(data.fps);quality=int(data.quality);sensitivity=data.sensitivity;deadzone=data.deadzone
	reading_size=int(data.reading_size);invert_y=data.invert_y;orbital_gravity=data.orbital_gravity;show_fps=data.show_fps
	return true
func load_file() -> bool:
	if not FileAccess.file_exists(PATH):return false
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(PATH))!=OK:return false
	return parser.data is Dictionary and restore(parser.data)
func save_file() -> bool:
	var file:=FileAccess.open(PATH+".tmp",FileAccess.WRITE)
	if not file:return false
	file.store_string(JSON.stringify(snapshot()));file.close()
	return DirAccess.rename_absolute(PATH+".tmp",PATH)==OK
func steer(value: Vector2) -> Vector2:
	var result:=value*sensitivity
	if invert_y:result.y=-result.y
	return result.limit_length()
func msaa() -> int:
	return [Viewport.MSAA_DISABLED,Viewport.MSAA_2X,Viewport.MSAA_4X][quality]
