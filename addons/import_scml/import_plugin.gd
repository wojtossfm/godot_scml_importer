@tool
extends EditorImportPlugin

# Tested against
# * spriter_data scml_version="1.0" generator="BrashMonkey Spriter" generator_version="r11

var _thread : Thread = null
var _imported : Node2D = null

const REPARENTING_INSTANCING = 'instance per parent'
const HALF_TAU = TAU/2


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
	var resource : CompressedTexture2D

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
		var name = attributes.get("realname")
		if name == null:
			name = attributes["name"]
		self.name = name
		self.type = attributes["type"]
		if self.type == "bone":
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
		# time is in MS
		self.time = float(attributes.get("time", 0)) / 1000
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

	static func _sort_by_parent(a: SCMLReference, b: SCMLReference):
		return a.parent < b.parent


class SCMLMainline:
	extends SCMLParsedNode
	var keys: Dictionary
	var children: Array
	func from_attributes(attributes: Dictionary):
		assert(attributes.is_empty())
		self.keys = {}
		self.children = []

	func add_key(attributes: Dictionary) -> SCMLMainlineKey:
		var obj = SCMLMainlineKey.new()
		obj.from_attributes(attributes)
		self.keys[obj.id] = obj
		self.children.append(obj)
		return obj


class Utilities:

	static func int_or_neg(value):
		return int(value) if value != null else -1

	static func float_or_null(value):
		return float(value) if value != null else value

	static func is_a_rotation_path(path: NodePath) -> bool:
		return String(path).ends_with(':rotation')

	static func is_a_texture_path(path: NodePath) -> bool:
		return String(path).ends_with(':texture')

	static func is_visibility_path(path: NodePath) -> bool:
		return String(path).ends_with(':visible')


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
	var visible = true

	func from_attributes(attributes: Dictionary):
		self.x = self.utilities.float_or_null(attributes.get('x'))
		self.y = self.utilities.float_or_null(attributes.get('y'))
		self.pivot_x = self.utilities.float_or_null(attributes.get('pivot_x'))
		self.pivot_y = self.utilities.float_or_null(attributes.get('pivot_y'))
		self.scale_x = self.utilities.float_or_null(attributes.get('scale_x'))
		self.scale_y = self.utilities.float_or_null(attributes.get('scale_y'))
		var angle_deg = self.utilities.float_or_null(attributes.get('angle'))
		self.angle = deg_to_rad(angle_deg) if angle_deg != null else null
		self.alpha = self.utilities.float_or_null(attributes.get('a', 1))


class SCMLBone:
	extends SCML2DNode


class SCMLObject:
	extends SCML2DNode
	var folder: int
	var file: int

	func from_attributes(attributes: Dictionary):
		self.folder = self.utilities.int_or_neg(attributes.get("folder"))
		self.file = self.utilities.int_or_neg(attributes.get("file"))
		super(attributes)


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
		# Time is in ms
		self.time = float(attributes.get("time", 0)) / 1000
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


class SCMLEventline:
	extends SCMLParsedNode
	var id : int
	var name : String
	var keys: Dictionary
	var children: Array

	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		self.name = attributes["name"]
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
	var looping: bool
	var name: String
	var mainline: SCMLMainline
	var timelines : Dictionary
	var eventlines : Dictionary

	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		# time is in ms
		self.length = float(attributes["length"]) / 1000
		self.interval = float(attributes["interval"]) / 1000
		self.name = attributes["name"]
		var looping_str = attributes.get("looping", "true")
		self.looping = looping_str != "false"
		self.timelines = {}
		self.eventlines = {}

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

	func add_eventline(attributes: Dictionary) -> SCMLEventline:
		var obj = SCMLEventline.new()
		obj.from_attributes(attributes)
		self.eventlines[obj.id] = obj
		return obj


class SCMLMap:
	extends SCMLParsedNode
	var folder: int
	var file: int
	var target_folder: int
	var target_file: int

	func from_attributes(attributes: Dictionary):
		self.folder = Utilities.int_or_neg(attributes.get("folder"))
		self.file = Utilities.int_or_neg(attributes.get("file"))
		self.target_folder = Utilities.int_or_neg(attributes.get("target_folder"))
		self.target_file = Utilities.int_or_neg(attributes.get("target_file"))


