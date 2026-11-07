extends RefCounted
# Source information pages only. DOS policy bytes are intentionally separate
# from the pinned JJFFE metadata currently used by procedural World generation.
const Text=preload("res://scripts/source_information_text.gd")
const Math=preload("res://scripts/ffe_math.gd")
const Galaxy=preload("res://scripts/source_galaxy.gd")
const MASK:=0xffffffff
const SOURCE_VARIANT:="dos-firstenc-system-information-pages-v1"
const CONTEXT_LIMIT:=16
static var _resource:Dictionary={}
static var _bytes:=PackedByteArray()
static var _contexts:Dictionary={}
static var _context_order:Array=[]
static var _mutex:=Mutex.new()

static func _load()->bool:
	_mutex.lock()
	if not _resource.is_empty():_mutex.unlock();return true
	var source:=Text.source_resource()
	if source.get("metadata_variant")!="dos-original-info-only" or source.get("metadata_stride_bytes")!=54 or source.get("dos_handcoded_count")!=329 or not source.get("dos_metadata_hex") is String:
		_mutex.unlock();return false
	var raw:=str(source.dos_metadata_hex).hex_decode()
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(raw)
	if raw.size()!=18268 or hash.finish().hex_encode()!=source.get("dos_metadata_sha256",""):
		_mutex.unlock();return false
	_resource=source;_bytes=raw;_mutex.unlock();return true

static func policy_index(system_id:int)->int:
	if system_id<0 or system_id>MASK or not _load():return -999
	for index in range(329):
		if int(_bytes.decode_u32(432+index*54))==system_id:return index
	for exception:Variant in _resource.source_exception_ids:
		if (system_id&0x03ffffff)==int(exception):return -1
	var child:=(system_id>>26)&7
	var x:=absi((system_id&8191)-0x1718)+child
	var y:=absi(((system_id>>13)&8191)-0x1524)+child
	var distance:=(x*x+y*y)&MASK
	for pair:Array in [[0x4c90,-8],[0x121,-7],[0x64,-6],[0x31,-5],[0x19,-4],[0x9,-3]]:
		if distance>=int(pair[0]):return int(pair[1])
	return -2

static func policy(system_id:int)->Dictionary:
	var index:=policy_index(system_id)
	return policy_record(index) if index!=-999 else {}

static func policy_record(index:int)->Dictionary:
	if index< -8 or index>=329 or not _load():return {}
	var at:=(index+8)*54;var flags:=_bytes.slice(at+13,at+44)
	flags.resize(37);flags[32]=13 # Exact F870: DATA8791 aliases output+32.
	return {"policy_index":index,"record_hex":_bytes.slice(at,at+54).hex_encode(),"short_code":int(_bytes.decode_u32(at+46)),"long_code":int(_bytes.decode_u32(at+50)),"population_raw":int(_bytes[at+5]),"population_class":int(_bytes[at+4]),"political_word":int(_bytes.decode_u16(at+10)),"F870_values":[int(_bytes[at+4]),int(_bytes[at+12]),int(_bytes.decode_u16(at+10))],"commodity_flags":flags,"source_variant":SOURCE_VARIANT}

static func _base_provenance(system_id:int,selected:Dictionary,effective_known:bool)->Dictionary:
	return {"source_variant":SOURCE_VARIANT,"source_sha256":Text.SOURCE_SHA,"source_commit":str(_resource.get("source_commit","")),"system_id":system_id,"metadata_variant":"dos-original-info-only","live_world_metadata_variant":"jjffe-7e54034-policy-table-with10-added-rows","policy_index":selected.get("policy_index",-999),"population_raw":selected.get("population_raw",0),"effective_known":effective_known,"presentation":"semantic_text_not_original_pixel_positions","F863_distance":"not_requested_no_observer_in_API","bodies_policy":"caller_supplied_original_runtime_records_not_regenerated_by_information_module"}

static func _merge(target:Dictionary,result:Dictionary)->void:
	for code:Variant in result.get("unsupported_codes",[]):
		if not target.unsupported_codes.has(code):target.unsupported_codes.append(code)
	for glyph:Variant in result.get("unmapped_glyphs",[]):
		if not target.has("unmapped_glyphs"):target["unmapped_glyphs"]=[]
		if not target.unmapped_glyphs.has(glyph):target.unmapped_glyphs.append(glyph)
	if not result.get("ok",false):
		target.ok=false
		if not str(result.get("error","")).is_empty():target.error+=("; " if not target.error.is_empty() else "")+str(result.error)

