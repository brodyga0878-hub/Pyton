extends RefCounted
# View independent source geometry. Integer vertices use the verified native VM;
# polygon curves use modern tessellation. Source screen-space decorations are
# retained as events, not silently converted to invented solid geometry.
const VM=preload("res://scripts/source_model_vm.gd")
const Vertices=preload("res://scripts/source_model_vertices.gd")
const Polygon=preload("res://scripts/source_polygon.gd")
const IDENTITY:=[2147483647,0,0,0,2147483647,0,0,0,2147483647]
var error:=""
var triangles:Array=[]
var events:Array=[]
var instances:Array=[]
var _seen_triangles:Dictionary={}
var _seen_events:Dictionary={}
var _seen_instances:Dictionary={}
var _steps:=0
var _calls:=0
var _entity:Array=[]
var _options:Dictionary={}
var _minimum:Array=[]
var _maximum:Array=[]
func _fail(reason:String)->bool:
	if error.is_empty():error=reason
	return false
func compile(index:int,context:Dictionary={})->Dictionary:
	error="";triangles.clear();events.clear();instances.clear();_seen_triangles.clear();_seen_events.clear();_seen_instances.clear()
	_steps=0;_calls=0;_minimum=[];_maximum=[];_options=context
	_entity=context.get("entity_variables_u16",[]).duplicate()
	if _entity.is_empty():
		_entity.resize(64);_entity.fill(0)
		var seed:int=int(context.get("source_seed",0))&0xffffffff
		_entity[2]=seed&65535;_entity[3]=(seed>>16)&65535
	var asset:=VM.model(index)
	if asset.is_empty():return {"ok":false,"error":"Model %d is outside the verified source assets"%index}
	var parameters:Array=context.get("frame_parameters",[0,null,null,null,null,null,null,null]).duplicate()
	parameters.resize(8)
	var frame:={"matrix":context.get("matrix_q31",IDENTITY).duplicate(),"parity":0,"scale":int(context.get("scale_shift_raw",int(asset.scale)+int(asset.scale2))),
		"range_scale":0,"origin":[0,0,0],"parameters":parameters,"anchors":context.get("anchors_local_raw",[]),
		"random":context.get("random_state_u32",Vertices.CHOSEN_STATIC_RANDOM_STATE).duplicate(),"colour":context.get("local_colour_rgb4",[1,1,1]).duplicate(),"sort_hint":{"sort_hint_kind":"primitive_depth","sort_depth_hint_raw":0},"aux":[],"aux_parity":0,"path":str(index)}
	_run_model(index,frame,0)
	if not error.is_empty():return {"ok":false,"error":error,"model_index":index}
	return {"ok":true,"model_index":index,"triangles_raw":triangles,"source_events":events,"instances":instances,
		"bounds_raw":{"minimum":_minimum,"maximum":_maximum},"source_scale":int(asset.scale)+int(asset.scale2),
		"profile":"static-near-normal-union-v1","units":"original model integer units; no SI calibration applied",
		"random_state_profile":"explicit-state-snapshot" if context.has("random_state_u32") else "chosen-static-state-v1",
		"initial_random_state_u32":frame.random.duplicate(),"dynamic_effects_profile":"retained-source-events",
		"triangle_count":triangles.size(),"instruction_count":_steps,"instance_count":instances.size()}
func _evaluator(asset:Dictionary,frame:Dictionary)->Object:
	var evaluator:=Vertices.new()
	if not evaluator.configure(str(asset.vertex_hex).hex_decode(),{"matrix_q31":frame.matrix,"scale_shift_raw":frame.scale,
		"frame_parameters":frame.parameters,"entity_variables_u16":_entity,"anchors_local_raw":frame.anchors,"random_state_u32":frame.random}):
		_fail(evaluator.error)
	return evaluator
func _copy_state(state:Dictionary,asset:Dictionary)->Dictionary:
	var copy:Dictionary=state.duplicate(true)
	var original:Object=state.evaluator
	var evaluator:=_evaluator(asset,copy.frame)
	evaluator.cache=original.cache.duplicate(true);evaluator.random_state=original.random_state.duplicate()
	copy.evaluator=evaluator
	return copy