class SCMLCharacterMap:
	extends SCMLParsedNode
	var id: int
	var name: String
	var maps: Array[SCMLMap]
	
	func from_attributes(attributes: Dictionary):
		self.id = int(attributes["id"])
		self.name = attributes["name"]
		
	func add_map(attributes: Dictionary) -> SCMLMap:
		var obj = SCMLMap.new()
		obj.from_attributes(attributes)
		self.maps.append(obj)
		return obj


class SCMLEntity:
	extends SCMLParsedNode
	var id: int
	var name: String
	var object_infos : Dictionary
	var animations : Dictionary
	var character_maps : Dictionary

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

	func add_character_map(attributes: Dictionary) -> SCMLCharacterMap:
		var obj = SCMLCharacterMap.new()
		obj.from_attributes(attributes)
		self.character_maps[obj.name] = obj
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
					var generator_version = attributes.get("generator_version")
					if generator_version != "r11":
						push_warning("SCML from non r11 version. May not work as expected. Try re-saving it with v11 spriter. Found " + generator_version)
				"character_map":
					assert(parents.size() == 2)
					item = last_parent.add_character_map(attributes)
				"map":
					assert(parents.size() == 3)
					item = last_parent.add_map(attributes)
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
				"frames":
					# ignore i/frames when they appear in obj_info
					item = SCMLParsedNode.new()
					assert(parents.size() == 3)
				"i":
					# ignore i/frames when they appear in obj_info
					item = SCMLParsedNode.new()
					assert(parents.size() == 4)
				"animation":
					assert(parents.size() == 2)
					item = last_parent.add_animation(attributes)
				"mainline":
					assert(parents.size() == 3)
					item = last_parent.add_mainline(attributes)
				"timeline":
					assert(parents.size() == 3)
					item = last_parent.add_timeline(attributes)
				"key": # same indentation for mainline and timeline and eventline
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
				"eventline":
					assert(parents.size() == 3)
					item = last_parent.add_eventline(attributes)

			var has_children = not parser.is_empty()
			if item and has_children:
				item._node_name = node_name
				parents.append(item)
		elif parser.get_node_type() == XMLParser.NODE_ELEMENT_END:
			var popped = parents.pop_back()
	return parsed_data


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
			else:
				to_remove.pop_front()
				for remove_index in to_remove:
					animation.track_remove_key(track_index, remove_index)
				to_remove.clear()


func _optimize_animations_for_blends(animation_player: AnimationPlayer):
	var animation_names = animation_player.get_animation_list()
	for animation_name in animation_names:
		var animation = animation_player.get_animation(animation_name)
		for track_index in range(animation.get_track_count()):
			var path = animation.track_get_path(track_index)
			var is_rotation = Utilities.is_a_rotation_path(path)

			if not is_rotation:
				continue

			if animation.track_get_key_count(track_index) == 0:
				continue

			var value = animation.track_get_key_value(track_index, 0)
			var diff = int(value / TAU) * TAU

			if value - diff < -HALF_TAU: # value/diff are negative
				diff -= TAU
			elif value - diff > HALF_TAU: # value/diff are positive
				diff += TAU


			if is_zero_approx(diff):
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
			var is_rotation = Utilities.is_a_rotation_path(path)
			var is_visibility = Utilities.is_visibility_path(path)
			if is_visibility:
				continue
			var can_remove = animation.track_get_key_count(track_index) < 2
			if optimized_tracks.has(path):
				continue
			var value = animation.track_get_key_value(track_index, 0)
			for other_animation_index in range(animation_index + 1, len(animation_names)):
				var other_animation_name = animation_names[other_animation_index]
				var other_animation = animation_player.get_animation(other_animation_name)
				var other_track_index = other_animation.find_track(path, Animation.TYPE_VALUE)
				if other_track_index < 0:
					continue
				var other_track_value = other_animation.track_get_key_value(other_track_index, 0)

				if other_animation.track_get_key_count(other_track_index) > 1:
					can_remove = false
				elif other_track_value != value:
					can_remove = false

				if is_rotation:
					var diff = other_track_value - value
					var other_track_adjust = 0

					if diff > HALF_TAU: # other_track_value greater than value
						other_track_adjust = -TAU
					elif diff < -HALF_TAU: # other_track_value samller than value
						other_track_adjust = TAU

					if is_zero_approx(other_track_adjust):
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
			var track_index = animation.find_track(path, Animation.TYPE_VALUE)
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
		bone.set_length(scml_obj_info.width)
		bones[bone.name] = bone
	return bones


