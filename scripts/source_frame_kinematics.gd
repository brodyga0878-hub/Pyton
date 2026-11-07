extends RefCounted
# Exact F572/F573 rotation primitives. These procedures neither translate a
# parent origin nor add/subtract omega cross radius; F570/F606 caller policy
# and automatic reference-frame selection remain outside this module.
const Motion=preload("res://scripts/source_motion_pipeline.gd")
const Gravity=preload("res://scripts/source_gravity.gd")
const Ground=preload("res://scripts/ground_coordinates.gd")
const Orbit=preload("res://scripts/source_orbit.gd")
const PROFILE:="source-f572-f573-rotation-primitive-v1"
static func _matrix(value:Variant)->bool:
	if not (value is Array or value is PackedInt64Array) or value.size()!=9:return false
	for word in value:
		if not Motion._whole(word,-0x80000000,0x7fffffff):return false
	return true
static func _vector(vector:PackedInt64Array,matrix:Variant,transpose:bool)->PackedInt64Array:
	var result:=PackedInt64Array()
	for axis in range(3):
		var sum:=0
		for component in range(3):
			var index:=axis*3+component if transpose else component*3+axis
			sum=Ground.signed32(sum+Ground.multiply_q31(vector[component],int(matrix[index])))
		result.append(sum)
	return result
static func rotate(body:PackedByteArray,matrix_q31:Variant,enter_rotating:Variant,source_frame_byte:Variant=1)->Dictionary:
	if body.size()!=Motion.OBJECT_BYTES or not _matrix(matrix_q31) or not enter_rotating is bool or not Motion._whole(source_frame_byte,0,255):return {}
	var result:=body.duplicate();var position:=PackedInt64Array([body.decode_s64(0x3e),body.decode_s64(0x46),body.decode_s64(0x4e)])
	var shift:=maxi(0,Gravity._vec64_msb(position)-28);var truncated:=PackedInt64Array()
	for coordinate in position:truncated.append(Ground.signed32(Orbit.shift_words(Orbit._words(coordinate),-shift)[0]))
	var transformed:=_vector(truncated,matrix_q31,enter_rotating)
	for axis in range(3):
		# F1517 reconstructs signed32 coordinates at the previous truncation
		# exponent, retaining the original low-bit loss and modulo64 behavior.
		var reconstructed:=Orbit.shift_words(Orbit._words(transformed[axis]),shift)
		result.encode_s64(0x3e+axis*8,Orbit.signed64(reconstructed))
	for group in range(3):
		var orientation:=_vector(Motion._read_vector(body,group*12),matrix_q31,enter_rotating)
		for axis in range(3):result.encode_s32(group*12+axis*4,orientation[axis])
	result[0x57]=1 if enter_rotating else 0
	if enter_rotating:result[0x58]=(int(source_frame_byte)-1)&255
	var velocity:=_vector(Motion._read_vector(body,0x8c),matrix_q31,enter_rotating)
	for axis in range(3):result.encode_s32(0x8c+axis*4,velocity[axis])
	return {"body":result,"profile":PROFILE,"procedure":"F572" if enter_rotating else "F573","truncate_shift":shift,"parent_translation_included":false,"angular_surface_velocity_included":false,"automatic_reference_frame_selection":false}