func _point(state:Dictionary,index:int)->Array:
	var point:Array=state.evaluator.point(index)
	if not state.evaluator.error.is_empty():_fail("%s (model %d, next byte %d, vertex %d)"%[state.evaluator.error,state.model_index,state.pc,index]);return []
	var result:Array=[]
	for k in range(3):result.append(VM.s32(int(point[k])+int(state.frame.origin[k])))
	return result
func _local(state:Dictionary,code:int,angle:=false)->Dictionary:
	var parameters:Array=state.frame.parameters
	if code&0xc0==0xc0 and ((code&63)>=parameters.size() or parameters[code&63]==null):
		return {"ok":false,"error":"Read of uninitialized source model local %02x (model %d, next byte %d)"%[code,state.model_index,state.pc]}
	return VM.parameter(code,parameters,_entity,angle)
func _event(state:Dictionary,command:Dictionary,kind:String,extra:Dictionary={})->void:
	var event:={"kind":kind,"model_index":state.model_index,"offset":command.offset,"word":command.word,
		"words":command.words.duplicate(),"origin_raw":state.frame.origin.duplicate(),"matrix_q31":state.frame.matrix.duplicate(),
		"scale_shift_raw":state.frame.scale,"instance_path":state.frame.path,"local_colour_rgb4":state.frame.colour.duplicate()}
	event.merge(extra,true)
	if event.has("material_code"):event.material_base=VM.material_base(int(event.material_code),state.frame.colour)
	var key:=JSON.stringify(event)
	if not _seen_events.has(key):_seen_events[key]=true;events.append(event)
func _triangle(points:Array,material:int,state:Dictionary,command:Dictionary,normal_override:=Vector3.ZERO)->void:
	if points.size()!=3:return
	var a:=Vector3(points[0][0],points[0][1],points[0][2]);var b:=Vector3(points[1][0],points[1][1],points[1][2]);var c:=Vector3(points[2][0],points[2][1],points[2][2])
	if (b-a).cross(c-a).length_squared()==0:return
	var keys:Array=[]
	for point in points:keys.append(JSON.stringify(point))
	keys.sort()
	var material_base:=VM.material_base(material,state.frame.colour)
	var key:="%d:"%material+JSON.stringify(material_base)+":".join(keys)
	if _seen_triangles.has(key):return
	_seen_triangles[key]=true
	var triangle:={"vertices":points,"material_code":material,"model_index":state.model_index,"offset":command.offset,
		"instance_path":state.frame.path,"default_rgb":state.asset.default_rgb,"local_colour_rgb4":state.frame.colour.duplicate(),"material_base":material_base}
	triangle.merge(state.frame.get("sort_hint",{"sort_hint_kind":"unresolved","sort_depth_hint_raw":0}),true)
	triangle.sort_hint_scope="frame_local_render_adaptation"
	var normal:Vector3=normal_override
	if normal.length_squared()==0 and int(command.opcode)==5:normal=_normal(state,int(command.words[2])&255)
	if normal.length_squared()>0:triangle.normal_raw=[normal.x,normal.y,normal.z]
	triangles.append(triangle)
	for point in points:
		if _minimum.is_empty():_minimum=point.duplicate();_maximum=point.duplicate()
		for k in range(3):_minimum[k]=mini(int(_minimum[k]),int(point[k]));_maximum[k]=maxi(int(_maximum[k]),int(point[k]))
func _face(state:Dictionary,command:Dictionary,indices:Array,mirrored:=false)->void:
	var points:Array=[]
	for index in indices:
		points.append(_point(state,int(index)^(1 if mirrored else 0)))
		if not error.is_empty():return
	if mirrored:points.reverse()
	var normal_index:int=int(command.words[3])&255 if int(command.opcode) in [3,7] else int(command.words[4])&255
	var normal:=_normal(state,normal_index^(1 if mirrored else 0))
	for i in range(1,points.size()-1):_triangle([points[0],points[i],points[i+1]],int(command.words[1]),state,command,normal)
