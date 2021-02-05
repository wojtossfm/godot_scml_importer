tool
extends AnimationPlayer

func _ready():
	if not self.has_animation("Idle"):
		printerr("SCML Importer: Setting rest pose needs an animation named 'Idle'")
		return
	current_animation = "Idle"
	advance(0)
	var skeleton: Skeleton2D = get_parent()
	for idx in range(skeleton.get_bone_count()):
		var bone: Bone2D = skeleton.get_bone(idx)
		bone.rest = bone.transform
	stop(false)
