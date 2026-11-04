		var contact:=SegmentBox.intersect(previous,ship.position,expanded)
		if not contact.is_empty() and float(contact.time)<first:
			best=contact;first=float(contact.time)
			if contact.inside:best.position=Vector3(previous.x,expanded.end.y+0.05,previous.z)
	if best.is_empty():return
	ship.position=Vector3(best.position)+Vector3(best.normal)*0.05
	var inward:float=ship.velocity.dot(best.normal)
	if inward<0:
		ship.hull=maxf(0,ship.hull-maxf(0,-inward-6)*2)
		ship.velocity-=Vector3(best.normal)*inward
	ship.brake();landing=false;taking_off=false
	message="Столкновение со зданием. Снизьте скорость и отойдите от фасада."

