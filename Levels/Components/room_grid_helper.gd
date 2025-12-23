@tool
class_name RoomGridHelper
extends Node2D
## Editor tool to visualize and auto-generate Room nodes for a grid-based level.
## Place this in your level, configure the grid, then click "Generate Rooms" in inspector.

# ============ GRID CONFIGURATION ============
@export_group("Grid Settings")
## Size of each room/cell in pixels (matches 1152x648 viewport)
@export var cell_size: Vector2 = Vector2(1152, 648):
	set(value):
		cell_size = value
		queue_redraw()

## Number of columns in grid
@export var columns: int = 4:
	set(value):
		columns = value
		_update_grid_data()
		queue_redraw()

## Number of rows in grid
@export var rows: int = 4:
	set(value):
		rows = value
		_update_grid_data()
		queue_redraw()

## Grid origin (top-left corner position)
@export var grid_origin: Vector2 = Vector2.ZERO:
	set(value):
		grid_origin = value
		queue_redraw()

@export_group("Room Generation")
## Which cells have rooms (use the checkboxes to toggle)
@export var active_cells: Array[bool] = []:
	set(value):
		active_cells = value
		queue_redraw()

## Click to generate Room nodes for active cells
@export var generate_rooms: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_generate_room_nodes()

## Click to clear all generated rooms
@export var clear_rooms: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_clear_room_nodes()

@export_group("Visualization")
## Color for active (has room) cells
@export var active_color: Color = Color(0.2, 0.7, 0.3, 0.3)
## Color for inactive cells
@export var inactive_color: Color = Color(0.5, 0.5, 0.5, 0.15)
## Grid line color
@export var grid_color: Color = Color(1, 1, 1, 0.5)


func _ready() -> void:
	_update_grid_data()


func _update_grid_data() -> void:
	# Resize active_cells array to match grid
	var total_cells = columns * rows
	if active_cells.size() != total_cells:
		var old_cells = active_cells.duplicate()
		active_cells.resize(total_cells)
		# Preserve existing values
		for i in range(mini(old_cells.size(), total_cells)):
			active_cells[i] = old_cells[i]
		# Default new cells to false
		for i in range(old_cells.size(), total_cells):
			active_cells[i] = false


func _get_cell_rect(col: int, row: int) -> Rect2:
	var pos = grid_origin + Vector2(col * cell_size.x, row * cell_size.y)
	return Rect2(pos, cell_size)


func _get_cell_index(col: int, row: int) -> int:
	return row * columns + col


func _generate_room_nodes() -> void:
	if not Engine.is_editor_hint():
		return
	
	var parent = get_parent()
	if not parent:
		push_error("RoomGridHelper must have a parent node")
		return
	
	# Load the Room scene or script
	var room_script = preload("res://Levels/Components/room.gd")
	
	var generated_count = 0
	for row in range(rows):
		for col in range(columns):
			var idx = _get_cell_index(col, row)
			if idx < active_cells.size() and active_cells[idx]:
				var room_id = "room_%d_%d" % [col, row]
				
				# Check if room already exists
				var existing = parent.get_node_or_null(room_id)
				if existing:
					continue
				
				# Create new Room
				var room = Area2D.new()
				room.set_script(room_script)
				room.name = room_id
				room.room_id = room_id
				room.room_size = cell_size
				room.position = grid_origin + Vector2(col * cell_size.x, row * cell_size.y)
				
				parent.add_child(room)
				room.owner = get_tree().edited_scene_root
				generated_count += 1
	
	print("Generated %d room(s)" % generated_count)


func _clear_room_nodes() -> void:
	if not Engine.is_editor_hint():
		return
	
	var parent = get_parent()
	if not parent:
		return
	
	var removed_count = 0
	for child in parent.get_children():
		if child is Area2D and child.has_method("get_bounds"):
			child.queue_free()
			removed_count += 1
	
	print("Removed %d room(s)" % removed_count)


# ============ EDITOR VISUALIZATION ============

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	
	# Draw each cell
	for row in range(rows):
		for col in range(columns):
			var rect = _get_cell_rect(col, row)
			var local_rect = Rect2(rect.position - global_position, rect.size)
			var idx = _get_cell_index(col, row)
			
			# Fill based on active state
			var is_active = idx < active_cells.size() and active_cells[idx]
			var fill_color = active_color if is_active else inactive_color
			draw_rect(local_rect, fill_color, true)
			
			# Border
			draw_rect(local_rect, grid_color, false, 1.0)
			
			# Cell label
			var font = ThemeDB.fallback_font
			var label = "%d,%d" % [col, row]
			var label_pos = local_rect.position + Vector2(5, 20)
			draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, grid_color)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
