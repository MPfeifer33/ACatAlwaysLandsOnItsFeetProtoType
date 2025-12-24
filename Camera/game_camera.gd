class_name GameCamera
extends Camera2D
## Metroidvania-style camera with room locking and configurable behavior.
## Locks to room boundaries and snaps between rooms with optional effects.

# ============ SIGNALS ============
signal room_entered(room_id: String)
signal room_exited(room_id: String)
signal room_transition_started(from_room: String, to_room: String)
signal room_transition_complete(room_id: String)

# ============ FOLLOW SETTINGS ============
@export_group("Follow Settings")
## Target node to follow (auto-finds Player if empty)
@export var target_node: Node2D = null
## Vertical offset from target (negative = look up)
@export var vertical_offset: float = 0.0
## Horizontal offset from target (positive = look right)
@export var horizontal_offset: float = 0.0

@export_group("Zoom Settings")
## Zoom multiplier on top of auto-zoom. 1.0 = fit room exactly, 2.0 = 2x tighter (see half the room)
@export var base_zoom: float = 1.0:
	set(value):
		base_zoom = value
		_apply_zoom()
## Extra zoom margin to prevent seeing outside rooms (small value like 1.02)
@export var zoom_margin: float = 1.0:
	set(value):
		zoom_margin = value
		_apply_zoom()
## If true, automatically calculate zoom so room fills viewport exactly
@export var auto_zoom_to_room: bool = true

@export_group("Room Transition")
## How to handle room transitions
@export_enum("Instant Snap", "Smooth Pan", "Fade") var transition_mode: int = 0
## Duration of smooth transitions (if not instant)
@export var transition_duration: float = 0.3
## Bounce intensity when snapping to new room (0 = no bounce)
@export_range(0.0, 30.0) var snap_bounce_intensity: float = 12.0
## How fast the bounce decays
@export_range(1.0, 25.0) var bounce_decay: float = 10.0

@export_group("Room Constraints")
## If true, camera locks to room bounds. If false, free follow.
@export var lock_to_rooms: bool = true
## If true, camera stays locked to last valid room when player leaves all rooms
@export var stay_in_last_room: bool = true
## If true, clamp player position to current room bounds (prevents leaving)
@export var confine_player_to_room: bool = false
## Margin inside room edge for player confinement (pixels)
@export var player_confine_margin: float = 8.0

@export_group("Screen Shake")
## Default shake intensity
@export var default_shake_intensity: float = 5.0
## Default shake decay rate
@export var default_shake_decay: float = 8.0

@export_group("Debug")
## Show debug info in console
@export var debug_mode: bool = false

# ============ INTERNAL STATE ============
var _current_room: Node = null  # Can be Room or CameraRoom
var _current_room_id: String = ""
var _previous_room_id: String = ""
var _last_valid_room: Node = null  # Fallback when player leaves all rooms
var _player_outside_rooms: bool = false

# Bounce effect
var _bounce_offset: Vector2 = Vector2.ZERO
var _bounce_velocity: Vector2 = Vector2.ZERO

# Screen shake
var _shake_intensity: float = 0.0
var _shake_decay: float = 8.0

# Smooth transition
var _is_transitioning: bool = false
var _transition_start_pos: Vector2 = Vector2.ZERO
var _transition_end_pos: Vector2 = Vector2.ZERO
var _transition_progress: float = 0.0

# Cached viewport size
var _viewport_size: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Make camera top-level so it's not affected by parent transforms
	top_level = true
	
	# Disable built-in camera limits - we handle this ourselves
	limit_left = -10000000
	limit_right = 10000000
	limit_top = -10000000
	limit_bottom = 10000000
	
	# Cache viewport size first (needed for zoom calculations)
	_viewport_size = get_viewport_rect().size
	
	# Find target if not set
	await get_tree().process_frame
	if not target_node:
		_find_target()
	
	# Find starting room immediately to prevent seeing outside bounds
	_find_starting_room()
	
	# Apply zoom (will auto-calculate if auto_zoom_to_room is enabled)
	_apply_zoom()
	
	# Snap to target within room bounds
	if target_node:
		var target_pos = _get_target_position()
		if _current_room:
			global_position = _clamp_to_room_bounds(target_pos, _current_room)
		else:
			global_position = target_pos
	
	# Add to group for easy finding
	add_to_group("GameCamera")
	
	# Make this the current camera
	make_current()
	
	if debug_mode:
		print("[GameCamera] Ready. Viewport: ", _viewport_size, " Zoom: ", zoom, " Starting room: ", _current_room_id)


