extends SceneTree
# Fixed independent baseline captured before this material-only change.
const Station=preload("res://scripts/station_visual.gd")
const Library=preload("res://scripts/material_library.gd")
const BASELINE={0:"6cf5a4bc2ecc09c7f6ad5ca00b4ab2d3f22bb5203bd62a284544c1e6b2e1612b",1:"5b22e08a7e5212bd4046439d8e5af88c6ed02ccd1f12416fab8e58a29547d06a",2:"5b22e08a7e5212bd4046439d8e5af88c6ed02ccd1f12416fab8e58a29547d06a"}
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func geometry_hash(station:Node3D)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	for child in station.get_children():
		if not child is MeshInstance3D:continue
		hash.update(str(child.name).to_utf8_buffer())
		for index in range(child.mesh.get_surface_count()):hash.update(var_to_bytes(child.mesh.surface_get_arrays(index)))
	return hash.finish().hex_encode()
func dedicated_maps(material:StandardMaterial3D)->void:
	check(material.albedo_texture==Station.finish_texture("albedo"),"Station finish binds dedicated albedo")
	check(material.normal_texture==Station.finish_texture("normal"),"Station finish binds dedicated normal")
	check(material.ao_texture==Station.finish_texture("orm") and material.roughness_texture==material.ao_texture and material.metallic_texture==material.ao_texture,"ORM channels share one data texture")
	check(material.uv1_triplanar and not material.uv1_world_triplanar,"Projection remains object-fixed during world rebases")
	check(material.uv1_scale.is_equal_approx(Vector3.ONE/16.0),"Atlas repeats at16m scale")
	check(material.ao_texture_channel==BaseMaterial3D.TEXTURE_CHANNEL_RED and material.roughness_texture_channel==BaseMaterial3D.TEXTURE_CHANNEL_GREEN and material.metallic_texture_channel==BaseMaterial3D.TEXTURE_CHANNEL_BLUE,"ORM channels remain linear physical data")
func run()->void:
	var metadata:=Station.finish_metadata()
	check(int(metadata.resolution)==1024 and int(metadata.tile_size_m)==16,"Authored atlas resolution and physical tile size explicit")
	for channel in ["albedo","normal","orm"]:
		var texture:=Station.finish_texture(channel)
		check(texture!=null and texture==Station.finish_texture(channel),"Dedicated maps are shared cached resources: "+channel)
		if texture==null:continue
		check(texture.get_width()==1024 and texture.get_height()==1024,"Dedicated imported dimensions: "+channel)
		check(texture.get_image().has_mipmaps(),"Imported atlas has mipmaps: "+channel)
		check(FileAccess.get_sha256(Station.FINISH_ROOT+channel+".png")==str(metadata.files[channel].sha256),"Authored atlas bytes match manifest: "+channel)
	check(Station.finish_texture("invalid")==null,"Invalid map channel rejected without filesystem access")
	var modified:=Station.finish_metadata();modified["resolution"]=1
	check(int(Station.finish_metadata().resolution)==1024,"Consumer metadata cannot mutate shared cache")
	var station:=Station.new();root.add_child(station)
	for quality in [0,1,2]:
		station.configure(quality)
		check(geometry_hash(station)==BASELINE[quality],"All station vertex/normal/UV/index bytes match pre-change baseline at quality%d"%quality)
		check(station.geometry_batches==6,"No new station batches or geometry introduced")
		for role in ["shell","dark"]:
			var material:StandardMaterial3D=station._materials[role];dedicated_maps(material)
			check(material.normal_enabled==(quality>0),"Normal cost follows station quality: "+role)
			var target_rough:=0.37 if role=="shell" else 0.30
			check(is_equal_approx(material.roughness*float(metadata.mean_roughness),target_rough),"Measured atlas roughness preserves established finish: "+role)
			var original:=Color("c5cdd2") if role=="shell" else Color("202e3c")
			var average:Color=material.albedo_color.srgb_to_linear()*float(metadata.mean_linear_luminance)
			var desired:Color=original.srgb_to_linear()
			check(is_equal_approx(average.r,desired.r) and is_equal_approx(average.g,desired.g) and is_equal_approx(average.b,desired.b),"Mean linear hue/tint remains established station palette: "+role)
		check(station._materials.gold.albedo_texture==Library.texture("brushed_metal","albedo"),"Existing gold trim keeps original metal material")
		for role in ["light","amber"]:
			check(station._materials[role].albedo_texture==null and station._materials[role].emission_enabled,"Navigation emitters remain clean: "+role)
		var shell:StandardMaterial3D=station._materials.shell
		station.configure(quality)
		check(station._materials.shell==shell,"Repeated same-quality configure does not rebuild materials")
	var high:StandardMaterial3D=station._materials.shell
	var other:=Station.new();root.add_child(other);other.configure(0)
	check(high!=other._materials.shell and high.normal_enabled and not other._materials.shell.normal_enabled,"Separate stations cannot mutate another station's quality")
	check(high.albedo_texture==other._materials.shell.albedo_texture,"Station instances share only immutable map resources")
	other.queue_free();station.queue_free();await process_frame
	print("STATION FINISH TESTS: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
