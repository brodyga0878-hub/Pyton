extends SceneTree
const Galaxy=preload("res://scripts/source_galaxy.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<16:push_error(message)
func run()->void:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_galaxy_native.json"))
	var galaxy:=Galaxy.new();var total:=0
	check(fixture.case_count==fixture.cases.size() and fixture.case_count>=500,"Independent complete source-sector controls")
	check(fixture.fresh_process_runs==3 and fixture.reverse_repeat_count==fixture.case_count and fixture.canaries_unchanged and fixture.non_target_bytes_unchanged,"Native repetition and complete-buffer guards")
	check(FileAccess.get_sha256(Galaxy.DATA_PATH)==fixture.resource_sha256,"Source tables match independently native-used bytes")
	for row:Dictionary in fixture.cases:
		var obj:=str(row.object_hex).hex_decode();var stars:=str(row.stars_hex).hex_decode();var before_obj:=obj.duplicate();var before_stars:=stars.duplicate()
		var result:=galaxy.sector_raw(row.x,row.y,obj,stars,row.seed_a_u32,row.seed_b_u32)
		check(not result.is_empty(),"Source sector executes "+str([row.x,row.y]))
		if result.is_empty():continue
		check(result.object==str(row.expected.object_hex).hex_decode(),"Complete source object agrees")
		check(result.records==str(row.expected.stars_hex).hex_decode(),"Complete source star buffer agrees")
		check(result.count==int(row.expected.count),"Native star count")
		check(result.seed_a_u32==int(row.expected.seed_a_u32) and result.seed_b_u32==int(row.expected.seed_b_u32),"Native RNG agrees")
		check(galaxy.density(row.x,row.y)==int(row.expected.density_u32),"Native F853 exact density %s expected%s actual%s"%[str([row.x,row.y]),str(row.expected.density_u32),str(galaxy.density(row.x,row.y))])
		check(obj==before_obj and stars==before_stars,"Input buffers remain unchanged")
		for i in range(result.systems.size()):
			var entry:Dictionary=result.systems[i];var expected:Dictionary=row.expected.stars[i]
			check(entry.record==str(expected.record_hex).hex_decode(),"Native six-byte source star")
			check([entry.star_type,entry.star_count_code]==[int(expected.type_pair[0]),int(expected.type_pair[1])],"Source spectral/multiplicity pair")
			var point:PackedInt64Array=entry.position_q16
			check(point[0]==int(expected.position_q16[0]) and point[1]==int(expected.position_q16[1]) and point[2]==int(expected.position_q16[2]),"Actual F856 fixed-point coordinates %s expected%s actual%s"%[str([row.x,row.y,i]),str(expected.position_q16),str(point)])
			check(entry.id==(int(row.x)|(int(row.y)<<13)|(i<<26)),"Original sector/system ID layout")
			total+=1
	check(total==fixture.position_case_count,"Every native position consumed")
	for xy in [[-1,0],[0,-1],[8192,0],[0,8192],[0.5,0],[NAN,0],[INF,0]]:check(galaxy.sector(xy[0],xy[1]).is_empty(),"Invalid coordinate rejected")
	var sol:=galaxy.system(0x02a49718);var alpha:=galaxy.system(0x06a49718)
	check(not sol.is_empty() and not alpha.is_empty(),"Known original IDs resolve in their real sector")
	print("SOURCE GALAXY TESTS: %d checks, %d failures; native F841/F853/F856/F861 sectors, no source-system-composition claim"%[checks,failures])
	quit(1 if failures else 0)
