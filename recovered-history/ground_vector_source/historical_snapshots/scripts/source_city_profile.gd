extends RefCounted
# Lightweight, deterministic city placement. It never compiles an entire city.
const Ground=preload("res://scripts/ground_coordinates.gd")
const Pads=preload("res://scripts/source_ground_pads.gd")
const Models=preload("res://scripts/source_model_vm.gd")
const Units=preload("res://scripts/source_units.gd")

static func basis_at(latitude:float,longitude:float)->Basis:
	var sl:=sin(latitude);var cl:=cos(latitude);var sn:=sin(longitude);var cs:=cos(longitude)
	return Basis(Vector3(-sn,0,-cs),Vector3(cl*cs,sl,-cl*sn),Vector3(sl*cs,-cl,-sl*sn))

static func describe(site:Dictionary,radius:float)->Dictionary:
	if int(site.get("type_code",-1))!=35 or not site.has("source_seed"):return {}
	var model:=int(site.model_index)
	if model<81 or model>90:return {}
	var coordinates:Array=Ground.coordinates(site)
	if coordinates.is_empty():return {}
	var asset:=Models.model(model)
	if asset.is_empty():return {}
	var matrix:Array=Pads.matrix_for_angles(int(site.ground_phase_u16),int(site.ground_inclination_u16))
	var positions:Array=Pads.transformed_positions(model,matrix)
	var selected:=Pads.pick_highest_free(model)
	if selected<0 or selected>=positions.size():return {}
	var basis:=basis_at(coordinates[0],coordinates[1])
	var raw_position:Array=positions[selected]
	var offset:=Vector3(float(raw_position[0]),float(raw_position[1]),float(raw_position[2]))*Units.METRES_PER_RAW
	var x:float=cos(coordinates[0])*cos(coordinates[1])*radius+float(offset.x)
	var y:float=sin(coordinates[0])*radius+float(offset.y)
	var z:float=-cos(coordinates[0])*sin(coordinates[1])*radius+float(offset.z)
	var latitude:=atan2(y,sqrt(x*x+z*z))
	var longitude:=atan2(-z,x)
	var exponent:=int(asset.scale)+int(asset.scale2)-8
	var outer:=Units.metres(float(asset.outer_radius_q8)*pow(2.0,exponent))
	# The source city is a tangent-plane model. The surrounding terrain is graded
	# to that plane in this explicit revision; source terrain/anchor height is separate.
	var inner:=maxf(1000.0,outer*1.05+64.0)
	return {"site_id":str(site.id),"model_index":model,"source_seed":int(site.source_seed),
		"root_latitude":coordinates[0],"root_longitude":coordinates[1],"root_basis":basis,
		"source_matrix_q31":matrix,"pad_index":selected,"pad_count":positions.size(),"pad_offset_body_m":offset,
		"pad_offset_local_m":basis.inverse()*offset,"pad_latitude":latitude,"pad_longitude":longitude,
		"flat_inner_m":inner,"flat_outer_m":inner+1000.0,"root_elevation_m":0.0,
		"key":"%d:%d:%d:%d"%[model,int(site.source_seed),int(site.ground_phase_u16),int(site.ground_inclination_u16)]}

static func plane_height(profile:Dictionary,radius:float,latitude:float,longitude:float)->float:
	var cosine:=sin(latitude)*sin(float(profile.root_latitude))+cos(latitude)*cos(float(profile.root_latitude))*cos(longitude-float(profile.root_longitude))
	return (radius+float(profile.root_elevation_m))/maxf(0.000001,cosine)-radius
