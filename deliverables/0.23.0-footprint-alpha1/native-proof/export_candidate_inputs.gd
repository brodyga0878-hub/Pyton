extends "res://tests/test_source_natural_surface_bridge.gd"
func run()->void:
 if not configure():quit(1);return
 var rows:Array=[]
 var rotations:=[['upright',Vector3.ZERO],['roll_plus',Vector3(0,0,0.25)],['roll_minus',Vector3(0,0,-0.25)],['pitch_plus',Vector3(0.22,0,0)],['pitch_minus',Vector3(-0.22,0,0)],['compound',Vector3(0.17,-0.11,0.23)]]
 for ship_id:String in ['eagle','cobra','shuttle']:
  for rotation:Array in rotations:
   var offsets:Array=[-0.5,3.0,80.0]
   if ship_id=='shuttle' and str(rotation[0]) in ['pitch_plus','pitch_minus']:offsets.append(0.5)
   for offset:float in offsets:
    ship.ship_id=ship_id;ship.attitude=Quaternion.from_euler(rotation[1]);var data:=Phone.source_ship_data(ship_id);var inner_m:=int(data.inner_radius_raw)*Phone.Units.METRES_PER_RAW
    ship.position=Vector3(0,accepted_height+surface.clearance(ship)-inner_m+offset,0)
    var f:=Bridge._prepare_frame(surface,ship,{})
    var source:PackedFloat64Array=f.body_point.duplicate();var correction:float=inner_m-float(f.phone_clearance_m)
    for axis in range(3):source[axis]+=float(f.basis.y[axis])*correction
    var original:=Bridge._raw_point(source);var player:=PackedByteArray();player.resize(338);player.fill(0);var parent:=player.duplicate();var matrix:=Phone.contact_orientation_q31(f.basis,f.input_attitude)
    for index in range(9):player.encode_s32(index*4,matrix[index])
    for axis in range(3):parent.encode_s32(axis*16,0x7fffffff)
    player.encode_u32(0x82,int(data.model_index));player[0x86]=1;parent[0x86]=2;player[0x56]=2;player[0x57]=1;player[0x14c]=int(f.natural_ship.initial_object_flags_14c_u8);parent.encode_u32(0xa0,f.record.decode_u32(4));parent=Bridge.Ground.initialize_model(parent,int(f.model)).object
    player.encode_s64(0x138,int(data.outer_radius_raw));player.encode_s64(0x140,int(data.inner_radius_raw))
    for axis in range(3):player.encode_s64(0x3e+axis*8,original[axis])
    var ctx:={"graphics_level":1,"initial_globals":Bridge.caller_globals(history())}
    var classified:=Natural.new().classify_natural_player(player,parent,original,ctx);var visible:Array=[]
    for trace:Dictionary in classified.iterations:
     var raw_bytes:=str(trace.relative_before_hex).hex_decode();var metres:=PackedFloat64Array()
     for axis in range(3):metres.append(float(raw_bytes.decode_s64(axis*8))*Phone.Units.METRES_PER_RAW)
     var local:=Phone.to_local_vector(f.basis,metres);local[1]-=float(f.globe.radius)
     var provider:=Bridge._clone_provider(surface.source_render_state);var hit:Dictionary=provider.height_at(f.globe,local[0],local[2]);var ground_point:=PackedFloat64Array()
     for axis in range(3):ground_point.append(float(f.basis.x[axis])*local[0]+float(f.basis.y[axis])*(float(f.globe.radius)+float(hit.height))+float(f.basis.z[axis])*local[2])
     visible.append({"child_index":trace.child_index,"actor_probe_relative_hex":trace.relative_before_hex,"visible_ground_raw_hex":Bridge._vector_hex(Bridge._raw_point(ground_point)),"local_f64_hex":Bridge._floats_hex(local),"visible_height":hit.height,"triangle_index":hit.triangle_index})
    rows.append({"id":"118_%s_%s_%s"%[ship_id,rotation[0],str(offset)],"input_domain":"explicit_published_flat_visible_fixture_not_live_triangle_certificate","ship_id":ship_id,"player_model":int(data.model_index),"parent_model":118,"orientation_name":rotation[0],"euler_radians":[rotation[1].x,rotation[1].y,rotation[1].z],"source_center_height_m":offset,"player_object_hex":player.hex_encode(),"parent_object_hex":parent.hex_encode(),"relative_before_hex":Bridge._vector_hex(original),"context":ctx,"visible_ground_points":visible})
 var file:=FileAccess.open('/tmp/footprint-candidate-inputs.json',FileAccess.WRITE);file.store_string(JSON.stringify({"schema":1,"rows":rows},'\t'));file.close();print('FOOTPRINT CANDIDATES ',rows.size());quit()