static func _part(code:int,variables:Array,language:String)->Dictionary:
	var output:=Text.render_code(code,variables,{},language)
	output["code"]=code;output["variables"]=variables.duplicate(true)
	return output

static func demographic_calls(system_id:int,selected:Dictionary,language:="en")->Array:
	var word:=int(selected.get("political_word",0))
	var variables:=[0x84cb+(word&63),0x84bb+(word&63),0x84b7+(word>>6),0x84db+int(selected.get("population_class",0)),0]
	var calls:Array=[_part(0x84b5,variables,language)]
	variables[0]=(system_id&8191)-0x1718;variables[1]=((system_id>>13)&8191)-0x1524;variables[2]=(system_id>>26)&63
	calls.append(_part(0x84b6,variables,language));return calls

static func trade_groups(selected:Dictionary,language:="ru")->Dictionary:
	var result:={"major_imports":[],"minor_imports":[],"major_exports":[],"minor_exports":[],"illegal_goods":[],"calls":[],"ok":true,"unsupported_codes":[],"error":""}
	var flags:PackedByteArray=selected.get("commodity_flags",PackedByteArray())
	if flags.size()<33:result.ok=false;result.error="Original F870 commodity flags are missing.";return result
	for index in range(33):
		var value:=int(flags[index]);var key:=""
		if value&128:key="illegal_goods"
		elif (value&7)>=5:key="major_exports" if value&8 else "major_imports"
		elif (value&7)>=3:key="minor_exports" if value&8 else "minor_imports"
		if key.is_empty():continue
		var entry:=_part(0x8e00+index,[],language);entry["commodity_index"]=index;entry["flags"]=value;entry["group"]=key
		result[key].append(entry);result.calls.append(entry);_merge(result,entry)
	return result

static func _record(body:Dictionary)->PackedByteArray:
	var value:Variant=body.get("runtime_record_hex")
	if not Text._hex(value) or value.length()!=136:return PackedByteArray()
	return str(value).hex_decode()

static func _remember(system_id:int,bodies:Array,settlements:Array)->void:
	var records:Dictionary={}
	for row:Variant in bodies+settlements:
		if not row is Dictionary:continue
		var index:=int(row.get("original_index",0));var raw:=_record(row)
		if index>=1 and index<=128 and raw.size()==68:records[index]=row.duplicate(true)
	_mutex.lock();_contexts[system_id]=records;_context_order.erase(system_id);_context_order.append(system_id)
	while _context_order.size()>CONTEXT_LIMIT:_contexts.erase(_context_order.pop_front())
	_mutex.unlock()

static func _context(system_id:int)->Dictionary:
	_mutex.lock();var result:Dictionary=_contexts.get(system_id,{}).duplicate(true);_mutex.unlock();return result

