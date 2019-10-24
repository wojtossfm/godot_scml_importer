extends Control

var _thread : Thread = null


class SCMLFile:
	var id : int
	var name : String
	var width : int
	var height: int
	var pivot_x : float
	var pivot_y : float
	
	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		self.name = attributes["name"]
		self.width = int(attributes["width"])
		self.height = int(attributes["height"])
		self.pivot_x = float(attributes["pivot_x"])
		self.pivot_y = float(attributes["pivot_y"])


class SCMLFolder:
	var id : int
	var files : Dictionary
	
	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		self.files = {}

	func add_file(attributes: Dictionary) -> SCMLFile:
		var obj = SCMLFile.new()
		obj.from_attributes(attributes)
		self.files[obj.id] = obj
		return obj


class SCMLObjectInfo:
	var name: String
	var type: String
	var width : float
	var height : float
	
	func from_attributes(attributes: Dictionary):
		self.name = attributes["name"]
		self.type = attributes["type"]
		self.width = float(attributes["w"])
		self.height = float(attributes["h"])


const SCML_NO_PARENT = -1


class SCMLBoneReference:
	var id : int
	var parent : int
	var timeline : int
	var key : int
	
	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		self.parent = int(attributes.get("parent", SCML_NO_PARENT))
		self.timeline = int(attributes["timeline"])
		self.key = int(attributes["key"])


class SCMLObjectReference:
	var id : int
	var parent : int
	var timeline : int
	var key : int
	var z_index : int
	
	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		self.parent = int(attributes.get("parent", SCML_NO_PARENT))
		self.timeline = int(attributes["timeline"])
		self.key = int(attributes["key"])
		self.z_index = int(attributes["z_index"])


class SCMLMainlineKey:
	var id: int
	var time: float
	var object_references : Dictionary
	var bone_references : Dictionary
	
	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		self.time = float(attributes.get("time", 0)) / 100
		self.object_references = {}
		self.bone_references = {}
	
	func add_bone_reference(attributes: Dictionary) -> SCMLBoneReference:
		var obj = SCMLBoneReference.new()
		obj.from_attributes(attributes)
		self.bone_references[obj.id] = obj
		return obj
	
	func add_object_reference(attributes: Dictionary) -> SCMLObjectReference:
		var obj = SCMLObjectReference.new()
		obj.from_attributes(attributes)
		self.object_references[obj.id] = obj
		return obj


class SCMLMainline:
	var keys: Dictionary
	
	func from_attributes(attributes: Dictionary):
		assert attributes.empty()
		self.keys = {}
	
	func add_key(attributes: Dictionary) -> SCMLMainlineKey:
		var obj = SCMLMainlineKey.new()
		obj.from_attributes(attributes)
		self.keys[obj.id] = obj
		return obj


class Utilities:
	
	static func float_or_null(value):
		return float(value) if value != null else value


class SCMLBone:
	var utilities = Utilities
	# untyped to support null
	var x
	var y
	var pivot_x
	var pivot_y
	var scale_x
	var scale_y
	var angle
	var alpha
	
	func from_attributes(attributes: Dictionary):
		self.x = self.utilities.float_or_null(attributes.get('x'))
		self.y = self.utilities.float_or_null(attributes.get('y'))
		self.pivot_x = self.utilities.float_or_null(attributes.get('pivot_x'))
		self.pivot_y = self.utilities.float_or_null(attributes.get('pivot_y'))
		self.scale_x = self.utilities.float_or_null(attributes.get('scale_x'))
		self.scale_y = self.utilities.float_or_null(attributes.get('scale_y'))
		self.angle = self.utilities.float_or_null(attributes.get('angle'))
		self.alpha = self.utilities.float_or_null(attributes.get('a', 1))


class SCMLObject:
	var utilities = Utilities
	var folder: int
	var file: int
	# untyped to support null
	var x
	var y
	var pivot_x
	var pivot_y
	var scale_x
	var scale_y
	var angle
	var alpha
	
	func from_attributes(attributes: Dictionary):
		self.folder = int(attributes["folder"])
		self.file = int(attributes["file"])
		self.x = self.utilities.float_or_null(attributes.get('x'))
		self.y = self.utilities.float_or_null(attributes.get('y'))
		self.pivot_x = self.utilities.float_or_null(attributes.get('pivot_x'))
		self.pivot_y = self.utilities.float_or_null(attributes.get('pivot_y'))
		self.scale_x = self.utilities.float_or_null(attributes.get('scale_x'))
		self.scale_y = self.utilities.float_or_null(attributes.get('scale_y'))
		self.angle = self.utilities.float_or_null(attributes.get('angle'))
		self.alpha = self.utilities.float_or_null(attributes.get('a', 1))


