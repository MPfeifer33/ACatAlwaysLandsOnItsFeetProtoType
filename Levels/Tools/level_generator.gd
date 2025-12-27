@tool
class_name LevelGenerator
extends RefCounted
## Procedural level generator using a walker algorithm.
## Generates a grid of connected rooms based on defined rules.
##
## Usage:
##   var generator = LevelGenerator.new()
##   generator.set_seed(12345)  # Optional: for reproducible levels
##   var result = generator.generate()
##   # result.grid = Dictionary of Vector2i -> RoomPlacement
##   # result.rooms = Array of RoomPlacement objects

# ============ GRID SETTINGS ============
## Base cell size in pixels (matches camera room system)
const CELL_SIZE := Vector2(1152, 648)

## Tile size for stamp alignment
const TILE_SIZE := 16

# ============ DIRECTION HELPERS ============
enum Dir { TOP, RIGHT, BOTTOM, LEFT }

const DIR_VECTORS := {
	Dir.TOP: Vector2i(0, -1),
	Dir.RIGHT: Vector2i(1, 0),
	Dir.BOTTOM: Vector2i(0, 1),
	Dir.LEFT: Vector2i(-1, 0),
}

const OPPOSITE_DIR := {
	Dir.TOP: Dir.BOTTOM,
	Dir.RIGHT: Dir.LEFT,
	Dir.BOTTOM: Dir.TOP,
	Dir.LEFT: Dir.RIGHT,
}

const DIR_NAMES := {
	Dir.TOP: "top",
	Dir.RIGHT: "right",
	Dir.BOTTOM: "bottom",
	Dir.LEFT: "left",
}