func _run_model(index:int,frame:Dictionary,depth:int)->void:
	if not error.is_empty():return
	var instance_key:=JSON.stringify(frame)
	if _seen_instances.has(instance_key):return
	_seen_instances[instance_key]=true
	_calls+=1
	if depth>24 or _calls>16384:_fail("Source model instance budget exceeded");return
	var asset:=VM.model(index)
	if asset.is_empty():_fail("Missing original submodel %d"%index);return
	if frame.scale<0 or frame.scale>30:_fail("Unreviewed source scale exponent %d"%frame.scale);return
	var offsets:={}
	for command in asset.commands:offsets[int(command.offset)]=command
	var evaluator:=_evaluator(asset,frame)
	if not error.is_empty():return
	instances.append({"model_index":index,"path":frame.path,"origin_raw":frame.origin.duplicate(),"matrix_q31":frame.matrix.duplicate(),"scale_shift_raw":frame.scale})
	var pending:Array=[{"pc":0,"frame":frame,"evaluator":evaluator,"model_index":index,"asset":asset}]
	var visited:={}
	while not pending.is_empty() and error.is_empty():
		var state:Dictionary=pending.pop_back()
		while error.is_empty():
			_steps+=1
			if _steps>400000:_fail("Source model command budget exceeded");return
			var signature:=str(state.pc)+JSON.stringify(state.frame.parameters)+JSON.stringify(state.frame.aux)+JSON.stringify(state.frame.colour)+JSON.stringify(state.frame.get("sort_hint",{}))+JSON.stringify(state.evaluator.cache)+JSON.stringify(state.evaluator.random_state)
			if visited.has(signature):break
			visited[signature]=true
			if not offsets.has(state.pc):_fail("Source command offset is not verified: model %d byte %d"%[index,state.pc]);return
			var command:Dictionary=offsets[state.pc];var words:Array=command.words;var op:int=command.opcode
			state.pc=int(command.next_offset)
			match op:
				0:break
				3,7:
					var indices:Array=[int(words[2])>>8,int(words[2])&255,int(words[3])>>8]
					_face(state,command,indices)
					if op==7:_face(state,command,indices,true)
				4,8:
					var indices:Array=[int(words[2])>>8,int(words[3])&255,int(words[2])&255,int(words[3])>>8]
					_face(state,command,indices)
					if op==8:_face(state,command,indices,true)
				5:_polygon(state,command)
				2:
					_event(state,command,"line",{"vertices_raw":[_point(state,int(words[2])>>8),_point(state,int(words[2])&255)],"material_code":words[1]})
				1:
					var radius:=_local(state,int(words[2]),true)
					if not radius.ok:_fail(radius.error);return
					var shift:int=state.frame.scale-8;var value:int=radius.value
					value=VM.s32(value<<(shift&31)) if shift>=0 else (value&0xffffffff)>>((-shift)&31)
					_event(state,command,"ball",{"center_raw":_point(state,int(words[3])>>8),"radius_raw":value,"material_code":words[1],"normal_index":int(words[3])&255})
				11,12:
					if int(words[1])&0x8000:
						# A view independent mesh contains both source normal branches.
						var alternate:=_copy_state(state,asset)
						var next:=VM.branch(true,int(command.word),int(command.next_offset))
						if next.active!=0:alternate.pc=next.offset;pending.append(alternate)
					else:
						# Original F1751 returns false at near detail for positive thresholds.
						var next:=VM.branch(op==12,int(command.word),int(command.next_offset))
						if next.active==0:break
						state.pc=next.offset
				19,20:
					var tested:=_local(state,int(words[1])&255)
					if not tested.ok:_fail(tested.error);return
					var result:=VM.bit_condition(op==20,int(words[1])&255,int(words[1])>>8,state.frame.parameters,_entity)
					var next:=VM.branch(result.value,int(command.word),int(command.next_offset))
					if next.active==0:break
					state.pc=next.offset
				13,29:
					for code in [int(words[1])&255,int(words[1])>>8]:
						var checked:=_local(state,code)
						if not checked.ok:_fail(checked.error);return
					var result:=VM.math(int(command.word),int(words[1])&255,int(words[1])>>8,state.frame.parameters,_entity)
					if not result.ok:_fail(result.error);return
					state.frame.parameters[result.destination]=result.value
				14,27:_submodel(state,command,depth)
				28:_rotate_aux(state,command)
				6,21:_sort_state(state,command)
				10:_event(state,command,"text",{"anchor_raw":_point(state,int(words[3])&255),"normal_index":int(words[2])&255,"source_text_reference":words[4]})
				15:_event(state,command,"sound")
				9:_event(state,command,"thruster")
				17:_cone(state,command)
				22:
					_event(state,command,"spline",{"control_points_raw":[_point(state,int(words[2])>>8),_point(state,int(words[2])&255),_point(state,int(words[3])>>8),_point(state,int(words[3])&255)],"material_code":words[1]})
				24:
					var radius:=_local(state,int(words[2]),true)
					if not radius.ok:_fail(radius.error);return
					var value:int=radius.value;var fixed_screen_size:bool=bool(value&0x8000)
					if fixed_screen_size:value&=0x7fff
					else:
						var shift:int=state.frame.scale-7
						value=VM.s32(value<<(shift&31)) if shift>=0 else (value&0xffffffff)>>((-shift)&31)
					var points:Array=[]
					for pair in range(3,words.size()):
						var vertex:int=int(words[pair])>>8
						if vertex==127:break
						points.append(_point(state,vertex));vertex=int(words[pair])&255
						if vertex==127:break
						points.append(_point(state,vertex))
					_event(state,command,"billboard_array",{"centers_raw":points,"radius_raw":value,"fixed_screen_size":fixed_screen_size,"material_code":words[1]})
				18:_event(state,command,"glowpoint",{"center_raw":_point(state,int(command.word)>>5)})
				26:_colour_state(state,command)
				_:
					_fail("Unsupported original model opcode %d in model %d at byte %d"%[op,index,command.offset]);return