static func system_pages(system_id:int,system_name:String,bodies:Array=[],settlements:Array=[],known:bool=true,language:String="ru",source_counts:Dictionary={})->Dictionary:
	var selected:=policy(system_id)
	var result:={"ok":false,"pages":[],"provenance":{},"unsupported_codes":[],"error":""}
	if selected.is_empty() or not language in ["ru","en"]:result.error="Original system-information data or system identifier is invalid.";return result
	var effective_known:=known and int(selected.population_raw)!=0
	result.ok=true;result.provenance=_base_provenance(system_id,selected,effective_known)
	_remember(system_id,bodies if effective_known else [],settlements if effective_known else [])
	var general:={"id":"general","title":Text.ui("general",language),"source_action_id":255,"text":system_name,"source_calls":[]}
	# F832's primary/multiplicity and spectral strings come from original galaxy
	# bytes, while short/long descriptions below use the separate DOS policy.
	var kernel:=Galaxy.new();var star:=kernel.system(system_id)
	if not star.is_empty():
		var count:=int(star.star_count_code)&7
		if count>0:
			var multiple:=_part(0x8498+count,[],language);_merge(result,multiple);general.text+="\n"+str(multiple.text)
		var spectral:=_part(0x8488+(int(star.star_type)&31),[],language);_merge(result,spectral);general.text+="\n"+str(spectral.text)
	var short:=_part(int(selected.short_code),[],language);_merge(result,short)
	general.text+="\n"+str(short.text)
	if effective_known:
		var count:Variant=source_counts.get("body_count_byte")
		if not Text._integer(count,0,255):
			# F878 and F881 increment their counter differently for barycentres
			# and orbital stations. Never infer it from displayed row counts.
			result.provenance["body_count_available"]=false
		else:
			var summary:=_part(0x84a0,[int(count)],language);_merge(result,summary);general.source_calls.append(summary);general.text+="\n\n"+str(summary.text)
			result.provenance["body_count_available"]=true
		var description:=_part(int(selected.long_code),[],language);_merge(result,description);general.source_calls.append(description)
		general.text+="\n\n"+str(description.text)
	else:
		var unknown:=_part(0x84b3,[],language);_merge(result,unknown);general.source_calls.append(unknown);general.text+="\n\n"+str(unknown.text)
	result.pages.append(general)
	if effective_known:
		var demographic:={"id":"demography","title":Text.ui("demography",language),"source_action_id":250,"text":"","source_calls":demographic_calls(system_id,selected,language)}
		for call:Dictionary in demographic.source_calls:_merge(result,call);demographic.text+=("\n\n" if not demographic.text.is_empty() else "")+str(call.text)
		result.pages.append(demographic)
		var groups:=trade_groups(selected,language);_merge(result,groups)
		var trade:={"id":"trade","title":Text.ui("trade",language),"source_action_id":249,"text":"","groups":groups,"source_calls":groups.calls}
		for key:String in ["major_imports","minor_imports","major_exports","minor_exports","illegal_goods"]:
			var names:=PackedStringArray()
			for entry:Dictionary in groups[key]:names.append(str(entry.text))
			trade.text+=("\n\n" if not trade.text.is_empty() else "")+Text.ui(key,language)+":\n"+("\n".join(names) if not names.is_empty() else Text.ui("no_entries",language))
		result.pages.append(trade)
	return result

static func unsigned_packed_integer(packed:int)->int:
	# Exact F1494 logical SHR, not the signed F1491 helper used elsewhere.
	var exponent:=Math.s16(packed>>16);var mantissa:=Math.s16(packed)&MASK
	if exponent<=15:return mantissa>>((15-exponent)&31)
	if exponent<=32:return (mantissa<<((exponent-15)&31))&MASK
	return MASK

static func body_source_calls(body:Dictionary,records:Dictionary={},language:="en")->Dictionary:
	var result:={"ok":true,"calls":[],"unsupported_codes":[],"error":"","values":{}}
	var raw:=_record(body);var index:=int(body.get("original_index",0))
	if raw.size()!=68 or index<1 or index>61:result.ok=false;result.error="Original body record or F843 action is unavailable.";return result
	var type:=int(raw.decode_u16(10));var variables:Array=[0,0,0,0,0]
	if type>34:result.ok=false;result.unsupported_codes.append(0x2000000|type);result.error="This object has no original F843 selectable body card.";return result
	if type>0 and type<32:
		variables[0]=int(raw.decode_u16(36))-273
		variables[1]=(Math.fixed_multiply(unsigned_packed_integer(Math.shift(int(raw.decode_u32(0)),-63)),0xab5a)&MASK)>>2
		result.calls.append(_part(0x84a1,variables,language))
		var ports:="";var next:=index+1
		while records.has(next):
			var port:Dictionary=records[next];var port_raw:=_record(port)
			if port_raw.size()!=68 or port_raw.decode_u16(10)!=35 or port_raw.decode_u32(0)==0:break
			if not ports.is_empty():ports+=str(Text.render_label(7099,[],{},language).text)
			ports+=_name(port,port_raw,language);next+=1
		if ports.is_empty():ports=str(Text.render_code(0x84a7,[],{},language).text)
		result.calls.append({"ok":true,"code":MASK,"variables":[0,0,0,0,0],"text":ports,"raw_bytes":Text._string_bytes(ports,language),"unsupported_codes":[],"error":""})
	if raw.decode_u32(20)!=0:
		var exponent:=Math.s16(int(raw.decode_u32(20))>>16)
		var unit:=0x84a6 if exponent>27 else (0x84a5 if exponent>19 else 0x84a4)
		var factor:=0xffeb551f if exponent>27 else (0xfff06117 if exponent>19 else 0xfff548d1)
		variables[1]=unsigned_packed_integer(Math.multiply(int(raw.decode_u32(20)),factor))
		result.calls.append(_part(unit,variables,language))
		variables[0]=unsigned_packed_integer(Math.multiply(0xffdb759a,int(raw.decode_u32(14))))
		variables[1]=int(raw.decode_u16(32));variables[2]=(int(raw.decode_u16(34))*3600)>>16;variables[3]=int(raw.decode_u32(4))
		var parent:=int(raw.decode_u16(8));var parent_type:=0 if parent==0 else -1
		if records.has(parent):
			var parent_raw:=_record(records[parent])
			if parent_raw.size()==68:parent_type=int(parent_raw.decode_u16(10))
		if parent_type<0:
			result.ok=false;result.unsupported_codes.append(0x200ffff);result.error="Original parent record is required to choose the co-orbital page."
		else:
			var coorbital:=parent_type==0 and parent>index-3
			if coorbital:variables[0]=(int(variables[0])<<1)&MASK
			result.values["coorbital"]=coorbital
			result.calls.append(_part(0x84a3 if coorbital else 0x84a2,variables,language))
	var title:=_name(body,raw,language)+str(Text.render_label(7100,[],{},language).text)
	var type_text:=_part(0x8476+type,variables,language);_merge(result,type_text);title+=str(type_text.text)
	result.calls.append({"ok":true,"code":MASK,"variables":[0,0,0,0,0],"text":title,"raw_bytes":Text._string_bytes(title,language),"unsupported_codes":[],"error":""})
	result["title"]=title
	for call:Dictionary in result.calls:_merge(result,call)
	return result