# ============ ROOM DEFINITIONS ============
## Room type definitions with sizes and connection rules
## size: Vector2i grid cells (width, height)
## exits: Array of Dir - which sides have doors
## tags: Array of String - for connection rules
## terminal: bool - if true, this room ends a branch
## weight: float - spawn probability weight
var room_types := {
	# === CORRIDORS ===
	"corridor_h": {
		"size": Vector2i(1, 1),
		"exits": [Dir.LEFT, Dir.RIGHT],
		"tags": ["corridor", "basic"],
		"weight": 10.0,
	},
	"corridor_v": {
		"size": Vector2i(1, 1),
		"exits": [Dir.TOP, Dir.BOTTOM],
		"tags": ["corridor", "basic"],
		"weight": 10.0,
	},
	"corridor_long_h": {
		"size": Vector2i(2, 1),
		"exits": [Dir.LEFT, Dir.RIGHT],
		"tags": ["corridor", "basic"],
		"weight": 5.0,
	},
	"corridor_long_v": {
		"size": Vector2i(1, 2),
		"exits": [Dir.TOP, Dir.BOTTOM],
		"tags": ["corridor", "basic"],
		"weight": 5.0,
	},
	
	# === CORNERS ===
	"corner_tl": {
		"size": Vector2i(1, 1),
		"exits": [Dir.TOP, Dir.LEFT],
		"tags": ["corner", "basic"],
		"weight": 6.0,
	},
	"corner_tr": {
		"size": Vector2i(1, 1),
		"exits": [Dir.TOP, Dir.RIGHT],
		"tags": ["corner", "basic"],
		"weight": 6.0,
	},
	"corner_bl": {
		"size": Vector2i(1, 1),
		"exits": [Dir.BOTTOM, Dir.LEFT],
		"tags": ["corner", "basic"],
		"weight": 6.0,
	},
	"corner_br": {
		"size": Vector2i(1, 1),
		"exits": [Dir.BOTTOM, Dir.RIGHT],
		"tags": ["corner", "basic"],
		"weight": 6.0,
	},
	
	# === JUNCTIONS ===
	"t_junction_up": {
		"size": Vector2i(1, 1),
		"exits": [Dir.TOP, Dir.LEFT, Dir.RIGHT],
		"tags": ["junction", "hub"],
		"weight": 4.0,
	},
	"t_junction_down": {
		"size": Vector2i(1, 1),
		"exits": [Dir.BOTTOM, Dir.LEFT, Dir.RIGHT],
		"tags": ["junction", "hub"],
		"weight": 4.0,
	},
	"t_junction_left": {
		"size": Vector2i(1, 1),
		"exits": [Dir.TOP, Dir.BOTTOM, Dir.LEFT],
		"tags": ["junction", "hub"],
		"weight": 4.0,
	},
	"t_junction_right": {
		"size": Vector2i(1, 1),
		"exits": [Dir.TOP, Dir.BOTTOM, Dir.RIGHT],
		"tags": ["junction", "hub"],
		"weight": 4.0,
	},
	"crossroads": {
		"size": Vector2i(1, 1),
		"exits": [Dir.TOP, Dir.RIGHT, Dir.BOTTOM, Dir.LEFT],
		"tags": ["junction", "hub"],
		"weight": 2.0,
	},
	
	# === SPECIAL ROOMS ===
	"start_room": {
		"size": Vector2i(1, 1),
		"exits": [Dir.RIGHT],
		"tags": ["start", "special"],
		"weight": 0.0,  # Never randomly placed
	},
	"save_room": {
		"size": Vector2i(1, 1),
		"exits": [Dir.LEFT],
		"tags": ["save", "terminal", "special"],
		"terminal": true,
		"weight": 3.0,
	},
	"treasure_room": {
		"size": Vector2i(1, 1),
		"exits": [Dir.LEFT],
		"tags": ["treasure", "terminal", "special"],
		"terminal": true,
		"weight": 3.0,
	},
	"boss_room": {
		"size": Vector2i(2, 2),
		"exits": [Dir.LEFT],
		"tags": ["boss", "terminal", "special"],
		"terminal": true,
		"weight": 0.0,  # Placed intentionally
	},
	
	# === CHALLENGE ROOMS ===
	"arena_small": {
		"size": Vector2i(1, 1),
		"exits": [Dir.LEFT, Dir.RIGHT],
		"tags": ["arena", "combat"],
		"weight": 4.0,
	},
	"arena_large": {
		"size": Vector2i(2, 1),
		"exits": [Dir.LEFT, Dir.RIGHT],
		"tags": ["arena", "combat"],
		"weight": 2.0,
	},
	"vertical_shaft": {
		"size": Vector2i(1, 2),
		"exits": [Dir.TOP, Dir.BOTTOM],
		"tags": ["shaft", "platforming"],
		"weight": 4.0,
	},
}

# ============ CONNECTION RULES ============
## Rules for what room types can connect
## Key: tag, Value: array of allowed connecting tags (empty = any)
var connection_rules := {
	"boss": ["corridor", "hub"],  # Boss rooms only connect to corridors/hubs
	"save": ["corridor", "hub", "junction"],
	"treasure": ["corridor", "junction"],
	"start": ["corridor", "basic"],
}

# ============ GENERATION SETTINGS ============
var settings := {
	"min_rooms": 10,
	"max_rooms": 20,
	"branch_chance": 0.3,  # Chance to branch at junctions
	"terminal_chance": 0.15,  # Chance to place terminal room
	"force_boss": true,  # Always place a boss room
	"force_save": true,  # Always place at least one save room
	"max_branch_depth": 5,  # How deep branches can go
}

# ============ INTERNAL STATE ============
var _rng := RandomNumberGenerator.new()
var _grid: Dictionary = {}  # Vector2i -> RoomPlacement
var _rooms: Array = []  # All placed RoomPlacement objects
var _open_exits: Array = []  # Array of {pos: Vector2i, dir: Dir, depth: int}
var _placed_tags: Dictionary = {}  # Track how many of each tag placed


