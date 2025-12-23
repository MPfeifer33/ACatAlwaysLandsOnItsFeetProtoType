@tool
class_name Room
extends Area2D
## Drop-in room component. Place in your level, position it, and the camera will
## lock to this room's bounds when the player enters.
## Standard size: 1200x700 (fits well at multiple resolutions)

# ============ SIGNALS ============
signal player_entered(room: Room)
signal player_exited(room: Room)

# ============ CONFIGURATION ============
## Unique ID for this room (auto-generated if empty)
@export var room_id: String = ""

## Room size in pixels - default matches 1152x648 viewport
@export var room_size: Vector2 = Vector2(1152, 648):
	set(value):
		room_size = value
		_update_collision_shape()
		queue_redraw()

## Editor visualization color
@export var editor_color: Color = Color(0.2, 0.7, 0.4, 0.25)

## Whether this is the starting room (camera snaps here on level load)
@export var is_starting_room: bool = false

# ============ INTERNAL ============
var _collision_shape: CollisionShape2D = null
var _player_inside: bool = false


func _ready() -> void:
	# Auto-generate room_id if empty
	if room_id.is_empty():
		room_id = "room_" + str(get_instance_id())
	
	# Setup collision
	_setup_collision()
	
	if not Engine.is_editor_hint():
		# Connect signals
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
		
		# Set collision to detect player only
		collision_layer = 0
		collision_mask = 2  # Player layer
		
		# Register with SceneManager if available
		_register_room()


func _setup_collision() -> void:
	# Find or create collision shape
	for child in get_children():
		if child is CollisionShape2D:
			_collision_shape = child
			break
	
	if not _collision_shape:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		add_child(_collision_shape)
		if Engine.is_editor_hint():
			_collision_shape.owner = get_tree().edited_scene_root
	
	_update_collision_shape()


func _update_collision_shape() -> void:
	if not _collision_shape:
		return
	
	var shape = _collision_shape.shape
	if not shape or not shape is RectangleShape2D:
		shape = RectangleShape2D.new()
		_collision_shape.shape = shape
	
	(shape as RectangleShape2D).size = room_size
	# Center the collision shape
	_collision_shape.position = room_size / 2


func _register_room() -> void:
	# Add to group for easy finding
	add_to_group("Room")
	
	# If SceneManager exists, register
	if Engine.has_singleton("SceneManager"):
		pass  # SceneManager will find us via group
	
	# If this is starting room, notify camera immediately
	if is_starting_room:
		call_deferred("_notify_camera_starting_room")


func _notify_camera_starting_room() -> void:
	var camera = _find_game_camera()
	if camera and camera.has_method("snap_to_room"):
		camera.snap_to_room(self)


# ============ BOUNDS ============

func get_bounds() -> Rect2:
	"""Returns the room bounds in global coordinates."""
	return Rect2(global_position, room_size)


func get_camera_bounds(viewport_size: Vector2) -> Rect2:
	"""Returns bounds for camera center, accounting for viewport size."""
	var bounds = get_bounds()
	var half_viewport = viewport_size / 2
	
	var min_pos = bounds.position + half_viewport
	var max_pos = bounds.end - half_viewport
	
	# If room is smaller than viewport in any dimension, center on that axis
	if min_pos.x > max_pos.x:
		var center_x = bounds.position.x + bounds.size.x / 2
		min_pos.x = center_x
		max_pos.x = center_x
	if min_pos.y > max_pos.y:
		var center_y = bounds.position.y + bounds.size.y / 2
		min_pos.y = center_y
		max_pos.y = center_y
	
	return Rect2(min_pos, max_pos - min_pos)


func contains_point(point: Vector2) -> bool:
	"""Check if a global point is inside this room."""
	return get_bounds().has_point(point)


# ============ PLAYER DETECTION ============

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_player_inside = true
		player_entered.emit(self)
		
		# Notify camera
		var camera = _find_game_camera()
		if camera and camera.has_method("enter_room"):
			camera.enter_room(self)


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		_player_inside = false
		player_exited.emit(self)


func _find_game_camera() -> Node:
	var cameras = get_tree().get_nodes_in_group("GameCamera")
	if cameras.size() > 0:
		return cameras[0]
	return null


func is_player_inside() -> bool:
	return _player_inside


# ============ EDITOR VISUALIZATION ============

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	
	var rect = Rect2(Vector2.ZERO, room_size)
	
	# Fill
	draw_rect(rect, editor_color, true)
	
	# Border
	var border_color = editor_color
	border_color.a = 1.0
	draw_rect(rect, border_color, false, 3.0)
	
	# Corner markers
	var corner_size = 20.0
	var corners = [
		Vector2.ZERO,
		Vector2(room_size.x - corner_size, 0),
		Vector2(0, room_size.y - corner_size),
		room_size - Vector2(corner_size, corner_size)
	]
	for corner in corners:
		draw_rect(Rect2(corner, Vector2(corner_size, corner_size)), border_color, false, 2.0)
	
	# Room ID and size label
	var font = ThemeDB.fallback_font
	var font_size = 16
	draw_string(font, Vector2(10, 25), room_id, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, border_color)
	draw_string(font, Vector2(10, 45), "%dx%d" % [int(room_size.x), int(room_size.y)], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, border_color)
	
	# Starting room indicator
	if is_starting_room:
		draw_string(font, Vector2(10, 65), "[START]", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size - 2, Color.YELLOW)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
