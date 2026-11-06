extends SceneTree
# Expected full record banks come from actual F891/F892/F893/F791 instructions.
const Builder=preload("res://scripts/source_settlement_builder.gd")
const FIXTURE:="res://tests/fixtures/source_settlements_native.json"
var checks:=0
var failures:=0

func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=20:push_error(message)

static func sha(bytes:PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()

func bank_for(row:Dictionary,slots:int=60)->Array:
	var records:Array=[]
	for _slot in range(slots):
		var record:=PackedByteArray();record.resize(68);record.fill(int(row.get("fill_byte",0)));records.append(record)
	for key in row.get("records",{}):records[int(key)]=str(row.records[key]).hex_decode()
	return records

func request_for(row:Dictionary)->Dictionary:
	var request:Dictionary={}
	for key in Builder.FIELDS+["model_offset","count_scale","port_type","parent_index"]:request[str(key)]=row[key]
	return request

func construct(builder:RefCounted,records:Array,request:Dictionary,operation:int,slots:int=60)->Dictionary:
	if slots==128:return builder.construct_ground_full(records,request) if operation==0 else builder.construct_orbital_full(records,request)
	return builder.construct_ground(records,request) if operation==0 else builder.construct_orbital(records,request)

func controls(builder:RefCounted,fixture:Dictionary,slots:int=60)->void:
	var changed:=0;var operations:Dictionary={};var models:Dictionary={};var gates:=0
	var rows:Array=fixture.cases if slots==60 else fixture.wide_cases
	for row:Dictionary in rows:
		var records:=bank_for(row,slots);var request:=request_for(row)
		var before:=var_to_bytes(records);var request_before:=request.duplicate(true)
		var actual:=construct(builder,records,request,int(row.operation),slots)
		check(not actual.is_empty() and actual.get("ok",false),"Original settlement context succeeds: "+str(row.group))
		if actual.is_empty() or not actual.get("ok",false):continue
		for key in ["index","seed_a","seed_b","ordinal_counter","port_count_byte","orbital_count_byte","appended_count"]:
			check(actual.get(key)==int(row.expected[key]),"Original settlement state "+key+" matches native "+str(row.group))
		var expected:=records.duplicate()
		for key in row.expected.records:
			expected[int(key)]=str(row.expected.records[key]).hex_decode()
			models[int(expected[int(key)].decode_u16(12))]=true
		check(actual.records==expected,"All%d source records exactly match native output, including unchanged name tails and flags"%slots)
		var bytes:=PackedByteArray()
		for record:PackedByteArray in actual.records:bytes.append_array(record)
		check(sha(bytes)==str(row.expected.whole_bank_sha256),"Complete native bank SHA-256 matches")
		check(var_to_bytes(records)==before and request==request_before,"Accepted settlement call preserves both caller inputs")
		operations[int(row.operation)]=true
		changed+=int(actual.appended_count)
		if int(actual.appended_count)==0:gates+=1
	check(operations.size()==2,"Both complete source settlement helpers execute")
	check(changed==int(fixture.appended_records if slots==60 else fixture.wide_appended_records) and changed>100,"Native fixture contains appended settlement records")
	if slots==60:check(models.has(96),"Source underground model96 is retained rather than replaced by an open city")
	check(gates>0,"Original signed byte port-count rejection is independently exercised")

func invalid_controls(builder:RefCounted,base:Dictionary)->void:
	var records:=bank_for(base);var request:=request_for(base);var before:=var_to_bytes(records)
	for operation in [0,1]:
		var extra:Array=["model_offset","count_scale"] if operation==0 else ["port_type","parent_index"]
		for key in Builder.FIELDS+extra:
			for value in [-1,0x100000000,0.5,"1",null]:
				var invalid:=request.duplicate(true);invalid[key]=value
				check(construct(builder,records,invalid,operation).is_empty(),"Invalid settlement field rejects: "+str(key))
		for key in ["port_count_byte","orbital_count_byte"]:
			var invalid:=request.duplicate(true);invalid[key]=256
			check(construct(builder,records,invalid,operation).is_empty(),"Source byte counter cannot exceed255")
		var invalid:=request.duplicate(true);invalid.index=60
		check(construct(builder,records,invalid,operation).is_empty(),"Index beyond the source bank rejects")
		check(construct(builder,[],request,operation).is_empty(),"Incomplete source bank rejects")
		var broken:=records.duplicate();broken[3]=PackedByteArray([1,2,3])
		check(construct(builder,broken,request,operation).is_empty(),"Malformed source record rejects")
		invalid=request.duplicate(true);invalid.index=59;invalid.port_count_byte=0
		var result:=construct(builder,records,invalid,operation)
		check(not result.get("ok",true) and result.get("reason")=="capacity" and not result.has("records"),"Unsafe source append past bank capacity rejects atomically")
	var invalid:=request.duplicate(true);invalid.parent_index=0;invalid.port_count_byte=0
	check(builder.construct_orbital(records,invalid).is_empty(),"Orbital parent cannot read before the bank")
	invalid=request.duplicate(true);invalid.parent_index=int(invalid.index)+2;invalid.port_count_byte=0
	check(builder.construct_orbital(records,invalid).is_empty(),"Forward orbital parent rejects")
	invalid=request.duplicate(true);invalid.model_offset=48;invalid.port_count_byte=0
	check(builder.construct_ground(records,invalid).is_empty(),"Ground model-table overrun cannot publish partial settlements")
	check(var_to_bytes(records)==before,"Every rejected settlement request preserves caller bytes")
	var wide:=bank_for(base,128);var wide_before:=var_to_bytes(wide)
	for operation in [0,1]:
		invalid=request.duplicate(true);invalid.index=127;invalid.port_count_byte=0
		var result:=construct(builder,wide,invalid,operation,128)
		check(not result.get("ok",true) and result.get("reason")=="capacity" and not result.has("records"),"Wide original-system API rejects writes outside128slots atomically")
		check(construct(builder,wide,request,operation).is_empty(),"Legacy60-slot API cannot silently accept a different bank shape")
		check(construct(builder,records,request,operation,128).is_empty(),"Full128-slot API requires its explicitly chosen bank")
	check(var_to_bytes(wide)==wide_before,"Every rejected wide-bank call preserves caller bytes")

func run()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	if not fixture is Dictionary:push_error("Missing independent source settlement controls");quit(1);return
	check(fixture.get("schema")==1 and fixture.get("source_variant")==Builder.SOURCE_VARIANT,"Native settlement fixture schema and variant")
	check(fixture.get("source_sha256")==Builder.SOURCE_SHA,"Native settlement executable provenance")
	check(fixture.get("case_count")==fixture.get("cases",[]).size() and fixture.cases.size()>1000,"Native fixture has substantial full-helper controls")
	check(fixture.get("fresh_process_runs")==3 and fixture.get("reverse_repeat_count")==fixture.cases.size(),"Fresh native processes and reverse contexts agree")
	check(fixture.get("records_buffer_guard_canaries_unchanged",false) and fixture.get("non_target_records_unchanged",false) and fixture.get("global_rng_unchanged",false),"Native bank boundaries, unrelated records and global RNG remain intact")
	check(fixture.get("settlement_rules_sha256")==FileAccess.get_sha256(Builder.DATA_PATH),"Native source templates and model/coordinate tables agree with runtime data")
	check(fixture.get("wide_bank_slots")==128 and fixture.get("wide_case_count")==fixture.get("wide_cases",[]).size() and fixture.wide_cases.size()>100,"Independent original-system bank has explicit128slots and native boundary controls")
	check(fixture.get("wide_fresh_process_runs")==3 and fixture.get("wide_reverse_repeat_count")==fixture.wide_cases.size(),"Wide-bank fresh process and reverse controls agree")
	var builder:=Builder.new();controls(builder,fixture);controls(builder,fixture,128);invalid_controls(builder,fixture.cases[0])
	print("SOURCE SETTLEMENT TESTS: %d checks, %d failures; actual F891/F892/F893/F791 native records, not a full galaxy"%[checks,failures])
	quit(1 if failures else 0)
