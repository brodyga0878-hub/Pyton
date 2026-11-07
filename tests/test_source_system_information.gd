extends SceneTree
# Independent native original procedures are the oracle, not regenerated
# expected values from the GDScript under test. Additional real World checks
# establish the read-only, knowledge and DOS/JJFFE variant boundaries.
const Info=preload("res://scripts/source_system_information.gd")
const Text=preload("res://scripts/source_information_text.gd")
const World=preload("res://scripts/planetary_system.gd")
const Definition=preload("res://scripts/source_system_definition.gd")
const FIXTURE:="res://tests/fixtures/source_information_native.json"
var checks:=0
var failures:=0
var domains:Dictionary={}
var evidence:Array=[]
var domain_failures:Dictionary={}
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<=40:push_error(message)
func bytes_equal(actual:Dictionary,expected:Dictionary,label:String)->void:
	check(actual.get("ok",false),label+" expands without unsupported errors: "+str(actual.get("error","")))
	check(actual.get("raw_bytes",PackedByteArray()).hex_encode()==str(expected.expected_hex),label+" matches literal native bytes; actual="+actual.get("raw_bytes",PackedByteArray()).hex_encode()+" expected="+str(expected.expected_hex))
func source_records(bank:PackedByteArray)->Dictionary:
	var records:Dictionary={}
	for index in range(int(bank.size()/68)):
		var raw:=bank.slice(index*68,index*68+68)
		records[index+1]={"id":"native_"+str(index),"name":"native_"+str(index),"original_index":index+1,"runtime_record_hex":raw.hex_encode()}
	return records
func integer_arrays_equal(actual:Array,expected:Array)->bool:
	if actual.size()!=expected.size():return false
	for index in range(actual.size()):
		if (int(actual[index])&0xffffffff)!=(int(expected[index])&0xffffffff):return false
	return true
func compare_calls(actual:Array,expected:Array,label:String,variables:bool=true)->void:
	check(actual.size()==expected.size(),label+" native draw call count actual%d expected%d"%[actual.size(),expected.size()])
	for index in range(mini(actual.size(),expected.size())):
		check(int(actual[index].code)==int(expected[index].code),label+" native code call"+str(index))
		bytes_equal(actual[index],expected[index],label+" call"+str(index))
		if variables and int(actual[index].code)!=0xffffffff:
			check(integer_arrays_equal(actual[index].variables,expected[index].variables),label+" original source registers call"+str(index)+" actual="+str(actual[index].variables)+" expected="+str(expected[index].variables))
func native_cases()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string(FIXTURE))
	check(fixture is Dictionary and fixture.get("schema")==1 and fixture.get("source_sha256")==Text.SOURCE_SHA,"Native fixture identifies uploaded original DOS bytes")
	check(fixture.get("canaries_unchanged",false) and fixture.get("fresh_process_runs")==3 and fixture.get("reverse_repeat_count")==fixture.get("case_count"),"Original host routines were repeated with buffer canaries")
	for at in range(fixture.cases.size()):
		var sample:Dictionary=fixture.cases[at];var domain:=str(sample.domain);domains[domain]=int(domains.get(domain,0))+1
		var previous_failures:=failures
		var label:="native %d/%s"%[at,domain];var vars:Array=sample.variables.duplicate(true)
		if sample.has("string4_hex"):vars[3]=str(sample.string4_hex).hex_decode()
		if sample.has("string5_hex"):vars[4]=str(sample.string5_hex).hex_decode()
		match int(sample.operation):
			0:bytes_equal(Text.render_code(int(sample.code),vars,{},"en"),sample,label)
			1:bytes_equal(Text.expand(str(sample.raw_hex).hex_decode(),vars,{},"en"),sample,label)
			3:
				var selected:=Info.policy_record(int(sample.metadata_index))
				check(integer_arrays_equal(selected.F870_values,sample.expected_policy_values),label+" F870 demographic values")
				check(selected.commodity_flags.hex_encode()==sample.expected_commodity_flags_hex,label+" F870 exact37commodity bytes including forced +32")
			4:
				check(Text._string_bytes(Text._source_fraction(int(vars[0]),int(sample.code)),"en").hex_encode()==sample.expected_hex,label+" exact original F1377 signed fraction")
			2:
				var selected:=Info.policy_record(int(sample.metadata_index));var actual:Array=[]
				if sample.has("bank_hex"):
					var records:=source_records(str(sample.bank_hex).hex_decode());var row:Dictionary=records[int(sample.record_index)+1]
					var result:=Info.body_source_calls(row,records,"en")
					check(result.ok,label+" native body page executes: "+result.error);actual=result.calls
				elif int(sample.known)!=0:
					if int(sample.action)==250:actual=Info.demographic_calls(int(sample.system_id),selected,"en")
					elif int(sample.action)==249:
						actual=[Info._part(0x84b4,[0,0,0,0,0],"en")]
						var groups:=Info.trade_groups(selected,"en");check(groups.ok,label+" native commodity graph valid");actual.append_array(groups.calls)
				compare_calls(actual,sample.expected_calls,label,int(sample.action)!=249)
		if failures>previous_failures:domain_failures[domain]=int(domain_failures.get(domain,0))+failures-previous_failures
	var all_consumed:bool=domains.size()==fixture.domain_counts.size()
	for key:String in domains:all_consumed=all_consumed and int(domains[key])==int(fixture.domain_counts.get(key,-1))
	check(all_consumed,"Every native fixture case is consumed exactly once")
	evidence.append({"native_cases":fixture.case_count,"domains":domains,"domain_failures":domain_failures,"native_output_sha256":fixture.native_output_sha256})