func _find_target() -> void:
	# First check if parent is player
	var parent = get_parent()
	if parent and parent.is_in_group("Player"):
		target_node = parent
		if debug_mode:
			print("[GameCamera] Found target: parent Player")
		return
	
	# Search for player in scene
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		target_node = player
		if debug_mode:
			print("[GameCamera] Found target: Player in scene")


func _find_starting_room() -> void:
	"""Find and set the starting room based on player position or is_starting_room flag."""
	var rooms = get_tree().get_nodes_in_group("Room")
	
	# First, look for a room marked as starting room
	for room in rooms:
		if "is_starting_room" in room and room.is_starting_room:
			_set_room(room)
			if debug_mode:
				print("[GameCamera] Found starting room: ", _current_room_id)
			return
	
	# Otherwise, find the room containing the player/target
	if target_node:
		for room in rooms:
			var bounds = _get_room_bounds(room)
			if bounds.has_point(target_node.global_position):
				_set_room(room)
				if debug_mode:
					print("[GameCamera] Found room containing player: ", _current_room_id)
				return
	
	# Fallback: use first room
	if rooms.size() > 0:
		_set_room(rooms[0])
		if debug_mode:
			print("[GameCamera] Using first room as fallback: ", _current_room_id)


func _set_room(room: Node) -> void:
	"""Internal helper to set current room and update zoom."""
	_current_room = room
	_last_valid_room = room
	
	if "room_id" in room:
		_current_room_id = room.room_id
	else:
		_current_room_id = room.name
	
	# Update zoom if auto-zoom is enabled
	if auto_zoom_to_room:
		_apply_zoom()


func _apply_zoom() -> void:
	"""Apply zoom based on settings. If auto_zoom_to_room, calculates zoom to fit room, then multiplies by base_zoom."""
	if _viewport_size == Vector2.ZERO:
		# Not ready yet, will be called again in _ready
		return
	
	var final_zoom = base_zoom
	
	if auto_zoom_to_room and _current_room:
		var room_bounds = _get_room_bounds(_current_room)
		if room_bounds.size != Vector2.ZERO:
			# Calculate zoom needed to fit room exactly in viewport
			var zoom_x = _viewport_size.x / room_bounds.size.x
			var zoom_y = _viewport_size.y / room_bounds.size.y
			# Use the larger zoom (more zoomed in) to ensure room fills viewport
			var room_fit_zoom = maxf(zoom_x, zoom_y)
			
			# Multiply by base_zoom: 1.0 = fit room exactly, 2.0 = see half the room, etc.
			final_zoom = room_fit_zoom * base_zoom
			
			if debug_mode:
				print("[GameCamera] Auto-zoom: viewport=", _viewport_size, " room=", room_bounds.size, " room_fit_zoom=", room_fit_zoom, " base_zoom=", base_zoom, " final=", final_zoom)
	
	# Apply zoom with margin
	zoom = Vector2(final_zoom * zoom_margin, final_zoom * zoom_margin)


func _get_target_position() -> Vector2:
	if not target_node:
		return global_position
	return target_node.global_position + Vector2(horizontal_offset, vertical_offset)


func _physics_process(delta: float) -> void:
	if not target_node:
		return
	
	# Handle smooth transitions
	if _is_transitioning:
		_update_transition(delta)
		return
	
	# Determine which room to use for constraints - ALWAYS use a room if we have one
	var active_room = _get_active_room()
	
	# Confine player to room if enabled
	if confine_player_to_room and active_room:
		_confine_player_to_room(active_room)
	
	# Calculate target position
	var target_pos = _get_target_position()
	
	# ALWAYS clamp to room bounds if we have a room - this is the key fix
	if active_room:
		target_pos = _clamp_to_room_bounds(target_pos, active_room)
	
	# Apply position
	global_position = target_pos
	
	# Update effects
	_update_bounce(delta)
	_update_shake(delta)


func _get_active_room() -> Node:
	"""Returns the room to use for camera constraints.
	ALWAYS returns a room if we have one - camera should never be unconstrained."""
	# If we have a current room, use it and remember it
	if _current_room and is_instance_valid(_current_room):
		_last_valid_room = _current_room
		_player_outside_rooms = false
		return _current_room
	
	# Player is outside all rooms - use last valid room
	if _last_valid_room and is_instance_valid(_last_valid_room):
		if not _player_outside_rooms and debug_mode:
			push_warning("[GameCamera] Player outside rooms, staying locked to: ", _last_valid_room.name)
		_player_outside_rooms = true
		return _last_valid_room
	
	# No room at all - this shouldn't happen in normal gameplay
	if debug_mode:
		push_error("[GameCamera] No active room! Camera is unconstrained.")
	return null


