extends SceneTree
const Anchor=preload("res://scripts/source_city_anchor.gd")
const Query=preload("res://scripts/terrain_query.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=12:push_error(message)
func equal_numbers(a:Variant,b:Variant)->bool:
	if a.size()!=b.size():return false
	for i in range(a.size()):
		if int(a[i])!=int(b[i]):return false
	return true
func _init()->void:call_deferred("run")
func run()->void:
	var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/city_placement_reference.json"))
	var before:=JSON.stringify(reference)
	check(reference.case_count==373 and reference.variants.size()==2,"All746 independent original F879 results are present")
	var anchor:=Anchor.new()
	for variant in reference.variants:
		for index in range(reference.cases.size()):
			var row:Dictionary=reference.cases[index]
			var expected:Dictionary=reference.variants[variant].results[index]
			var actual:=anchor.place_raw(int(row.parent_model_index),int(row.parent_uid_u32),int(row.city_model_index),int(row.ground_phase_u16),int(row.ground_inclination_u16),variant,int(row.graphics_level_raw))
			check(actual.ok,"Original F879 ground path completes %s case%d: %s"%[variant,index,actual.get("error","")])
			if not actual.ok:continue
			check(equal_numbers(actual.matrix_q31,expected.matrix_q31),"F879 preserves the original F1674 orientation")
			check(equal_numbers(actual.position_vec64_raw,expected.position_vec64_raw),"F879 final Vec64 equals the full native collision chain")
			check(int(actual.parent_outer_raw_i64)==int(expected.parent_outer_raw_i64) and int(actual.parent_inner_raw_i64)==int(expected.parent_inner_raw_i64),"Original F1533/F1495 parent radii agree")
			for pass_index in range(2):
				var observed:Dictionary=actual.passes[pass_index]
				var wanted:Dictionary=expected.passes[pass_index]
				check(equal_numbers(observed.input_position_vec64_raw,wanted.input_position_vec64_raw),"Original city radial probe equals native Vec64")
				check(equal_numbers(observed.query_matrix_raw,wanted.query_matrix_raw),"F579 truncation/F581 matrix equals native query")
				check(equal_numbers(observed.query_center_raw,wanted.query_center_raw),"F581 query center equals native query")
				for field in ["clearance_i32","altitude_raw_i64","query_style_raw","query_limit_raw","pending_query_flag"]:
					check(int(observed[field])==int(wanted[field]),"F879 source pass %s equals native collision chain"%field)
				check(int(observed.recorded_intersection_raw)==int(wanted.intersection_raw),"F1876 intersection equals independent native control")
	check(not anchor.place_raw(117,1,84,0,0,"jjffe_sar3").ok,"Nonuniform source model117 is rejected explicitly")
	check(not anchor.place_raw(129,1,80,0,0,"jjffe_sar3").ok,"Unsupported city collision geometry is rejected")
	check(not anchor.place_raw(129,1,84,0,0,"automatic").ok,"Correction variant cannot be inferred implicitly")
	check(not anchor.place_raw(129,1,84,0,0,"jjffe_sar3",0).ok,"Unsupported original graphics range is rejected")
	check(JSON.stringify(reference)==before,"Source city placement preserves independent native controls")
	print("SOURCE CITY ANCHOR TESTS: %d checks, %d failures;746 native F879 controls"%[checks,failures])
	quit(1 if failures else 0)
