extends SceneTree
const VM=preload("res://scripts/source_model_vm.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _init()->void:call_deferred("run")
func equal_numbers(a:Array,b:Array)->bool:
	if a.size()!=b.size():return false
	for i in range(a.size()):
		if int(a[i])!=int(b[i]):return false
	return true
func run()->void:
	var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/model_aux_rotation_reference.json"))
	var before:=JSON.stringify(reference)
	check(reference.cases.size()==1809,"All independent native auxiliary rotation controls are present")
	for row in reference.cases:
		var matrix:Array=row.matrix_q31
		var original:=matrix.duplicate()
		var axis:=int(row.command_or_axis_u32)
		var cosine:=int(row.cosine_i32)
		var sine:=int(row.sine_i32)
		if int(row.mode)!=2:
			var locals:Array=reference.context.frame_locals_i32.duplicate()
			locals[0]=row.local_0_i32
			var angle:=VM.parameter(int(row.encoded_angle_word),locals,reference.context.entity_variables_u16,true)
			check(angle.ok and int(angle.value)==int(row.result.decoded_angle_i32),"F1743 angle decoder equals native source")
			if not angle.ok:continue
			cosine=Ground.sin_q31(int(angle.value)+0x4000)
			sine=Ground.sin_q31(int(angle.value))
			if int(row.mode)==0:axis=(axis>>5)&3
		var actual:=VM.auxiliary_rotation(matrix,axis,cosine,sine)
		check(actual.ok and equal_numbers(actual.matrix,row.result.matrix_after_q31),"F1744 auxiliary matrix equals native integer source")
		check(equal_numbers(matrix,original),"Auxiliary rotation preserves its input matrix")
	for axis in [-1,3,4,127]:
		check(not VM.auxiliary_rotation([1,0,0,0,1,0,0,0,1],axis,1,0).ok,"Undefined source rotation axis is rejected")
	check(not VM.auxiliary_rotation([1,0],0,1,0).ok,"Incomplete source matrix is rejected")
	check(JSON.stringify(reference)==before,"Source rotation leaves native fixture state unchanged")
	print("SOURCE MODEL AUXILIARY ROTATION TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
