@tool
class_name LevelEntrance
extends Marker2D
## Drop-in spawn point marker. Place where players should appear when
## entering from another level.

# ============ CONFIGURATION ============
## Unique ID for this entrance (referenced by LevelConnection.target_entrance)
@export var entrance_id: String = "default"

## Which direction the player should face when spawning
@export_enum("Left:-1", "Right:1") var facing_direction: int = 1

## Editor visualization color
@export var editor_color: Color = Color(0.0, 1.0, 0.5, 0.8)

## Size of the visual marker in editor
@export var marker_size: float = 24.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		add_to_group("LevelEntrance")


## Get this entrance by ID from the current scene
static func find_entrance(target_entrance_id: String) -> LevelEntrance:
	var tree = Engine.get_main_loop() as SceneTree
	if not tree:
		return null
	
	var entrances = tree.get_nodes_in_group("LevelEntrance")
	for entrance in entrances:
		if entrance is LevelEntrance and entrance.entrance_id == target_entrance_id:
			return entrance
	
	# Fallback: return first entrance if ID not found
	if entrances.size() > 0:
		push_warning("LevelEntrance: '%s' not found, using first entrance" % target_entrance_id)
		return entrances[0] as LevelEntrance
	
	return null


## Spawn the player at this entrance
func spawn_player(player: Node2D) -> void:
	player.global_position = global_position
	
	# Set facing direction if player supports it
	if player.has_method("set_facing_direction"):
		player.set_facing_direction(facing_direction)
	elif "facing_direction" in player:
		player.facing_direction = facing_direction
	elif "_facing_direction" in player:
		player._facing_direction = float(facing_direction)
		# Also flip sprite if it exists
		var sprite = player.get_node_or_null("AnimatedSprite2D")
		if sprite:
			sprite.flip_h = facing_direction < 0


# ============ EDITOR VISUALIZATION ============

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	
	# Draw spawn point circle
	draw_circle(Vector2.ZERO, marker_size / 2, editor_color)
	
	# Draw border
	draw_arc(Vector2.ZERO, marker_size / 2, 0, TAU, 32, Color.WHITE, 2.0)
	
	# Draw facing direction arrow
	var arrow_length = marker_size * 0.8
	var arrow_head_size = 8.0
	var arrow_end = Vector2(facing_direction * arrow_length, 0)
	
	draw_line(Vector2.ZERO, arrow_end, Color.WHITE, 2.0)
	
	# Arrow head
	var arrow_points = PackedVector2Array([
		arrow_end,
		arrow_end + Vector2(-facing_direction * arrow_head_size, -arrow_head_size / 2),
		arrow_end + Vector2(-facing_direction * arrow_head_size, arrow_head_size / 2)
	])
	draw_colored_polygon(arrow_points, Color.WHITE)
	
	# Entrance ID label
	var font = ThemeDB.fallback_font
	var font_size = 14
	draw_string(font, Vector2(-marker_size, marker_size), entrance_id, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
