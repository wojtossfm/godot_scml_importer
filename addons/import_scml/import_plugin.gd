extends EditorImportPlugin

# Tested against
# * spriter_data scml_version="1.0" generator="BrashMonkey Spriter" generator_version="r11
tool

var _thread : Thread = null
var _imported : Node2D = null

const REPARENTING_INSTANCING = 'instance per parent'
const REPARENTING_REMOTE_TRANSFORM = 'remote transform'


class SCMLParsedNode:
	var _node_name : String


class SCMLFile:
	extends SCMLParsedNode
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
	extends SCMLParsedNode
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
	extends SCMLParsedNode
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

class SCMLReference:
	extends SCMLParsedNode
	var id : int
	var parent : int
	var timeline : int
	var key : int
	
	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		self.parent = int(attributes.get("parent", SCML_NO_PARENT))
		self.timeline = int(attributes["timeline"])
		self.key = int(attributes["key"])


class SCMLBoneReference:
	extends SCMLReference


class SCMLObjectReference:
	extends SCMLReference
	var z_index : int
	
	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		self.parent = int(attributes.get("parent", SCML_NO_PARENT))
		self.timeline = int(attributes["timeline"])
		self.key = int(attributes["key"])
		self.z_index = int(attributes["z_index"])


class SCMLMainlineKey:
	extends SCMLParsedNode
	var id: int
	var time: float
	var object_references : Dictionary
	var bone_references : Dictionary
	var children: Array
	
	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		self.time = float(attributes.get("time", 0)) / 100
		self.object_references = {}
		self.bone_references = {}
		self.children = []
	
	func add_bone_reference(attributes: Dictionary) -> SCMLBoneReference:
		var obj = SCMLBoneReference.new()
		obj.from_attributes(attributes)
		self.bone_references[obj.id] = obj
		self.children.append(obj)
		return obj
	
	func add_object_reference(attributes: Dictionary) -> SCMLObjectReference:
		var obj = SCMLObjectReference.new()
		obj.from_attributes(attributes)
		self.object_references[obj.id] = obj
		self.children.append(obj)
		return obj


class SCMLMainline:
	extends SCMLParsedNode
	var keys: Dictionary
	var children: Array
	func from_attributes(attributes: Dictionary):
		assert(attributes.empty())
		self.keys = {}
		self.children = []
	
	func add_key(attributes: Dictionary) -> SCMLMainlineKey:
		var obj = SCMLMainlineKey.new()
		obj.from_attributes(attributes)
		self.keys[obj.id] = obj
		self.children.append(obj)
		return obj


class Utilities:
	
	static func float_or_null(value):
		return float(value) if value != null else value


class SCML2DNode:
	extends SCMLParsedNode
	var utilities = Utilities
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


class SCMLBone:
	extends SCML2DNode


class SCMLObject:
	extends SCML2DNode
	var folder: int
	var file: int
	
	func from_attributes(attributes: Dictionary):
		self.folder = int(attributes["folder"])
		self.file = int(attributes["file"])
		.from_attributes(attributes)


class SCMLTimelineKey:
	extends SCMLParsedNode
	var id: int
	var spin: int
	var time: float
	var objects : Array
	var bones : Array
	var children : Array
	
	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		self.spin = int(attributes.get("spin", 0))
		self.time = float(attributes.get("time", 0)) / 100
		self.objects = []
		self.bones = []
		self.children = []
	
	func add_object(attributes: Dictionary) -> SCMLObject:
		var obj = SCMLObject.new()
		obj.from_attributes(attributes)
		self.objects.append(obj)
		self.children.append(obj)
		return obj
	
	func add_bone(attributes: Dictionary) -> SCMLBone:
		var obj = SCMLBone.new()
		obj.from_attributes(attributes)
		self.bones.append(obj)
		self.children.append(obj)
		return obj