# ============ ROOM PLACEMENT CLASS ============
class RoomPlacement:
	var type: String  # Room type key
	var grid_pos: Vector2i  # Top-left grid position
	var size: Vector2i  # Size in grid cells
	var exits: Array  # Array of Dir
	var pixel_pos: Vector2  # World position in pixels
	var pixel_size: Vector2  # Size in pixels
	
	func _init(p_type: String, p_pos: Vector2i, p_size: Vector2i, p_exits: Array) -> void:
		type = p_type
		grid_pos = p_pos
		size = p_size
		exits = p_exits.duplicate()
		pixel_pos = Vector2(p_pos) * LevelGenerator.CELL_SIZE
		pixel_size = Vector2(p_size) * LevelGenerator.CELL_SIZE
	
	func get_bounds() -> Rect2:
		return Rect2(pixel_pos, pixel_size)
	
	func occupies_cell(cell: Vector2i) -> bool:
		return cell.x >= grid_pos.x and cell.x < grid_pos.x + size.x \
			and cell.y >= grid_pos.y and cell.y < grid_pos.y + size.y
	
	func get_exit_position(dir: int) -> Vector2i:
		## Returns the grid cell where an exit is located
		match dir:
			LevelGenerator.Dir.TOP:
				return Vector2i(grid_pos.x + size.x / 2, grid_pos.y)
			LevelGenerator.Dir.BOTTOM:
				return Vector2i(grid_pos.x + size.x / 2, grid_pos.y + size.y - 1)
			LevelGenerator.Dir.LEFT:
				return Vector2i(grid_pos.x, grid_pos.y + size.y / 2)
			LevelGenerator.Dir.RIGHT:
				return Vector2i(grid_pos.x + size.x - 1, grid_pos.y + size.y / 2)
		return grid_pos


# ============ PUBLIC API ============

func set_seed(seed_value: int) -> void:
	_rng.seed = seed_value


func set_setting(key: String, value: Variant) -> void:
	if settings.has(key):
		settings[key] = value


func add_room_type(type_name: String, definition: Dictionary) -> void:
	room_types[type_name] = definition


func generate() -> Dictionary:
	"""Main generation function. Returns {grid: Dictionary, rooms: Array}."""
	_reset()
	
	# Place starting room
	_place_start_room()
	
	# Main generation loop
	var iterations := 0
	var max_iterations := settings.max_rooms * 10  # Safety limit
	
	while _rooms.size() < settings.max_rooms and _open_exits.size() > 0 and iterations < max_iterations:
		iterations += 1
		
		# Pick a random open exit
		var exit_idx := _rng.randi() % _open_exits.size()
		var exit_info: Dictionary = _open_exits[exit_idx]
		
		# Try to place a room at this exit
		var placed := _try_place_room_at_exit(exit_info)
		
		if not placed:
			# Remove this exit if we couldn't place anything
			_open_exits.remove_at(exit_idx)
	
	# Force place required rooms if not already placed
	if settings.force_boss and not _placed_tags.has("boss"):
		_force_place_terminal("boss_room")
	
	if settings.force_save and not _placed_tags.has("save"):
		_force_place_terminal("save_room")
	
	# Close remaining open exits (they become walls)
	_open_exits.clear()
	
	print("[LevelGenerator] Generated %d rooms in %d iterations" % [_rooms.size(), iterations])
	
	return {
		"grid": _grid,
		"rooms": _rooms,
		"cell_size": CELL_SIZE,
	}


# ============ INTERNAL METHODS ============

func _reset() -> void:
	_grid.clear()
	_rooms.clear()
	_open_exits.clear()
	_placed_tags.clear()


func _place_start_room() -> void:
	var start_def: Dictionary = room_types["start_room"]
	var placement := RoomPlacement.new(
		"start_room",
		Vector2i.ZERO,
		start_def.size,
		start_def.exits
	)
	_add_room(placement)


