extends EditorImportPlugin

# Tested against
# * spriter_data scml_version="1.0" generator="BrashMonkey Spriter" generator_version="r11
tool

var _thread : Thread = null
var _imported : Node2D = null

class SCMLFile:
	var id : int
	var name : String
	var width : int
	var height: int
	var pivot_x : float
	var pivot_y : float
	var resource : StreamTexture
	
	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		self.name = attributes["name"]
		self.width = int(attributes["width"])
		self.height = int(attributes["height"])
		self.pivot_x = float(attributes["pivot_x"])
		self.pivot_y = float(attributes["pivot_y"])
		self.resource = null # will be loaded later


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
		assert(attributes.empty())
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
		self.scale_x = self.utilities.float_or_null(attributes.get('scale_x', 1))
		self.scale_y = self.utilities.float_or_null(attributes.get('scale_y', 1))
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
		assert(self.mainline == null)
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
					assert(parents.size() == 0)
					item = parsed_data
				"folder":
					assert(parents.size() == 1)
					item = last_parent.add_folder(attributes)
				"file":
					assert(parents.size() == 2)
					item = last_parent.add_file(attributes)
				"entity":
					assert(parents.size() == 1)
					item = last_parent.add_entity(attributes)
				"obj_info":
					assert(parents.size() == 2)
					item = last_parent.add_object_info(attributes)
				"animation":
					assert(parents.size() == 2)
					item = last_parent.add_animation(attributes)
				"mainline":
					assert(parents.size() == 3)
					item = last_parent.add_mainline(attributes)
				"timeline":
					assert(parents.size() == 3)
					item = last_parent.add_timeline(attributes)
				"key": # same indentation for mainline and timeline
					assert(parents.size() == 4)
					item = last_parent.add_key(attributes)
				"bone_ref":
					assert(parents.size() == 5)
					item = last_parent.add_bone_reference(attributes)
				"object_ref":
					assert(parents.size() == 5)
					item = last_parent.add_object_reference(attributes)
				"object":
					assert(parents.size() == 5)
					item = last_parent.add_object(attributes)
				"bone":
					assert(parents.size() == 5)
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
	if count > 0 and String(path).ends_with(':rotation_degrees'):
		var previous_key_index = count - 1
		var previous_ease = animation.track_get_key_transition(track_index, previous_key_index)
		var previous_value = animation.track_get_key_value(track_index, previous_key_index)
		var previous_time = animation.track_get_key_time(track_index, previous_key_index)
		assert(previous_time < time)
		var input_value = value
		# not the prettiest thing but only way I could figure out to
		# adapt the values to adhere to the spin direction. I'm 90% sure
		# this can be simplified to better work with cases where an
		# over 360 spin is present but imagine those are rare and
		# currently not needed by me.
		while previous_ease < 0:
			if value > previous_value:
				value -= 360
			elif (value + 360) <= previous_value:
				value += 360
			else:
				break
		while previous_ease > 0:
			if value < previous_value:
				value += 360
			elif (value - 360) >= previous_value:
				value -= 360
			else:
				break
	animation.track_insert_key(track_index, time, value, easing)
	var key_index = animation.track_find_key(track_index, time, true)
	assert(animation.track_get_key_transition(track_index, key_index) == easing)
	assert(animation.track_get_key_value(track_index, key_index) == value)
	return track_index


func _optimize_animation(animation: Animation):
	for track_index in range(animation.get_track_count()):
		var to_remove = []
		var keys = animation.track_get_key_count(track_index)
		for key_index in range(keys - 1, 0, -1):
			var current_transition = animation.track_get_key_transition(track_index, key_index)
			var current_value = animation.track_get_key_value(track_index, key_index)
			var previous_transition = animation.track_get_key_transition(track_index, key_index - 1)
			var previous_value = animation.track_get_key_value(track_index, key_index - 1)

			var following_transition = current_transition
			var following_value = current_value
			if key_index < keys - 1:
				following_transition = animation.track_get_key_transition(track_index, key_index + 1)
				following_value = animation.track_get_key_value(track_index, key_index + 1)

			if current_transition == previous_transition and current_transition == following_transition \
				and current_value == previous_value and current_value == following_value:
				to_remove.append(key_index)
		for key_index in to_remove:
			animation.track_remove_key(track_index, key_index)


