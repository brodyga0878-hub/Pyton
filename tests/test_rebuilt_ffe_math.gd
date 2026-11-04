extends SceneTree
const Math=preload("res://scripts/ffe_math.gd")
var checks:=0
var failures:=0

func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<15:push_error(message)

func _init()->void:
	var fixture:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/rebuilt_ffe_math_native.json"))
	if not fixture is Dictionary or not fixture.get("cases",[]) is Array or fixture.cases.size()<30000:
		push_error("Missing independent original F1467 fixture")
		quit(1)
		return
	check(fixture.exe_sha256==Math.SOURCE_SHA256,"Native controls use the actual uploaded original executable")
	for row in fixture.cases:
		var input:=int(row[0])
		var expected:=int(row[1])
		check(Math.integer_sqrt(input)==expected,"Original F1467 mismatch for 0x%08x"%input)
		check(Math.integer_sqrt(input-0x100000000)==expected,"Signed EAX compatibility mismatch for 0x%08x"%input)
	for row in fixture.packed_cases:
		var first:=int(row[1])
		var second:=int(row[2])
		var actual:=0
		match int(row[0]):
			1:actual=Math.from_uint(first)
			2:actual=Math.multiply(first,second)
			3:actual=Math.divide(first,second)
			4:actual=Math.add(first,second)
			5:actual=Math.to_integer(first)
			6:actual=Math.square_root(first)
			7:actual=Math.fixed_multiply(first,second)
			8:actual=Math.period(first,second)
			9:actual=Math.shift(first,second)
			_:push_error("Unknown original math control operation");quit(1);return
		check((actual&0xffffffff)==int(row[3]),"Original %s mismatch for 0x%08x,0x%08x: 0x%08x != 0x%08x"%[fixture.operations[int(row[0])],first,second,actual&0xffffffff,int(row[3])])
	for row in fixture.real_cases:
		var bytes:PackedByteArray=str(row[1]).hex_decode()
		var expected:float=bytes.decode_double(0)
		var actual:float=Math.real(int(row[0]))
		check(actual==expected,"Independent M*2^(E-15) binary64 conversion mismatch for 0x%08x: %s != %s"%[int(row[0]),str(actual),str(expected)])
	check(Math.integer_sqrt(0x100000004)==2,"Inputs truncate to unsigned EAX before the source branches")
	check(Math.integer_sqrt(0xffffffff)!=int(floor(sqrt(float(0xffffffff)))),"This implementation retains original LUT quantization")
	print("REBUILT FFE MATH TESTS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
