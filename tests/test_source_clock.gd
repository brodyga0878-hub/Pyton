extends SceneTree
# Exact original calendar/time output; elapsed-days integration is a separate,
# explicit display adapter and does not test original simulation accumulation.
const Clock=preload("res://scripts/source_clock.gd")
var checks:=0
var failures:=0
func _initialize()->void:call_deferred("run")
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<15:push_error(message)
func run()->void:
	var reference:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_clock_native.json"))
	check(reference.revision=="source-f1357-f1363-clock-native-v1" and reference.schema==1,"Clock fixture has a distinct independently executed source scope")
	check(reference.source_executable_sha256=="d919566140abfc298bc9929bc9141d92526586821f017be1336253a04bca1e72" and reference.source_commit=="7e540341d4e09aa3c92877b87d49e7f2c143ad8d","Native controls pin the user executable and reviewed source commit")
	check(reference.fresh_process_outputs_identical and int(reference.fresh_process_runs)==3 and int(reference.reverse_interleaving_cases)==reference.cases.size(),"Fresh and reverse-interleaved original functions were independently repeated")
	check(reference.cases.size()==1453 and reference.binary_signature_verification.size()==5,"All1453 native contexts and original binary signatures are present")
	var actual_24:=0;var actual_leap:=0;var centuries:=0
	for index in range(reference.cases.size()):
		var row:Dictionary=reference.cases[index]
		var result:=Clock.decode(row.day_u32,row.tick_u32)
		check(not result.is_empty(),"Original u32 context accepted case%d"%index)
		if result.is_empty():continue
		check([result.year,result.month,result.day]==[int(row.year),int(row.month),int(row.day)],"Native F1357 calendar matches case%d"%index)
		check([result.hour,result.minute,result.second]==[int(row.hour),int(row.minute),int(row.second)] and result.time_ru==row.time_ascii,"Native F1363 display divisions and formatting match case%d"%index)
		check(int(result.day_u32)==int(row.day_u32) and int(result.tick_u32)==int(row.tick_u32),"Decoding preserves both original timestamp words case%d"%index)
		check(result.date_ru is String and result.label_ru==result.time_ru+" "+result.date_ru and result.date_ru.find("-")>=1,"Russian label is derived from the verified clock values case%d"%index)
		if int(row.hour)==24:actual_24+=1
		if int(row.month)==2 and int(row.day)==29:actual_leap+=1
		if int(row.year)%100==0:centuries+=1
	check(actual_24>0 and actual_leap>0 and centuries>0,"Controls cover24:00:00, leap-year0 and century handling")
	var initial:=Clock.decode(0x121cf7,0x80000000)
	check(initial.year==3250 and initial.month==1 and initial.day==1 and initial.label_ru=="12:00:00 1-янв-3250","Original initial words represent noon1January3250")
	check(Clock.decode(59,0).date_ru=="29-фев-0" and Clock.decode(60,0).date_ru=="1-мар-0","Year0 is leap in the original calendar")
	check(Clock.decode(0xffffffff,0xffffffff).time_ru=="24:00:00","Final u32 ticks preserve the source display edge without invented rollover")
	var bridges:Array=[
		[0.0,0x121cf7,0x80000000,"12:00:00 1-янв-3250"],
		[0.25,0x121cf7,0xc0000000,"18:00:00 1-янв-3250"],
		[0.5,0x121cf8,0,"00:00:00 2-янв-3250"],
		[0.75,0x121cf8,0x40000000,"06:00:00 2-янв-3250"],
		[1.0,0x121cf8,0x80000000,"12:00:00 2-янв-3250"],
		[30.5,0x121d16,0,"00:00:00 1-фев-3250"],
		[364.5,0x121e64,0,"00:00:00 1-янв-3251"],
		[788.5,0x12200c,0,"00:00:00 29-фев-3252"],
	]
	for row in bridges:
		var result:=Clock.from_elapsed_days(row[0])
		check(not result.is_empty(),"Adapted elapsed-days timestamp accepts a bounded existing-navigation value")
		if result.is_empty():continue
		check(result.day_u32==int(row[1]) and result.tick_u32==int(row[2]) and result.label_ru==row[3],"Elapsed-days bridge preserves epoch, half-day carry, month/year/leap boundaries")
	var tiny:=Clock.from_elapsed_days(1.0/float(Clock.TICKS_PER_DAY))
	check(tiny.day_u32==Clock.EPOCH_DAY_U32 and tiny.tick_u32==Clock.EPOCH_TICK_U32+1,"Bridge retains a representable one-tick fraction before epoch addition")
	var maximum:=Clock.from_elapsed_days(1000000000.0)
	check(maximum.day_u32==Clock.EPOCH_DAY_U32+1000000000 and maximum.tick_u32==Clock.EPOCH_TICK_U32,"Entire existing Navigation elapsed-days range has defined bounded timestamps")
	for invalid in [-1,0x100000000,0.5,NAN,INF,-INF,"1",null,true,[],{}]:
		check(Clock.decode(invalid,0).is_empty() and Clock.decode(0,invalid).is_empty(),"Invalid raw word rejects atomically")
	for invalid in [-1.0,1000000000.5,NAN,INF,-INF,"0",null,true,[],{}]:
		check(Clock.from_elapsed_days(invalid).is_empty(),"Invalid elapsed-days adapter input rejects without changing caller state")
	print("SOURCE CLOCK TESTS: %d checks, %d failures; %d independent native calendar/time contexts, display-only elapsed bridge"%[checks,failures,reference.cases.size()])
	quit(1 if failures else 0)