class Entity:
	var _imported: Node2D
	var _scml_entity: SCMLEntity
	var _skeleton: Skeleton2D
	var _animation_player: AnimationPlayer
	var _animation_library: AnimationLibrary
	var _options: Dictionary
	var _bones: Dictionary
	var _scales: Dictionary
	var _instances_per_name: Dictionary
	var _rest_pose_animation: Animation

	func _init(imported: Node2D, scml_entity: SCMLEntity, options):
		self._options = options
		self._imported = imported
		self._imported.z_as_relative = self._options.z_as_relative
		self._scml_entity = scml_entity
		self._imported.name = scml_entity.name
		self._skeleton = Skeleton2D.new()
		self._skeleton.z_as_relative = self._options.z_as_relative
		self._skeleton.name = "Skeleton"
		self._imported.add_child(self._skeleton)
		self._skeleton.set_owner(self._imported)

		self._animation_player = AnimationPlayer.new()
		self._animation_library = AnimationLibrary.new()
		self._animation_player.add_animation_library("scml", self._animation_library)
		self._animation_player.name = "AnimationPlayer"
		self._animation_player.speed_scale = self._options.playback_speed
		self._skeleton.add_child(self._animation_player)
		self._animation_player.set_owner(self._imported)
		self._skeleton.rotation = -HALF_TAU
		self._skeleton.scale = Vector2(-1, 1)
		self._bones = {'skeleton': self._skeleton}
		self._scales = {self._skeleton: Vector2.ONE}
		self._instances_per_name = {"":{[]: self._skeleton}}
		self._rest_pose_animation = null
		self._initialize_instances()

	func set_rest_pose(animation: Animation):
		self._rest_pose_animation = animation

	func get_animation_value(animation: Animation, node_path: NodePath, default):
		var track_index = animation.find_track(node_path, Animation.TYPE_VALUE)
		var value
		if track_index >= 0 and animation.track_get_key_count(track_index) > 0:
			value = animation.track_get_key_value(track_index, 0)
		else:
			value = default
		return value

	func get_path_to_instance(instance):
		return self._skeleton.get_path_to(instance)

	func apply_rest_pose():
		var animation: Animation = self._rest_pose_animation
		assert (animation != null)
		for collection in self._instances_per_name.values():
			for instance_t in collection.values():
				var instance: Node2D = instance_t
				if instance == self._skeleton:
					continue
				var node_path = self.get_path_to_instance(instance)
				var position: Vector2 = self.get_animation_value(animation, String(node_path) + ':position', instance.position)
				var modulate: Color = self.get_animation_value(animation, String(node_path) + ':modulate', instance.modulate)
				var rotation: float = self.get_animation_value(animation, String(node_path) + ':rotation', instance.rotation)
				instance.position = position
				instance.modulate = modulate
				instance.rotation = rotation
				if instance is Sprite2D:
					var texture: Texture2D = self.get_animation_value(animation, String(node_path) + ':texture', instance.texture)
					var offset: Vector2 = self.get_animation_value(animation, String(node_path) + ':offset', instance.offset)
					var scale: Vector2 = self.get_animation_value(animation, String(node_path) + ':scale', instance.scale)
					var z_index: int = self.get_animation_value(animation, String(node_path) + ':z_index', instance.z_index)
					instance.texture = texture
					instance.offset = offset
					instance.scale = scale
					instance.z_index = z_index

	func build_path(scml_animation: SCMLAnimation, scml_mainline_key: SCMLMainlineKey, scml_reference: SCMLReference) -> Array:
		var path_to_skeleton = []
		var current_reference: SCMLReference = scml_reference
		while true:
			var timeline: SCMLTimeline = scml_animation.timelines[current_reference.timeline]
			path_to_skeleton.append(timeline.name)
			if current_reference.parent == -1:
				break
			current_reference = scml_mainline_key.bone_references[current_reference.parent]
		assert(path_to_skeleton.size() > 0)
		path_to_skeleton.reverse()
		return path_to_skeleton

	func get_instances_other(path: Array):
		var instances = []
		var name = path.back()
		for instance_path in self._instances_per_name[name].keys():
			if instance_path != path:
				instances.append(self._instances_per_name[name][instance_path])
		return instances

	func get_instance(path: Array) -> Node2D:
		var name = "" if path.is_empty() else path.back()
		var instance = self._instances_per_name[name][path]
		return instance

	func get_parent(path: Array) -> Node2D:
		var parent_path = path.duplicate()
		parent_path.pop_back()
		return self.get_instance(parent_path)

	func bones() -> Array:
		var instances = []
		for collection in self._instances_per_name.values():
			for instance in collection.values():
				if instance is Bone2D:
					instances.append(instance)
		return instances

	func get_paths_set() -> Dictionary:
		var paths = {}
		for collection in self._instances_per_name.values():
			for instance in collection.values():
				if instance == self._skeleton:
					continue
				var node_path = self.get_path_to_instance(instance)
				paths[node_path] = true
		return paths

	func _initialize_instances():
		for scml_animation_t in self._scml_entity.animations.values():
			var scml_animation: SCMLAnimation = scml_animation_t
			for scml_mainline_key_t in scml_animation.mainline.children:
				var scml_mainline_key: SCMLMainlineKey = scml_mainline_key_t
				for scml_reference_t in scml_mainline_key.children:
					var scml_reference: SCMLReference = scml_reference_t
					var path = self.build_path(scml_animation, scml_mainline_key, scml_reference)
					var name = path.back()
					var collection = self._instances_per_name.get(name, {})
					if not collection.has(path):
						var instance: Node2D
						if scml_reference is SCMLBoneReference:
							instance = Bone2D.new()
							var scml_timeline = scml_animation.timelines[scml_reference.timeline]
							var scml_obj_info: SCMLObjectInfo = self._scml_entity.object_infos[scml_timeline.name]
							instance.set_length(scml_obj_info.width)
						else:
							instance = Sprite2D.new()
						instance.z_as_relative = self._options.z_as_relative
						collection[path] = instance
						instance.name = name
						var parent = self.get_parent(path)
						parent.add_child(instance)
						instance.set_owner(self._imported)
					self._instances_per_name[name] = collection

	func create_animation(scml_animation: SCMLAnimation) -> Animation:
		var animation = Animation.new()
		animation.loop_mode = self._options.loop_animations if scml_animation.looping else Animation.LOOP_NONE
		animation.length = scml_animation.length
		animation.step = 0.01
		self._animation_library.add_animation(scml_animation.name, animation)
		return animation

	func remove_if_track_empty(animation: Animation, path: NodePath):
		var track_index: int = animation.find_track(path, Animation.TYPE_VALUE)
		if track_index < 0:
			return
		var key_count = animation.track_get_key_count(track_index)
		if key_count == 0:
			animation.remove_track(track_index)

	func ensure_track_exists(animation: Animation, path: NodePath):
		var track_index: int = animation.find_track(path, Animation.TYPE_VALUE)
		if track_index >= 0:
			return
		track_index = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track_index, path)
		if Utilities.is_a_texture_path(path):
			animation.value_track_set_update_mode(track_index, Animation.UPDATE_DISCRETE)
		else:
			animation.value_track_set_update_mode(track_index, Animation.UPDATE_CONTINUOUS)

	func add_animation_key(animation: Animation, path: NodePath, scml_mainline_key: SCMLMainlineKey, spin: int, value):
		var is_rotation: bool = Utilities.is_a_rotation_path(path)
		if value == null:
			return
		var easing: int
		var time: float = scml_mainline_key.time

		if not is_rotation:
			easing = 1
		else:
			easing = 1 if spin == 0 else -1

		var key_index: int = scml_mainline_key.id
		var track_index: int = animation.find_track(path, Animation.TYPE_VALUE)
		assert(track_index >= 0, "{} {} {}".format([track_index, path, key_index], "{}"))
		var key_count = animation.track_get_key_count(track_index)
		assert(key_count <= key_index, "{} {} {} {}".format([track_index, path, key_index, key_count], "{}"))

		if key_count > 0 and Utilities.is_a_rotation_path(path):
			var previous_key_index = key_count - 1
			var previous_ease = animation.track_get_key_transition(track_index, previous_key_index)
			var previous_value = animation.track_get_key_value(track_index, previous_key_index)
			var previous_time = animation.track_get_key_time(track_index, previous_key_index)
			#if previous_time >= time:
				#prints(previous_time, time, path)
			assert(previous_time < time, str(path))
			# Simplified to better handle cases where an over 360 spin is present
			value = wrapf(value - previous_value, -PI, PI) + previous_value
			
		var new_key_index = animation.track_insert_key(track_index, time, value, easing)
		# We cannot make this strict as there are apparently keys that can have the same time
		# and are e.g. not in the mainline
		assert(new_key_index <= key_index)
		assert(animation.track_get_key_transition(track_index, new_key_index) == easing)
		assert(animation.track_get_key_value(track_index, new_key_index) == value)


