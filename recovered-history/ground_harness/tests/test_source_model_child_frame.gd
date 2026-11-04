extends SceneTree
const VM=preload("res://scripts/source_model_vm.gd")
class CapturedChild:
	extends "res://scripts/source_model_mesh.gd"
	var captured:Dictionary={}
	var control:Dictionary={}
	var _point_calls:=0
	func _point(_state:Dictionary,index:int)->Array:
		_point_calls+=1
		if _point_calls==1:return control.origin_vertex_i32.duplicate()
		var signed_index:=(index&255)-256 if (index&255)>=128 else index&255
		return control.cached_parent_vertices_i32[signed_index+6].duplicate()
	func _run_model(_index:int,frame:Dictionary,_depth:int)->void:
		captured=frame.duplicate(true)
class ParentRandom:
	extends RefCounted
	var random_state:Array=[0x12345678,0x87654321]
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func equal_numbers(a:Array,b:Array)->bool:
	if a.size()!=b.size():return false
	for i in range(a.size()):
		if int(a[i])!=int(b[i]):return false
	return true
func equal_points(a:Array,b:Array)->bool:
	if a.size()!=b.size():return false
	for i in range(a.size()):
		if not equal_numbers(a[i],b[i]):return false
	return true
func _init()->void:call_deferred("run")
func run()->void:
	var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/model_child_frame_reference.json"))
	var before:=JSON.stringify(reference)
	check(reference.cases.size()==1776,"All independent original child-frame controls are present")
	for row in reference.cases:
		var evaluator:=CapturedChild.new()
		evaluator.control=row
		var expected:Dictionary=row.result
		var parameters:Array=row.parent_locals_0_1_2_i32.duplicate()
		parameters.append(int(row.extra_scale_i32))
		parameters.append_array([null,null,null,null])
		var frame:={"matrix":row.parent_matrix_q31,"parity":int(row.parent_parity_i32),"aux":row.parent_aux_matrix_q31,"aux_parity":int(row.parent_aux_parity_i32),"parameters":parameters,"range_scale":int(row.parent_range_scale_i32),"colour":row.child_colour_rgb_u8,"path":"native-child-control"}
		var words:Array=[14,int(row.placement_word_u16)]
		# These controls start at the F1750 call boundary. The wrapper supplies
		# an equivalent explicit local3 for extra scale and local RGB colour.
		# F1748's colour/operand decoder is outside the native fixture scope.
		var scaled:=int(row.extra_scale_i32)!=0
		if scaled:words.append_array([0x3800,0x1000])
		if int(row.placement_word_u16)&0x8000:
			var a:Array=row.anchor_operand_u8
			words.append_array([int(a[0])|(int(a[1])<<8),int(a[2])|(int(a[3])<<8)])
		var state:={"frame":frame,"evaluator":ParentRandom.new()}
		var command:={"words":words,"model_id":int(row.child_model_index),"opcode":27 if scaled else 14,"offset":0}
		evaluator._submodel(state,command,0)
		check(evaluator.error.is_empty() and not evaluator.captured.is_empty(),"Original child-frame composition completes")
		if evaluator.captured.is_empty():continue
		var actual:Dictionary=evaluator.captured
		check(equal_numbers(actual.matrix,expected.matrix_q31) and int(actual.parity)==int(expected.parity_i32),"F1740 child orientation/parity equals native source")
		check(equal_numbers(actual.origin,expected.origin_i32),"F1750 child uses the original transformed parent origin")
		check(int(actual.scale)==int(expected.scale_i32) and int(actual.range_scale)==int(expected.range_scale_i32),"F1750 child scale and inherited range equal native source")
		check(equal_numbers(actual.parameters.slice(0,3),expected.locals_0_1_2_i32),"F1750 incremented/inherited parameters equal native source")
		check(equal_numbers(actual.colour,expected.colour_rgb_u8),"F1750 child RGB bytes equal native source")
		check(equal_points(actual.anchors,expected.external_anchors_relative_i32),"F1750 child external anchor order and relative coordinates equal native source")
		check(actual.parameters.slice(3,8)==[null,null,null,null,null],"Undefined original child parameters remain unavailable")
	check(JSON.stringify(reference)==before,"Composition preserves supplied native control inputs")
	print("SOURCE MODEL CHILD FRAME TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
