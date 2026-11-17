extends SceneTree
const RESOURCE:="res://data/ffe_collision_programs.json"
const RESOURCE_SHA:="7ccd9884e0c05fc4d645347301112ab972d83c40780243325f3e907d5f527013"
const CAPTURE:="res://validation/collision-programs-2026-11-17/resources/original-spans.json"
const CAPTURE_SHA:="6b9f0d858a74389d7b9113d582fa1fec81fc74f0ecaa41fafd30212b4aebd535"
const REPORT:="res://build/current-test-reports/source-collision-resources.json"
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
 checks+=1
 if not ok:
  failures+=1
  if failures<20:push_error(message)
func hash_bytes(raw:PackedByteArray)->String:
 var ctx:=HashingContext.new();ctx.start(HashingContext.HASH_SHA256);ctx.update(raw);return ctx.finish().hex_encode()
func run()->void:
 check(FileAccess.get_sha256(RESOURCE)==RESOURCE_SHA,"Original complete collision resources have a fixed independent fingerprint")
 check(FileAccess.get_sha256(CAPTURE)==CAPTURE_SHA,"Captured executable spans have a fixed independent fingerprint")
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(RESOURCE))
 var captures:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CAPTURE))
 var old:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ffe_runtime_model_descriptors.json"))
 var factory:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/ffe_object_factory.json"))
 check(data.schema=="starfrontier-original-collision-program-resources-v1" and data.profile=="dos-firstenc-collision-program-resources-v1","Collision resources explicitly differ from rendering program resources")
 check(data.source_executable_sha256=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" and data.source_assembly_sha256=="d4f1b76aa78895d3634b182428e14f36ac57b304e56fedb67a89ee39b5f6873a" and data.source_data_sha256=="34219c91c5d019440ebf4fc707711a32c5080123ede05cf4d10a27d41f770850","Uploaded executable and logical assembly identities are pinned")
 check(data.root_model_count==149 and data.model_count==178 and data.models.size()==178 and data.collision_program_count==178,"149 primary model slots retain all29 recursively required collision submodels")
 check(captures.spans.size()==993,"All993 exact source byte spans survive packaging")
 var classes:Dictionary={};var conditions:=0;var terrain:=0;var children:=0
 for name:String in captures.spans:
  var span:Dictionary=captures.spans[name];var raw:=str(span.hex).hex_decode()
  check(raw.size()==int(span.bytes) and hash_bytes(raw)==span.sha256,"Every captured original byte span retains bytes/SHA: "+name)
  check(int(span.virtual_address_u32)>0x400000 and int(span.executable_offset)>=0,"Every span retains an explicit logical VA and executable offset")
 for key:String in data.models:
  var row:Dictionary=data.models[key];var index:=int(key);var descriptor:=str(row.descriptor_hex).hex_decode();var program:=str(row.collision_program_hex).hex_decode();var vertices:=str(row.vertices_hex).hex_decode();var normals:=str(row.normals_hex).hex_decode()
  check(descriptor.size()==68 and int(row.model_index_u32)==index,"Exact original descriptor and model identity: "+key)
  check(row.source_spans.descriptor.hex==row.descriptor_hex and int(row.source_spans.descriptor.virtual_address_u32)==int(row.original_pointers_u32.descriptor),"Descriptor pointer/span association remains exact")
  check(str(data.model_table_slots_hex[key]).hex_decode().decode_u32(0)==descriptor_pointer(row),"Original F1538 slot resolves to its captured descriptor")
  check(row.source_spans.program.hex==row.collision_program_hex and int(row.source_spans.program.virtual_address_u32)==int(descriptor.decode_u32(0x34)),"Collision program comes from descriptor34, not render pointer00")
  check(row.vertices_origin_u32==0 and ((normals.is_empty() and row.normals_origin_u32==0) or (not normals.is_empty() and row.normals_origin_u32==6)),"Packed normal origin preserves original minus-six lookup")
  check(program.size()>0 and program[-1]==0 and row.all_program_records_structurally_decoded,"Complete collision stream includes its actual instruction terminator")
  if index<149:
   check(old.models[key].descriptor_hex==row.descriptor_hex and factory.models[key].descriptor_hex==row.descriptor_hex,"Primary descriptors match separately pinned original factory resources")
  for part:String in row.source_spans:
   var span:Dictionary=row.source_spans[part];var span_name:="model%d/%s"%[index,part]
   check(captures.spans.has(span_name) and captures.spans[span_name]==span,"Every published span matches its original extraction capture")
  var cursor:=0
  for record:Dictionary in row.program_records:
   var offset:=int(record.offset);var cls:=int(record.class_u8);classes[str(cls)]=int(classes.get(str(cls),0))+1
   check(offset==cursor and offset+2<=program.size() and int(program[offset])==int(record.opcode_u8) and int(program[offset+1])==int(record.volume_u8),"Structural record metadata remains byte-bound")
   check(int(record.next_offset)>offset and int(record.next_offset)<program.size(),"Record extent ends before the program terminator")
   if record.has("condition"):conditions+=1
   if record.kind=="submodel":
    var extra:=2 if record.has("condition") else 0;var at:=offset+2+extra;var child:=int(record.model_index_u32)
    check(program[at]*256+program[at+1]==child and int(program[at+2])==int(record.orientation_u8) and int(program[at+3])==int(record.vertex_code_u8),"Nested source order is modelBE16/orientation/vertex")
    var in_refs:=false
    for reference:Variant in row.nested_model_indices:
     if int(reference)==child:in_refs=true
    check(data.models.has(str(child)) and in_refs,"Every actual nested model reference is available")
   elif record.kind=="terrain":terrain+=1
   cursor=int(record.next_offset)
  check(cursor==program.size()-1,"Resource ends at the first structurally decoded terminal opcode")
  var backward:=str(row.children_hex).hex_decode();children+=row.children_records.size()
  check(backward.size()==2+row.children_records.size()*4 and backward.decode_s16(0)==0,"Backward child list has exact sentinel and records")
  for n in range(row.children_records.size()):
   var at:=backward.size()-2-n*4;var child:Dictionary=row.children_records[n]
   check(int(child.displacement_s16)==backward.decode_s16(at) and int(child.axis_radius_encoded_s16)==backward.decode_s16(at-2),"F576 child order matches backward original reads")
  check(row.undefined_child_axis_records.is_empty(),"Actual captured child records avoid the undefined axis6 branch")
  # Validate original packed reads, including documented source-memory
  # extensions; never replace them with generated normals or mesh bounds.
  for rec:Dictionary in row.program_records:
   for code:Variant in rec.get("plane_codes_u8",[]):
    var normal_at:=(int(code)>>1)*6
    check(normal_at+6<=normals.size(),"Actual plane read is wholly present in captured original memory")
    if normal_at+6<=normals.size():check((int(normals[normal_at])>>1)*6+6<=vertices.size(),"Actual plane's source vertex read is present")
 check(classes=={"0":84,"64":81,"128":158,"192":66},"All four source record classes are extracted across the real model domain")
 check(conditions==57 and terrain==37 and children==138,"Conditional equipment, terrain and child-list records retain the actual original inventory")
 check(data.models["24"].collision_program_hex=="80800017000000","Model24 uses the literal original collision submodel23 program")
 check(data.models["81"].collision_program_hex=="808000f4000050800000" and data.models.has("244"),"Actual source ground port resolves collision submodel244")
 check(data.models["96"].collision_program_hex=="808000ed000050800000" and data.models.has("237"),"Actual underground model resolves collision submodel237")
 check(data.models["117"].collision_program_hex=="1082ff060204000200000050800000","Natural117 program retains complete terrain record and exact terminal extent")
 check(data.models["19"].packed_read_extensions.size()==2 and data.models["35"].packed_read_extensions.size()==2 and data.models["244"].packed_read_extensions.size()==1,"Original memory reads beyond descriptor count baselines are documented rather than corrected")
 var sources:Dictionary={}
 for path:String in ["data/ffe_collision_programs.json","data/ffe_runtime_model_descriptors.json","data/ffe_object_factory.json","tools/extract_source_collision_programs.py","tests/test_source_collision_resources.gd","validation/collision-programs-2026-11-17/resources/original-spans.json"]:sources[path]=FileAccess.get_sha256("res://"+path)
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REPORT.get_base_dir()))
 var file:=FileAccess.open(REPORT,FileAccess.WRITE)
 if file:file.store_string(JSON.stringify({"profile":data.profile,"checks":checks,"failures":failures,"primary_models":149,"models_with_recursive_dependencies":178,"original_spans":993,"source_records":389,"conditional_records":57,"terrain_records":37,"child_records":138,"sources":sources,"full_collision_execution_claimed":false,"Main_integrated":false},"\t"));file.close()
 print("SOURCE COLLISION RESOURCES TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func descriptor_pointer(row:Dictionary)->int:return int(row.original_pointers_u32.descriptor)
