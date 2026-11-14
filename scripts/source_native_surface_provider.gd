extends RefCounted
# A bounded, immutable set of explicit observer-owned source leaves. The
# literal Float32 render triangle is the height provider. Original integer
# F1876/F575 remains a separate, witnessed law; no universal mesh is claimed.
const Native=preload("res://scripts/source_natural_contact.gd")
const Point=preload("res://scripts/source_terrain_point.gd")
const Frame=preload("res://scripts/source_terrain_query_frame.gd")
const Geometry=preload("res://scripts/source_native_contact_geometry.gd")
const Trace=preload("res://scripts/source_terrain_query_trace.gd")
const Field=preload("res://scripts/source_terrain_contact_field.gd")
const Phone=preload("res://scripts/source_surface_contact_bridge.gd")
const Ground=preload("res://scripts/source_ground_surface.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const CONTRACT:="source-native-explicit-leaf-surface-provider-v1"
const MAX_LEAVES:=3
const MAX_SNAPSHOT_BYTES:=524288
const MAX_NODES:=16384
var _ready:=false
var _entries:Array=[]
var _active:=-1
var _binding:Dictionary={}
var _snapshot:Dictionary={}
var _kind:=""
var _model:=-1
var _uid:=0
var _root:Dictionary={}

static func _failure(reason:String)->Dictionary:return {"ok":false,"reason":reason,"provider":null,"source_contract":CONTRACT,"ordinary_terrain_fallback":false}
static func _sha(value:Dictionary)->String:return JSON.stringify(value,"",true).sha256_text()
static func _hex_digits(value:String)->bool:
	# Godot's numeric parser accepts a leading sign; byte codecs must not.
	for index in range(value.length()):
		var code:=value.unicode_at(index)
		if not ((code>=48 and code<=57) or (code>=97 and code<=102)):return false
	return true
static func _hex64(value:int)->String:
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_s64(0,value);return bytes.hex_encode()
static func _float_hex(value:float)->String:
	var bytes:=PackedByteArray();bytes.resize(8);bytes.encode_double(0,value);return bytes.hex_encode()
static func _encode(value:Variant)->Variant:
	if value is Dictionary:
		var data:Dictionary={}
		for key:Variant in value:data[str(key)]=_encode(value[key])
		return {"t":"dict","v":data}
	if value is Array:
		var data:Array=[]
		for item:Variant in value:data.append(_encode(item))
		return {"t":"array","v":data}
	if value is PackedByteArray:return {"t":"bytes","v":value.hex_encode()}
	if value is PackedInt64Array:
		var bytes:=PackedByteArray();bytes.resize(value.size()*8)
		for index in range(value.size()):bytes.encode_s64(index*8,value[index])
		return {"t":"i64array","v":bytes.hex_encode()}
	if value is PackedFloat64Array:return {"t":"f64array","v":Geometry._hex64(value)}
	if value is int:return {"t":"i64","v":_hex64(value)}
	if value is float:return {"t":"f64","v":_float_hex(value)}
	return value
static func _decode(value:Variant,budget:Dictionary,depth:int=0)->Dictionary:
	budget.nodes+=1
	if depth>24 or int(budget.nodes)>MAX_NODES:return {"ok":false}
	if value==null or value is bool or value is String:return {"ok":true,"value":value}
	if not value is Dictionary or value.size()!=2 or not value.get("t") is String or not value.has("v"):return {"ok":false}
	var tag:=str(value.t);var data:Variant=value.v
	if tag=="dict":
		if not data is Dictionary:return {"ok":false}
		var result:Dictionary={}
		for key:Variant in data:
			if not key is String:return {"ok":false}
			var child:=_decode(data[key],budget,depth+1)
			if not child.get("ok",false):return child
			result[key]=child.value
		return {"ok":true,"value":result}
	if tag=="array":
		if not data is Array:return {"ok":false}
		var result:Array=[]
		for item:Variant in data:
			var child:=_decode(item,budget,depth+1)
			if not child.get("ok",false):return child
			result.append(child.value)
		return {"ok":true,"value":result}
	if not data is String or data.length()>MAX_SNAPSHOT_BYTES or data.length()%2!=0 or not _hex_digits(data):return {"ok":false}
	var bytes:=str(data).hex_decode()
	if tag=="bytes":return {"ok":true,"value":bytes}
	if tag=="i64" or tag=="f64":
		if bytes.size()!=8:return {"ok":false}
		if tag=="i64":return {"ok":true,"value":bytes.decode_s64(0)}
		var number:=bytes.decode_double(0)
		return {"ok":is_finite(number),"value":number}
	if (tag!="i64array" and tag!="f64array") or bytes.size()%8!=0:return {"ok":false}
	var result:Variant=PackedInt64Array() if tag=="i64array" else PackedFloat64Array()
	for offset in range(0,bytes.size(),8):
		if tag=="i64array":result.append(bytes.decode_s64(offset))
		else:
			var number:=bytes.decode_double(offset)
			if not is_finite(number):return {"ok":false}
			result.append(number)
	return {"ok":true,"value":result}
static func _valid_binding(value:Dictionary)->bool:
	return value.size()==3 and Native._whole(value.get("generation"),0,0x7fffffff) and value.get("request_token") is String and not str(value.request_token).is_empty() and str(value.request_token).length()<=256 and value.get("request_sha256") is String and str(value.request_sha256).length()==64 and _hex_digits(str(value.request_sha256))
static func _vector(hex:String)->PackedInt64Array:
	if hex.length()!=48 or not _hex_digits(hex):return PackedInt64Array()
	var bytes:=hex.hex_decode()
	return PackedInt64Array([bytes.decode_s64(0),bytes.decode_s64(8),bytes.decode_s64(16)]) if bytes.size()==24 else PackedInt64Array()
static func _point_local(raw:PackedInt64Array,phone:Dictionary)->PackedFloat64Array:
	var values:=PackedFloat64Array()
	for component:int in raw:values.append(float(component)*Phone.Units.METRES_PER_RAW)
	var local:=Geometry._linear(phone.inverse.rows,values);local[1]-=float(phone.radius)
	return local
static func _volume_operands(body:PackedByteArray,relative:PackedInt64Array,ship:Dictionary,index:int)->Dictionary:
	# Consistency of captured caller operands only: no classifier, query,
	# source-global write or response is run a second time.
	if index==0:return {"relative":relative.duplicate(),"threshold":Native._s32(body.decode_u32(0x140))}
	if body[0x14c]<128 or index>ship.children.size():return {}
	var child:Dictionary=ship.children[index-1];var encoded:=int(child.axis_radius_encoded_s16);var row:int=(encoded&6)/2;var shift:=Native._s32(23-int(ship.descriptor.decode_s32(0x14)));var threshold:=Native._s32((encoded&0xfff8)<<15);var point:=PackedInt64Array()
	if shift!=0:threshold>>=shift&31
	for axis in range(3):
		var component:=body.decode_s32((row*3+axis)*4)
		if encoded&1:component=Native._s32(-component)
		component=Native._s32((component>>16)*int(child.displacement_s16))
		if shift!=0:component>>=shift&31
		point.append(Native._add64(relative[axis],component))
	return {"relative":point,"threshold":threshold}
static func _check_volume(body:PackedByteArray,parent:PackedByteArray,relative:PackedInt64Array,ship:Dictionary,model:Dictionary,index:int,iteration:Dictionary)->bool:
	var operands:=_volume_operands(body,relative,ship,index)
	if operands.is_empty() or _vector(str(iteration.get("relative_before_hex","")))!=operands.relative or int(iteration.get("threshold_before_s32",-1))!=int(operands.threshold):return false
	var scale:=maxi(0,Gravity._vec64_msb(operands.relative)-28);var observer:=PackedInt64Array()
	for value:int in operands.relative:observer.append(Point._s32(Point.shift_int64(value,-scale)))
	var minimum:=int(model.mesh_zoom)-23
	if scale<minimum:
		for axis in range(3):observer[axis]>>=(minimum-scale)&31
		scale=minimum
	var threshold:=int(operands.threshold)>>scale
	if int(iteration.get("vector_scale_s32",-1))!=scale or iteration.get("observer_model_local_raw")!=observer or int(iteration.get("threshold_s32",-1))!=threshold:return false
	var distance:=Point.source_length(observer);var outer:=Native._s32(Point.shift_int64(parent.decode_s64(0x138),-scale));var inner:=Native._s32(Point.shift_int64(parent.decode_s64(0x140),-scale))
	if Native._s32(distance-outer)>=threshold or Native._s32(distance-inner)<=threshold:return false
	var expected_return:=0 if (threshold>>16)>int(iteration.get("query_result_raw",2147483647)) else -1
	return int(iteration.get("f579_return_s32",9))==expected_return

# Exact expansion arithmetic for orient2d on a deliberately bounded dyadic
# domain. All supplied F32 vertices and F64 footprint coordinates are exact
# binary values; no selected geometric epsilon or rounded sign is used.
static func _two_sum(a:float,b:float)->PackedFloat64Array:
	var x:=a+b;var bv:=x-a;var av:=x-bv;return PackedFloat64Array([(a-av)+(b-bv),x])
static func _two_diff(a:float,b:float)->PackedFloat64Array:
	var x:=a-b;var bv:=a-x;var av:=x+bv;return PackedFloat64Array([(a-av)+(bv-b),x])
static func _two_product(a:float,b:float)->PackedFloat64Array:
	var x:=a*b;var ca:=134217729.0*a;var abig:=ca-a;var ahi:=ca-abig;var alo:=a-ahi;var cb:=134217729.0*b;var bbig:=cb-b;var bhi:=cb-bbig;var blo:=b-bhi
	var err1:=x-ahi*bhi;var err2:=err1-alo*bhi;var err3:=err2-ahi*blo
	return PackedFloat64Array([alo*blo-err3,x])
static func _grow(expansion:PackedFloat64Array,value:float)->PackedFloat64Array:
	var result:=PackedFloat64Array();var q:=value
	for component:float in expansion:
		var pair:=_two_sum(q,component)
		if pair[0]!=0:result.append(pair[0])
		q=pair[1]
	if q!=0:result.append(q)
	return result
static func _product(a:PackedFloat64Array,b:PackedFloat64Array)->PackedFloat64Array:
	var result:=PackedFloat64Array()
	for first:float in a:
		for second:float in b:
			var pair:=_two_product(first,second);result=_grow(_grow(result,pair[0]),pair[1])
	return result
static func _orient(ax:float,az:float,bx:float,bz:float,px:float,pz:float)->Dictionary:
	for value:float in [ax,az,bx,bz,px,pz]:
		if not is_finite(value) or absf(value)>pow(2.0,100) or (value!=0 and absf(value)<pow(2.0,-200)):return {"ok":false,"reason":"exact_orientation_domain"}
	var first:=_product(_two_diff(ax,px),_two_diff(bz,pz));var second:=_product(_two_diff(az,pz),_two_diff(bx,px));var result:=first
	for component:float in second:result=_grow(result,-component)
	return {"ok":true,"sign":0 if result.is_empty() else (1 if result[-1]>0 else -1),"expansion":result}
static func _orient_interval(ax:float,az:float,bx:float,bz:float,px:float,pz:float)->PackedFloat64Array:
	return Geometry._sub(Geometry._mul(Geometry._sub(Geometry._i(ax),Geometry._i(px)),Geometry._sub(Geometry._i(bz),Geometry._i(pz))),Geometry._mul(Geometry._sub(Geometry._i(az),Geometry._i(pz)),Geometry._sub(Geometry._i(bx),Geometry._i(px))))
static func _ratio(vertices:PackedFloat64Array,x:float,z:float)->Dictionary:
	var numerator:=PackedFloat64Array()
	for index in range(3):
		var b:=(index+1)%3;var c:=(index+2)%3;var oriented:=_orient(vertices[b*3],vertices[b*3+2],vertices[c*3],vertices[c*3+2],x,z)
		var term:=_product(oriented.expansion,PackedFloat64Array([vertices[index*3+1]]))
		for component:float in term:numerator=_grow(numerator,component)
	return {"numerator":numerator,"denominator":_orient(vertices[0],vertices[2],vertices[3],vertices[5],vertices[6],vertices[8]).expansion}
static func _height_order(first:PackedFloat64Array,second:PackedFloat64Array,x:float,z:float)->Dictionary:
	# A comparison contains products of degree five. Narrower bounds keep
	# every error-free product/residual normal and finite, including cancellation.
	var values:=PackedFloat64Array([x,z]);values.append_array(first);values.append_array(second)
	for value:float in values:
		if not is_finite(value) or absf(value)>pow(2.0,80) or (value!=0 and absf(value)<pow(2.0,-80)):return {"ok":false}
	var a:=_ratio(first,x,z);var b:=_ratio(second,x,z)
	if a.denominator.is_empty() or b.denominator.is_empty():return {"ok":false}
	var difference:=_product(a.numerator,b.denominator);var subtrahend:=_product(b.numerator,a.denominator)
	for component:float in subtrahend:difference=_grow(difference,-component)
	var sign:=0 if difference.is_empty() else (1 if difference[-1]>0 else -1)
	if a.denominator[-1]<0:sign=-sign
	if b.denominator[-1]<0:sign=-sign
	return {"ok":true,"sign":sign}
static func _coverage(vertices:PackedFloat64Array,x:float,z:float)->Dictionary:
	if vertices.size()!=9:return {}
	var area:=_orient(vertices[0],vertices[2],vertices[3],vertices[5],vertices[6],vertices[8])
	if not area.get("ok",false) or int(area.sign)==0:return {}
	var denominator:=_orient_interval(vertices[0],vertices[2],vertices[3],vertices[5],vertices[6],vertices[8])
	if not Geometry._valid_interval(denominator) or (denominator[0]<=0 and denominator[1]>=0):return {}
	var weights:Array=[];var ordinary:=PackedFloat64Array()
	for index in range(3):
		var b:=(index+1)%3;var c:=(index+2)%3;var side:=_orient(vertices[b*3],vertices[b*3+2],vertices[c*3],vertices[c*3+2],x,z)
		if not side.get("ok",false) or (int(side.sign)!=0 and int(side.sign)!=int(area.sign)):return {}
		var numerator:=Geometry._i(0.0) if int(side.sign)==0 else _orient_interval(vertices[b*3],vertices[b*3+2],vertices[c*3],vertices[c*3+2],x,z)
		var weight:=Geometry._div(numerator,denominator)
		if not Geometry._valid_interval(weight):return {}
		weight[0]=maxf(0.0,weight[0]);weight[1]=minf(1.0,weight[1])
		if not Geometry._valid_interval(weight):return {}
		weights.append(weight)
		ordinary.append((vertices[b*3]-x)*(vertices[c*3+2]-z)-(vertices[b*3+2]-z)*(vertices[c*3]-x))
	var det:=(vertices[0]-vertices[6])*(vertices[5]-vertices[8])-(vertices[2]-vertices[8])*(vertices[3]-vertices[6])
	if not is_finite(det) or det==0:return {}
	var height:=0.0;var enclosure:=Geometry._i(0.0)
	for index in range(3):height+=ordinary[index]/det*vertices[index*3+1];enclosure=Geometry._add(enclosure,Geometry._mul(weights[index],Geometry._i(vertices[index*3+1])))
	if not Geometry._valid_interval(enclosure) or not is_finite(height) or height<enclosure[0] or height>enclosure[1]:return {}
	var ab:=Vector3(vertices[3]-vertices[0],vertices[4]-vertices[1],vertices[5]-vertices[2]);var ac:=Vector3(vertices[6]-vertices[0],vertices[7]-vertices[1],vertices[8]-vertices[2]);var normal:=ab.cross(ac).normalized()
	if not normal.is_finite() or normal==Vector3.ZERO:return {}
	if normal.y<0:normal=-normal
	return {"height":height,"height_interval":enclosure,"normal":normal,"coverage_exact":true,"coverage_policy":"exact-bounded-binary-expansion-orient2d-and-outward-height-interval-v1","native_integer_height_equivalence":false}
static func _entry(child:int,frame:Dictionary,row:Dictionary,phone_frame:Dictionary,local:PackedFloat64Array)->Dictionary:
	var built:=Geometry.build(frame,row,phone_frame)
	if not built.get("ok",false):return {"ok":false,"reason":str(built.get("reason","leaf_packet_unavailable"))}
	if built.certificate.native_query_capped:return {"ok":false,"reason":"capped_native_query"}
	var bytes:=str(built.packet.local_vertices_f32_hex).hex_decode();var vertices:=PackedFloat64Array()
	if bytes.size()!=36:return {"ok":false,"reason":"invalid_native_render_vertex_bytes"}
	for index in range(9):vertices.append(bytes.decode_float(index*4))
	var hit:=_coverage(vertices,local[0],local[2])
	if hit.is_empty():return {"ok":false,"reason":"actual_footprint_outside_own_literal_leaf"}
	return {"ok":true,"child_id":child,"frame":frame.duplicate(true),"trace_row":row.duplicate(true),"packet":built.packet.duplicate(true),"certificate":built.certificate.duplicate(true),"vertices":vertices,"probe_local":local.duplicate(),"probe_height":hit}
static func _finish(entries:Array,active:int,kind:String,model:int,uid:int,binding:Dictionary,witness:Dictionary,root:Dictionary={})->Dictionary:
	if entries.is_empty() or entries.size()>MAX_LEAVES:return _failure("native_leaf_budget")
	var provider:=new();provider._entries=entries.duplicate(true);provider._active=active;provider._kind=kind;provider._model=model;provider._uid=uid;provider._binding=binding.duplicate(true);provider._root=root.duplicate(true)
	var encoded:Variant=_encode(witness);var snapshot:={"schema":1.0,"source_contract":CONTRACT,"kind":kind,"source_witness":encoded,"witness_sha256":_sha({"witness":encoded})};snapshot["snapshot_sha256"]=_sha(snapshot)
	if JSON.stringify(snapshot).length()>MAX_SNAPSHOT_BYTES:return _failure("native_snapshot_budget")
	provider._snapshot=snapshot;provider._ready=true
	return {"ok":true,"reason":"explicit_native_leaves_staged","provider":provider,"snapshot_sha256":provider.snapshot_identity(),"ordinary_terrain_fallback":false}

static func stage_from_classification(body:PackedByteArray,parent:PackedByteArray,relative:PackedInt64Array,classified:Dictionary,trace_rows:Array,phone_frame:Dictionary,binding:Dictionary,phase:String="session_f576_stage")->Dictionary:
	if phase not in ["session_f576_stage","post_response_render_only","airborne_render_only"]:return _failure("invalid_native_provider_phase")
	if not _valid_binding(binding):return _failure("invalid_request_binding")
	var phone:=Geometry._phone(phone_frame)
	if phone.is_empty() or body.size()!=338 or parent.size()!=338 or relative.size()!=3:return _failure("invalid_raw_actor_or_phone_frame")
	if int(phone.model)<118 or int(phone.model)>133:return _failure("unsupported_native_trial_model")
	if body[0x56]!=parent[0x86] or body[0x57]==0 or int(body[0x56])!=int(phone.body_parent_index) or int(body[0x57])!=int(phone.body_frame) or int(parent[0x86])!=int(phone.parent_index) or parent.slice(0,36).hex_encode()!=phone.parent_matrix_hex:return _failure("unsupported_source_parent_frame")
	var ship:=Native.ship_model(body.decode_u32(0x82));var model:=Native.parent_model(int(phone.model))
	if int(parent.decode_u32(0x82))!=int(phone.model) or int(parent.decode_u32(0xa0))!=int(phone.uid) or ship.is_empty() or model.is_empty():return _failure("mismatched_raw_source_identity")
	var position:=PackedInt64Array()
	for axis in range(3):position.append(body.decode_s64(0x3e+axis*8))
	if position!=relative:return _failure("primary_relative_is_not_raw_body_position")
	if classified.get("ok")!=true or classified.get("source_contract")!=Native.CONTRACT or classified.get("body_after")!=body or classified.get("parent_after")!=parent or classified.get("relative_position_s64")!=relative or not classified.get("iterations") is Array or not classified.get("query_trace") is Array:return _failure("mismatched_actual_classification")
	if not Native._whole(classified.get("terrain_query_calls"),0,MAX_LEAVES) or not Native._whole(classified.get("f576_return_s32"),-1,0):return _failure("invalid_actual_classification_words")
	var iterations:Array=classified.iterations
	if iterations.is_empty() or iterations.size()>MAX_LEAVES or trace_rows.size()!=iterations.size() or int(classified.get("terrain_query_calls",-1))!=iterations.size() or classified.query_trace.size()!=iterations.size():return _failure("coarse_or_incomplete_native_volume_walk")
	var entries:Array=[]
	for index in range(iterations.size()):
		if not iterations[index] is Dictionary or not trace_rows[index] is Dictionary:return _failure("invalid_native_volume_record")
		var iteration:Dictionary=iterations[index]
		for key:String in ["child_index","terrain_query_calls","threshold_before_s32","threshold_s32","vector_scale_s32","query_result_raw","query_limit_raw","query_style_raw","f579_return_s32"]:
			if not Native._whole(iteration.get(key),-2147483648,2147483647):return _failure("invalid_actual_volume_word")
		if int(iteration.get("child_index",-1))!=index or iteration.get("branch")!="terrain_query" or int(iteration.get("terrain_query_calls",0))!=1 or iteration.get("parent_transpose_applied")!=false:return _failure("coarse_or_unmapped_native_volume")
		if int(iteration.get("query_result_raw",2147483647))>=int(iteration.get("query_limit_raw",0)):return _failure("capped_native_volume")
		if not _check_volume(body,parent,relative,ship,model,index,iteration):return _failure("captured_native_volume_operands_or_bounds_mismatch")
		if index<iterations.size()-1 and int(iteration.f579_return_s32)>=0:return _failure("source_walk_continued_after_contact")
		var observer:Variant=iteration.get("observer_model_local_raw")
		if not observer is PackedInt64Array:return _failure("invalid_actual_observer")
		var frame:=Frame.build(int(phone.model),observer,int(iteration.get("vector_scale_s32",-1)))
		if not frame.get("ok",false):return _failure(str(frame.get("reason","native_frame_unavailable")))
		if iteration.get("query_matrix_raw")!=frame.query_matrix_raw or iteration.get("query_center_raw")!=frame.query_center_raw:return _failure("actual_classification_frame_mismatch")
		var source_row:Dictionary=trace_rows[index]
		if not source_row.get("result") is Dictionary:return _failure("missing_actual_source_query_result")
		for pair:Array in [["query_result_raw","query_result_raw"],["recorded_intersection_raw","recorded_intersection_raw"],["pending_query_flag","pending_query_flag"]]:
			if iteration.get(pair[0])!=source_row.result.get(pair[1]):return _failure("actual_iteration_query_result_mismatch")
		if iteration.get("query_limit_raw")!=source_row.get("query_limit_s32") or iteration.get("query_style_raw")!=source_row.get("style_s32"):return _failure("actual_iteration_query_operands_mismatch")
		var raw:=_vector(str(iteration.get("relative_before_hex","")))
		if raw.size()!=3:return _failure("invalid_actual_footprint_raw")
		for component:int in raw:
			if component<(-Frame.MAX_EXACT_PHONE_RAW) or component>Frame.MAX_EXACT_PHONE_RAW:return _failure("actual_footprint_phone_precision_domain")
		var entry:=_entry(index,frame,trace_rows[index],phone_frame,_point_local(raw,phone))
		if not entry.get("ok",false):return _failure(str(entry.get("reason","native_leaf_unavailable")))
		entries.append(entry)
	var hit:=int(classified.get("f576_return_s32",-1))==0
	if hit!=(int(iterations[-1].f579_return_s32)==0):return _failure("source_walk_return_mismatch")
	if not hit and body[0x14c]>=128 and iterations.size()!=ship.children.size()+1:return _failure("source_walk_missing_actual_child")
	var active:=int(iterations[-1].child_index) if int(classified.get("f576_return_s32",-1))==0 else 0
	var witness:={"body":body.duplicate(),"parent":parent.duplicate(),"relative":relative.duplicate(),"classification":classified.duplicate(true),"trace_rows":trace_rows.duplicate(true),"phone_frame":phone_frame.duplicate(true),"binding":binding.duplicate(true),"phase":phase}
	return _finish(entries,active,"actual_f576_visited_leaves" if phase=="session_f576_stage" else phase,phone.model,phone.uid,binding,witness)

static func prepare_root(record:PackedByteArray,phone_frame:Dictionary,direction:PackedInt64Array,binding:Dictionary)->Dictionary:
	if not _valid_binding(binding):return _failure("invalid_request_binding")
	var phone:=Geometry._phone(phone_frame)
	if phone.is_empty() or record.size()!=68 or record.decode_u16(12)!=int(phone.model) or record.decode_u32(4)!=int(phone.uid) or int(phone.model)<118:return _failure("unsupported_native_root_identity")
	var root:=Field.new().sample_radial(record,direction,1)
	if not root.get("ok",false) or root.get("certified")!=true or root.get("source_bounds",{}).get("terrain_query_eligible")!=true:return _failure("native_root_not_original_terrain_eligible")
	var last:Dictionary=root.query_trace[-1];var observer:=PackedInt64Array()
	# Select the actually returned root sample; an exact zero can finish before
	# a bracket exists, and the adjacent outside point need not be the last call.
	for sample:Dictionary in root.query_trace:
		if sample.position_raw==root.position_raw:last=sample;break
	for component:int in root.position_raw:observer.append(Point._s32(Point.shift_int64(component,-int(last.vector_scale_s32))))
	var frame:=Frame.build(int(phone.model),observer,int(last.vector_scale_s32))
	if not frame.get("ok",false):return _failure(str(frame.get("reason","native_root_frame_unavailable")))
	var tracer:=Trace.new();var query:=tracer.query_raw(phone.uid,int(frame.query_style_raw),frame.query_matrix_raw,frame.query_center_raw,int(frame.query_limit_raw),1,str(frame.features_hex).hex_decode());var rows:=tracer.read_trace()
	if query.is_empty() or rows.size()!=1:return _failure("native_root_leaf_unavailable")
	var entry:=_entry(0,frame,rows[0],phone_frame,_point_local(root.position_raw,phone))
	if not entry.get("ok",false):return _failure(str(entry.get("reason","native_root_render_coverage_unavailable")))
	var anchor:={"position_raw":root.position_raw.duplicate(),"local_point":entry.probe_local.duplicate(),"status":str(root.status),"residual_raw_s64":int(root.residual_raw_s64),"source_bounds":root.source_bounds.duplicate(true),"render_only":true,"actual_ship_collision":false}
	return _finish([entry],0,"render_only_signed_root",phone.model,phone.uid,binding,{"record":record.duplicate(),"phone_frame":phone_frame.duplicate(true),"direction":direction.duplicate(),"binding":binding.duplicate(true)},anchor)

static func from_snapshot(value:Dictionary)->RefCounted:
	if value.size()!=6 or value.get("schema")!=1 or value.get("source_contract")!=CONTRACT or not value.get("kind") is String or not value.get("source_witness") is Dictionary or JSON.stringify(value).length()>MAX_SNAPSHOT_BYTES:return null
	var check:=value.duplicate(true);check.erase("snapshot_sha256")
	if value.get("snapshot_sha256")!=_sha(check) or value.get("witness_sha256")!=_sha({"witness":value.source_witness}):return null
	var decoded:=_decode(value.source_witness,{"nodes":0})
	if not decoded.get("ok",false) or not decoded.get("value") is Dictionary:return null
	var witness:Dictionary=decoded.value;var built:Dictionary={}
	if value.kind in ["actual_f576_visited_leaves","post_response_render_only","airborne_render_only"] and witness.size()==8:
		if not witness.get("body") is PackedByteArray or not witness.get("parent") is PackedByteArray or not witness.get("relative") is PackedInt64Array or not witness.get("classification") is Dictionary or not witness.get("trace_rows") is Array or not witness.get("phone_frame") is Dictionary or not witness.get("binding") is Dictionary or not witness.get("phase") is String:return null
		built=stage_from_classification(witness.body,witness.parent,witness.relative,witness.classification,witness.trace_rows,witness.phone_frame,witness.binding,witness.phase)
	elif value.kind=="render_only_signed_root" and witness.size()==4:
		if not witness.get("record") is PackedByteArray or not witness.get("phone_frame") is Dictionary or not witness.get("direction") is PackedInt64Array or not witness.get("binding") is Dictionary:return null
		built=prepare_root(witness.record,witness.phone_frame,witness.direction,witness.binding)
	else:return null
	if not built.get("ok",false) or built.provider.snapshot()!=value:return null
	return built.provider
static func verify_snapshot(value:Dictionary)->Dictionary:
	var rebuilt:=from_snapshot(value)
	return {"ok":rebuilt!=null,"reason":"native_provider_witness_rebuilt" if rebuilt!=null else "invalid_or_stale_native_provider_snapshot","source_contract":CONTRACT,"classification_reexecuted":false,"native_physics_authorized":false}
func configured()->bool:return _ready
func snapshot()->Dictionary:return _snapshot.duplicate(true)
func snapshot_identity()->String:return str(_snapshot.get("snapshot_sha256","")) if _ready else ""
func generation()->int:return int(_binding.get("generation",-1)) if _ready else -1
func root_anchor()->Dictionary:return _root.duplicate(true)
func height_at(x:float,z:float,child_id:int=-1)->Dictionary:
	if not _ready or not is_finite(x) or not is_finite(z):return {}
	var selected:=child_id;var candidates:Array=[]
	for entry:Dictionary in _entries:
		if selected>=0 and int(entry.child_id)!=selected:continue
		var hit:=_coverage(entry.vertices,x,z)
		if hit.is_empty():continue
		var id:=int(entry.child_id)
		hit["child_id"]=id;hit["triangle_index"]=id;hit["provider"]=CONTRACT;hit["snapshot_sha256"]=snapshot_identity();hit["packet_sha256"]=str(entry.certificate.packet_sha256);hit["native_physics_authorized"]=false;hit["selection_policy"]="own_leaf" if selected>=0 else "uppermost_emitted_triangle_then_lowest_child_id"
		candidates.append({"hit":hit,"vertices":entry.vertices})
	if selected>=0:return candidates[0].hit if not candidates.is_empty() else {}
	var winner:Dictionary={}
	for candidate:Dictionary in candidates:
		var proven:=true
		for other:Dictionary in candidates:
			if candidate.hit.child_id==other.hit.child_id:continue
			var first:PackedFloat64Array=candidate.hit.height_interval;var second:PackedFloat64Array=other.hit.height_interval
			if first[0]>second[1]:continue
			if first[1]<second[0]:proven=false;break
			var order:=_height_order(candidate.vertices,other.vertices,x,z)
			if not order.get("ok",false) or int(order.sign)<0 or (int(order.sign)==0 and int(candidate.hit.child_id)>int(other.hit.child_id)):proven=false;break
		if proven:winner=candidate.hit;break
	return winner
func probe_sample(child_id:int)->Dictionary:
	if not _ready:return {}
	for entry:Dictionary in _entries:
		if int(entry.child_id)==child_id:return {"child_id":child_id,"local_point":entry.probe_local.duplicate(),"height":height_at(entry.probe_local[0],entry.probe_local[2],child_id),"packet":entry.packet.duplicate(true),"certificate":entry.certificate.duplicate(true),"actual_source_classification":_kind!="render_only_signed_root","render_phase":_kind,"native_integer_height_equivalence":false,"native_physics_authorized":false}
	return {}
func render_payload()->Dictionary:
	if not _ready:return {}
	var triangles:Array=[]
	for entry:Dictionary in _entries:
		var vertices:=PackedVector3Array()
		for index in range(3):vertices.append(Vector3(entry.vertices[index*3],entry.vertices[index*3+1],entry.vertices[index*3+2]))
		triangles.append({"child_id":int(entry.child_id),"role":"active" if int(entry.child_id)==_active else "visited_witness","vertices":vertices,"indices":PackedInt32Array([0,1,2]),"packet_sha256":str(entry.certificate.packet_sha256)})
	return {"ok":true,"source_contract":CONTRACT,"snapshot_sha256":snapshot_identity(),"generation":generation(),"request_binding":_binding.duplicate(true),"active_child_id":_active,"source_model_index":_model,"source_uid_u32":_uid,"render_only_root":_kind=="render_only_signed_root","render_only_witness":_kind!="actual_f576_visited_leaves","render_phase":_kind,"triangles":triangles,"generic_height_policy":"uppermost_emitted_triangle_then_lowest_child_id","universal_mesh_identity":false,"native_integer_height_equivalence":false,"native_physics_authorized":false}