class SCMLTimelineKey:
	var id: int
	var spin: int
	var time: float
	var objects : Array
	var bones : Array
	
	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		self.spin = int(attributes.get("spin", 0))
		self.time = float(attributes.get("time", 0)) / 100
		self.objects = []
		self.bones = []
	
	func add_object(attributes: Dictionary) -> SCMLObject:
		var obj = SCMLObject.new()
		obj.from_attributes(attributes)
		self.objects.append(obj)
		return obj
	
	func add_bone(attributes: Dictionary) -> SCMLBone:
		var obj = SCMLBone.new()
		obj.from_attributes(attributes)
		self.bones.append(obj)
		return obj


class SCMLTimeline:
	var id : int
	var name : String
	var object_type : String
	var keys: Dictionary
	
	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		self.name = attributes["name"]
		self.object_type = attributes.get("object_type", 'object')
		self.keys = {}
	
	func add_key(attributes: Dictionary) -> SCMLTimelineKey:
		var obj = SCMLTimelineKey.new()
		obj.from_attributes(attributes)
		self.keys[obj.id] = obj
		return obj


class SCMLAnimation:
	var id: int
	var length: float
	var interval: float
	var name: String
	var mainline: SCMLMainline
	var timelines : Dictionary
	
	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		self.length = float(attributes["length"]) / 100
		self.interval = float(attributes["interval"]) / 100
		self.name = attributes["name"]
		self.timelines = {}
	
	func add_mainline(attributes: Dictionary) -> SCMLMainline:
		var obj = SCMLMainline.new()
		obj.from_attributes(attributes)
		assert self.mainline == null
		self.mainline = obj
		return obj
	
	func add_timeline(attributes: Dictionary) -> SCMLTimeline:
		var obj = SCMLTimeline.new()
		obj.from_attributes(attributes)
		self.timelines[obj.id] = obj
		return obj


class SCMLEntity:
	var id: int
	var name: String
	var object_infos : Dictionary
	var animations : Dictionary
	
	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		self.name = attributes["name"]
		self.object_infos = {}
		self.animations = {}
	
	func add_object_info(attributes: Dictionary) -> SCMLObjectInfo:
		var obj = SCMLObjectInfo.new()
		obj.from_attributes(attributes)
		self.object_infos[obj.name] = obj
		return obj
	
	func add_animation(attributes: Dictionary) -> SCMLAnimation:
		var obj = SCMLAnimation.new()
		obj.from_attributes(attributes)
		self.animations[obj.id] = obj
		return obj


class SCMLData:
	var folders : Dictionary
	var entities : Dictionary

	func add_folder(attributes) -> SCMLFolder:
		var folder = SCMLFolder.new()
		folder.from_attributes(attributes)
		self.folders[folder.id] = folder
		return folder

	func add_entity(attributes) -> SCMLEntity:
		var obj = SCMLEntity.new()
		obj.from_attributes(attributes)
		self.entities[obj.id] = obj
		return obj


func _parse_data(path: String) -> SCMLData:
	var parser = XMLParser.new()
	var error = parser.open(path)
	if error != 0:
		print("Open error: ", error)
		return null
	
	var parsed_data = SCMLData.new()
	var parents = []

	while true:
		error = parser.read()
		if error == ERR_FILE_EOF:
			print("Finished processing XML")
			break
		if error != 0:
			print("Read Error: ", error)
			break
		if parser.get_node_type() == XMLParser.NODE_ELEMENT:
			var node_name = parser.get_node_name()
			
			if node_name.begins_with("?xml"):
				continue
			
			var attributes = {}
			var item = null
			var last_parent = parents.back() if parents.size() > 0 else null
			for index in range(parser.get_attribute_count()):
				attributes[parser.get_attribute_name(index)] = parser.get_attribute_value(index)

			match node_name:
				"spriter_data":
					assert parents.size() == 0
					item = parsed_data
				"folder":
					assert parents.size() == 1
					item = last_parent.add_folder(attributes)
				"file":
					assert parents.size() == 2
					item = last_parent.add_file(attributes)
				"entity":
					assert parents.size() == 1
					item = last_parent.add_entity(attributes)
				"obj_info":
					assert parents.size() == 2
					item = last_parent.add_object_info(attributes)
				"animation":
					assert parents.size() == 2
					item = last_parent.add_animation(attributes)
				"mainline":
					assert parents.size() == 3
					item = last_parent.add_mainline(attributes)
				"timeline":
					assert parents.size() == 3
					item = last_parent.add_timeline(attributes)
				"key": # same indentation for mainline and timeline
					assert parents.size() == 4
					item = last_parent.add_key(attributes)
				"bone_ref":
					assert parents.size() == 5
					item = last_parent.add_bone_reference(attributes)
				"object_ref":
					assert parents.size() == 5
					item = last_parent.add_object_reference(attributes)
				"object":
					assert parents.size() == 5
					item = last_parent.add_object(attributes)
				"bone":
					assert parents.size() == 5
					item = last_parent.add_bone(attributes)

			var has_children = not parser.is_empty()
			if item and has_children:
				parents.append(item)
		elif parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			parents.pop_back()
	return parsed_data


