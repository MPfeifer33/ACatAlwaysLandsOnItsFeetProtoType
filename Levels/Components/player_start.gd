@tool
class_name PlayerStart
extends Marker2D
## Drop this into your level to mark the player spawn point.
## Add to "player_start" group automatically.

@export var is_default_spawn: bool = true  ## If multiple exist, this one is used for new games


func _ready() -> void:
	add_to_group("player_start")
	
	# Editor visualization
	if Engine.is_editor_hint():
		queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	
	# Draw a visible marker in the editor
	var color = Color.LIME_GREEN if is_default_spawn else Color.YELLOW
	
	# Cat silhouette-ish shape
	draw_circle(Vector2.ZERO, 8, color)
	draw_circle(Vector2(-5, -6), 3, color)  # Left ear
	draw_circle(Vector2(5, -6), 3, color)   # Right ear
	
	# Arrow pointing down
	draw_line(Vector2(0, 10), Vector2(0, 20), color, 2.0)
	draw_line(Vector2(0, 20), Vector2(-4, 16), color, 2.0)
	draw_line(Vector2(0, 20), Vector2(4, 16), color, 2.0)
	
	# Label
	draw_string(ThemeDB.fallback_font, Vector2(-20, 35), "SPAWN", HORIZONTAL_ALIGNMENT_CENTER, -1, 10, color)