func _optimize_animations_for_blends(animation_player: AnimationPlayer):
	var animation_names = animation_player.get_animation_list()
	for animation_name in animation_names:
		var animation = animation_player.get_animation(animation_name)
		for track_index in range(animation.get_track_count()):
			var path = animation.track_get_path(track_index)

			if not String(path).ends_with(':rotation_degrees'):
				continue

			var value = animation.track_get_key_value(track_index, 0)
			var diff = int(value / 360) * 360

			if value - diff < -180: # value/diff are negative
				diff -= 360
			elif value - diff > 180: # value/diff are positive
				diff += 360

			if diff == 0:
				continue

			for key_index in range(animation.track_get_key_count(track_index)):
				value = animation.track_get_key_value(track_index, key_index)
				animation.track_set_key_value(track_index, key_index, value - diff)

	var optimized_tracks = {}
	var remove_tracks = {}
	for animation_index in range(len(animation_names)):
		var animation_name = animation_names[animation_index]
		var animation = animation_player.get_animation(animation_name)

		for track_index in range(animation.get_track_count()):
			var path = animation.track_get_path(track_index)
			var can_remove = animation.track_get_key_count(track_index) < 2
			if optimized_tracks.has(path):
				continue
			var value = animation.track_get_key_value(track_index, 0)
			for other_animation_index in range(animation_index + 1, len(animation_names)):
				var other_animation_name = animation_names[other_animation_index]
				var other_animation = animation_player.get_animation(other_animation_name)
				var other_track_index = other_animation.find_track(path)
				if other_track_index < 0:
					continue
				var other_track_value = other_animation.track_get_key_value(other_track_index, 0)

				if other_animation.track_get_key_count(other_track_index) > 1:
					can_remove = false
				elif other_track_value != value:
					print(animation_name, other_animation_name, path, value, other_track_value)
					can_remove = false

				if String(path).ends_with(':rotation_degrees'):
					var diff = other_track_value - value
					var other_track_adjust = 0
					if diff > 180: # other_track_value greater than value
						other_track_adjust = -360
					elif diff < -180: # other_track_value samller than value
						other_track_adjust = 360
					if other_track_adjust == 0:
						continue
					for key_index in range(other_animation.track_get_key_count(other_track_index)):
						other_track_value = other_animation.track_get_key_value(other_track_index, key_index)
						other_animation.track_set_key_value(other_track_index, key_index, other_track_value + other_track_adjust)

			if can_remove:
				remove_tracks[path] = 1

			optimized_tracks[path] = 1

	for animation_index in range(len(animation_names)):
		var animation_name = animation_names[animation_index]
		var animation = animation_player.get_animation(animation_name)
		for path in remove_tracks:
			var track_index = animation.find_track(path)
			if track_index < 0:
				continue
			animation.remove_track(track_index)


