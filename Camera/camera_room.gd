@tool
class_name CameraRoom
extends Area2D
## Defines a camera room boundary. Place in levels and size the CollisionShape2D
## to match your room dimensions. The camera will be constrained to this area.

## Unique identifier for this room (used for saves)
@export var room_id: String = ""

## Visual color in editor (doesn't affect gameplay)
@export var editor_color: Color = Color(0.2, 0.6, 1.0, 0.3)

## The bounding rectangle of this room in global coordinates
var bounds: Rect2:
	get:
		return _calculate_bounds()

var _collision_shape: CollisionShape2D = null


func _ready() -> void:
	# Auto-generate room_id if empty
	if room_id.is_empty():
		room_id = "room_" + str(get_instance_id())
	
	# Find collision shape
	for child in get_children():
		if child is CollisionShape2D:
			_collision_shape = child
			break
	
	# Connect signals for player detection
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
		
		# Set collision to detect player
		collision_layer = 0
		collision_mask = 2  # Player layer


func _calculate_bounds() -> Rect2:
	if not _collision_shape or not _collision_shape.shape:
		# Return a default large rect if no shape
		return Rect2(global_position - Vector2(500, 500), Vector2(1000, 1000))
	
	var shape = _collision_shape.shape
	var shape_pos = _collision_shape.global_position
	
	if shape is RectangleShape2D:
		var size = shape.size
		return Rect2(shape_pos - size / 2, size)
	elif shape is CircleShape2D:
		var radius = shape.radius
		return Rect2(shape_pos - Vector2(radius, radius), Vector2(radius * 2, radius * 2))
	elif shape is CapsuleShape2D:
		var width = shape.radius * 2
		var height = shape.height
		return Rect2(shape_pos - Vector2(width / 2, height / 2), Vector2(width, height))
	
	# Fallback
	return Rect2(shape_pos - Vector2(500, 500), Vector2(1000, 1000))


func get_camera_bounds(viewport_size: Vector2) -> Rect2:
	"""Returns the bounds the camera center should be clamped to.
	This accounts for viewport size so camera edges don't go outside room."""
	var room_bounds = bounds
	var half_viewport = viewport_size / 2
	
	# If room is smaller than viewport, center camera in room
	var min_pos = room_bounds.position + half_viewport
	var max_pos = room_bounds.end - half_viewport
	
	# Clamp so min doesn't exceed max
	if min_pos.x > max_pos.x:
		min_pos.x = room_bounds.get_center().x
		max_pos.x = min_pos.x
	if min_pos.y > max_pos.y:
		min_pos.y = room_bounds.get_center().y
		max_pos.y = min_pos.y
	
	return Rect2(min_pos, max_pos - min_pos)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		var camera = _find_game_camera()
		if camera:
			camera.enter_room(self)


func _on_body_exited(_body: Node2D) -> void:
	# Room exit is handled by entering the next room
	pass


func _find_game_camera() -> GameCamera:
	# First try to find via group (most reliable)
	var cameras = get_tree().get_nodes_in_group("GameCamera")
	if cameras.size() > 0:
		return cameras[0] as GameCamera
	
	# Fallback: check if player has camera as child
	var player = get_tree().get_first_node_in_group("Player")
	if player:
		for child in player.get_children():
			if child is GameCamera:
				return child
				
		# Also check for Camera2D that might be GameCamera
		for child in player.get_children():
			if child is Camera2D and child.has_method("enter_room"):
				return child as GameCamera
	
	return null


# ============ EDITOR VISUALIZATION ============

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	
	var rect = bounds
	# Convert to local coordinates
	var local_rect = Rect2(rect.position - global_position, rect.size)
	
	# Draw filled rectangle
	draw_rect(local_rect, editor_color, true)
	
	# Draw border
	var border_color = editor_color
	border_color.a = 1.0
	draw_rect(local_rect, border_color, false, 2.0)
	
	# Draw room ID label
	if not room_id.is_empty():
		var font = ThemeDB.fallback_font
		var font_size = ThemeDB.fallback_font_size
		draw_string(font, local_rect.position + Vector2(10, 20), room_id, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, border_color)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
