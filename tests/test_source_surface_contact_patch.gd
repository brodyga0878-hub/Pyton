extends SceneTree
const Terrain=preload("res://scripts/source_surface_terrain.gd")
const Packet=preload("res://scripts/source_surface_render_packet.gd")
const State=preload("res://scripts/source_surface_render_state.gd")
const Contact=preload("res://scripts/source_surface_contact_patch.gd")
class NativeSystem extends RefCounted:
	var by_id:Dictionary={}
	var settlements:Array=[]
	var system_id:=44341016
var checks:=0
var failures:=0
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize()->void:call_deferred("run")
func copy(value:Variant)->Variant:return JSON.parse_string(JSON.stringify(value))
func source_globe(model:int)->RefCounted:
	var fixture:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/source_ground_surface_native.json"));var record:=PackedByteArray()
	for row:Dictionary in fixture.cases:
		if int(row.parent_model)==model:record=str(row.parent_record_hex).hex_decode();break
	var system:=NativeSystem.new();system.by_id.body={"runtime_record_hex":record.hex_encode(),"radius_km":1.0}
	var globe:=Terrain.new();globe.configure(system,"body","");globe.latitude=-PI/8;globe.longitude=PI/2
	return globe

func actual_nonvertex()->void:
	var globe:=source_globe(117);var packet:=Packet.prepare(globe,{"core_width":8000.0,"core_cells":32,"include_rings":false,"source_key":"native117-mobile-250m"})
	var state:=State.new();check(state.configure(packet),"Current1178km/32-cell published packet configures")
	var point:=Vector2.ZERO;var best:=-1.0;var published:=0.0;var source_height:=0.0
	for z in [82.5,982.5,1982.5,-2187.5,-3187.5]:
		for x in [113.25,913.25,1913.25,-2186.75,-3186.75]:
			var hit:=state.height_at(globe,x,z);var raw:=float(globe.raw_height(x,z));var difference:=absf(float(hit.height)-raw)
			if difference>best:best=difference;point=Vector2(x,z);published=float(hit.height);source_height=raw
	check(best>0.01,"Real native117 parked nonvertex has a material published-triangle/raw-field difference")
	var patch:=state.contact_patch(globe,point.x,point.y)
	check(not patch.is_empty() and Contact._plain(patch) and patch.vertices.size()==3 and patch.profile=="source-mobile117-core-8000-32-v1","Capture stores only three vertices and explicit current mobile profile as JSON primitives")
	var encoded:Dictionary=copy(patch);var verified:=Contact.new()
	check(verified.configure(encoded,globe) and verified.validation_samples==3,"Restored contact independently recomputes all three original source heights")
	var hit:=verified.height_at(globe,point.x,point.y)
	check(not hit.is_empty() and absf(float(hit.height)-published)<0.000001,"Legitimate nonvertex park restores its actual published triangle instead of raw terrain")
	var parked_y:=float(Vector3(point.x,published+7.88,point.y).y)
	check(absf(parked_y-7.88-float(hit.height))<=Contact.float32_tolerance(parked_y),"Float32 parked hull retains correct height above independently verified contact")
	check(copy(verified.contact_patch(globe,point.x,point.y))==encoded,"Verified state can re-save the same plain triangle before first visual packet publication")
	var stats:Dictionary=globe.cache_stats()
	for i in range(100):verified.height_at(globe,point.x,point.y)
	check(globe.cache_stats()==stats,"Verified contact plane queries add no native source sampling on live terrain")
	check(verified.height_at(globe,99999,99999).is_empty() and verified.contact_patch(globe,99999,99999).is_empty(),"Outside verified triangle explicitly falls back without an arbitrary AGL correction")
	for mutation in ["height","frame","hash","profile","topology","policy","radius","domain","object","extra_agl"]:
		var bad:Dictionary=encoded.duplicate(true)
		if mutation=="height":bad.vertices[0][1]+=1.0
		elif mutation=="frame":bad.frame.latitude+=0.002
		elif mutation=="hash":bad.frame.record_hash="0".repeat(64)
		elif mutation=="profile":bad.profile="unverified-grid"
		elif mutation=="topology":bad.vertices[0][0]+=250.0
		elif mutation=="policy":bad.terrain_policy="unverified-height-policy"
		elif mutation=="radius":bad.frame.radius+=1.0
		elif mutation=="domain":bad.frame.record_domain="constructor-template"
		elif mutation=="object":bad.vertices[0]=Vector3.ZERO
		elif mutation=="extra_agl":bad.height_bias=15.0
		# Recomputing the public corruption checksum must not bypass native
		# vertex-height / frame / source-record / grid verification.
		bad.checksum=Contact.checksum_for(bad)
		check(not verified.configure(bad,globe) and verified.configured_ok and absf(float(verified.height_at(globe,point.x,point.y).height)-published)<0.000001,"Edited contact rejects atomically even with recalculated checksum: "+mutation)
	var altered_checksum:Dictionary=encoded.duplicate(true);altered_checksum.frame.longitude+=0.0000001
	check(not verified.configure(altered_checksum,globe),"Unsealed geographic-frame edit rejects through local corruption checksum")
	var packet_point:=Vector3(point.x,published,point.y)
	globe.latitude+=600.0/globe.radius;globe.longitude+=512.0/(globe.radius*cos(globe.latitude));var current:Vector3=state.transform_to(globe)*packet_point
	var rebased:=Contact.new();check(rebased.configure(encoded,globe),"Old packet-frame triangle validates against same body after600m/512m surface rebase")
	var expected:=state.height_at(globe,current.x,current.z);var actual:=rebased.height_at(globe,current.x,current.z)
	check(not actual.is_empty() and absf(float(actual.height)-float(expected.height))<0.000001,"Verified saved triangle retains exact physical vertical contact through rebase")
	var foreign:=source_globe(120)
	check(not verified.configure(encoded,foreign) and verified.height_at(foreign,0,0).is_empty(),"Same-sized or different native body cannot borrow foreign contact record")
	check(not verified.configure(encoded,null) and verified.height_at(null,0,0).is_empty(),"Null lifecycle rejects without losing previously verified state")
	verified.clear();check(not verified.configured_ok and verified.height_at(globe,0,0).is_empty(),"Explicit clear removes saved-contact authority")
	print("NATIVE117 CONTACT point=",point," published=",published," raw=",source_height," difference_m=",best," vertices=",encoded.vertices.size())