func _add_animation_key(animation: Animation, path: NodePath, time: float, value, spin):
	if value == null:
		return
	var easing = 1 if spin == 0 else -1
	var track_index = animation.find_track(path)
	if track_index < 0:
		track_index = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track_index, path)
		animation.value_track_set_update_mode(track_index, Animation.UPDATE_CONTINUOUS)
		animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)
	var count = animation.track_get_key_count(track_index)
	if count > 0 and String(path).ends_with('degrees'):
		var key_indices = Array(animation.value_track_get_key_indices (track_index, 0, -animation.length))
		key_indices.sort() # make sure it is sorted
		var previous_key_idx = key_indices[key_indices.size() - 1]
		var previous_ease = animation.track_get_key_transition(track_index, previous_key_idx)
		var previous_value = animation.track_get_key_value(track_index, previous_key_idx)
		var previous_time = animation.track_get_key_time(track_index, previous_key_idx)
		assert previous_time < time
		var input_value = value
		while previous_ease < 0:
			if value > previous_value:
				value -= 360
			elif value + 360 > previous_value:
				break
			else:
				value += 360
		while previous_ease > 0:
			if previous_value > value:
				value += 360
			elif value - 360 < previous_value:
				break
			else:
				value -= 360
		value += 0
		input_value = 0
	animation.track_insert_key(track_index, time, value, easing)
	var key_idx = animation.track_find_key(track_index, time, true)
	assert animation.track_get_key_transition(track_index, key_idx) == easing
	assert animation.track_get_key_value(track_index, key_idx) == value
	return track_index


func _process_path(path: String):
	print("Processing in thread: ", path)
	
	var parsed_data = _parse_data(path)
	if parsed_data == null:
		return null
	
	var imported = Node2D.new()
	imported.name = 'Imported'
	add_child(imported)
	
	var resources = {}
	for scml_folder in parsed_data.folders.values():
		for scml_file in scml_folder.files.values():
			var key = "{folder_id} : {file_id}".format({'folder_id': scml_folder.id, 'file_id': scml_file.id})
			var resource = load(path.get_base_dir().plus_file(scml_file.name))
			resources[key] = resource
			var sprite = Sprite.new()
			sprite.texture = resource

	for scml_entity in parsed_data.entities.values():
		var skeleton = Skeleton2D.new()
		skeleton.name = scml_entity.name
		imported.add_child(skeleton)
		skeleton.set_owner(imported)
		
		var animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		skeleton.add_child(animation_player)
		skeleton.rotation_degrees = -180
		animation_player.set_owner(imported)
		var bones = {
			'skeleton': skeleton
		}
		var objects = {}
		
		for scml_obj_info in scml_entity.object_infos.values():
			var bone = Bone2D.new()
			bone.name = scml_obj_info.name
			bone.set_default_length(scml_obj_info.width)
			bones[bone.name] = bone
		
		for scml_animation in scml_entity.animations.values():
			if scml_animation.name != "Idle":
				continue
			var animation = Animation.new()
			animation.length = scml_animation.length
			animation.step = 0.01
			animation_player.add_animation(scml_animation.name, animation)
			var scml_mainline_key_ids = scml_animation.mainline.keys.keys()
			scml_mainline_key_ids.sort()
			for scml_mainline_key_id in scml_mainline_key_ids:
				var scml_mainline_key = scml_animation.mainline.keys[scml_mainline_key_id]
				var is_setup = scml_mainline_key.time == 0
				if not is_setup:
					# not sure what the further mainlines give us for now
					break
					
				for scml_bone_ref in scml_mainline_key.bone_references.values():
					var scml_timeline = scml_animation.timelines[scml_bone_ref.timeline]
					assert scml_timeline.object_type == 'bone'
					var bone = bones[scml_timeline.name]
							
					if is_setup:
						var parent = bones['skeleton']
						if scml_bone_ref.parent > -1:
							var scml_parent_bone_reference = scml_mainline_key.bone_references[scml_bone_ref.parent]
							var scml_parent_timeline = scml_animation.timelines[scml_parent_bone_reference.timeline]
							assert scml_parent_timeline.object_type == 'bone'
							parent = bones[scml_parent_timeline.name]
						if bone.get_parent() == null:
							parent.add_child(bone)
						else:
							assert parent == bone.get_parent()
						bone.set_owner(imported)

					var scml_timeline_key_ids = scml_timeline.keys.keys()
					scml_timeline_key_ids.sort()
					for scml_timeline_key_id in scml_timeline_key_ids:
						var scml_timeline_key = scml_timeline.keys[scml_timeline_key_id]
						for scml_bone in scml_timeline_key.bones:
							var x = scml_bone.x if scml_bone.x != null else 0
							var y = scml_bone.y if scml_bone.y != null else 0
							var angle = scml_bone.angle if scml_bone.angle != null else null
