extends RefCounted
# Isolated, bounded map data. A map owns its catalogue and never edits Navigation.
const GalaxyData=preload("res://scripts/galaxy.gd")
const Kernel=preload("res://scripts/source_galaxy.gd")
const Metadata=preload("res://scripts/source_system_metadata.gd")
const Names=preload("res://scripts/source_planet_names.gd")
const MAP_DATA_PATH:="res://data/ffe_galactic_map.json"
const SECTOR_LY:=8.0
const DISPLAY_ORIGIN:=Vector2i(0x1718,0x1524)
const MIN_RAW:=0
const MAX_RAW:=8191
const MAX_VISIBLE_ROWS:=9*62
const OVERVIEW_SIZE:=Vector2i(320,158)
var galaxy:RefCounted
var native:=true
var current_id:=GalaxyData.SOL_ID
var selected_id:=GalaxyData.SOL_ID
var jump_range_ly:=0.0
var fuel:=0
var fuel_capacity:=0
var jump_blocked_reason:=""
var center_sector:=Vector2.ZERO
var rows:Array=[]
var current:Dictionary={}
var selected:Dictionary={}
var search_results:Array=[]
var last_error:=""
var _kernel:=Kernel.new()
var _map_data:Dictionary={}

static func prepare_shared_resources()->bool:
	# These preserved text helpers have static read-only caches. Warm them on
	# the UI thread before constructing a completely isolated worker catalogue.
	return Metadata._load() and Names._load()

static func _number(value:Variant,low:float,high:float,whole:=false)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high and (not whole or float(value)==floorf(float(value)))

static func raw_sector(display:Vector2i)->Vector2i:return display+DISPLAY_ORIGIN
static func display_sector(raw:Vector2i)->Vector2i:return raw-DISPLAY_ORIGIN
static func valid_sector(raw:Vector2i)->bool:return raw.x>=MIN_RAW and raw.x<=MAX_RAW and raw.y>=MIN_RAW and raw.y<=MAX_RAW
static func clamp_center(value:Vector2)->Vector2:return Vector2(clampf(value.x,0,8191.999),clampf(value.y,0,8191.999))

func configure_state(state:Dictionary)->bool:
	if not state.get("native",true) is bool:return false
	for key in ["current_id","selected_id"]:
		if not _number(state.get(key,GalaxyData.SOL_ID),0,4294967295.0,true):return false
	if not _number(state.get("jump_range_ly",0.0),0,1000000):return false
	for key in ["fuel","fuel_capacity"]:
		if not _number(state.get(key,0),0,2147483647,true):return false
	if int(state.get("fuel",0))>int(state.get("fuel_capacity",0)):return false
	if not state.get("jump_blocked_reason","") is String:return false
	var candidate:=GalaxyData.new()
	if bool(state.get("native",true)) and not candidate.configure_native():return false
	var origin:Dictionary=candidate.get_system(int(state.get("current_id",GalaxyData.SOL_ID)))
	var target:Dictionary=candidate.get_system(int(state.get("selected_id",GalaxyData.SOL_ID)))
	if origin.is_empty() or target.is_empty():return false
	galaxy=candidate;native=bool(state.get("native",true));current_id=int(origin.id);selected_id=int(target.id)
	current=origin;selected=target;jump_range_ly=float(state.get("jump_range_ly",0));fuel=int(state.get("fuel",0));fuel_capacity=int(state.get("fuel_capacity",0))
	jump_blocked_reason=str(state.get("jump_blocked_reason",""));center_sector=sector_position(target);rows=[];search_results=[];last_error=""
	return true

func sector_position(row:Dictionary)->Vector2:
	if native and row.get("position_q16") is Array and row.position_q16.size()==3:
		return Vector2(float(row.position_q16[0])/65536.0,float(row.position_q16[1])/65536.0)
	var point:Array=row.get("position_ly",[0.0,0.0,0.0])
	return Vector2(float(DISPLAY_ORIGIN.x)+float(point[0])/8.0,float(DISPLAY_ORIGIN.y)+float(point[1])/8.0)

func center_ly()->Array:
	if not native:return [(float(center_sector.x)-DISPLAY_ORIGIN.x)*8.0,(float(center_sector.y)-DISPLAY_ORIGIN.y)*8.0,0.0]
	return [(float(center_sector.x)-float(galaxy._sol_q16[0])/65536.0)*8.0,(float(center_sector.y)-float(galaxy._sol_q16[1])/65536.0)*8.0,0.0]