func _submodel(state:Dictionary,command:Dictionary,depth:int)->void:
	var words:Array=command.words;var placement:int=words[1];var child_id:int=command.model_id
	var child:=VM.model(child_id)
	if child.is_empty():_fail("Missing original child model %d"%child_id);return
	var origin:=_point(state,placement&255)
	if not error.is_empty():return
	var source_matrix:Array=state.frame.matrix;var source_parity:int=state.frame.parity
	if (placement>>8)&7==6:
		if state.frame.aux.is_empty():_fail("Source auxiliary matrix was used before initialization");return
		source_matrix=state.frame.aux;source_parity=state.frame.aux_parity
		placement&=~0x3f00
	var rotated:=VM.orientation(source_matrix,source_parity,placement)
	if not rotated.ok:_fail(rotated.error);return
	var extra:=0
	var colour:Array=state.frame.colour.duplicate()
	if int(command.opcode)==27:
		colour=VM.material_base(int(words[3]),state.frame.colour).rgb4_base
		if int(words[2])&0x800:
			var slot:=(int(words[2])>>12)&15
			if slot>=8 or state.frame.parameters[slot]==null:_fail("Uninitialized scaled child parameter");return
			extra=int(state.frame.parameters[slot])
		else:extra=VM.s16(int(words[2]))>>12
	var parameters:Array=[VM.s32(int(state.frame.parameters[0])+1),state.frame.parameters[1],state.frame.parameters[2],null,null,null,null,null]
	var anchors:Array=[[0,0,0]]
	if int(words[1])&0x8000:
		# F1750's external array begins with the child's parent origin, then the
		# third, first, second and fourth supplied parent vertices respectively.
		var a:int=words[words.size()-2];var b:int=words[words.size()-1]
		var external:Array=[b&255,a&255,a>>8,b>>8]
		for i in range(external.size()):
			var vertex:int=external[i]
			# F1750 always resolves c first; only a/b/d use sentinel127.
			if i>0 and vertex==127:break
			var point:=_point(state,vertex)
			if not error.is_empty():return
			anchors.append([VM.s32(int(point[0])-int(origin[0])),VM.s32(int(point[1])-int(origin[1])),VM.s32(int(point[2])-int(origin[2]))])
	var frame:={"matrix":rotated.matrix,"parity":rotated.parity,"scale":VM.s32(extra+int(child.scale)+int(child.scale2)-int(state.frame.range_scale)),
		"range_scale":state.frame.range_scale,"origin":origin,"parameters":parameters,"anchors":anchors,
		"random":state.evaluator.random_state.duplicate(),"colour":colour,"sort_hint":state.frame.get("sort_hint",{"sort_hint_kind":"unresolved","sort_depth_hint_raw":0}).duplicate(),"aux":[],"aux_parity":0,"path":"%s/%d@%d"%[state.frame.path,child_id,command.offset]}
	_run_model(child_id,frame,depth+1)