func _confine_player_to_room(room: Node) -> void:
	"""Clamp player position to stay within room bounds."""
	if not target_node or not room:
		return
	
	var room_bounds = _get_room_bounds(room)
	if room_bounds.size == Vector2.ZERO:
		return
	
	# Shrink bounds by margin
	var confined_bounds = Rect2(
		room_bounds.position + Vector2(player_confine_margin, player_confine_margin),
		room_bounds.size - Vector2(player_confine_margin * 2, player_confine_margin * 2)
	)
	
	# Clamp player position
	var player_pos = target_node.global_position
	var clamped_pos = player_pos.clamp(confined_bounds.position, confined_bounds.end)
	
	if player_pos != clamped_pos:
		target_node.global_position = clamped_pos
		# Also zero out velocity in the clamped direction to prevent fighting
		if target_node.has_method("get") and "velocity" in target_node:
			var vel = target_node.velocity
			if player_pos.x != clamped_pos.x:
				vel.x = 0
			if player_pos.y != clamped_pos.y:
				vel.y = 0
			target_node.velocity = vel


func _get_room_bounds(room: Node) -> Rect2:
	"""Get the bounds rect from a room node."""
	if room.has_method("get_bounds"):
		return room.get_bounds()
	elif "bounds" in room:
		return room.bounds
	elif "room_size" in room:
		return Rect2(room.global_position, room.room_size)
	return Rect2()


func _clamp_to_room_bounds(pos: Vector2, room: Node) -> Vector2:
	"""Clamp camera position to room bounds - ensures nothing outside room is visible."""
	var room_bounds = _get_room_bounds(room)
	if room_bounds.size == Vector2.ZERO:
		if debug_mode:
			print("[GameCamera] WARNING: Room bounds are zero!")
		return pos
	
	# Get effective viewport size (accounting for zoom)
	var effective_viewport = _viewport_size / zoom
	var half_viewport = effective_viewport / 2
	
	# Calculate camera bounds (where camera CENTER can be)
	# Camera center must stay far enough from edges that viewport doesn't show outside
	var min_pos = room_bounds.position + half_viewport
	var max_pos = room_bounds.end - half_viewport
	
	if debug_mode:
		print("[GameCamera] Clamp debug: room_bounds=", room_bounds, " effective_viewport=", effective_viewport, " min=", min_pos, " max=", max_pos, " input_pos=", pos)
	
	# Handle rooms smaller than or equal to viewport (center camera)
	if room_bounds.size.x <= effective_viewport.x:
		# Room is narrower than viewport - center horizontally
		var center_x = room_bounds.position.x + room_bounds.size.x / 2
		min_pos.x = center_x
		max_pos.x = center_x
	if room_bounds.size.y <= effective_viewport.y:
		# Room is shorter than viewport - center vertically
		var center_y = room_bounds.position.y + room_bounds.size.y / 2
		min_pos.y = center_y
		max_pos.y = center_y
	
	var result = pos.clamp(min_pos, max_pos)
	
	if debug_mode and result != pos:
		print("[GameCamera] Clamped from ", pos, " to ", result)
	
	return result


func _update_bounce(delta: float) -> void:
	if _bounce_offset.length() < 0.01 and _bounce_velocity.length() < 0.01:
		_bounce_offset = Vector2.ZERO
		_bounce_velocity = Vector2.ZERO
		return
	
	# Spring physics
	_bounce_velocity -= _bounce_offset * bounce_decay * delta * 60
	_bounce_velocity *= pow(0.85, delta * 60)  # Damping
	_bounce_offset += _bounce_velocity * delta
	
	# Apply as offset
	offset = _bounce_offset


func _update_shake(delta: float) -> void:
	if _shake_intensity <= 0:
		return
	
	var shake_offset = Vector2(
		randf_range(-_shake_intensity, _shake_intensity),
		randf_range(-_shake_intensity, _shake_intensity)
	)
	offset = _bounce_offset + shake_offset
	_shake_intensity = maxf(0, _shake_intensity - _shake_decay * delta)


func _update_transition(delta: float) -> void:
	_transition_progress += delta / transition_duration
	
	if _transition_progress >= 1.0:
		_transition_progress = 1.0
		_is_transitioning = false
		global_position = _transition_end_pos
		room_transition_complete.emit(_current_room_id)
		
		if debug_mode:
			print("[GameCamera] Transition complete to: ", _current_room_id)
	else:
		# Smooth easing
		var t = _ease_out_cubic(_transition_progress)
		global_position = _transition_start_pos.lerp(_transition_end_pos, t)


func _ease_out_cubic(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3)