func load_sector_window(center:Vector2)->bool:
	if galaxy==null or not center.is_finite():return false
	center_sector=clamp_center(center);rows=[]
	if not native:
		rows=galaxy.all();return true
	var x:=floori(center_sector.x);var y:=floori(center_sector.y)
	for dy in range(-1,2):
		for dx in range(-1,2):rows.append_array(galaxy.sector_page(x+dx,y+dy))
	return rows.size()<=MAX_VISIBLE_ROWS

func select(id:int)->bool:
	if galaxy==null:return false
	var candidate:Dictionary=galaxy.get_system(id)
	if candidate.is_empty():return false
	selected_id=id;selected=candidate;return true

func distance_ly(row:Dictionary)->float:
	var a:Array=current.get("position_ly",[]);var b:Array=row.get("position_ly",[])
	if a.size()!=3 or b.size()!=3:return INF
	var total:=0.0
	for axis in range(3):total+=pow(float(a[axis])-float(b[axis]),2)
	return sqrt(total)

func jump_state(row:Dictionary={})->Dictionary:
	var target:Dictionary=selected if row.is_empty() else row
	var distance:=distance_ly(target);var required:=ceili(distance/4.0) if is_finite(distance) and distance>0 else 0
	var reason:=jump_blocked_reason
	if int(target.get("id",-1))==current_id:reason="Вы уже в этой системе."
	elif distance>jump_range_ly:reason="Система за пределами дальности гипердвигателя."
	elif required>fuel:reason="Недостаточно гипертоплива."
	return {"distance_ly":distance,"fuel_required":required,"reachable":reason.is_empty(),"reason":reason,"fuel_profile":"current-navigation-4ly-per-unit-adapter"}

static func _search_name(row:Dictionary,query:String)->bool:
	var first:=str(row.get("name","")).to_lower();var second:=str(row.get("original_name","")).to_lower()
	if first.contains(query) or second.contains(query):return true
	var aliases:={"sol":"солнце","alpha centauri":"альфа центавра","sirius":"сириус","wolf":"вольф","cygni":"лебедя","cassiopeia":"кассиопеи","ross":"росс","lave":"лейв","diso":"дисо","leesti":"листи","zaonce":"заонс","gateway":"гейтвей"}
	for english in aliases:
		if second.contains(english) and str(aliases[english]).contains(query):return true
	return false

func search(query:String)->Array:
	search_results=[]
	if galaxy==null:return search_results
	var needle:=query.strip_edges().to_lower()
	if needle.is_empty():return search_results
	var seen:Dictionary={}
	for row:Dictionary in rows:
		if _search_name(row,needle):search_results.append(row.duplicate(true));seen[int(row.id)]=true
	if native and _kernel._load():
		# Original named sectors are finite and globally searchable. Procedural
		# names are searched in the displayed region; no fake global index.
		for sector in range(49):
			var xy:=int(_kernel._tables["6799"].decode_u32(sector*4));var x:=xy&65535;var y:=(xy>>16)&65535
			var start:=int(_kernel._tables.starts.decode_u32(sector*4));var end:=int(_kernel._tables.starts.decode_u32((sector+1)*4))
			for index in range(end-start):
				var id:=x|(y<<13)|(index<<26)
				if seen.has(id):continue
				var row:Dictionary=galaxy.get_system(id)
				if not row.is_empty() and _search_name(row,needle):search_results.append(row);seen[id]=true
		var gateway:Dictionary=galaxy.get_system(0x1aa51717)
		if not gateway.is_empty() and not seen.has(int(gateway.id)) and _search_name(gateway,needle):search_results.append(gateway)
	search_results.sort_custom(func(a:Dictionary,b:Dictionary):return distance_ly(a)<distance_ly(b))
	if search_results.size()>64:search_results.resize(64)
	return search_results.duplicate(true)

static func map_point(position:Array,center:Array,yaw:float,tilt:float,pixels_per_ly:float,screen_center:Vector2)->Dictionary:
	if position.size()!=3 or center.size()!=3 or not is_finite(yaw) or not is_finite(tilt) or not is_finite(pixels_per_ly) or pixels_per_ly<=0:return {}
	var x:=float(position[0])-float(center[0]);var ground:float=float(position[1])-float(center[1]);var height:=float(position[2])-float(center[2])
	if not is_finite(x) or not is_finite(ground) or not is_finite(height):return {}
	var horizontal:=x*cos(yaw)-ground*sin(yaw);var depth:=x*sin(yaw)+ground*cos(yaw)
	var cy:=depth*sin(tilt)-height*cos(tilt);var cz:=depth*cos(tilt)+height*sin(tilt)
	var distance:=maxf(32.0,650.0/pixels_per_ly)
	if distance+cz<=distance*0.12:return {}
	var perspective:=distance/(distance+cz)
	var point:=screen_center+Vector2(horizontal,cy)*pixels_per_ly*perspective
	if not point.is_finite() or not is_finite(perspective):return {}
	return {"point":point,"perspective":perspective,"depth":cz}