#							angle -= 180
							var position = Vector2(x, y)
							if is_setup:
								bone.position = position
								if scml_bone.angle != null:
									bone.rotation_degrees = scml_bone.angle
							
							var node_path = skeleton.get_path_to(bone)
							_add_animation_key(animation, String(node_path) + ':position', scml_timeline_key.time, position, 0)
							_add_animation_key(animation, String(node_path) + ':rotation_degrees', scml_timeline_key.time, angle, scml_timeline_key.spin)
					
				for scml_object_ref in scml_mainline_key.object_references.values():
					var scml_timeline = scml_animation.timelines[scml_object_ref.timeline]
					assert scml_timeline.object_type == 'object'
					var scml_timeline_key_ids = scml_timeline.keys.keys()
					scml_timeline_key_ids.sort()
					for scml_timeline_key_id in scml_timeline_key_ids:
						var scml_timeline_key = scml_timeline.keys[scml_timeline_key_id]
						for scml_object in scml_timeline_key.objects:
							var key = "{folder_id} : {file_id}".format({
								'folder_id': scml_object.folder, 
								'file_id': scml_object.file
							})
							var object = objects.get(key)
							var position = Vector2(scml_object.x, scml_object.y)
							var angle = scml_object.angle
#							angle -= 180
							var modulate = Color(1, 1, 1, scml_object.alpha)
							if object == null:
								object = Sprite.new()
								object.name = key
								objects[key] = object
								object.texture = resources[key]
								object.offset = Vector2(0,0)
#								object.offset = Vector2(-object.texture.get_width(), -object.texture.get_height())
								object.offset = Vector2(0, -object.texture.get_height())
#								object.offset = Vector2(-object.texture.get_width(), 0)
								object.flip_v = true
								object.z_as_relative = false
								object.centered = false
								
								var parent = bones['skeleton']
								if scml_object_ref.parent > -1:
									var scml_parent_bone_reference = scml_mainline_key.bone_references[scml_object_ref.parent]
									var scml_parent_timeline = scml_animation.timelines[scml_parent_bone_reference.timeline]
									assert scml_parent_timeline.object_type == 'bone'
									parent = bones[scml_parent_timeline.name]

								parent.add_child(object)
								object.set_owner(imported)
								object.position = position
								object.rotation_degrees = angle
								object.modulate = modulate
								
							object.z_index = scml_object_ref.z_index
							var node_path = skeleton.get_path_to(object)
							_add_animation_key(animation, String(node_path) + ':position', scml_timeline_key.time, position, 0)
							_add_animation_key(animation, String(node_path) + ':modulate', scml_timeline_key.time, modulate, 0)
							_add_animation_key(animation, String(node_path) + ':rotation_degrees', scml_timeline_key.time, angle, scml_timeline_key.spin)
			# TODO : add animation cleanup - if all values on track are the same then
			# remove all the values but the first one
		animation_player.current_animation = "Idle"
	
	var scene = PackedScene.new()

	var result = scene.pack(imported)
	if result == OK:
		var err = ResourceSaver.save("res://test-{time}.tscn".format({'time': OS.get_system_time_msecs()}), scene) # or user://...
		print("Save result error:" + str(err))
	print("Finished processing data. Pack result: " + str(result))
	
	$VBoxContainer/LoadingLabel.visible = false;


func _on_save():
	var scene = PackedScene.new()
	# only node and rigid are now packed
	var result = scene.pack(get_node("Imported"))
	if result == OK:
	    ResourceSaver.save("res://imported.scn", scene) # or user://...


func _on_file_selected(path: String):
	if _thread != null and _thread.is_active():
		print("Cannot start loading new SCML while still loading previous SCML")
		return
	_thread = Thread.new()
	$VBoxContainer/LoadingLabel.visible = true;
	_process_path(path)
#	_thread.start(self, "_process_path", path)


func _on_import_button_pressed():
	$LoadDialog.popup()


# Called when the node enters the scene tree for the first time.
func _ready():
	$LoadDialog.connect("file_selected", self, "_on_file_selected")
	$VBoxContainer/Button.connect("pressed", self, "_on_import_button_pressed")
	_process_path("res://BlacksmithGuyParts/Animations.scml")