func _sort_state(state:Dictionary,command:Dictionary)->void:
	_event(state,command,"source_sort_state")
	var word:int=command.word;var payload:=word>>5;var mode:=word>>13
	var hint:={"sort_hint_kind":"unresolved_mode","sort_depth_hint_raw":0,"sort_source_model":state.model_index,"sort_source_offset":command.offset,"sort_command_word":word}
	if int(command.opcode)==21:hint.sort_hint_kind="unresolved_nested_group"
	elif mode==0 or mode in [4,5,6]:hint.sort_hint_kind="primitive_depth"
	elif mode==7:
		if payload<2045:
			hint.sort_hint_kind="forced_forward_offset"
			hint.sort_depth_hint_raw=VM.s32(VM.s16(int(command.words[1]))<<(int(state.frame.scale)&31))
			hint.sort_anchor_vertex=Vertices.s8(payload&255)
		elif payload==2047:hint.sort_hint_kind="model_origin"
		else:hint.sort_hint_kind="unresolved_fixed_key"
	elif mode in [1,2,3]:hint.sort_hint_kind="unresolved_vertex_group"
	state.frame.sort_hint=hint
func _colour_state(state:Dictionary,command:Dictionary)->void:
	var words:Array=command.words;var code:int=words[1];var selector:int=int(words[2])>>8
	if selector:
		var selected:=_local(state,selector)
		if not selected.ok:_fail(selected.error);return
		var slot:int=int(selected.value)&7
		if slot:
			if 2+slot>=words.size():_fail("Source palette selector outside command");return
			code=int(words[2+slot])
	var base:=VM.material_base(code,state.frame.colour)
	var normal:int=int(words[2])&255
	_event(state,command,"source_colour_state",{"selected_material_code":code,"material_base":base,"normal_index":normal,
		"source_normal_lighting_unresolved":not base.unlit and not base.textured})
	if not normal&0x80:state.frame.colour=base.rgb4_base
func _rotate_aux(state:Dictionary,command:Dictionary)->void:
	var word:int=command.word;var mode:=word&0xc000
	if mode==0xc000:_fail("Unreviewed three-anchor source auxiliary orientation");return
	if mode!=0x8000:
		var rotated:=VM.orientation(state.frame.matrix,state.frame.parity,word<<1)
		if not rotated.ok:_fail(rotated.error);return
		state.frame.aux=rotated.matrix;state.frame.aux_parity=rotated.parity
	elif state.frame.aux.is_empty():_fail("Source auxiliary rotation precedes initialization");return
	var code:int=command.words[1]
	if code==0 and mode!=0x8000:return
	var angle:=_local(state,code,true)
	if not angle.ok:_fail(angle.error);return
	var sine:=VM.Ground.sin_q31(angle.value);var cosine:=VM.Ground.sin_q31(int(angle.value)+0x4000)
	var axis:=(word>>5)&3
	if axis==3:_fail("Invalid source auxiliary rotation axis");return
	state.frame.aux=VM.auxiliary_rotation(state.frame.aux,axis,cosine,sine).matrix
