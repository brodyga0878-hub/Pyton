extends SceneTree
const Frame=preload("res://scripts/source_frame_kinematics.gd")
const FIXTURE:="res://tests/fixtures/source_frame_native.json"
const FIXTURE_SHA:="42320b712c4f4410cda409cf45f55c3cd07e433eb2aa12823ea8e95e425e5f5a"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<25:push_error(label)
func differences(first:PackedByteArray,second:PackedByteArray)->String:
	var result:Array=[]
	for index in range(mini(first.size(),second.size())):
		if first[index]!=second[index]:result.append("%x:%x/%x"%[index,first[index],second[index]])
	return str(result.slice(0,12))
func run()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Independent original instruction fixture remains pinned")
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture.profile==Frame.PROFILE and fixture.case_count==720 and fixture.cases.size()==720,"Complete whole-procedure native frame cases present")
	check(fixture.fresh_process_runs==3 and fixture.reverse_case_count==720 and fixture.canaries_and_matrix_unchanged,"Native process/order/buffer controls")
	var modes:Dictionary={};var quantized_roundtrips:=0;var case_index:=0
	for row:Dictionary in fixture.cases:
		var original:=str(row.body_hex).hex_decode();var frozen:=original.duplicate();var matrix:Array=row.matrix_q31.duplicate();var mode:=int(row.operation);modes[mode]=true
		var result:=Frame.rotate(original,matrix,mode%2==0,row.source_frame_byte)
		if mode>=2 and not result.is_empty():result=Frame.rotate(result.body,matrix,mode%2!=0,row.source_frame_byte)
		var label:="mode%d case%d"%[mode,case_index];var expected:=str(row.expected_body_hex).hex_decode()
		check(not result.is_empty(),"Original frame primitive returns "+label)
		if result.is_empty():case_index+=1;continue
		check(result.body==expected,"Entire338byte native source frame output "+label+" "+differences(result.body,expected))
		check(not result.parent_translation_included and not result.angular_surface_velocity_included and not result.automatic_reference_frame_selection,"Primitive scope remains explicit "+label)
		check(original==frozen and row.matrix_q31==matrix,"Caller body/matrix inputs remain untouched "+label)
		check(result.body.slice(0xec,0xf2)==original.slice(0xec,0xf2),"Actual F572/F573 retain fractional velocity words unchanged "+label)
		if mode>=2 and result.body.slice(0x3e,0x56)!=original.slice(0x3e,0x56):quantized_roundtrips+=1
		case_index+=1
	check(modes.size()==4 and quantized_roundtrips>0,"Native composed roundtrips preserve source truncation loss instead of asserting artificial reversibility")
	var control:Dictionary=fixture.cases[0];var body:=str(control.body_hex).hex_decode();var before:=body.duplicate();var matrix:Array=control.matrix_q31
	for invalid in [null,[],[1,2,3],true,{},[0,0,0,0,0,0,0,0,NAN],[0,0,0,0,0,0,0,0,true],[0,0,0,0,0,0,0,0,2147483648]]:check(Frame.rotate(body,invalid,true).is_empty(),"Invalid matrix rejects")
	for invalid in [null,0,1,"true",[]]:check(Frame.rotate(body,matrix,invalid).is_empty(),"Enter/leave selector requires actual boolean")
	for invalid in [null,true,-1,256,0.5,NAN,INF]:check(Frame.rotate(body,matrix,true,invalid).is_empty(),"Bad source frame byte rejects")
	check(body==before,"Invalid frame calls do not mutate original")
	print("SOURCE FRAME KINEMATICS TESTS: %d checks, %d failures; original F572/F573 primitives and independently native lossy roundtrips"%[checks,failures]);quit(1 if failures else 0)