func supported_profiles()->void:
	for specification in [[117,4000.0,64],[117,8000.0,64],[120,4000.0,64]]:
		var model:=int(specification[0]);var width:=float(specification[1]);var cells:=int(specification[2]);var globe:=source_globe(model)
		var step:=width/cells;var cell:=Vector2i(cells/2,cells/2);var points:Array=[]
		for xz in [Vector2.ZERO,Vector2(step,0),Vector2(0,step)]:points.append(Vector3(xz.x,globe.raw_height(xz.x,xz.y),xz.y))
		var frame:={"latitude":globe.latitude,"longitude":globe.longitude,"radius":globe.radius,"record_hash":State._sha(globe.source_record),"terrain_revision":Terrain.REVISION_NAME,"record_domain":State.RECORD_DOMAIN}
		var patch:=Contact.seal_capture(frame,width,cells,Vector2.ZERO,cell,0,points,globe);var restored:=Contact.new()
		check(not patch.is_empty() and restored.configure(copy(patch),globe),"Known independently verified mobile contact profile restores "+str(specification))
		check(not restored.height_at(globe,step*0.25,step*0.25).is_empty(),"Known contact profile exposes physical triangle interior")
	check(Contact.float32_tolerance(-300000.0)==0.0625 and Contact.float32_tolerance(0.0)==0.00001,"Source vertex comparison tolerance follows actual Float32 ULP at large negative geoid height")

func run()->void:
	actual_nonvertex();supported_profiles()
	print("SOURCE SURFACE CONTACT PATCH TESTS: ",checks," checks, ",failures," failures; threeindependentnativeheights, JSONonly, parkednonvertex117, atomicedits")
	quit(1 if failures else 0)
