extends SceneTree
const Rng=preload("res://scripts/source_global_rng.gd")
const FIXTURE:="res://tests/fixtures/source_damage_native.json"
const FIXTURE_SHA:="d8f25e97a65c7b04eed8f13a9252758d8866b371a57d8f1e1872cc115a3789c3"
const REPORT:="res://build/current-test-reports/source-global-rng.json"
var checks:=0
var failures:=0
var native_cases:=0
var native_complete:=false
var buffers:Dictionary={}
var cache:Dictionary={}
var dependencies:Dictionary={}
var operations:Dictionary={}
var bounds:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<26:push_error(message)
func root()->PackedByteArray:
	var result:=PackedByteArray();result.resize(Rng.ROOT_BYTES);result.encode_u32(0x24,0x12345678);result.encode_u32(0x28,0x89abcdef);return result
func buffer(reference:String)->PackedByteArray:
	if cache.has(reference):return cache[reference].duplicate()
	var entry:Dictionary=buffers[reference];var raw:=Marshalls.base64_to_raw(str(entry.zlib_base64)).decompress(int(entry.byte_count),FileAccess.COMPRESSION_DEFLATE)
	var hasher:=HashingContext.new();hasher.start(HashingContext.HASH_SHA256);hasher.update(raw)
	check(raw.size()==int(entry.byte_count) and hasher.finish().hex_encode()==reference,"RNG native buffer pool preserves every decoded byte")
	cache[reference]=raw.duplicate();return raw
func standalone()->void:
	var initial:=root();var before:=initial.duplicate();var first:=Rng.execute(initial,"F1530");var second:=Rng.execute(first.root_after,"F922",0xffffffff)
	check(first.ok and second.ok and initial==before,"Both source RNG operations execute on a returned copy of the sole raw Root owner")
	var changed:PackedByteArray=second.root_after.duplicate()
	for offset in range(changed.size()):
		if offset>=0x24 and offset<0x2c:changed[offset]=initial[offset]
	check(changed==initial,"Original global RNG functions write only the shared Root+24/+28 words")
	first.root_after[0]=255;check(initial==before,"Returned RNG root cannot alias supplied raw Root")
	for bad:Variant in [null,true,0,"raw",[],{},PackedByteArray()]:check(not Rng.execute(bad,"F1530").ok,"Malformed shared RNG Root rejects")
	for bad:Variant in [null,true,0,[],{},"random","F953"]:check(not Rng.execute(initial,bad).ok,"Unknown RNG operation rejects")
	for bad:Variant in [null,true,NAN,INF,0.5,-1,0x100000000,"0"]:check(not Rng.execute(initial,"F922",bad).ok,"Invalid raw F922 bound rejects")
	for bad:Variant in [0,1,true,"0"]:check(not Rng.execute(initial,"F1530",bad).ok,"F1530 does not accept an invented bound argument")
	check(initial==before,"Rejected shared RNG deliveries leave caller Root untouched")
func native_controls()->void:
	check(FileAccess.get_sha256(FIXTURE)==FIXTURE_SHA,"Original F1530/F922 native fixture is pinned")
	if not FileAccess.file_exists(FIXTURE):return
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE));buffers=fixture.buffers;dependencies=fixture.get("source_dependencies_sha256",{})
	for path:String in dependencies:check(FileAccess.get_sha256("res://"+path)==dependencies[path],"Native RNG reproduction dependency is pinned: "+path)
	for row:Dictionary in fixture.cases:
		if row.operation not in ["rng1530","rng922"]:continue
		var initial:=buffer(str(row.context_before.root));var before:=initial.duplicate();var operation:="F1530" if row.operation=="rng1530" else "F922";var bound:Variant=null if operation=="F1530" else int(row.get("bound_u32",row.get("bound_s32",0)))&0xffffffff
		var result:=Rng.execute(initial,operation,bound);native_cases+=1
		check(result.ok and result.root_after==buffer(str(row.expected.context_after.root)) and int(result.return_u32)==int(row.expected.return_u32),"Full raw shared Root RNG output equals original native instructions: "+str(row.name))
		check(initial==before,"Native RNG replay leaves its supplied Root immutable: "+str(row.name))
		check(result.source_order==row.expected.source_order,"Native RNG source order is preserved: "+str(row.name))
		var cold:Dictionary=JSON.parse_string(JSON.stringify({"root_hex":initial.hex_encode(),"operation":operation,"bound":bound}));var again:=Rng.execute(str(cold.root_hex).hex_decode(),cold.operation,cold.bound)
		check(again.ok and again.root_after==result.root_after and int(again.return_u32)==int(result.return_u32),"Cold JSON RNG operands preserve source32bit transition and product truncation: "+str(row.name))
		operations[operation]=true
		if operation=="F922":bounds[int(bound)]=true
	check(native_cases>0 and operations.has("F1530") and operations.has("F922"),"Native controls cover both generators using the same Root words")
	for bound:int in [0x80000000,0xffffffff,0,1,2,65535,65536,0x7fffffff]:check(bounds.has(bound),"Actual native F922 controls cover full32-bit edge bound "+str(bound))
	native_complete=true
func run()->void:
	standalone();native_controls();check(native_complete,"The complete independent shared RNG controls return normally")
	var sources:Dictionary={}
	for path:String in dependencies:sources[path]=FileAccess.get_sha256("res://"+path)
	for path:String in ["scripts/source_global_rng.gd","tests/test_source_global_rng.gd",FIXTURE.trim_prefix("res://")]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"schema":1,"profile":Rng.PROFILE,"checks":checks,"failures":failures,"native_cases":native_cases,"sources":sources,"Main_integrated":false,"physical_device_tested":false},"\t"));file.close()
	print("SOURCE GLOBAL RNG TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
