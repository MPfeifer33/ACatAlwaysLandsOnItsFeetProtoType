extends Node
## SceneManager - Handles level loading, transitions, and coordinates with camera system.
## Add as an autoload singleton named "SceneManager"

# ============ SIGNALS ============
signal scene_transition_started(from_scene: String, to_scene: String)
signal scene_transition_completed(scene_path: String)
signal fade_completed()

# ============ CONFIGURATION ============
## Duration of fade out
@export var fade_out_duration: float = 0.4
## Duration of fade in
@export var fade_in_duration: float = 0.4
## Color to fade to
@export var fade_color: Color = Color.BLACK

# ============ STATE ============
var current_scene: Node = null
var current_scene_path: String = ""
var _is_transitioning: bool = false
var _pending_entrance: String = ""
var _pending_direction: int = -1  # LevelConnection.Direction

# ============ FADE OVERLAY ============
var _fade_overlay: ColorRect = null
var _fade_tween: Tween = null


func _ready() -> void:
	add_to_group("SceneManager")
	_setup_fade_overlay()
	
	# Get current scene reference
	await get_tree().process_frame
	current_scene = get_tree().current_scene
	if current_scene:
		current_scene_path = current_scene.scene_file_path


func _setup_fade_overlay() -> void:
	# Create a CanvasLayer for the fade overlay (renders on top of everything)
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 100  # High layer to be on top
	canvas_layer.name = "FadeLayer"
	add_child(canvas_layer)
	
	# Create the fade rectangle
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "FadeOverlay"
	_fade_overlay.color = Color(fade_color.r, fade_color.g, fade_color.b, 0.0)
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Make it cover the entire screen
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	canvas_layer.add_child(_fade_overlay)


# ============ PUBLIC API ============

func transition_to_scene(target_scene: PackedScene, entrance_id: String = "default", direction: int = -1) -> void:
	"""Transition to a new scene with fade effect."""
	if _is_transitioning:
		push_warning("SceneManager: Already transitioning, ignoring request")
		return
	
	if not target_scene:
		push_error("SceneManager: No target scene provided!")
		return
	
	_is_transitioning = true
	_pending_entrance = entrance_id
	_pending_direction = direction
	
	var from_path = current_scene_path
	var to_path = target_scene.resource_path
	
	scene_transition_started.emit(from_path, to_path)
	
	# Fade out
	await _fade_out()
	
	# Change scene
	_change_scene(target_scene)
	
	# Wait a frame for scene to initialize
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Position player at entrance
	_spawn_player_at_entrance()
	
	# Fade in
	await _fade_in()
	
	_is_transitioning = false
	scene_transition_completed.emit(to_path)


func transition_to_scene_path(scene_path: String, entrance_id: String = "default", direction: int = -1) -> void:
	"""Transition using a scene path instead of PackedScene."""
	var scene = load(scene_path) as PackedScene
	if scene:
		transition_to_scene(scene, entrance_id, direction)
	else:
		push_error("SceneManager: Failed to load scene: " + scene_path)


func reload_current_scene() -> void:
	"""Reload the current scene (useful for respawning)."""
	if current_scene_path.is_empty():
		push_error("SceneManager: No current scene to reload")
		return
	
	transition_to_scene_path(current_scene_path)


func is_transitioning() -> bool:
	return _is_transitioning


# ============ FADE EFFECTS ============

func _fade_out() -> void:
	if _fade_tween:
		_fade_tween.kill()
	
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_overlay, "color:a", 1.0, fade_out_duration)
	await _fade_tween.finished


func _fade_in() -> void:
	if _fade_tween:
		_fade_tween.kill()
	
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_overlay, "color:a", 0.0, fade_in_duration)
	await _fade_tween.finished
	fade_completed.emit()


func instant_fade_out() -> void:
	"""Instantly set screen to black (useful for initial load)."""
	_fade_overlay.color.a = 1.0


func instant_fade_in() -> void:
	"""Instantly clear fade (useful for initial load)."""
	_fade_overlay.color.a = 0.0


# ============ SCENE MANAGEMENT ============

func _change_scene(new_scene: PackedScene) -> void:
	# Remove current scene
	if current_scene:
		current_scene.queue_free()
		current_scene = null
	
	# Instance new scene
	current_scene = new_scene.instantiate()
	current_scene_path = new_scene.resource_path
	
	# Add to tree
	get_tree().root.add_child(current_scene)
	get_tree().current_scene = current_scene
	
	# Notify SaveManager of level change
	if has_node("/root/SaveManager"):
		var save_manager = get_node("/root/SaveManager")
		save_manager.current_level = current_scene_path


func _spawn_player_at_entrance() -> void:
	# Find player
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		push_warning("SceneManager: No player found to spawn")
		return
	
	# Find entrance
	var entrance = LevelEntrance.find_entrance(_pending_entrance)
	if entrance:
		entrance.spawn_player(player)
	else:
		# Try to find starting room and spawn there
		var starting_room = _find_starting_room()
		if starting_room:
			var room_center = starting_room.global_position + starting_room.room_size / 2
			player.global_position = room_center
			push_warning("SceneManager: No entrance found, spawning at starting room center")
		else:
			push_warning("SceneManager: No entrance or starting room found, player position unchanged")
	
	# Notify camera to snap to player's room
	_snap_camera_to_player()


func _find_starting_room() -> Room:
	var rooms = get_tree().get_nodes_in_group("Room")
	for room in rooms:
		if room is Room and room.is_starting_room:
			return room
	# Return first room if no starting room designated
	if rooms.size() > 0:
		return rooms[0] as Room
	return null


func _snap_camera_to_player() -> void:
	var camera = get_tree().get_first_node_in_group("GameCamera")
	if not camera:
		return
	
	var player = get_tree().get_first_node_in_group("Player")
	if not player:
		return
	
	# Find which room the player is in
	var rooms = get_tree().get_nodes_in_group("Room")
	for room in rooms:
		if room is Room and room.contains_point(player.global_position):
			if camera.has_method("snap_to_room"):
				camera.snap_to_room(room)
			return
	
	# If no room found, just snap to player
	if camera.has_method("set_target"):
		camera.set_target(player)


# ============ UTILITY ============

func get_current_rooms() -> Array[Room]:
	"""Get all rooms in the current scene."""
	var rooms: Array[Room] = []
	for node in get_tree().get_nodes_in_group("Room"):
		if node is Room:
			rooms.append(node)
	return rooms


func get_room_at_position(pos: Vector2) -> Room:
	"""Find which room contains a given position."""
	for room in get_current_rooms():
		if room.contains_point(pos):
			return room
	return null