# ============ ROOM MANAGEMENT ============

func enter_room(room: Node) -> void:
	"""Called when player enters a new room. Handles transition."""
	if room == _current_room:
		return
	
	var old_room = _current_room
	_previous_room_id = _current_room_id
	
	# Set the new room
	_set_room(room)
	
	if debug_mode:
		print("[GameCamera] Entering room: ", _current_room_id, " from: ", _previous_room_id)
	
	room_entered.emit(_current_room_id)
	
	if old_room:
		room_exited.emit(_previous_room_id)
		room_transition_started.emit(_previous_room_id, _current_room_id)
		_handle_room_transition(old_room, room)
	else:
		# First room - just snap
		snap_to_room(room)
		room_transition_complete.emit(_current_room_id)


func snap_to_room(room: Node) -> void:
	"""Instantly snap camera to room bounds (no transition effects)."""
	_set_room(room)
	
	# Clear effects
	_bounce_offset = Vector2.ZERO
	_bounce_velocity = Vector2.ZERO
	_is_transitioning = false
	
	# Snap to target within room
	if target_node:
		var target_pos = _get_target_position()
		global_position = _clamp_to_room_bounds(target_pos, room)
	
	if debug_mode:
		print("[GameCamera] Snapped to room: ", _current_room_id)


func _handle_room_transition(from_room: Node, to_room: Node) -> void:
	"""Handle the transition between two rooms based on transition_mode."""
	match transition_mode:
		0:  # Instant Snap
			_do_instant_snap(from_room, to_room)
		1:  # Smooth Pan
			_do_smooth_pan(to_room)
		2:  # Fade (would need additional implementation)
			_do_instant_snap(from_room, to_room)  # Fallback to snap for now


func _do_instant_snap(from_room: Node, to_room: Node) -> void:
	"""Instant snap with optional bounce effect."""
	# Calculate target position in new room
	var target_pos = _get_target_position()
	global_position = _clamp_to_room_bounds(target_pos, to_room)
	
	# Trigger bounce if enabled
	if snap_bounce_intensity > 0 and from_room:
		_trigger_snap_bounce(from_room, to_room)
	
	room_transition_complete.emit(_current_room_id)


func _do_smooth_pan(to_room: Node) -> void:
	"""Smooth pan to new room."""
	_transition_start_pos = global_position
	
	# Calculate end position
	var target_pos = _get_target_position()
	_transition_end_pos = _clamp_to_room_bounds(target_pos, to_room)
	
	_transition_progress = 0.0
	_is_transitioning = true


func _trigger_snap_bounce(from_room: Node, to_room: Node) -> void:
	"""Create a bounce effect based on transition direction."""
	# Get room centers
	var from_bounds: Rect2
	var to_bounds: Rect2
	
	if from_room.has_method("get_bounds"):
		from_bounds = from_room.get_bounds()
	elif "bounds" in from_room:
		from_bounds = from_room.bounds
	else:
		return
	
	if to_room.has_method("get_bounds"):
		to_bounds = to_room.get_bounds()
	elif "bounds" in to_room:
		to_bounds = to_room.bounds
	else:
		return
	
	var from_center = from_bounds.get_center()
	var to_center = to_bounds.get_center()
	var direction = (to_center - from_center).normalized()
	
	# Bounce opposite to movement direction
	_bounce_velocity = -direction * snap_bounce_intensity


# ============ PUBLIC API ============

func get_current_room() -> Node:
	return _current_room


func get_current_room_id() -> String:
	return _current_room_id


func shake(intensity: float = -1.0, decay: float = -1.0) -> void:
	"""Trigger screen shake effect."""
	_shake_intensity = intensity if intensity > 0 else default_shake_intensity
	_shake_decay = decay if decay > 0 else default_shake_decay


func set_target(new_target: Node2D) -> void:
	"""Change the follow target."""
	target_node = new_target
	if target_node and _current_room:
		global_position = _clamp_to_room_bounds(_get_target_position(), _current_room)


func force_position(pos: Vector2) -> void:
	"""Force camera to a specific position (ignores room bounds temporarily)."""
	global_position = pos
	_bounce_offset = Vector2.ZERO
	_bounce_velocity = Vector2.ZERO


# ============ SAVE/LOAD ============

func get_save_data() -> Dictionary:
	return {
		"room_id": _current_room_id,
		"position_x": global_position.x,
		"position_y": global_position.y
	}


func load_save_data(data: Dictionary) -> void:
	if data.has("room_id"):
		_current_room_id = data.room_id
	if data.has("position_x") and data.has("position_y"):
		global_position = Vector2(data.position_x, data.position_y)