func runtime_contracts()->void:
	for key:String in ["parent","ground_port","no_entries"]:
		check(not Text.ui(key,"ru").is_empty(),"Russian semantic page caption is present: "+key)
	var world:=World.new();var definition:=Definition.new();var sol:=definition.describe(0x02a49718)
	world.configure(sol,World.FULL_LAYOUT)
	var before:=var_to_bytes(world.snapshot());var bodies_before:=var_to_bytes(world.bodies);var ports_before:=var_to_bytes(world.settlements)
	var pages:=Info.system_pages(0x02a49718,"Солнце",world.bodies,world.settlements,true,"ru",{"body_count_byte":world.source_runtime_state.body_count_byte})
	check(pages.ok and pages.pages.size()==3,"Actual source Sol provides three Russian pages: "+pages.error)
	check(pages.provenance.effective_known and pages.provenance.metadata_variant=="dos-original-info-only","DOS policy selects knowledge independently from live JJFFE World")
	check(pages.provenance.body_count_available and pages.pages[0].source_calls[0].variables==[int(world.source_runtime_state.body_count_byte)],"Original major-body count comes from the actual source counter, including authored orbital stations")
	check(not Info.system_pages(0x02a49718,"Солнце",world.bodies,world.settlements,true,"ru").provenance.body_count_available,"Missing original body counter is never guessed from natural-body rows")
	check(pages.pages[1].text.contains("Федера") and pages.pages[1].text.contains("10"),"Sol demographics use original Federation and source population class")
	for row:Dictionary in world.bodies+world.settlements:
		var body:=Info.body_page(0x02a49718,row,world.settlements,"ru")
		check(body.ok,"Actual source Sol body/port card "+str(row.id)+": "+body.error)
		check(not body.text.is_empty() and not body.text.contains("{FF"),"Actual Russian source card has expanded text "+str(row.id))
		if int(row.type_code)==35:check(body.source_action_id==-1 and body.provenance.has("adapter"),"Ground port has explicit adapter and no invented original selectable action")
	check(var_to_bytes(world.snapshot())==before and var_to_bytes(world.bodies)==bodies_before and var_to_bytes(world.settlements)==ports_before,"Information queries leave every actual World byte unchanged")
	var unknown:=Info.system_pages(0x02a49718,"Солнце",world.bodies,world.settlements,false,"ru")
	check(unknown.ok and unknown.pages.size()==1 and not unknown.provenance.effective_known,"Caller unknown flag suppresses all planetary/demographic/trade pages")
	var resource:=Text.source_resource();var bytes:=str(resource.dos_metadata_hex).hex_decode();var empty_id:=0
	for index in range(329):
		var offset:=432+index*54
		if bytes[offset+5]==0:empty_id=int(bytes.decode_u32(offset));break
	check(empty_id!=0,"DOS table contains native unknown systems")
	var gated:=Info.system_pages(empty_id,"Unknown",world.bodies,world.settlements,true,"en")
	check(gated.ok and gated.pages.size()==1 and not gated.provenance.effective_known,"F842 original population_raw zero overrides accidental caller-known and stale body data")
	check(not Info.body_page(empty_id,world.bodies[0],world.settlements,"en").ok,"Native unknown system does not expose a stale body card")
	check(not Info.system_pages(-1,"invalid").ok and not Info.system_pages(0x100000000,"invalid").ok,"Non-u32 systems reject atomically")
	check(not Text.render_code(0x3fff).ok and Text.render_code(0x3fff).unsupported_codes==[0x3fff],"Unknown FF branch is explicit and never guessed")
	check(not Text.render_code(0x3016,[0,0,0,"[Sy"]).ok and Text.render_code(0x3016,[0,0,0,"[Sy"]).unsupported_codes.size()==1,"Stateful F76 commands explicitly report unsupported")
	check(Text.render_code(0x8438,[],{},"en").raw_bytes.hex_encode()=="4b725b7220363000","Original Kr[ger default bracket behavior matches original byte stream")
	var source_glyph:=Text.render_label(7167,[],{},"en")
	check(source_glyph.ok and source_glyph.unmapped_glyphs==[131] and source_glyph.raw_bytes.has(131) and source_glyph.text.contains(String.chr(0xfffd)),"Unknown original font glyph keeps its exact byte with an explicit unmapped display diagnostic")
	check(Text.expand("fe0000fd00ff300000".hex_decode(),[],{},"en").raw_bytes.hex_encode()=="1f00001e0000","Zero bytes inside FE/FD/FF operands survive independently from C-string terminators")
	check(not Text.expand("ff30".hex_decode(),[],{},"en").ok and not Text.expand("fe01".hex_decode(),[],{},"en").ok,"Truncated original FF/FE operands reject instead of reading outside the input")
	var cycle:=Text.render_code(0x3018,[0x3018],{},"en")
	check(not cycle.ok and cycle.unsupported_codes==[0x3018],"Recursive original variable cycles reject within a bounded stack")
	var oversized:=Text.expand("a".repeat(Text.MAX_OUTPUT+100),[],{},"en")
	check(not oversized.ok and oversized.expanded_text.length()==Text.MAX_OUTPUT,"Malformed oversized original input is bounded without touching another page")
	var malformed:Dictionary=world.bodies[0].duplicate(true);malformed.runtime_record_hex="00"
	check(not Info.body_page(0x02a49718,malformed,world.settlements,"ru").ok,"Missing complete source records never fall back to adapted masses/radii")
	var unsupported:Dictionary=world.bodies[0].duplicate(true);var unsupported_raw:=str(unsupported.runtime_record_hex).hex_decode();unsupported_raw.encode_u16(10,36);unsupported.runtime_record_hex=unsupported_raw.hex_encode()
	check(not Info.body_page(0x02a49718,unsupported,[],"ru").ok and Info.body_page(0x02a49718,unsupported,[],"ru").unsupported_codes==[0x2000024],"Unproven type36 card reports its exact unsupported branch instead of borrowing a body description")
	var copied:=pages.duplicate(true);copied.pages[0].text="changed"
	check(Info.system_pages(0x02a49718,"Солнце",world.bodies,world.settlements,true,"ru").pages[0].text!=copied.pages[0].text,"Returned pages and input context are isolated snapshots")
	# DOS has329 known rows; the following10 JJFFE-only entries must go through
	# original radial fallback instead of being silently read as original data.
	var jjffe:=str(resource.metadata_variants.jjffe_hex).hex_decode()
	for index in range(329,339):
		var id:=int(jjffe.decode_u32(432+index*54))
		check(Info.policy_index(id)<0,"JJFFE-only policy entry stays out of DOS info "+str(id))
	evidence.append({"system_id":0x02a49718,"world_bodies":world.bodies.size(),"world_settlements":world.settlements.size(),"pages":pages.pages.size(),"world_unchanged":var_to_bytes(world.snapshot())==before,"dos_known_rows":329})
func run()->void:
	native_cases();runtime_contracts()
	var path:="res://validation/system-information-2026-11-07/source-information-core.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file:=FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"schema":1,"checks":checks,"failures":failures,"scope":"Native original information text, DOS policy, F843 demographics/trade/body branches and read-only actual World boundary; not complete original renderer or full F76 game-state interpreter.","evidence":evidence,"sources":{"test_sha256":FileAccess.get_file_as_string("res://tests/test_source_system_information.gd").sha256_text(),"text_sha256":FileAccess.get_file_as_string("res://scripts/source_information_text.gd").sha256_text(),"pages_sha256":FileAccess.get_file_as_string("res://scripts/source_system_information.gd").sha256_text(),"fixture_sha256":FileAccess.get_file_as_string(FIXTURE).sha256_text(),"raw_resource_sha256":FileAccess.get_file_as_string(Text.DATA_PATH).sha256_text(),"russian_resource_sha256":FileAccess.get_file_as_string(Text.RU_PATH).sha256_text()}},"\t"))
	print("Source system information: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
