extends SceneTree
const Definition=preload("res://scripts/source_system_definition.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<20:push_error(message)
func run()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_system_definition_native.json"))
	var definition:=Definition.new()
	check(fixture.case_count>=4200 and fixture.fresh_process_runs==3 and fixture.reverse_repeat_count==fixture.case_count and fixture.canaries_unchanged,"Native original F830/F860 corpus")
	check(FileAccess.get_sha256(Definition.DATA_PATH)==fixture.system_name_resource_sha256,"Native source string bytes")
	for row:Dictionary in fixture.cases:
		var header:=definition.header(row.id)
		check(header.is_empty()==(int(row.return_s32)!=0),"F860 validates actual sector count system%s"%str(row.id))
		if header.is_empty():continue
		var raw:=str(row.params_hex).hex_decode()
		for field in [["seed_a",0],["mass",4],["num_stars",8],["system_id",12],["population_raw",16]]:
			check(int(header[field[0]])==int(raw.decode_u32(field[1])),"F860 field %s system%s"%[field[0],str(row.id)])
		check(header.system_name_bytes==str(row.name_hex).hex_decode(),"Actual F830 original name system%s expected%s actual%s"%[str(row.id),row.name_hex,header.system_name_bytes.hex_encode()])
	for invalid in [-1,4294967296,0.5,NAN,INF,"Sol"]:check(definition.describe(invalid).is_empty(),"Invalid IDs rejected")
	var sol:=definition.describe(0x02a49718);var before:=sol.duplicate(true);sol.source_parameters.mass=0
	check(definition.describe(0x02a49718)==before,"Cached definitions are isolated")
	check(before.name=="Солнце" and before.position_ly==[0.0,0.0,0.0] and not before.has_station,"Native source Sol with honest station context")
	print("SOURCE SYSTEM DEFINITION TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