func _polygon(state:Dictionary,command:Dictionary)->void:
	var contours:Array=[];var current:Array=[];var words:Array=command.words;var p:=3
	while p<words.size():
		var word:int=words[p];var op:=word>>9
		match op:
			0:break
			2:
				if p+1>=words.size():_fail("Truncated source polygon start");return
				if not current.is_empty():contours.append(current)
				current=[_point(state,word&255),_point(state,int(words[p+1])&255)];p+=2
			3:current.append(_point(state,word&255));p+=1
			5:
				if not current.is_empty():contours.append(current);current=[]
				p+=1
			1,4:
				var controls:Array=[]
				if op==1:
					if p+2>=words.size():_fail("Truncated source polygon curve");return
					if not current.is_empty():contours.append(current)
					controls=[_point(state,int(words[p+1])>>8),_point(state,int(words[p+1])&255),_point(state,int(words[p+2])>>8),_point(state,int(words[p+2])&255)]
					current=[controls[0]];p+=3
				else:
					if current.is_empty() or p+1>=words.size():_fail("Invalid continued source polygon curve");return
					controls=[current[-1],_point(state,word&255),_point(state,int(words[p+1])>>8),_point(state,int(words[p+1])&255)];p+=2
				if not error.is_empty():return
				for step in range(1,17):
					var t:=step/16.0;var q:=1.0-t;var point:Array=[]
					for k in range(3):point.append(roundi(q*q*q*controls[0][k]+3*q*q*t*controls[1][k]+3*q*t*t*controls[2][k]+t*t*t*controls[3][k]))
					current.append(point)
			6:
				if p+1>=words.size():_fail("Truncated source polygon circle");return
				if not current.is_empty():contours.append(current);current=[]
				var center:=_point(state,word&255);var packed:int=words[p+1]
				var normal:=_normal(state,packed&255)
				if normal.length_squared()==0:_fail("Source circle requires an explicit source normal");return
				var tangent:=normal.normalized().cross(Vector3.RIGHT if absf(normal.normalized().x)<0.9 else Vector3.UP).normalized()
				var binormal:=normal.normalized().cross(tangent).normalized()
				var radius:=(packed>>8)<<(int(state.frame.scale)&31)
				var circle:Array=[]
				for step in range(32):
					var offset:=(tangent*cos(step*TAU/32.0)+binormal*sin(step*TAU/32.0))*radius
					circle.append([int(center[0])+roundi(offset.x),int(center[1])+roundi(offset.y),int(center[2])+roundi(offset.z)])
				contours.append(circle);p+=2
			_:
				_fail("Unsupported source polygon operation %d in model %d at byte %d"%[op,state.model_index,command.offset]);return
		if not error.is_empty():return
	if not current.is_empty():contours.append(current)
	_tessellate_contours(contours,state,command)
func _normal(state:Dictionary,index:int)->Vector3:
	index&=127
	if index<2:return Vector3.ZERO
	var row:=(index/2)-1
	if row>=state.asset.normal_records.size():return Vector3.ZERO
	var record:Array=state.asset.normal_records[row];var result:=Vector3.ZERO
	for axis in range(3):
		for source_axis in range(3):result[axis]+=Vertices.s8(int(record[source_axis+2]))*(-1 if source_axis==0 and index&1 else 1)*float(state.frame.matrix[source_axis*3+axis])/2147483648.0
	return result
func _cone(state:Dictionary,command:Dictionary)->void:
	# F1761: endpoints are the low/high byte of word2; radius is the
	# high byte of each following word, normal selector the low byte.
	var words:Array=command.words;var first:=_point(state,int(words[2])&255);var second:=_point(state,int(words[2])>>8)
	if not error.is_empty():return
	var first_radius:=(int(words[3])>>8)<<(int(state.frame.scale)&31)
	var second_radius:=(int(words[4])>>8)<<(int(state.frame.scale)&31)
	var normal:=_normal(state,int(words[3])&255).normalized()
	if normal.length_squared()==0:_fail("Source cone requires a valid explicit normal");return
	var tangent:=normal.cross(Vector3.RIGHT if absf(normal.x)<0.9 else Vector3.UP).normalized();var binormal:=normal.cross(tangent).normalized()
	var a:Array=[];var b:Array=[]
	for step in range(32):
		var radial:=tangent*cos(step*TAU/32.0)+binormal*sin(step*TAU/32.0)
		var pa:Array=[];var pb:Array=[]
		for k in range(3):pa.append(int(first[k])+roundi(radial[k]*first_radius));pb.append(int(second[k])+roundi(radial[k]*second_radius))
		a.append(pa);b.append(pb)
	for step in range(32):
		var following:=(step+1)%32
		_triangle([a[step],b[step],a[following]],int(words[1]),state,command)
		_triangle([a[following],b[step],b[following]],int(words[1]),state,command)
		_triangle([first,a[following],a[step]],int(words[5]),state,command)
		_triangle([second,b[step],b[following]],int(words[6]),state,command)
	_event(state,command,"cone",{"centers_raw":[first,second],"radii_raw":[first_radius,second_radius],"material_code":words[1],"geometry_tessellated":true})