class SCMLTimeline:
	extends SCMLParsedNode
	var id : int
	var name : String
	var object_type : String
	var keys: Dictionary
	var children: Array
	
	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		self.name = attributes["name"]
		self.object_type = attributes.get("object_type", 'object')
		self.keys = {}
		self.children = []
	
	func add_key(attributes: Dictionary) -> SCMLTimelineKey:
		var obj = SCMLTimelineKey.new()
		obj.from_attributes(attributes)
		self.keys[obj.id] = obj
		self.children.append(obj)
		return obj


class SCMLAnimation:
	extends SCMLParsedNode
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
	extends SCMLParsedNode
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
	extends SCMLParsedNode
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
				"character_map":
					item = SCMLParsedNode.new()
				"map":
					item = SCMLParsedNode.new()
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
				item._node_name = node_name
				parents.append(item)
		elif parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			var popped = parents.pop_back()
	return parsed_data


func _add_animation_set_parent(animation: Animation, player_path, obj_path, parent_path):
	var	track_index = animation.add_track(Animation.TYPE_METHOD)
	animation.track_set_path(track_index, player_path)
	assert(animation.track_get_key_count(track_index) == 0)
	var arguments: Array = [obj_path, parent_path]
	animation.track_insert_key(track_index, 0, {'method': '_ensure_parent', 'args': arguments})
	#assert(animation.method_track_get_params(track_index, 0).size() == 2)


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


func _create_bones(scml_entity: SCMLEntity, skeleton):
	var bones: Dictionary = {
		'skeleton': skeleton
	}
	for scml_obj_info in scml_entity.object_infos.values():
		var bone = Bone2D.new()
		bone.name = scml_obj_info.name
		bone.set_default_length(scml_obj_info.width)
		bones[bone.name] = bone
	return bones


