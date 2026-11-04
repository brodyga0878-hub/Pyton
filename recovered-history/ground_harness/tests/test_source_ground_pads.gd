extends SceneTree
const Pads=preload("res://scripts/source_ground_pads.gd")
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
	var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/ground_pads_reference.json"))
	var before:=JSON.stringify(reference)
	check(reference.cases.size()==5832,"All original F650 controls are present")
	for row in reference.cases:
		var model:=int(row.model_index)
		var expected:Dictionary=row.result
		var matrix:Array=row.matrix_q31
		check(Pads.pad_count(model)-1==int(expected.initialized_last_pad_index_i32),"Extracted pad count equals original F880")
		if row.matrix_source=="original_f1674":
			check(equal_numbers(Pads.matrix_for_angles(int(row.ground_phase_u16),int(row.ground_inclination_u16)),matrix),"Full F1674 matrix equals native source")
		var actual:=Pads.allocate(model,int(row.npc_id_i32),row.occupancy_before_u8,matrix,int(row.last_pad_index_override_i32))
		check(int(actual.return_i32)==int(expected.return_i32),"F650 allocation succeeds/fails exactly as native source")
		check(equal_numbers(actual.occupancy_after_u8,expected.occupancy_after_u8),"F650 changes exactly the original occupancy slot")
		if actual.ok:
			check(int(actual.allocation_status_i32)==int(expected.allocation_status_i32),"F650 reuses/allocates as original source")
			check(int(actual.selected_pad_i32)==int(expected.selected_pad_i32),"F650 descending selection equals original source")
			check(equal_numbers(actual.target_vec64_raw,expected.target_vec64_raw),"F650 transformed, shifted and sign-extended target equals original source")
			check(equal_numbers(Pads.transformed_positions(model,matrix)[int(actual.selected_pad_i32)],expected.target_vec64_raw),"All-pad target helper agrees with the original selected pad")
		if row.origin=="all_free":check(Pads.pick_highest_free(model)==int(expected.selected_pad_i32),"Initial default pad is the original highest free index")
	for model in range(81,91):
		var local:=Pads.raw_local_positions(model)
		var vectors:=Pads.table_vectors(model)
		check(local.size()==Pads.pad_count(model),"Every original local pad is present")
		for index in range(local.size()):
			for axis in range(3):check(int(local[index][axis])==int(vectors[index][axis])*1024,"Local anchors retain exact extracted integer scale")
		var occupied:Array=[]
		for index in range(local.size()):occupied.append(23)
		check(Pads.pick_highest_free(model,occupied)==(-1),"Full original ground port has no free index")
		occupied[0]=0
		check(Pads.pick_highest_free(model,occupied)==0,"Free-pad helper searches downward through occupancy")
		vectors[0][0]=123456789
		check(int(Pads.table_vectors(model)[0][0])!=123456789,"Returned pad table is independent of cached source data")
	check(Pads.table_vectors(80).is_empty() and Pads.raw_local_positions(91).is_empty(),"Unsupported city models have no invented pad table")
	check(Pads.pick_highest_free(80)==(-1),"Unsupported model has no free pad")
	check(Pads.transformed_positions(81,[1,2]).is_empty(),"Incomplete transform is rejected")
	check(not Pads.allocate(81,7,[0],[], -2).ok,"Incomplete pad state is rejected")
	check(not Pads.allocate(81,7,[0,0,0,0],reference.cases[0].matrix_q31,4).ok,"Index beyond original table is rejected")
	check(JSON.stringify(reference)==before,"Pad helpers preserve reference matrices and occupancy inputs")
	print("SOURCE GROUND PAD TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