func _add_room(placement: RoomPlacement) -> void:
	# Mark grid cells as occupied
	for y in range(placement.size.y):
		for x in range(placement.size.x):
			var cell := Vector2i(placement.grid_pos.x + x, placement.grid_pos.y + y)
			_grid[cell] = placement
	
	_rooms.append(placement)
	
	# Track tags
	var room_def: Dictionary = room_types.get(placement.type, {})
	var tags: Array = room_def.get("tags", [])
	for tag in tags:
		_placed_tags[tag] = _placed_tags.get(tag, 0) + 1
	
	# Add open exits (unless terminal)
	if not room_def.get("terminal", false):
		for exit_dir in placement.exits:
			var exit_cell := placement.get_exit_position(exit_dir)
			var neighbor_cell := exit_cell + DIR_VECTORS[exit_dir]
			
			# Only add if neighbor cell is empty
			if not _grid.has(neighbor_cell):
				_open_exits.append({
					"pos": neighbor_cell,
					"dir": OPPOSITE_DIR[exit_dir],  # Direction TO enter the new room
					"from_room": placement,
					"depth": _open_exits.size(),  # Simple depth tracking
				})


func _try_place_room_at_exit(exit_info: Dictionary) -> bool:
	var target_pos: Vector2i = exit_info.pos
	var entry_dir: int = exit_info.dir  # Direction the new room needs an exit pointing
	var from_room: RoomPlacement = exit_info.from_room
	
	# Check if cell is still free
	if _grid.has(target_pos):
		return false
	
	# Get valid room types for this connection
	var valid_types := _get_valid_room_types(entry_dir, from_room)
	
	if valid_types.is_empty():
		return false
	
	# Decide if we should place a terminal room
	var should_terminal := _rng.randf() < settings.terminal_chance
	should_terminal = should_terminal and _rooms.size() >= settings.min_rooms
	
	if should_terminal:
		var terminal_types := valid_types.filter(func(t): return room_types[t].get("terminal", false))
		if not terminal_types.is_empty():
			valid_types = terminal_types
	else:
		# Filter out terminals unless we need them
		valid_types = valid_types.filter(func(t): return not room_types[t].get("terminal", false))
		if valid_types.is_empty():
			# All options were terminal, allow them
			valid_types = _get_valid_room_types(entry_dir, from_room)
	
	# Pick a room type weighted by weight value
	var room_type := _pick_weighted_room(valid_types)
	if room_type.is_empty():
		return false
	
	var room_def: Dictionary = room_types[room_type]
	var room_size: Vector2i = room_def.size
	
	# Calculate placement position (may need adjustment for multi-cell rooms)
	var place_pos := _calculate_placement_pos(target_pos, entry_dir, room_size)
	
	# Check if all required cells are free
	if not _can_place_at(place_pos, room_size):
		return false
	
	# Create and add the room
	var placement := RoomPlacement.new(room_type, place_pos, room_size, room_def.exits)
	_add_room(placement)
	
	# Remove the exit we just used
	_open_exits.erase(exit_info)
	
	return true


func _get_valid_room_types(required_exit: int, from_room: RoomPlacement) -> Array:
	"""Get room types that have the required exit direction and satisfy connection rules."""
	var valid: Array = []
	var from_tags: Array = room_types.get(from_room.type, {}).get("tags", [])
	
	for type_name in room_types:
		var def: Dictionary = room_types[type_name]
		
		# Must have the required exit
		if required_exit not in def.exits:
			continue
		
		# Must have positive weight (can be randomly placed)
		if def.get("weight", 1.0) <= 0:
			continue
		
		# Check connection rules
		var type_tags: Array = def.get("tags", [])
		var allowed := true
		
		for tag in type_tags:
			if connection_rules.has(tag):
				# This tag has restrictions
				var allowed_connections: Array = connection_rules[tag]
				var has_valid_connection := false
				for from_tag in from_tags:
					if from_tag in allowed_connections:
						has_valid_connection = true
						break
				if not has_valid_connection:
					allowed = false
					break
		
		if allowed:
			valid.append(type_name)
	
	return valid


func _pick_weighted_room(valid_types: Array) -> String:
	if valid_types.is_empty():
		return ""
	
	var total_weight := 0.0
	for type_name in valid_types:
		total_weight += room_types[type_name].get("weight", 1.0)
	
	var roll := _rng.randf() * total_weight
	var current := 0.0
	
	for type_name in valid_types:
		current += room_types[type_name].get("weight", 1.0)
		if roll <= current:
			return type_name
	
	return valid_types[-1]  # Fallback