func _process_path(path: String, options: Dictionary):
	print("Processing in thread: ", path)

	var parsed_data = _parse_data(path)
	if parsed_data == null:
		return null

	var imported = Node2D.new()
	_imported = imported
	imported.name = 'Imported'

	# load character map
	var character_map = null
	if options.character_map_file:
		var file = FileAccess.open(options.character_map_file, FileAccess.READ)
		var json_string = file.get_as_text()
		character_map = JSON.parse_string(json_string)
		file.close()

	var resources = {}
	for scml_folder in parsed_data.folders.values():
		for scml_file in scml_folder.files.values():
			var key = "{folder_id} : {file_id}".format({'folder_id': scml_folder.id, 'file_id': scml_file.id})
			var resource = load(path.get_base_dir().path_join(scml_file.name))
			scml_file.resource = resource

	for scml_entity in parsed_data.entities.values():
		var entity = Entity.new(imported, scml_entity, options)

		if character_map:
			for name in character_map["scms"]["cm"]:
				var scml_character_map: SCMLCharacterMap = scml_entity.character_maps[name]
				if not scml_character_map:
					prints("Character map not found:", name)
					continue

				for scml_map in scml_character_map.maps:
					for scml_animation in scml_entity.animations.values():
						for scml_timeline in scml_animation.timelines.values():
							for scml_timeline_key in scml_timeline.keys.values():
								for scml_child in scml_timeline_key.children:
									if scml_child is SCMLObject and scml_child.folder == scml_map.folder and scml_child.file == scml_map.file:
										if scml_map.target_folder == -1 or scml_map.target_file == -1:
											scml_child.visible = false
										else:
											scml_child.folder = scml_map.target_folder
											scml_child.file = scml_map.target_file

		var rest_pose_src = options.rest_pose_animation
		var all_paths: Dictionary = entity.get_paths_set()
		for scml_animation_t in scml_entity.animations.values():
			var scml_animation: SCMLAnimation = scml_animation_t
			if rest_pose_src.is_empty():
				rest_pose_src = scml_animation.name
			var should_set_rest_pose = rest_pose_src == scml_animation.name
			if should_set_rest_pose:
				prints("Using", rest_pose_src, "as rest pose source")
			var animation = entity.create_animation(scml_animation)

			prints("Processing", scml_animation.name)
			for node_path in all_paths:
				entity.ensure_track_exists(animation, String(node_path) + ':visible')

			# capture what timelines appear in the mainline keys
			for scml_mainline_key_t in scml_animation.mainline.children:
				var scml_mainline_key: SCMLMainlineKey = scml_mainline_key_t
				for scml_reference_t in scml_mainline_key.children:
					var scml_reference: SCMLReference = scml_reference_t
					var child_path = entity.build_path(scml_animation, scml_mainline_key, scml_reference)
					var child: Node2D = entity.get_instance(child_path)
					var node_path = entity.get_path_to_instance(child)
					entity.ensure_track_exists(animation, String(node_path) + ':position')
					entity.ensure_track_exists(animation, String(node_path) + ':modulate')
					entity.ensure_track_exists(animation, String(node_path) + ':rotation')
					entity.ensure_track_exists(animation, String(node_path) + ':scale')
					if child is Sprite2D:
						entity.ensure_track_exists(animation, String(node_path) + ':texture')
						entity.ensure_track_exists(animation, String(node_path) + ':offset')
						entity.ensure_track_exists(animation, String(node_path) + ':z_index')

			for scml_mainline_key_t in scml_animation.mainline.children:
				var scml_mainline_key: SCMLMainlineKey = scml_mainline_key_t
				var node_paths_missing = all_paths.duplicate()
				for scml_reference_t in scml_mainline_key.children:
					var scml_reference: SCMLReference = scml_reference_t
					var scml_timeline: SCMLTimeline = scml_animation.timelines[scml_reference.timeline]

					if scml_timeline.object_type == "point":
						prints("point object type not supported. Skipping")
						continue
					var child_path = entity.build_path(scml_animation, scml_mainline_key, scml_reference)
					var child: Node2D = entity.get_instance(child_path)
					var node_path = entity.get_path_to_instance(child)
					node_paths_missing.erase(node_path)
					var parent: Node2D = entity.get_parent(child_path)
					var scml_timeline_key: SCMLTimelineKey = scml_timeline.keys[scml_reference.key]
					assert(child.get_parent() == parent)

					for scml_child_t in scml_timeline_key.children:
						var scml_child: SCML2DNode = scml_child_t
						var offset: Vector2 = Vector2.ZERO
						var x = scml_child.x if scml_child.x != null else 0
						var y = scml_child.y if scml_child.y != null else 0
						var scale_x = scml_child.scale_x if scml_child.scale_x != null else 1
						var scale_y = scml_child.scale_y if scml_child.scale_y != null else 1
						var angle_rad = scml_child.angle if scml_child.angle != null else null
						var parentScale = entity._scales[child.get_parent()]
						var scale = Vector2(scale_x, scale_y) * parentScale
						var position = Vector2(x, y) * parentScale
						var modulate = Color(1, 1, 1, scml_child.alpha)
						var texture = null
						var visible = bool(scml_child.visible)
						child.position = position
						if child is Bone2D and scml_child is SCMLBone:
							entity._scales[child] = Vector2(abs(scale.x), abs(scale.y))
							scale = Vector2(sign(scale.x), sign(scale.y))
							child.scale = scale
						else:
							var scml_file = parsed_data.folders[scml_child.folder].files[scml_child.file]
							var pivot_x = scml_child.pivot_x if scml_child.pivot_x != null else scml_file.pivot_x
							var pivot_y = scml_child.pivot_y if scml_child.pivot_y != null else scml_file.pivot_y
							texture = scml_file.resource
							offset = Vector2(-(pivot_x) * texture.get_width(), -(pivot_y) * texture.get_height())
							child.z_index = scml_reference.z_index
							child.texture = texture
							child.offset = offset
							child.flip_v = true
							child.centered = false
							child.scale = scale

						child.modulate = modulate

						if angle_rad != null:
							child.rotation = angle_rad

						if scml_mainline_key.time == scml_timeline_key.time:
							entity.add_animation_key(animation, String(node_path) + ':position', scml_mainline_key, scml_timeline_key.spin, position)
							entity.add_animation_key(animation, String(node_path) + ':scale', scml_mainline_key, scml_timeline_key.spin, scale)
							entity.add_animation_key(animation, String(node_path) + ':modulate', scml_mainline_key, scml_timeline_key.spin, modulate)
							entity.add_animation_key(animation, String(node_path) + ':rotation', scml_mainline_key, scml_timeline_key.spin, angle_rad)
							entity.add_animation_key(animation, String(node_path) + ':visible', scml_mainline_key, scml_timeline_key.spin, visible)

						if child is Sprite2D:
							if scml_mainline_key.time == scml_timeline_key.time:
								entity.add_animation_key(animation, String(node_path) + ':texture', scml_mainline_key, scml_timeline_key.spin, texture)
								entity.add_animation_key(animation, String(node_path) + ':offset', scml_mainline_key, scml_timeline_key.spin, offset)
							entity.add_animation_key(animation, String(node_path) + ':z_index', scml_mainline_key, scml_timeline_key.spin, scml_reference.z_index)

				for node_path in node_paths_missing.keys():
					entity.add_animation_key(animation, String(node_path) + ':visible', scml_mainline_key, 0, false)

			# add event trigger
			if options.create_events_as_signals and scml_animation.eventlines:
				var method_track = animation.add_track(Animation.TYPE_METHOD)
				animation.track_set_path(method_track, entity.get_path_to_instance(entity._animation_player))
				for event_id in scml_animation.eventlines.keys():
					var event: SCMLEventline = scml_animation.eventlines[event_id]
					for timelinekey in event.children:
						animation.track_insert_key(method_track, timelinekey.time, {"method": "call_deferred", "args": ["emit_signal", event.name]})

			for scml_mainline_key_t in scml_animation.mainline.children:
				var scml_mainline_key: SCMLMainlineKey = scml_mainline_key_t
				for scml_reference_t in scml_mainline_key.children:
					var scml_reference: SCMLReference = scml_reference_t
					var child_path = entity.build_path(scml_animation, scml_mainline_key, scml_reference)
					var child: Node2D = entity.get_instance(child_path)
					var node_path = entity.get_path_to_instance(child)
					entity.remove_if_track_empty(animation, String(node_path) + ':position')
					entity.remove_if_track_empty(animation, String(node_path) + ':scale')
					entity.remove_if_track_empty(animation, String(node_path) + ':modulate')
					entity.remove_if_track_empty(animation, String(node_path) + ':rotation')
					entity.remove_if_track_empty(animation, String(node_path) + ':visible')
					if child is Sprite2D:
						entity.remove_if_track_empty(animation, String(node_path) + ':texture')
						entity.remove_if_track_empty(animation, String(node_path) + ':offset')
						entity.remove_if_track_empty(animation, String(node_path) + ':z_index')
					
					for other_child in entity.get_instances_other(child_path):
						var alt_path = entity.get_path_to_instance(other_child)
						entity.remove_if_track_empty(animation, String(alt_path) + ':modulate')


			if should_set_rest_pose:
				for bone_t in entity.bones():
					var bone: Bone2D = bone_t
					bone.rest = bone.transform
				entity.set_rest_pose(animation)

			_optimize_animation(animation)
			
			for track_index in range(animation.get_track_count()):
				animation.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)
				if scml_animation.looping:
					animation.track_set_interpolation_loop_wrap(track_index, options.loop_wrap_interpolation)
				else:
					animation.track_set_interpolation_loop_wrap(track_index, false)

		if options.optimize_for_blends:
			_optimize_animations_for_blends(entity._animation_player)

		for bone_t in entity.bones():
			var bone: Bone2D = bone_t
			var has_bone_children: bool = false

			for child in bone.get_children():
				if child is Bone2D:
					has_bone_children = true

			if not has_bone_children:
				bone.set_autocalculate_length_and_angle(false)
				bone.set_length(1)

		entity.apply_rest_pose()