static func _name(body:Dictionary,raw:PackedByteArray,language:String)->String:
	if language=="ru":return str(body.get("name",body.get("name_en","")))
	var bytes:=raw.slice(38);var zero:=bytes.find(0)
	if zero>=0:bytes=bytes.slice(0,zero)
	return Text._bytes_to_string(bytes)

static func body_page(system_id:int,body:Dictionary,settlements:Array=[],language:String="ru")->Dictionary:
	var result:={"ok":false,"id":"body_"+str(body.get("id",body.get("original_index",""))),"title":Text.ui("body",language),"source_action_id":-1,"text":"","unsupported_codes":[],"error":"","provenance":{}}
	var selected:=policy(system_id)
	if selected.is_empty() or not language in ["ru","en"]:result.error="Original system-information data or system identifier is invalid.";return result
	result.provenance=_base_provenance(system_id,selected,int(selected.population_raw)!=0)
	if int(selected.population_raw)==0:result.error="Original F842 does not provide planetary information for this system.";return result
	var raw:=_record(body)
	if raw.size()!=68:result.error="Original runtime body record is missing.";return result
	var type:=int(raw.decode_u16(10))
	var records:=_context(system_id)
	# Only consume cached context if this exact source record still belongs to it.
	var index:=int(body.get("original_index",0))
	if not records.has(index) or _record(records[index])!=raw:records={}
	for row:Variant in settlements:
		if row is Dictionary and _record(row).size()==68:records[int(row.get("original_index",0))]=row.duplicate(true)
	if type==35:
		result.ok=true;result.title=_name(body,raw,language);result.text=result.title+"\n"+Text.ui("ground_port",language)
		var parent:=int(raw.decode_u16(8))
		if records.has(parent):result.text+="\n"+Text.ui("parent",language)+": "+_name(records[parent],_record(records[parent]),language)
		result.unsupported_codes=[0x2000023];result.provenance["adapter"]="ground_port_parent_listing_no_original_standalone_F843_action"
		return result
	var calls:=body_source_calls(body,records,language);_merge(result,calls);result.ok=bool(calls.ok)
	result.source_action_id=0x80+index-1 if index>=1 and index<=61 else -1
	result["source_calls"]=calls.calls;result.title=str(calls.get("title",result.title));result.text=result.title
	# Preserve source call order in diagnostics; semantic UI pairs the period
	# value with its label instead of claiming original320px pixel placement.
	if type>0 and type<32 and calls.calls.size()>=3:
		result.text+="\n\n"+str(calls.calls[0].text)+": "+str(calls.calls[1].text)
	if raw.decode_u32(20)!=0 and calls.calls.size()>=3:
		var orbital:Dictionary=calls.calls[calls.calls.size()-2]
		var unit:Dictionary=calls.calls[calls.calls.size()-3]
		var lines:=str(orbital.text).split("\n",true,1)
		result.text+="\n\n"+str(lines[0])+": "+str(unit.text)
		if lines.size()>1:result.text+="\n"+str(lines[1])
	return result
