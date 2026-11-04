extends SceneTree
const VM=preload("res://scripts/source_model_vm.gd")
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
	var r:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/model_vm_reference.json"))
	var before:=JSON.stringify(r)
	for section in ["scalar_cases","math_cases","orientation_cases","branch_cases","bit_cases"]:
		for row in r[section]:
			var locals:Array=r.context.frame_locals_i32.duplicate();locals[0]=row.local_0_i32;locals[1]=row.local_1_i32
			var entity:Array=r.context.entity_variables_u16
			var result:Dictionary=row.result
			match int(row.handler):
				0:
					var a:=VM.parameter(int(row.first_selector_raw),locals,entity)
					var b:=VM.parameter(int(row.first_selector_raw),locals,entity,true)
					check(a.ok and int(a.value)==int(result.parameter_value_i32),"F1473 parameter equals native source")
					check(b.ok and int(b.value)==int(result.angle_value_i32),"F1474 angle equals native source")
				1:
					var value:=VM.math(int(row.command_u32),int(row.first_selector_raw),int(row.second_selector_raw),locals,entity)
					check(value.ok,"Audited model operation completes")
					if value.ok:locals[value.destination]=value.value
					check(equal_numbers(locals.slice(0,8),result.locals_after_i32),"F1758 operation and local destination equal native source")
				2:
					var value:=VM.orientation(row.source_matrix_i32,int(row.condition_or_parity_i32),int(row.command_u32))
					check(value.ok and equal_numbers(value.matrix,result.matrix_after_i32) and int(value.parity)==int(result.parity_after_i32),"F1739 permutation/signs/parity equal native source")
				3:
					var value:=VM.branch(int(row.condition_or_parity_i32)!=0,int(row.command_u32),0,int(r.initial_model_active_raw))
					check(int(value.offset)==int(result.pc_delta_i32) and int(value.active)==int(result.model_active_raw),"F1753 signed jump and model stop equal native source")
				4,5:
					var condition:=VM.bit_condition(int(row.handler)==5,int(row.first_selector_raw),int(row.bit_index_u8),locals,entity)
					check(condition.ok,"Audited source bit selector exists")
					if condition.ok:
						var value:=VM.branch(condition.value,int(row.command_u32),2,int(r.initial_model_active_raw))
						check(int(value.offset)==int(result.pc_delta_i32) and int(value.active)==int(result.model_active_raw),"F1756/F1757 bit branch equals native source")
	check(JSON.stringify(r)==before,"Source VM primitives preserve reference input state")
	for row in r.native_trap_cases:
		var value:=VM.math((int(row.operation)<<4)|13,0xc0,0xc1,[VM.s32(int(row.left_u32)),VM.s32(int(row.right_u32))],[])
		check(not value.ok,"Source division traps fail explicitly")
	check(not VM.orientation([1,0,0,0,1,0,0,0,1],0,0x700).ok,"Source invalid permutation fails explicitly")
	print("SOURCE MODEL VM TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