func _process_path(path: String, options: Dictionary):
	print("Processing in thread: ", path)

	var parsed_data = _parse_data(path)
	if parsed_data == null:
		return null

	var imported = Node2D.new()
	_imported = imported
	imported.name = 'Imported'

	var resources = {}
	for scml_folder in parsed_data.folders.values():
		for scml_file in scml_folder.files.values():
			var key = "{folder_id} : {file_id}".format({'folder_id': scml_folder.id, 'file_id': scml_file.id})
			var resource = load(path.get_base_dir().plus_file(scml_file.name))
			scml_file.resource = resource

	for scml_entity in parsed_data.entities.values():
		imported.name = scml_entity.name
		var skeleton = Skeleton2D.new()
		skeleton.name = "Skeleton"
		imported.add_child(skeleton)
		skeleton.set_owner(imported)
		
		var animation_player = AnimationPlayer.new()
		animation_player.name = "AnimationPlayer"
		animation_player.playback_speed = 3
		if options.set_rest_pose:
			var set_rest_script: Script = load("res://addons/import_scml/set_rest.gd")
			animation_player.set_script(set_rest_script)
		skeleton.add_child(animation_player)
		skeleton.rotation_degrees = -180
		skeleton.scale = Vector2(-1, 1)
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
#			if scml_animation.name != "Idle":
#				continue
			var animation = Animation.new()
			animation.loop = true
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
					assert(scml_timeline.object_type == 'bone')
					var bone = bones[scml_timeline.name]
							
					if is_setup:
						var parent = bones['skeleton']
						if scml_bone_ref.parent > -1:
							var scml_parent_bone_reference = scml_mainline_key.bone_references[scml_bone_ref.parent]
							var scml_parent_timeline = scml_animation.timelines[scml_parent_bone_reference.timeline]
							assert(scml_parent_timeline.object_type == 'bone')
							parent = bones[scml_parent_timeline.name]
						if bone.get_parent() == null:
							parent.add_child(bone)
						else:
							assert(parent == bone.get_parent())
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
					assert(scml_timeline.object_type == 'object')
					var scml_timeline_key_ids = scml_timeline.keys.keys()
					scml_timeline_key_ids.sort()
					for scml_timeline_key_id in scml_timeline_key_ids:
						var scml_timeline_key = scml_timeline.keys[scml_timeline_key_id]
						for scml_object in scml_timeline_key.objects:
							var scml_file = parsed_data.folders[scml_object.folder].files[scml_object.file]
							var object = objects.get(scml_timeline.id)
							var position = Vector2(scml_object.x, scml_object.y)
							var angle = scml_object.angle
							var texture = scml_file.resource
							var offset = Vector2(-(scml_file.pivot_x) * texture.get_width(), -(scml_file.pivot_y) * texture.get_height())
							var modulate = Color(1, 1, 1, scml_object.alpha)
							var scale = Vector2(scml_object.scale_x, scml_object.scale_y)
							if object == null:
								object = Sprite.new()
								objects[scml_timeline.id] = object
								object.texture = texture
								object.name = scml_file.name.get_basename()
								object.offset = offset
								object.flip_v = true
								object.z_as_relative = false
								object.centered = false
								object.scale = scale

								
								var parent = bones['skeleton']
								if scml_object_ref.parent > -1:
									var scml_parent_bone_reference = scml_mainline_key.bone_references[scml_object_ref.parent]
									var scml_parent_timeline = scml_animation.timelines[scml_parent_bone_reference.timeline]
									assert(scml_parent_timeline.object_type == 'bone')
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
							_add_animation_key(animation, String(node_path) + ':texture', scml_timeline_key.time, texture, 0)
							_add_animation_key(animation, String(node_path) + ':offset', scml_timeline_key.time, offset, 0)
							_add_animation_key(animation, String(node_path) + ':scale', scml_timeline_key.time, scale, 0)

			_optimize_animation(animation)
		if options.optimize_for_blends:
			_optimize_animations_for_blends(animation_player)

func _export_path(path: String):
	var scene = PackedScene.new()
	var result = scene.pack(_imported)
	if result == OK:
		result = ResourceSaver.save("%s.%s" % [path, get_save_extension()], scene)
		if result == OK:
			_imported.queue_free()
			_imported = null

func get_importer_name():
	return "importer.scml"

func get_visible_name():
	return "SCML Importer"

func get_recognized_extensions():
	return ["scml"]

func get_save_extension():
	return "scn"

func get_resource_type():
	return "PackedScene"

enum Presets { DEFAULT }

func get_preset_count():
	return Presets.size()

func get_preset_name(preset):
	match preset:
		Presets.DEFAULT:
			return "Default"
		_:
			return "Unknown"

func get_import_options(preset):
	match preset:
		Presets.DEFAULT:
			return [{
						"name": "optimize_for_blends",
						"default_value": false
					}, {
						"name": "set_rest_pose",
						"default_value": false
					}]
		_:
			return []

func get_option_visibility(option: String, options: Dictionary):
	return true

func import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array, gen_files: Array):
	_process_path(source_file, options)
	_export_path(save_path)
