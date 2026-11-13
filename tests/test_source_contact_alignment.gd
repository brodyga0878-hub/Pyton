extends SceneTree
# This is a structural/behavioral characterization gate. It does not assert
# that the currently observed alignment error must continue to exist.
const Matrix=preload("res://tools/check_source_contact_alignment.gd")
const REPORT:="res://build/current-test-reports/source-contact-alignment-matrix.json"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func run()->void:
	var result:=Matrix.new().characterize()
	check(result.ok and result.errors.is_empty(),"Every isolated characterization sample completes without mutating its source files")
	check(result.metrics.size()==51 and result.model_count==17 and result.player_count==3,"The matrix has all17landable source bodies,three anchors andthree actualplayers")
	var models:Dictionary={};var players:Dictionary={};var policies:Dictionary={};var layers:Dictionary={}
	for metric:Dictionary in result.metrics:
		models[int(metric.model_index)]=true
		check(is_finite(float(metric.exact_F879_elevation_m)) and is_finite(float(metric.bilinear_256m_elevation_m)) and is_finite(float(metric.grid_minus_F879_m)),"Construction and grid heights are finite and their difference is measured")
		check(is_finite(float(metric.scalar_point_minus_F879_m)) and is_finite(float(metric.phone_point_minus_scalar_m)),"Scalar64 and phone/Basis errors are measured separately")
		for triangle:Dictionary in metric.triangles:
			check(int(triangle.verified_vertices)==3 and str(triangle.checksum).length()==64 and is_finite(float(triangle.triangle_minus_field_m)),"Every saved contact triangle validates its three original source heights and reports its own interpolation effect")
	for row:Dictionary in result.classifications:
		players[int(row.player_model)]=true;policies[str(row.offset_policy)]=true;layers[str(row.height_layer)]=true
		check(int(row.return_s32) in [-1,0] and int(row.volume_count)>=1 and int(row.volume_count)<=3,"Actual F576 result and complete real player-volume loop stay in the supported domain")
		check(str(row.relative_s64_hex).length()==48 and str(row.previous_altitude_s64_hex).length()==16,"Authoritative classifier operands/results preserve all signed64 bits")
		check(row.F575_executed==false,"No characterization point applies a landing response, damage, HP or clock transition")
	check(models.size()==17 and players.size()==3 and policies.size()==3 and layers.size()==9,"Full source body/player/offset and currentLOD layer dimensions are represented")
	check(result.classification_count==result.classifications.size() and result.classification_count==2403,"Matrix count follows17×3anchors×3players×3offsets with supported117extraLODs")
	check(result.gas_and_stellar_exclusions.size()==15,"Gas and stellar natural fields are not labelled landable terrain")
	for row:Dictionary in result.gas_and_stellar_exclusions:check(row.natural_classifier_data_available and not row.landing_surface_supported and not row.landing_or_render_alignment_claim,"Gas/star source data availability is separate from landing support")
	for path:String in result.source_sha256:check(FileAccess.get_sha256("res://"+path)==result.source_sha256[path],"Final source pin still matches "+path)
	result["checks"]=checks;result["failures"]=failures
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"));file.close()
	print("SOURCE CONTACT ALIGNMENT: %d checks, %d failures; %d classifications"%[checks,failures,int(result.classification_count)])
	quit(1 if failures else 0)