class Entity:
	var _imported: Node2D
	var _scml_entity: SCMLEntity
	var _skeleton: Skeleton2D
	var _animation_player: AnimationPlayer
	var _options: Dictionary
	var _bones: Dictionary
	var _scales: Dictionary
	var _parent_counts: Dictionary
	var _reference_ids: Dictionary
	var _instances: Dictionary

	func _init(imported: Node2D, scml_entity: SCMLEntity, options):
		self._imported = imported
		self._scml_entity = scml_entity
		self._imported.name = scml_entity.name
		self._skeleton = Skeleton2D.new()
		self._skeleton.name = "Skeleton"
		self._imported.add_child(self._skeleton)
		self._skeleton.set_owner(self._imported)
		self._options = options

		self._animation_player = AnimationPlayer.new()
		self._animation_player.name = "AnimationPlayer"
		self._animation_player.playback_speed = self._options.playback_speed
		self._skeleton.add_child(self._animation_player)
		self._animation_player.set_owner(self._imported)
		self._skeleton.rotation_degrees = -180
		self._skeleton.scale = Vector2(-1, 1)
		self._bones = {'skeleton': self._skeleton}
		self._scales = {self._skeleton: Vector2.ONE}
		self._parent_counts = self._calculate_parent_counts()
		self._reference_ids = {}
		self._instances = {}

	func _get_timeline_child_id(scml_timeline: SCMLTimeline, child: SCML2DNode):
		var id = []
		if scml_timeline.object_type == 'bone':
			id.append(scml_timeline.name)
		else:
			id.append(child.folder)
			id.append(child.file)
		id.append(scml_timeline.object_type)
		return id

	func _is_multi_parent(id: Array) -> bool:
		return self._parent_counts[id] > 1

	func _get_reference_id(scml_reference: SCMLReference, scml_timeline: SCMLTimeline, child: SCML2DNode) -> Array:
		var id = self._get_timeline_child_id(scml_timeline, child)
		var is_multi_parent = self._is_multi_parent(id)
		id.append(scml_reference.parent)
		id.append(is_multi_parent)
		return id

	func _calculate_parent_counts() -> Dictionary:
		var parents = {self._skeleton: {}}
		for scml_animation_key in self._scml_entity.animations.keys():
			var scml_animation: SCMLAnimation = self._scml_entity.animations[scml_animation_key]
			for scml_mainline_key_t in scml_animation.mainline.children:
				var scml_mainline_key: SCMLMainlineKey = scml_mainline_key_t
				for scml_reference in scml_mainline_key.children:
					var scml_timeline: SCMLTimeline = scml_animation.timelines[scml_reference.timeline]
					for scml_timeline_key_t in scml_timeline.children:
						var scml_timeline_key: SCMLTimelineKey = scml_timeline_key_t
						for child in scml_timeline_key.children:
							var id = self._get_timeline_child_id(scml_timeline, child)
							var parent_dict = parents.get(id, {})
							parent_dict[scml_reference.parent] = 1
							parents[id] = parent_dict
		var parent_counts = {}
		for item_id in parents:
			parent_counts[item_id] = len(parents[item_id])
		return parent_counts

	func set_parent(animation: Animation, scml_mainline_key: SCMLMainlineKey, scml_animation: SCMLAnimation, scml_reference: SCMLReference, scml_timeline: SCMLTimeline, scml_child: SCML2DNode, child: Node2D):
		var id = self._get_reference_id(scml_reference, scml_timeline, scml_child)
		var parent
		if scml_reference.parent < 0:
			parent = self._skeleton
		else:
			var scml_parent_reference = scml_mainline_key.bone_references[scml_reference.parent]
			var scml_parent_timeline = scml_animation.timelines[scml_parent_reference.timeline]
			assert(scml_parent_timeline.object_type == 'bone')
			# Expected to be a bone so null as the 3rd argument should be fine
			parent = self.get_instance(scml_parent_reference, scml_parent_timeline, null)
		var is_multi_parent = id.back()
		if is_multi_parent:
			pass
		else:
			if child.get_parent() == null:
				parent.add_child(child)
				child.set_owner(self._imported)
			else:
				assert(parent == child.get_parent())
		return parent

	func get_instance(scml_reference: SCMLReference, scml_timeline: SCMLTimeline, scml_child: SCML2DNode):
		var id = self._get_reference_id(scml_reference, scml_timeline, scml_child)
		var instance: Node2D = self._instances.get(id)
		if instance == null:
			if scml_reference is SCMLBoneReference:
				instance = Bone2D.new()
				if scml_child is SCMLBone:
					var scml_obj_info: SCMLObjectInfo = self._scml_entity.object_infos[scml_timeline.name]
					instance.set_default_length(scml_obj_info.width)
			else:
				instance = Sprite.new()
			self._instances[id] = instance
			instance.name = scml_timeline.name
		return instance

	func create_animation(scml_animation: SCMLAnimation) -> Animation:
		var animation = Animation.new()
		animation.loop = self._options.loop_animations
		animation.length = scml_animation.length
		animation.step = 0.01
		self._animation_player.add_animation(scml_animation.name, animation)
		return animation


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
		var entity = Entity.new(imported, scml_entity, options)
		var rest_pose_src = options.rest_pose_animation
		for scml_animation_t in scml_entity.animations.values():
			var scml_animation: SCMLAnimation = scml_animation_t
			if not rest_pose_src:
				rest_pose_src = scml_animation.name
			var should_set_rest_pose = rest_pose_src == scml_animation.name
			if should_set_rest_pose:
				prints("Using", rest_pose_src, "as rest pose source")
			var animation = entity.create_animation(scml_animation)
			var processed_keys = {}
			for scml_mainline_key_t in scml_animation.mainline.children:
				var scml_mainline_key: SCMLMainlineKey = scml_mainline_key_t
				for scml_reference_t in scml_mainline_key.children:
					var texture = null
					var offset: Vector2 = Vector2.ZERO
					var scml_reference: SCMLReference = scml_reference_t
					var scml_timeline: SCMLTimeline = scml_animation.timelines[scml_reference.timeline]
					var scml_timeline_key: SCMLTimelineKey = scml_timeline.keys[scml_reference.key]

					# multiple mainline keys can reference the same timeline/key combo
					# lets avoid re-processing them in the same animation
					var processing_key = [scml_timeline.id, scml_timeline_key.id]
					if processed_keys.get(processing_key):
						continue
					processed_keys[processing_key] = true

					for scml_child_t in scml_timeline_key.children:
						var scml_child: SCML2DNode = scml_child_t
						var child_id = entity.get_instance_id()
						var child: Node2D = entity.get_instance(scml_reference, scml_timeline, scml_child)
						var parent = entity.set_parent(animation, scml_mainline_key, scml_animation, scml_reference, scml_timeline, scml_child, child)
						var x = scml_child.x if scml_child.x != null else 0
						var y = scml_child.y if scml_child.y != null else 0
						var scale_x = scml_child.scale_x if scml_child.scale_x != null else 1
						var scale_y = scml_child.scale_y if scml_child.scale_y != null else 1
						var scale = Vector2(scale_x, scale_y)
						var angle = scml_child.angle if scml_child.angle != null else null
						var parentScale = Vector2.ONE
