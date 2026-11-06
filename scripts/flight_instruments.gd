extends RefCounted
# Presentation/session controls for the classic console. Camera selection and
# pause add no save fields and never mutate flight dynamics or navigation.
const COCKPIT_VIEWS:=["front","rear"]
const VIEW_LABELS:={"front":"ВИД ВПЕРЁД","rear":"ВИД НАЗАД","external":"ВНЕШНИЙ ВИД"}
var cockpit_view:="front"
var paused:=false

func reset()->void:
	cockpit_view="front";paused=false

func view_key(external:bool)->String:
	return "external" if external else cockpit_view

func view_label(external:bool)->String:
	return str(VIEW_LABELS.get(view_key(external),VIEW_LABELS.front))

func cycle_view(external:bool)->bool:
	if external:
		cockpit_view="front";return false
	var index:=COCKPIT_VIEWS.find(cockpit_view)
	if index<0:
		cockpit_view="front";return false
	if index+1==COCKPIT_VIEWS.size():return true
	cockpit_view=COCKPIT_VIEWS[index+1];return false

func camera_pose(position:Vector3,attitude:Quaternion,external:bool,span:float)->Dictionary:
	# Existing authored chase-camera dimensions are retained. Cockpit views are
	# genuine camera rotations; the ship attitude and thrust axis stay unchanged.
	var eye:=position;var orientation:=attitude
	if external:
		eye+=Basis(attitude)*Vector3(0,span*0.34,span*1.65)
		orientation=(attitude*Quaternion(Vector3.RIGHT,-atan(0.25/1.65))).normalized()
	else:
		var yaw:=PI if cockpit_view=="rear" else 0.0
		orientation=(attitude*Quaternion(Vector3.UP,yaw)).normalized()
	return {"position":eye,"attitude":orientation}
