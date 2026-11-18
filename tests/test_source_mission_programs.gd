extends SceneTree
const Programs=preload("res://scripts/source_mission_programs.gd")
const Events=preload("res://scripts/source_events.gd")
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const CAPTURE:="res://validation/mission-expressions-2026-11-18/resources/original-spans.json"
const CAPTURE_SHA:="9292a646e49a2e1105d47e3b15f6758dd8ee14f656973e1d63e34fa7024fbd0b"
const REPORT:="res://build/current-test-reports/source-mission-programs.json"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(value:bool,message:String)->void:
	checks+=1
	if not value:
		failures+=1
		if failures<20:push_error(message)
func bytes(count:int)->PackedByteArray:
	var value:=PackedByteArray();value.resize(count);return value
func event_context(definitions:Dictionary)->Dictionary:
	return {"root":bytes(16384),"bank":bytes(38986),"event_registers":bytes(284),"scratch_words":bytes(32),"arena":bytes(5400),"temporary_event_index_s32":0,"tree_root_u32":0,"nodes":{},"next_node_id_u32":1,"task_variables":{},"next_variable_id_u32":1,"definitions":definitions.duplicate(true)}
func run()->void:
	check(FileAccess.get_sha256(Programs.RESOURCE)==Programs.RESOURCE_SHA,"Original mission resource bytes are independently pinned")
	check(FileAccess.get_sha256(CAPTURE)==CAPTURE_SHA,"Captured original spans are independently pinned")
	var data:=Programs.load_original();check(not data.is_empty(),"Strict loader accepts the complete captured original resource graph")
	if data.is_empty():print("SOURCE MISSION PROGRAMS TESTS: %d checks, %d failures"%[checks,failures]);quit(1);return
	var capture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CAPTURE))
	check(data.source_executable_sha256=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" and data.source_mission_assembly_sha256=="6f9732f6f881f038a9780460e287437d4d0b6b4b6df739d8a24e19a80e687a33","Actual DOS and separately reviewed mission-source identities are retained")
	check(data.module_count==105 and data.block_count==337 and data.expression_selector_count==68 and data.vector_count==27 and data.name_count==68 and data.mission_string_count==468,"All actual resource inventories are explicit")
	check(not data.bytecode_semantic_execution_claimed and not data.full_F41_VM_executed and not data.Main_integrated,"Resource retention does not claim execution of the mission interpreter")
	var image:=str(data.regions.mission.hex).hex_decode();var base:=int(data.regions.mission.original_va_u32);var total:=0
	for name:String in data.regions:
		var row:Dictionary=data.regions[name];var span:Dictionary=capture.spans[name];var raw:=str(row.hex).hex_decode();total+=raw.size()
		check(raw.size()==int(row.bytes),"Captured region retains its complete byte extent: "+name)
		check(row.hex==span.hex and row.sha256==span.sha256 and int(row.original_va_u32)==int(span.virtual_address_u32) and int(row.executable_offset)==int(span.executable_offset),"Resource region is exactly associated with its original VA/file span")
		check(Programs.read(data,name,0,raw.size())==raw,"Public bounded raw reader returns actual captured bytes")
		check(Programs.va_to_offset(data,name,int(row.original_va_u32),raw.size())==0,"VA-to-offset mapping keeps original logical resource addresses")
	check(total==108626 and data.captured_file_bytes==108626,"All eight captured regions cover the exact DOS mission image")
	var definitions:=Programs.events_definitions(data);check(definitions.size()==105 and Events._context(event_context(definitions)),"All105 original allocation definitions fit the actual Events profile")
	var seen_blocks:Dictionary={};var globals:Dictionary={};var cleanup_modules:Array=[];var clause_count:=0;var module32_checked:=false
	for index in range(105):
		var row:Dictionary=data.modules[index];var at:=int(row.descriptor_offset_u32);var pointer:=image.decode_u32(int(data.module_table_offset_u32)+index*4)
		check(at+base==pointer and int(row.module_index_u32)==index,"Original descriptor table resolves each module to its own bytes")
		check(image.decode_u32(at+8)==int(row.argument_count_u32) and image.decode_u32(at+16)==int(row.variable_words_u32) and image.decode_s32(at+12)==int(row.cleanup_block_index_s32) and image.decode_u32(at+24)==int(row.global_words_u32),"Descriptor scalar fields come from actual DOS bytes")
		for pair:Array in [["argument_targets_offset_u32",0],["argument_expressions_offset_u32",4]]:
			var original:=image.decode_u32(at+int(pair[1]));check((original==0 and int(row[pair[0]])==Programs.NULL_OFFSET) or original==base+int(row[pair[0]]),"Null and actual argument-program references are distinct")
		check(row.block_offsets_u32.size()==int(capture.source_layout.descriptor_block_counts[index]),"Variable-length descriptor array matches independently named source extent")
		for j in range(row.block_offsets_u32.size()):
			var offset:=int(row.block_offsets_u32[j]);check(image.decode_u32(at+28+j*4)==base+offset,"Each original block-array entry retains its pointer target")
			check(data.blocks.has(str(offset)),"Every actual module block header is present")
			var block:Dictionary=data.blocks[str(offset)];seen_blocks[str(offset)]=true
			check(image.decode_u32(offset)==base+int(block.initialization_offset_u32),"Block header00 is the F41 initialization statement cursor")
			check(image.decode_u32(offset+4)==block.clause_offsets_u32.size(),"Original clause count bounds the complete block pointer array")
			for k in range(block.clause_offsets_u32.size()):
				check(image.decode_u32(offset+8+k*4)==base+int(block.clause_offsets_u32[k]),"Actual clause pointer identifies F31 condition followed by F41 statements");clause_count+=1
		if int(row.global_words_u32)>0:
			check(image.decode_u32(at+20)==0x60bde0+int(row.global_owner_offset_u32) and int(row.global_owner_offset_u32)%4==0 and int(row.global_owner_offset_u32)+4<=40,"Static mission globals retain one shared40-byte owner")
			globals[str(int(row.global_owner_offset_u32))]=true
		else:check(int(row.global_owner_offset_u32)==Programs.NULL_OFFSET and image.decode_u32(at+20)==0,"A module without static globals does not get a fake private buffer")
		var definition:Dictionary=definitions[str(index)]
		check(int(definition.descriptor_ref_u32)==pointer and int(definition.variable_words_u32)==image.decode_u32(at+16),"Event allocation definition resolves original descriptor and variable count")
		if int(row.cleanup_block_index_s32)>=0:
			var block_offset:=int(row.block_offsets_u32[int(row.cleanup_block_index_s32)]);cleanup_modules.append(index)
			check(int(definition.cleanup_instruction_u32)==image.decode_u32(block_offset),"F54 cleanup reads the initialization statement cursor from the selected block")
		else:check(int(definition.cleanup_instruction_u32)==0,"No-cleanup module carries only the documented unused admission placeholder")
		var admitted:=Events.execute(event_context(definitions),"F51",[index,0x12345678])
		check(admitted.get("ok",false),"Actual original F51 admits resource-backed module "+str(index))
		if admitted.get("ok",false):
			var arena:PackedByteArray=admitted.context_after.arena;var variables:PackedByteArray=admitted.context_after.task_variables["1"]
			check(arena.decode_u32(28)==pointer and variables.size()==image.decode_u32(at+16)*4,"F51 uses the real descriptor pointer and exact variable allocation size")
			check(variables.decode_u32(0)==admitted.allocated_handle_u32 and variables.decode_u32(4)==0x12345678,"F51 initializes its handle/argument while preserving the native allocator policy")
		if index==32:module32_checked=int(row.variable_words_u32)==15
	check(seen_blocks.size()==337 and globals.size()==10 and cleanup_modules==[17,40,54,80],"Actual block/shared-global/cleanup graph is complete")
	check(module32_checked and data.DOS_JJFFE_descriptor_scalar_differences.size()==1 and data.DOS_JJFFE_descriptor_scalar_differences[0].DOS_u32==15 and data.DOS_JJFFE_descriptor_scalar_differences[0].JJFFE_u32==16,"Confirmed module32 DOS/JJFFE difference is preserved, not overwritten")
	var initial:=Programs.initial_module_globals(data)
	check(initial==bytes(40) and data.module_globals_initialization.file_backed_bytes==32 and data.module_globals_initialization.virtual_zero_fill_bytes==8,"Global initialization distinguishes32file bytes from8PEvirtual zero bytes")
	var metadata:=str(data.regions.expression_metadata.hex).hex_decode()
	for index in range(68):
		var row:Dictionary=data.expression_metadata_rows[index]
		for pair:Array in [["child_expression_count_s32",0],["event_code_s32",4],["event_argument0_kind_s32",8],["event_argument1_kind_s32",12]]:check(int(row[pair[0]])==metadata.decode_s32(index*16+int(pair[1])),"Every expression metadata word is the actual DOS operand")
	var string_table:=str(data.regions.string_table.hex).hex_decode();var string_data:=str(data.regions.strings.hex).hex_decode();var longest:=0
	for index in range(468):
		var row:Dictionary=data.mission_strings[index];var offset:=int(row.offset_u32);var count:=int(row.bytes_including_NUL_u32);longest=maxi(longest,count-1)
		check(string_table.decode_u32(index*4)==int(data.regions.strings.original_va_u32)+offset,"Every original mission-string pointer resolves into the captured text region")
		check(count>0 and offset+count<=string_data.size() and string_data[offset+count-1]==0 and string_data.slice(offset,offset+count-1).find(0)==-1,"Every captured mission string has its first real NUL terminator")
	check(longest==995,"Complete original strings retain their actual longest byte extent")
	var anything:="anything".to_ascii_buffer();anything.append(0);var carrier:="Vaccine carrier".to_ascii_buffer();carrier.append(0)
	check(Programs.name_bytes(data,0)==anything and Programs.string_bytes(data,467)==carrier,"Public text readers retain original bytes and NUL, without invented translation")
	check(Programs.metadata(data,67).selector_u8==67 and Programs.metadata(data,68).is_empty(),"Metadata is bounded to the actual68 source rows")
	var copy:=Programs.module(data,32);copy.variable_words_u32=16
	check(int(data.modules[32].variable_words_u32)==15 and int(Programs.module(data,32).variable_words_u32)==15,"Returned descriptor copies cannot edit shared immutable resources")
	var definition_copy:=definitions.duplicate(true);definition_copy["32"].variable_words_u32=16
	check(int(Programs.events_definitions(data)["32"].variable_words_u32)==15,"Returned event allocation definitions do not alias the immutable graph")
	var changed:=data.duplicate(true);changed.modules[32].variable_words_u32=16;check(not Programs.validate(changed) and Programs.module(changed,32).is_empty(),"Forged JJFFE-sized module with retained resource identity is rejected")
	changed=data.duplicate(true);changed.regions.mission.hex="00"+str(changed.regions.mission.hex).substr(2);check(not Programs.validate(changed) and Programs.read(changed,"mission",0,1).is_empty(),"Changed raw bytecode is rejected even with original metadata")
	for bad:Variant in [null,[],1,true,"",{},PackedByteArray()]:check(not Programs.validate(bad) and Programs.module(bad,0).is_empty(),"Malformed resource input is rejected without mutating owners")
	for bad:Variant in [-1,105,1.5,"32",true,null]:check(Programs.module(data,bad).is_empty(),"Malformed or out-of-range module selector is rejected")
	for args:Array in [["mission",-1,1],["mission",57560,1],["missing",0,1],["mission",0,57561],["mission",0.5,1],["mission",0,true]]:check(Programs.read(data,args[0],args[1],args[2]).is_empty(),"Invalid program byte range is rejected")
	check(Programs.va_to_offset(data,"mission",0x4801c3)==-1 and Programs.va_to_offset(data,"mission",0x48e29c)==-1 and Programs.va_to_offset(data,"mission",0x48e29c,0)==57560,"VA boundaries distinguish last byte and valid end cursor")
	check(Programs.block(data,Programs.NULL_OFFSET).is_empty() and Programs.string_bytes(data,468).is_empty() and Programs.name_bytes(data,68).is_empty(),"Uncaptured block/string/name references remain unavailable")
	var sources:Dictionary={}
	for path:String in ["data/ffe_mission_programs.json","scripts/source_mission_programs.gd","scripts/source_events.gd","scripts/source_clock_pipeline.gd","scripts/source_frame_dispatch.gd","tools/extract_source_mission_programs.py","tools/extract_source_collision_programs.py","tests/test_source_mission_programs.gd","validation/mission-expressions-2026-11-18/resources/original-spans.json"]:sources[path]=FileAccess.get_sha256("res://"+path)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()));var file:=FileAccess.open(REPORT,FileAccess.WRITE)
	if file:file.store_string(JSON.stringify({"profile":Programs.PROFILE,"checks":checks,"failures":failures,"modules":105,"blocks":337,"clause_pointers":clause_count,"original_file_bytes":108626,"original_strings":468,"metadata_rows":68,"real_F51_module_admissions":105,"sources":sources,"full_F41_VM_executed":false,"Main_integrated":false},"\t")+"\n");file.close()
	print("SOURCE MISSION PROGRAMS TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