func _calculate_placement_pos(target_cell: Vector2i, entry_dir: int, room_size: Vector2i) -> Vector2i:
	"""Calculate the top-left position for a room based on where we're entering from."""
	# For single-cell rooms, target_cell is the position
	if room_size == Vector2i(1, 1):
		return target_cell
	
	# For multi-cell rooms, adjust based on entry direction
	match entry_dir:
		Dir.TOP:
			# Entering from top, exit is on top edge
			return Vector2i(target_cell.x - room_size.x / 2, target_cell.y)
		Dir.BOTTOM:
			# Entering from bottom, exit is on bottom edge
			return Vector2i(target_cell.x - room_size.x / 2, target_cell.y - room_size.y + 1)
		Dir.LEFT:
			# Entering from left, exit is on left edge
			return Vector2i(target_cell.x, target_cell.y - room_size.y / 2)
		Dir.RIGHT:
			# Entering from right, exit is on right edge
			return Vector2i(target_cell.x - room_size.x + 1, target_cell.y - room_size.y / 2)
	
	return target_cell


func _can_place_at(pos: Vector2i, size: Vector2i) -> bool:
	"""Check if all cells for a room placement are free."""
	for y in range(size.y):
		for x in range(size.x):
			var cell := Vector2i(pos.x + x, pos.y + y)
			if _grid.has(cell):
				return false
	return true


func _force_place_terminal(room_type: String) -> void:
	"""Try to force place a terminal room at any available exit."""
	var room_def: Dictionary = room_types.get(room_type, {})
	if room_def.is_empty():
		return
	
	# Find an exit that can accommodate this room
	for i in range(_open_exits.size() - 1, -1, -1):
		var exit_info: Dictionary = _open_exits[i]
		var target_pos: Vector2i = exit_info.pos
		var entry_dir: int = exit_info.dir
		
		# Check if room has matching exit
		if entry_dir not in room_def.exits:
			continue
		
		var room_size: Vector2i = room_def.size
		var place_pos := _calculate_placement_pos(target_pos, entry_dir, room_size)
		
		if _can_place_at(place_pos, room_size):
			var placement := RoomPlacement.new(room_type, place_pos, room_size, room_def.exits)
			_add_room(placement)
			_open_exits.remove_at(i)
			print("[LevelGenerator] Force placed %s at %s" % [room_type, place_pos])
			return
	
	push_warning("[LevelGenerator] Could not force place %s - no valid exits" % room_type)


# ============ DEBUG / VISUALIZATION ============

func print_grid() -> void:
	"""Print ASCII representation of generated level."""
	if _grid.is_empty():
		print("(empty grid)")
		return
	
	# Find bounds
	var min_pos := Vector2i(999999, 999999)
	var max_pos := Vector2i(-999999, -999999)
	
	for cell in _grid:
		min_pos.x = mini(min_pos.x, cell.x)
		min_pos.y = mini(min_pos.y, cell.y)
		max_pos.x = maxi(max_pos.x, cell.x)
		max_pos.y = maxi(max_pos.y, cell.y)
	
	print("\n=== LEVEL GRID ===")
	print("Bounds: %s to %s" % [min_pos, max_pos])
	
	for y in range(min_pos.y, max_pos.y + 1):
		var row := ""
		for x in range(min_pos.x, max_pos.x + 1):
			var cell := Vector2i(x, y)
			if _grid.has(cell):
				var room: RoomPlacement = _grid[cell]
				# Use first letter of room type
				var char := room.type[0].to_upper()
				if room.type == "start_room":
					char = "S"
				elif room.type == "boss_room":
					char = "B"
				elif room.type == "save_room":
					char = "+"
				elif room.type == "treasure_room":
					char = "$"
				row += char
			else:
				row += "."
		print(row)
	
	print("==================\n")