static func _area(points:PackedVector2Array)->float:
	var area:=0.0
	for i in range(points.size()):area+=points[i].cross(points[(i+1)%points.size()])
	return area*0.5
static func _clean(raw:Array)->Array:
	var points:Array=[]
	for point in raw:
		if points.is_empty() or point!=points[-1]:points.append(point)
	if points.size()>1 and points[0]==points[-1]:points.pop_back()
	return points
func _tessellate_contours(raw_contours:Array,state:Dictionary,command:Dictionary)->void:
	if _options.get("polygon_observer",null) is Callable:_options.polygon_observer.call(state.model_index,command.offset,raw_contours)
	var contours:Array=[]
	for raw in raw_contours:
		var points:=_clean(raw)
		if points.size()>=3:contours.append(points)
	if contours.is_empty():return
	var normal:=_normal(state,int(command.words[2])&255)
	if normal.length_squared()==0:
		# Newell's whole-boundary normal is stable for curved source polygons.
		for contour in contours:
			for i in range(contour.size()):
				var a:Array=contour[i];var b:Array=contour[(i+1)%contour.size()]
				normal.x+=(float(a[1])-float(b[1]))*(float(a[2])+float(b[2]))
				normal.y+=(float(a[2])-float(b[2]))*(float(a[0])+float(b[0]))
				normal.z+=(float(a[0])-float(b[0]))*(float(a[1])+float(b[1]))
	if normal.length_squared()==0:return
	var axis:=normal.abs().max_axis_index();var origin:Array=contours[0][0];var extent:=1.0;var projected:Array=[]
	for contour in contours:
		var projection:=PackedVector2Array()
		for point in contour:
			var pair:=Vector2(int(point[(axis+1)%3])-int(origin[(axis+1)%3]),int(point[(axis+2)%3])-int(origin[(axis+2)%3]))
			projection.append(pair);extent=maxf(extent,maxf(pair.abs().x,pair.abs().y))
		projected.append(projection)
	for j in range(projected.size()):
		for i in range(projected[j].size()):projected[j][i]/=extent
	var parents:Array=[];var depths:Array=[]
	for i in range(projected.size()):
		var parent:=-1;var area:=INF
		for j in range(projected.size()):
			if i!=j and absf(_area(projected[j]))>absf(_area(projected[i])) and Geometry2D.is_point_in_polygon(projected[i][0],projected[j]):
				if absf(_area(projected[j]))<area:parent=j;area=absf(_area(projected[j]))
		parents.append(parent)
	for i in range(parents.size()):
		var depth:=0;var parent:int=parents[i]
		while parent>=0:
			depth+=1;parent=parents[parent]
			if depth>32:_fail("Cyclic source polygon contour nesting");return
		depths.append(depth)
	var output:Array=[]
	for i in range(contours.size()):
		if depths[i]&1:continue
		var points:Array=contours[i].duplicate();var projection:PackedVector2Array=projected[i].duplicate();var holes:Array=[]
		if _area(projection)<0:projection.reverse();points.reverse()
		for j in range(contours.size()):
			if parents[j]==i and depths[j]&1:holes.append(j)
		var wanted:=absf(_area(projected[i]))
		for hole in holes:wanted-=absf(_area(projected[hole]))
		for hole in holes:
			var joined:=_bridge_hole(points,projection,contours[hole],projected[hole],projected,i,holes)
			if not joined.ok:_slab_fallback(contours,projected,state,command);return
			points=joined.points;projection=joined.projection
		var indices:=Geometry2D.triangulate_polygon(projection)
		if indices.is_empty():_slab_fallback(contours,projected,state,command);return
		var actual:=0.0
		for k in range(0,indices.size(),3):
			var a:Vector2=projection[indices[k]];var b:Vector2=projection[indices[k+1]];var c:Vector2=projection[indices[k+2]]
			actual+=absf((b-a).cross(c-a))*0.5
			var center:=(a+b+c)/3.0
			for hole in holes:
				if Geometry2D.is_point_in_polygon(center,projected[hole]):_slab_fallback(contours,projected,state,command);return
		if absf(actual-wanted)>maxf(0.00001,wanted*0.0001):_slab_fallback(contours,projected,state,command);return
		for k in range(0,indices.size(),3):output.append([points[indices[k]],points[indices[k+1]],points[indices[k+2]]])
	for triangle in output:_triangle(triangle,int(command.words[1]),state,command)