#						var parentScale = entity._scales[child.get_parent()]
						var position = Vector2(x, y) * parentScale
						var modulate = Color(1, 1, 1, scml_child.alpha)
						child.position = position
						if child is Bone2D and scml_child is SCMLBone:
							if should_set_rest_pose:
								child.rest = child.transform
							entity._scales[child] = scale * parentScale
						else:
							var scml_file = parsed_data.folders[scml_child.folder].files[scml_child.file]
							var pivot_x = scml_child.pivot_x if scml_child.pivot_x != null else scml_file.pivot_x
							var pivot_y = scml_child.pivot_y if scml_child.pivot_y != null else scml_file.pivot_y
							texture = scml_file.resource
							offset = Vector2(-(pivot_x) * texture.get_width(), -(pivot_y) * texture.get_height())
							child.z_index = scml_reference.z_index
							child.texture = texture
							child.name = scml_file.name.get_basename()
							child.offset = offset
							child.flip_v = true
							child.z_as_relative = false
							child.centered = false

						child.rotation_degrees = angle
						child.modulate = modulate
						child.scale = scale

						if angle != null:
							child.rotation_degrees = angle
						var node_path = entity._skeleton.get_path_to(child)
						_add_animation_key(animation, String(node_path) + ':position', scml_timeline_key.time, position, 0)
						_add_animation_key(animation, String(node_path) + ':modulate', scml_timeline_key.time, modulate, 0)
						_add_animation_key(animation, String(node_path) + ':rotation_degrees', scml_timeline_key.time, angle, scml_timeline_key.spin)
						if child is Sprite:
							_add_animation_key(animation, String(node_path) + ':texture', scml_timeline_key.time, texture, 0)
							_add_animation_key(animation, String(node_path) + ':offset', scml_timeline_key.time, offset, 0)
							_add_animation_key(animation, String(node_path) + ':scale', scml_timeline_key.time, scale, 0)

			_optimize_animation(animation)
		if options.optimize_for_blends:
			_optimize_animations_for_blends(entity._animation_player)

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
						"name": "playback_speed",
						"default_value": 3,
						"property_hint": PROPERTY_HINT_RANGE,
						"hint_string": "0,10,or_greater"
					},{
						"name": "loop_animations",
						"default_value": true
					},{
						"name": "optimize_for_blends",
						"default_value": true
					}, {
						"name": "rest_pose_animation",
						"default_value": ""
					}, {
						"name": "reparenting_solution",
						"default_value": REPARENTING_INSTANCING,
						"property_hint": PROPERTY_HINT_ENUM,
						"hint_string": REPARENTING_INSTANCING + ',' + REPARENTING_REMOTE_TRANSFORM,
					}]
		_:
			return []

func get_option_visibility(option: String, options: Dictionary):
	return true

func import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array, gen_files: Array):
	_process_path(source_file, options)
	_export_path(save_path)
