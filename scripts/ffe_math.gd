extends RefCounted
# Reconstructed from original F1467 and DATA_007977, not a recovered old file.
# Packed FFE numbers use signed16 mantissa and signed16 binary exponent.
# All integer arithmetic below follows original register/word truncation.
const U32_MASK:=0xffffffff
const SOURCE_SHA256:="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72"
static var _sqrt_table:PackedInt32Array=_load_sqrt_table()

static func _load_sqrt_table()->PackedInt32Array:
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://data/ffe_math.json"))
	assert(parsed is Dictionary,"Missing original F1467 constants")
	assert(parsed.get("source_sha256","")==SOURCE_SHA256,"Unexpected original executable provenance")
	assert(parsed.get("sqrt_table",[]) is Array and parsed.sqrt_table.size()==2048,"Invalid F1467 table size")
	var result:=PackedInt32Array()
	for value in parsed.sqrt_table:
		assert(value is float or value is int,"Invalid F1467 table element")
		assert(int(value)>=0 and int(value)<=65535 and float(int(value))==float(value),"Invalid F1467 u16 constant")
		result.append(int(value))
	return result

static func integer_sqrt(value:int)->int:
	# Original x86 comparisons are unsigned and EAX discards higher bits.
	# F1467 is a quantized LUT approximation; floor(sqrt(n)) is not equivalent.
	var n:=value&U32_MASK
	if n>=0x40000000:return _sqrt_table[n>>21]
	if n>=0x10000000:return _sqrt_table[n>>19]>>1
	if n>=0x04000000:return _sqrt_table[n>>17]>>2
	if n>=0x00400000:return _sqrt_table[n>>15]>>3
	if n>=0x00040000:return _sqrt_table[n>>11]>>5
	if n>=0x00004000:return _sqrt_table[n>>7]>>7
	if n>=0x00000400:return _sqrt_table[n>>3]>>9
	return _sqrt_table[n*2]>>11

static func _signed16(value:int)->int:
	var word:=value&65535
	return word-65536 if word>=32768 else word

static func s16(value:int)->int:
	# MOVSX reg32,reg16, including the IMUL/MOVSX AX/SAR sequence in F882.
	return _signed16(value)

static func _signed32(value:int)->int:
	var word:=value&U32_MASK
	return word-0x100000000 if word>=0x80000000 else word

static func _pack(mantissa:int,exponent:int)->int:
	return ((exponent&65535)<<16)|(mantissa&65535)

static func from_uint(value:int)->int:
	# F1489: unsigned32 conversion; zero has its original noncanonical exponent.
	var n:=value&U32_MASK
	if n==0:return 0xfff90000
	var exponent:=32
	while n<0x80000000:
		n=(n<<1)&U32_MASK
		exponent-=1
	return _pack(n>>17,exponent)

static func shift(value:int,bits:int)->int:
	# Direct ADD to the packed exponent WORD used by F882/F879.
	return _pack(value,_signed16(value>>16)+bits)

static func real(value:int)->float:
	# Explicit display conversion: M * 2^(E-15), derived from F1491/F1495.
	# It does not replace any of the original integer arithmetic procedures.
	var mantissa:=_signed16(value)
	if mantissa==0:return 0.0
	var exponent:=_signed16(value>>16)-15
	# Split a tiny power so a representable subnormal is not lost before the
	# signed16 mantissa is applied. Each power-of-two multiplication is exact
	# until the final IEEE754 double rounding.
	if exponent<(-1022):return (float(mantissa)*pow(2.0,-1022.0))*pow(2.0,float(exponent+1022))
	return float(mantissa)*pow(2.0,float(exponent))

static func multiply(first:int,second:int)->int:
	# F1482 does not normalize the result after arithmetic right shift.
	var product:=_signed16(first)*_signed16(second)
	return _pack(product>>15,_signed16(first>>16)+_signed16(second>>16))

@warning_ignore("integer_division")
static func divide(first:int,second:int)->int:
	# F1483 retains the original divide-by-zero saturation constant.
	var denominator:=_signed16(second)
	if denominator==0:return 0x007f7fff
	var exponent:=_signed16(first>>16)-_signed16(second>>16)
	var mantissa:=_signed16((_signed16(first)<<14)/denominator)
	if absi(mantissa)>=0x4000:exponent+=1
	else:mantissa=_signed16(mantissa<<1)
	return _pack(mantissa,exponent)

static func add(first:int,second:int)->int:
	# F1486 compares signed exponents, masks native shifts, then normalizes.
	var exponent_first:=_signed16(first>>16)
	var exponent_second:=_signed16(second>>16)
	var exponent:=exponent_first if exponent_first>exponent_second else exponent_second
	var mantissa:int
	if exponent_first>exponent_second:
		if exponent_first>exponent_second+31:return first&U32_MASK
		mantissa=_signed16(first)+(_signed16(second)>>(exponent_first-exponent_second))
	else:
		if exponent_second>exponent_first+31:return second&U32_MASK
		mantissa=_signed16(second)+(_signed16(first)>>(exponent_second-exponent_first))
	if absi(mantissa)>0x7fff:return _pack(mantissa>>1,exponent+1)
	while mantissa!=0 and absi(mantissa)<0x3fff:
		mantissa=_signed16(mantissa<<1)
		exponent-=1
	return _pack(mantissa,exponent)

static func to_integer(value:int)->int:
	# F1491: the x86 SAR count is masked even for unusual negative exponents.
	var exponent:=_signed16(value>>16)
	var mantissa:=_signed16(value)
	if exponent>31:return -0x80000000 if mantissa<0 else 0
	return _signed32(mantissa<<16)>>((31-exponent)&31)

static func square_root(value:int)->int:
	# F1463 operates on the packed exponent and delegates to source F1467.
	var exponent:=_signed16(value>>16)
	var argument:=(_signed16(value)<<16)&U32_MASK
	if (exponent&1)!=0:exponent=(exponent>>1)+1
	else:
		exponent>>=1
		argument=(argument<<1)&U32_MASK
	return _pack(integer_sqrt(argument)>>1,exponent)

static func fixed_multiply(first:int,second:int)->int:
	# F1515 splits the first unsigned32 input into two16bit halves. The low
	# partial IMUL wraps BEFORE SHR, so a generic 64bit product differs.
	var first_u32:=first&U32_MASK
	var second_i32:=_signed32(second)
	var low:=(((first_u32&65535)*second_i32)&U32_MASK)>>16
	return (low+((first_u32>>16)*second_i32))&U32_MASK

static func period(orbit:int,parent_mass:int)->int:
	# Original F879/F882 packed period chain and mantissa factor 0x5edb.
	var root:=square_root(divide(multiply(multiply(orbit,orbit),orbit),parent_mass))
	return _pack((_signed16(root)*0x5edb)>>15,_signed16(root>>16))