func _slab_fallback(contours:Array,projected:Array,state:Dictionary,command:Dictionary)->void:
	# No ear-clipped face has been emitted before this fallback. The helper
	# evaluates all contours together under the independently checked odd rule.
	var result:=Polygon.tessellate(projected)
	if not result.ok:_fail("Source polygon %d@%d: %s"%[state.model_index,command.offset,result.error]);return
	var flattened:Array=[]
	for contour in contours:flattened.append_array(contour)
	var points:Array=[]
	for weights in result.weights:
		var point:Array=[0.0,0.0,0.0]
		for index in weights:
			for k in range(3):point[k]+=float(flattened[int(index)][k])*float(weights[index])
		for k in range(3):point[k]=roundi(point[k])
		points.append(point)
	for k in range(0,result.indices.size(),3):_triangle([points[result.indices[k]],points[result.indices[k+1]],points[result.indices[k+2]]],int(command.words[1]),state,command)
func _bridge_hole(outer:Array,projection:PackedVector2Array,hole:Array,hole_projection:PackedVector2Array,all:Array,outer_index:int,hole_indices:Array)->Dictionary:
	var hp:=hole_projection.duplicate();var raw:=hole.duplicate()
	if _area(hp)>0:hp.reverse();raw.reverse()
	var hi:=0
	for i in range(1,hp.size()):
		if hp[i].x>hp[hi].x or (hp[i].x==hp[hi].x and hp[i].y<hp[hi].y):hi=i
	var oi:=-1;var distance:=INF
	for i in range(projection.size()):
		var a:Vector2=hp[hi];var b:Vector2=projection[i];var midpoint:=(a+b)*0.5
		if not Geometry2D.is_point_in_polygon(midpoint,all[outer_index]):continue
		var visible:=true
		for h in hole_indices:
			if Geometry2D.is_point_in_polygon(midpoint,all[h]):visible=false;break
		if not visible:continue
		for boundary in all:
			for edge in range(boundary.size()):
				var c:Vector2=boundary[edge];var d:Vector2=boundary[(edge+1)%boundary.size()]
				if c.is_equal_approx(a) or d.is_equal_approx(a) or c.is_equal_approx(b) or d.is_equal_approx(b):continue
				if Geometry2D.segment_intersects_segment(a,b,c,d)!=null:visible=false;break
			if not visible:break
		if visible and a.distance_squared_to(b)<distance:oi=i;distance=a.distance_squared_to(b)
	if oi<0:return {"ok":false,"error":"No visible bridge for source polygon hole"}
	var result:Array=[];var projected:=PackedVector2Array()
	for i in range(oi+1):result.append(outer[i]);projected.append(projection[i])
	for step in range(hp.size()+1):
		var at:=(hi+step)%hp.size();result.append(raw[at]);projected.append(hp[at])
	result.append(outer[oi]);projected.append(projection[oi])
	for i in range(oi+1,outer.size()):result.append(outer[i]);projected.append(projection[i])
	# A duplicate bridge is a weakly simple polygon. Godot's ear clipping
	# accepts this topology; no source coordinate is moved or fabricated.
	return {"ok":true,"points":result,"projection":projected}
