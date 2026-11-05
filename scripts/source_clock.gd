extends RefCounted
# Pure original F1357 calendar / F1363 display conversion. The elapsed-days
# bridge does not replace Navigation, accumulation, save data or ephemerides.
const EPOCH_DAY_U32:=0x121cf7
const EPOCH_TICK_U32:=0x80000000
const TICKS_PER_DAY:=0x100000000
const TICKS_PER_DISPLAY_SECOND:=0xc22e
const MAX_ELAPSED_DAYS:=1000000000.0
const MONTHS_RU:=["янв","фев","мар","апр","май","июн","июл","авг","сен","окт","ноя","дек"]

static func _u32(value:Variant)->bool:
	return (value is int or value is float) and is_finite(float(value)) and value>=0 and value<=0xffffffff and float(value)==floorf(float(value))

@warning_ignore("integer_division")
static func decode(day_u32:Variant,tick_u32:Variant)->Dictionary:
	if not _u32(day_u32) or not _u32(tick_u32):return {}
	var raw_day:=int(day_u32);var raw_tick:=int(tick_u32)
	# F1357 uses 1461-day cycles with the leap year FIRST (including year0).
	# It does not apply Gregorian century exceptions.
	var year:int=(raw_day/1461)*4
	var remainder:int=raw_day%1461
	var leap:=remainder<366
	if not leap:
		remainder-=366
		year+=1+remainder/365
		remainder%=365
	var month_days:Array=[31,29 if leap else 28,31,30,31,30,31,31,30,31,30,31]
	var month:=0
	while remainder>=int(month_days[month]):
		remainder-=int(month_days[month]);month+=1
	var day:=remainder+1
	# The original integer divisor is49710, not2^32/86400. Its very last
	# 23296 tick values intentionally format24:00:00 before the word rolls over.
	var seconds:int=raw_tick/TICKS_PER_DISPLAY_SECOND
	var hour:int=seconds/3600
	var minute:int=(seconds%3600)/60
	var second:int=seconds%60
	var date_ru:="%d-%s-%d"%[day,MONTHS_RU[month],year]
	var time_ru:="%02d:%02d:%02d"%[hour,minute,second]
	return {"day_u32":raw_day,"tick_u32":raw_tick,"year":year,"month":month+1,"day":day,"hour":hour,"minute":minute,"second":second,"date_ru":date_ru,"time_ru":time_ru,"label_ru":time_ru+" "+date_ru}

static func from_elapsed_days(days:Variant)->Dictionary:
	if not (days is int or days is float) or not is_finite(float(days)) or days<0 or days>MAX_ELAPSED_DAYS:return {}
	var value:=float(days)
	var whole:=int(floorf(value))
	# Split before adding the initial half-day: retain representable sub-day
	# fractions instead of rounding them away in an early value+0.5 operation.
	var tick:=int(floorf((value-float(whole))*float(TICKS_PER_DAY)))+EPOCH_TICK_U32
	var day:=EPOCH_DAY_U32+whole
	if tick>=TICKS_PER_DAY:tick-=TICKS_PER_DAY;day+=1
	var result:=decode(day,tick)
	if result.is_empty():return {}
	result.elapsed_days=value
	return result
