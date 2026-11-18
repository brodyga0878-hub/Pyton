extends RefCounted
# Immutable DOS resource graph. Offsets name original resource bytes, never
# host pointers; module globals are a separate shared mutable forty-byte owner.
const Clock=preload("res://scripts/source_clock_pipeline.gd")
const Frame=preload("res://scripts/source_frame_dispatch.gd")
const RESOURCE:="res://data/ffe_mission_programs.json"
const RESOURCE_SHA:="ebd6caa6cc4f5d9d4a606d09a61339d737fada0628eb4cd131b9af91ef5b1f27"
const CANONICAL_RESOURCE_SHA:="cb575852cfb797c30190e61422be5bf8e65dfc2dd1e93736a12317ea348627d7"
const PROFILE:="dos-firstenc-mission-resource-graph-v1"
const NULL_OFFSET:=0xffffffff
const REGION_LAYOUT:={"mission":[0x4801c4,57560],"name_table":[0x48e29c,544],"string_table":[0x48e4bc,1872],"event_functions":[0x48ec0c,48],"expression_metadata":[0x48ec3c,1088],"vectors":[0x48f07c,324],"names":[0x48f1c0,716],"strings":[0x48f48c,46474]}
static func _plain(value:Variant,depth:int=0)->bool:
	if depth>32:return false
	if value is Dictionary:
		if value.size()>4096:return false
		for key:Variant in value:
			if not key is String or not _plain(value[key],depth+1):return false
		return true
	if value is Array:
		if value.size()>4096:return false
		for item:Variant in value:
			if not _plain(item,depth+1):return false
		return true
	if value is String:return value.length()<=300000
	return value==null or value is bool or value is int or (value is float and is_finite(value))
static func validate(value:Variant)->bool:
	if not value is Dictionary or value.get("schema")!="starfrontier-original-mission-program-resources-v1" or value.get("profile")!=PROFILE or not _plain(value):return false
	# Canonical JSON closes every field, raw byte span and pointer association;
	# callers cannot replace a module descriptor while retaining the resource tag.
	return Clock._hash(value)==CANONICAL_RESOURCE_SHA
static func load_original()->Dictionary:
	if FileAccess.get_sha256(RESOURCE)!=RESOURCE_SHA:return {}
	var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(RESOURCE))
	return value.duplicate(true) if validate(value) else {}
static func read(resource:Variant,region:Variant,offset:Variant,count:Variant)->PackedByteArray:
	if not validate(resource) or not region is String or not REGION_LAYOUT.has(region) or not Frame._whole(offset,0,int(REGION_LAYOUT[region][1])) or not Frame._whole(count,0,int(REGION_LAYOUT[region][1])) or int(offset)+int(count)>int(REGION_LAYOUT[region][1]):return PackedByteArray()
	var raw:=str(resource.regions[region].hex).hex_decode()
	return raw.slice(int(offset),int(offset)+int(count))
static func va_to_offset(resource:Variant,region:Variant,original_va:Variant,count:Variant=1)->int:
	if not validate(resource) or not region is String or not REGION_LAYOUT.has(region) or not Frame._whole(original_va,0,0xffffffff) or not Frame._whole(count,0,int(REGION_LAYOUT[region][1])):return -1
	var offset:=int(original_va)-int(REGION_LAYOUT[region][0])
	return offset if offset>=0 and offset+int(count)<=int(REGION_LAYOUT[region][1]) else -1
static func module(resource:Variant,index:Variant)->Dictionary:
	if not validate(resource) or not Frame._whole(index,0,104):return {}
	return resource.modules[int(index)].duplicate(true)
static func block(resource:Variant,offset:Variant)->Dictionary:
	if not validate(resource) or not Frame._whole(offset,0,57559) or not resource.blocks.has(str(int(offset))):return {}
	return resource.blocks[str(int(offset))].duplicate(true)
static func metadata(resource:Variant,selector:Variant)->Dictionary:
	if not validate(resource) or not Frame._whole(selector,0,67):return {}
	return resource.expression_metadata_rows[int(selector)].duplicate(true)
static func string_bytes(resource:Variant,index:Variant)->PackedByteArray:
	if not validate(resource) or not Frame._whole(index,0,467):return PackedByteArray()
	var row:Dictionary=resource.mission_strings[int(index)]
	return str(resource.regions.strings.hex).hex_decode().slice(int(row.offset_u32),int(row.offset_u32)+int(row.bytes_including_NUL_u32))
static func name_bytes(resource:Variant,index:Variant)->PackedByteArray:
	if not validate(resource) or not Frame._whole(index,0,67):return PackedByteArray()
	var row:Dictionary=resource.names[int(index)]
	return str(resource.regions.names.hex).hex_decode().slice(int(row.offset_u32),int(row.offset_u32)+int(row.bytes_including_NUL_u32))
static func initial_module_globals(resource:Variant)->PackedByteArray:
	return str(resource.module_globals_initialization.initial_hex).hex_decode() if validate(resource) else PackedByteArray()
static func events_definitions(resource:Variant)->Dictionary:
	if not validate(resource):return {}
	var result:Dictionary={}
	for row:Dictionary in resource.modules:
		var cleanup:=int(row.cleanup_block_index_s32);var instruction:=0
		if cleanup>=0:
			var target:Dictionary=resource.blocks[str(int(row.block_offsets_u32[cleanup]))]
			instruction=int(REGION_LAYOUT.mission[0])+int(target.initialization_offset_u32)
		# Zero is an unused admission placeholder for modules with cleanup=-1.
		# A caller must reject a fabricated priority5 cleanup for such modules.
		result[str(int(row.module_index_u32))]={"descriptor_ref_u32":int(REGION_LAYOUT.mission[0])+int(row.descriptor_offset_u32),"cleanup_instruction_u32":instruction,"variable_words_u32":int(row.variable_words_u32)}
	return result
