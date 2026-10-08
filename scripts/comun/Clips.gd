class_name Clips
extends RefCounted


static func find(anim: AnimationPlayer, wanted: String) -> String:
	for c in anim.get_animation_list():
		var s := String(c)
		if s == wanted or s.ends_with("/" + wanted) or s.ends_with("|" + wanted) or s.ends_with("_" + wanted):
			return s
	return ""