func _export_path(path: String):
	var scene = PackedScene.new()
	var result = scene.pack(_imported)
	if result == OK:
		result = ResourceSaver.save(scene, "%s.%s" % [path, _get_save_extension()])
		if result == OK:
			_imported.queue_free()
			_imported = null

func _get_importer_name():
	return "importer.scml"

func _get_visible_name():
	return "SCML Importer"

func _get_recognized_extensions():
	return ["scml"]

func _get_save_extension():
	return "scn"

func _get_resource_type():
	return "PackedScene"

enum Presets { DEFAULT }

func _get_preset_count():
	return Presets.size()

func _get_preset_name(preset):
	match preset:
		Presets.DEFAULT:
			return "Default"
		_:
			return "Unknown"

func _get_import_options(path, preset):
	match preset:
		Presets.DEFAULT:
			return [{
						"name": "playback_speed",
						"default_value": 1,
						"property_hint": PROPERTY_HINT_RANGE,
						"hint_string": "0,10,or_greater"
					}, {
						"name": "z_as_relative",
						"default_value": true
					}, {
						"name": "loop_animations",
						"default_value": Animation.LOOP_LINEAR,
						"property_hint": PROPERTY_HINT_ENUM,
						"hint_string": ",".join([
							"NONE:%d" % Animation.LOOP_NONE,
							"LINEAR:%d" % Animation.LOOP_LINEAR,
							"PINGPONG:%d" % Animation.LOOP_PINGPONG,
						]),
					}, {
						"name": "loop_wrap_interpolation",
						"default_value": true
					}, {
						"name": "optimize_for_blends",
						"default_value": true
					}, {
						"name": "create_events_as_signals",
						"default_value": true
					}, {
						"name": "rest_pose_animation",
						"default_value": ""
					}, {
						"name": "character_map_file",
						"default_value": "res://steve/sprites/charactermap.scms",
						"property_hint": PROPERTY_HINT_FILE,
						"hint_string": "*.scms"
					}, {
						"name": "reparenting_solution",
						"default_value": REPARENTING_INSTANCING,
						"property_hint": PROPERTY_HINT_ENUM,
						"hint_string": REPARENTING_INSTANCING,
					}]
		_:
			return []

func _get_option_visibility(path: String, option: StringName, options: Dictionary):
	return true
	
func _get_priority():
	return 1
	
func _get_import_order():
	return 1

func _import(source_file: String, save_path: String, options: Dictionary, platform_variants: Array, gen_files: Array):
	_process_path(source_file, options)
	_export_path(save_path)
