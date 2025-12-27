extends Node
## SceneManager - Handles level transitions with fade effects.
## Works WITH GameManager - GameManager handles game logic, SceneManager handles visual transitions.
## Add as an autoload singleton named "SceneManager"

# ============ SIGNALS ============
signal transition_started()
signal transition_completed()
signal fade_out_completed()
signal fade_in_completed()

# ============ CONFIGURATION ============
@export var fade_out_duration: float = 0.3
@export var fade_in_duration: float = 0.3
@export var fade_color: Color = Color.BLACK

# ============ STATE ============
var _is_transitioning: bool = false

# ============ FADE OVERLAY ============
var _fade_overlay: ColorRect = null
var _fade_tween: Tween = null


func _ready() -> void:
	_setup_fade_overlay()


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
	_fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	canvas_layer.add_child(_fade_overlay)


# ============ PUBLIC API ============

func is_transitioning() -> bool:
	return _is_transitioning


func fade_out() -> void:
	"""Fade to black. Await this or connect to fade_out_completed."""
	if _fade_tween:
		_fade_tween.kill()
	
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_overlay, "color:a", 1.0, fade_out_duration)
	await _fade_tween.finished
	fade_out_completed.emit()


func fade_in() -> void:
	"""Fade from black. Await this or connect to fade_in_completed."""
	if _fade_tween:
		_fade_tween.kill()
	
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_overlay, "color:a", 0.0, fade_in_duration)
	await _fade_tween.finished
	fade_in_completed.emit()


func instant_black() -> void:
	"""Instantly set screen to black."""
	if _fade_tween:
		_fade_tween.kill()
	_fade_overlay.color.a = 1.0


func instant_clear() -> void:
	"""Instantly clear the fade overlay."""
	if _fade_tween:
		_fade_tween.kill()
	_fade_overlay.color.a = 0.0


func transition_with_callback(callback: Callable) -> void:
	"""
	Perform a fade out -> callback -> fade in transition.
	The callback is called while the screen is black.
	Usage: await SceneManager.transition_with_callback(my_load_function)
	"""
	if _is_transitioning:
		push_warning("SceneManager: Already transitioning")
		return
	
	_is_transitioning = true
	transition_started.emit()
	
	# Fade out
	await fade_out()
	
	# Execute the callback (level loading, player positioning, etc.)
	if callback.is_valid():
		var result = callback.call()
		# If callback is async, wait for it
		if result is Signal:
			await result
	
	# Wait frames for scene to settle
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Snap camera to player's room
	_snap_camera_to_player()
	
	# Fade in
	await fade_in()
	
	_is_transitioning = false
	transition_completed.emit()


# ============ CAMERA HELPER ============

func _snap_camera_to_player() -> void:
	"""Snap the camera to whatever room the player is in."""
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
	
	# No room found - just position camera on player
	if camera.has_method("set_target"):
		camera.set_target(player)