static func pan_delta(delta:Vector2,yaw:float,tilt:float,pixels_per_ly:float)->Vector2:
	if not delta.is_finite() or not is_finite(pixels_per_ly) or pixels_per_ly<=0:return Vector2.ZERO
	var a:=delta.x/pixels_per_ly;var b:=delta.y/(pixels_per_ly*maxf(0.15,sin(tilt)))
	return Vector2(a*cos(yaw)+b*sin(yaw),-a*sin(yaw)+b*cos(yaw))/8.0

func overview_density(x:int,y:int,scale:int=16)->int:
	# F853's overview argument skips the handcrafted-sector override and
	# attenuates the small-scale hash. At scale>=16 it returns the bilinear
	# field directly. Kernel.density() is the different scale-zero sector path.
	if x<0 or x>8191 or y<0 or y>8191 or scale<1 or scale>255 or not _kernel._load():return 0
	var eax:=x<<3;var edx:=y<<3;var index:=((edx&0xfe00)+(eax>>7))>>2
	var grid:PackedByteArray=_kernel._tables.density
	var c:=int(grid[index]);var right:=int(grid[index+1]);var down:=int(grid[index+128]);var diagonal:=int(grid[index+129])
	eax=(eax&511)<<6;edx=(edx&511)<<6
	var value:=Kernel._s32((right-c)*eax+(down-c)*edx)
	var cross:=Kernel._s32(eax*edx)>>15
	value=Kernel._s32(value+Kernel._s32(cross*(diagonal-down-right+c)))
	value=Kernel._s32(Kernel._s32(value*2)+(c<<16))>>8
	if scale>=16:return value
	var sample:=Kernel._s32(eax+value);sample=(Kernel._s32(sample^(Kernel._s32(eax*edx)>>15))>>5)&127
	var rate:=int(_kernel._tables["6805"].decode_u32(sample*4))
	var factor:=Kernel._s32(0xffff-(Kernel._s32((16-scale)*rate)>>5))
	return (Kernel._s32(value*factor)&0xffffffff)>>16

func overview_pixels(scale:int)->PackedByteArray:
	if scale<1 or scale>255:return PackedByteArray()
	if _map_data.is_empty():
		var value:Variant=JSON.parse_string(FileAccess.get_file_as_string(MAP_DATA_PATH))
		if not value is Dictionary or value.get("schema")!=1 or value.get("source_sha256")!=Metadata.SOURCE_SHA:return PackedByteArray()
		if not value.get("overview_palette_indices") is Array or value.overview_palette_indices.size()!=64 or not value.get("overview_palette_rgb6") is Array or value.overview_palette_rgb6.size()!=16:return PackedByteArray()
		_map_data=value
	var pixels:=PackedByteArray();pixels.resize(OVERVIEW_SIZE.x*OVERVIEW_SIZE.y*4)
	var world_x_start:=floori(center_sector.x)-(scale>>1)+160*scale
	var world_y_start:=floori(center_sector.y)+(scale>>1)-79*scale
	# F847 visits screen x319..0 and y157..0. Store row-major pixels for Godot
	# without changing the original world coordinate associated with a pixel.
	for py in range(OVERVIEW_SIZE.y):
		var world_y:=world_y_start+(157-py)*scale
		for px in range(OVERVIEW_SIZE.x):
			var world_x:=world_x_start-(319-px)*scale
			var index:=clampi(overview_density(world_x,world_y,scale)>>10,0,63)
			var palette:=int(_map_data.overview_palette_indices[index]);var rgb:Array=_map_data.overview_palette_rgb6[palette]
			var at:=(py*OVERVIEW_SIZE.x+px)*4
			pixels[at]=int(rgb[0])<<2;pixels[at+1]=int(rgb[1])<<2;pixels[at+2]=int(rgb[2])<<2;pixels[at+3]=255
	return pixels

func overview_sector(pixel:Vector2,scale:int)->Vector2:
	var world_x_start:=floori(center_sector.x)-(scale>>1)+160*scale
	var world_y_start:=floori(center_sector.y)+(scale>>1)-79*scale
	return clamp_center(Vector2(world_x_start-(319-pixel.x)*scale,world_y_start+(157-pixel.y)*scale))
