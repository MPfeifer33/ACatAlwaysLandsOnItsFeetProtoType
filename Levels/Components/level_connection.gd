@tool
class_name LevelConnection
extends Area2D
## Drop-in component that connects levels. Place at room edges.
## When player touches this, triggers a scene transition.

# ============ CONFIGURATION ============
enum Direction { LEFT, RIGHT, UP, DOWN }

## The scene to load when player enters
@export var target_scene: PackedScene

## Which edge of the room this connection is on
@export var direction: Direction = Direction.RIGHT:
	set(value):
		direction = value
		_update_visual()
		queue_redraw()

## The entrance ID in the target scene to spawn at
@export var target_entrance: String = "default"

## Width/height of the trigger zone
@export var trigger_size: float = 32.0:
	set(value):
		trigger_size = value
		_update_collision()
		queue_redraw()

## Length along the edge (how wide/tall the trigger area is)
@export var trigger_length: float = 200.0:
	set(value):
		trigger_length = value
		_update_collision()
		queue_redraw()

## Editor color
@export var editor_color: Color = Color(1.0, 0.5, 0.0, 0.5)

## Optional: disable this connection (useful for locked doors)
@export var enabled: bool = true

# ============ INTERNAL ============
var _collision_shape: CollisionShape2D = null


func _ready() -> void:
	_setup_collision()
	
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		collision_layer = 0
		collision_mask = 2  # Player layer
		
		# Add to group for finding
		add_to_group("LevelConnection")


func _setup_collision() -> void:
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
	
	_update_collision()


func _update_collision() -> void:
	if not _collision_shape:
		return
	
	var shape = _collision_shape.shape
	if not shape or not shape is RectangleShape2D:
		shape = RectangleShape2D.new()
		_collision_shape.shape = shape
	
	# Size based on direction
	match direction:
		Direction.LEFT, Direction.RIGHT:
			(shape as RectangleShape2D).size = Vector2(trigger_size, trigger_length)
		Direction.UP, Direction.DOWN:
			(shape as RectangleShape2D).size = Vector2(trigger_length, trigger_size)


func _update_visual() -> void:
	_update_collision()


func _on_body_entered(body: Node2D) -> void:
	if not enabled:
		return
	
	if not body.is_in_group("Player"):
		return
	
	if not target_scene:
		push_warning("LevelConnection: No target_scene set!")
		return
	
	# Trigger scene transition via SceneManager
	var scene_manager = _get_scene_manager()
	if scene_manager:
		scene_manager.transition_to_scene(target_scene, target_entrance, direction)
	else:
		push_error("LevelConnection: SceneManager not found!")


func _get_scene_manager() -> Node:
	# Try autoload first
	if has_node("/root/SceneManager"):
		return get_node("/root/SceneManager")
	
	# Fallback to group search
	var managers = get_tree().get_nodes_in_group("SceneManager")
	if managers.size() > 0:
		return managers[0]
	
	return null


## Get the spawn offset for the target scene based on direction
func get_spawn_offset() -> Vector2:
	"""Returns offset to apply when spawning in target scene."""
	match direction:
		Direction.LEFT:
			return Vector2(50, 0)  # Spawn slightly right of left entrance
		Direction.RIGHT:
			return Vector2(-50, 0)  # Spawn slightly left of right entrance
		Direction.UP:
			return Vector2(0, 50)  # Spawn slightly below top entrance
		Direction.DOWN:
			return Vector2(0, -50)  # Spawn slightly above bottom entrance
	return Vector2.ZERO


# ============ EDITOR VISUALIZATION ============

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	
	var size: Vector2
	match direction:
		Direction.LEFT, Direction.RIGHT:
			size = Vector2(trigger_size, trigger_length)
		Direction.UP, Direction.DOWN:
			size = Vector2(trigger_length, trigger_size)
	
	var rect = Rect2(-size / 2, size)
	
	# Fill
	var fill_color = editor_color if enabled else Color(0.5, 0.5, 0.5, 0.3)
	draw_rect(rect, fill_color, true)
	
	# Border
	var border_color = fill_color
	border_color.a = 1.0
	draw_rect(rect, border_color, false, 2.0)
	
	# Arrow indicating direction
	var arrow_color = Color.WHITE
	var center = Vector2.ZERO
	var arrow_size = 15.0
	var arrow_points: PackedVector2Array
	
	match direction:
		Direction.RIGHT:
			arrow_points = PackedVector2Array([
				center + Vector2(-arrow_size, -arrow_size/2),
				center + Vector2(arrow_size, 0),
				center + Vector2(-arrow_size, arrow_size/2)
			])
		Direction.LEFT:
			arrow_points = PackedVector2Array([
				center + Vector2(arrow_size, -arrow_size/2),
				center + Vector2(-arrow_size, 0),
				center + Vector2(arrow_size, arrow_size/2)
			])
		Direction.DOWN:
			arrow_points = PackedVector2Array([
				center + Vector2(-arrow_size/2, -arrow_size),
				center + Vector2(0, arrow_size),
				center + Vector2(arrow_size/2, -arrow_size)
			])
		Direction.UP:
			arrow_points = PackedVector2Array([
				center + Vector2(-arrow_size/2, arrow_size),
				center + Vector2(0, -arrow_size),
				center + Vector2(arrow_size/2, arrow_size)
			])
	
	draw_colored_polygon(arrow_points, arrow_color)
	
	# Target scene name
	var font = ThemeDB.fallback_font
	var font_size = 12
	var label = target_scene.resource_path.get_file() if target_scene else "[NO TARGET]"
	draw_string(font, Vector2(-size.x/2, size.y/2 + 15), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, border_color)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
