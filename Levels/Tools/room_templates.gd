@tool
class_name RoomTemplates
extends RefCounted
## Room template definitions for the Metroidvania level builder.
## Each template is a 2D array of tile IDs that can be stamped into a TileMap.
##
## Tile Legend:
##   0 = Empty (air)
##   1 = Solid block (uses terrain autotile)
##   5 = Player spawn marker
##   6 = Enemy spawn marker
##   7 = Item/collectible marker
##   8 = Door/transition marker

# Room size in tiles (336x192 viewport / 16x16 tiles = 21x12)
# This matches Hollow Knight's tight camera feel
const ROOM_WIDTH := 21
const ROOM_HEIGHT := 12

# Tile IDs - these are internal markers
const EMPTY := 0
const SOLID := 1
const PLATFORM := 2
const SPIKE := 3
const PLAYER_SPAWN := 5
const ENEMY_SPAWN := 6
const ITEM_SPAWN := 7
const DOOR := 8


## Get a template by name. Returns empty array if not found.
func get_template(template_name: String) -> Array:
	match template_name:
		# Basic Shapes
		"flat_corridor": return _flat_corridor()
		"vertical_shaft": return _vertical_shaft()
		"l_corner_left": return _l_corner_left()
		"l_corner_right": return _l_corner_right()
		"t_intersection": return _t_intersection()
		"open_arena": return _open_arena()
		
		# Platforming Challenges
		"staircase_up": return _staircase_up()
		"floating_platforms": return _floating_platforms()
		"wall_jump_corridor": return _wall_jump_corridor()
		"pit_jump": return _pit_jump()
		"climb_room": return _climb_room()
		
		# Metroidvania Staples
		"save_room": return _save_room()
		"treasure_room": return _treasure_room()
		"hub_room_3way": return _hub_room_3way()
		"transition_corridor": return _transition_corridor()
		"boss_arena": return _boss_arena()
		
		_:
			push_warning("RoomTemplates: Unknown template '%s'" % template_name)
			return []


## Get list of all available template names grouped by category
func get_all_templates() -> Dictionary:
	return {
		"Basic Shapes": [
			"flat_corridor",
			"vertical_shaft",
			"l_corner_left",
			"l_corner_right",
			"t_intersection",
			"open_arena",
		],
		"Platforming Challenges": [
			"staircase_up",
			"floating_platforms",
			"wall_jump_corridor",
			"pit_jump",
			"climb_room",
		],
		"Special Rooms": [
			"save_room",
			"treasure_room",
			"hub_room_3way",
			"transition_corridor",
			"boss_arena",
		],
	}


## Helper to create an empty room filled with air
func _create_empty_room() -> Array:
	var room: Array = []
	for y in range(ROOM_HEIGHT):
		var row: Array = []
		for x in range(ROOM_WIDTH):
			row.append(EMPTY)
		room.append(row)
	return room


## Helper to add a horizontal line of tiles
func _h_line(room: Array, y: int, x_start: int, x_end: int, tile: int) -> void:
	for x in range(x_start, x_end + 1):
		if x >= 0 and x < ROOM_WIDTH and y >= 0 and y < ROOM_HEIGHT:
			room[y][x] = tile


## Helper to add a vertical line of tiles
func _v_line(room: Array, x: int, y_start: int, y_end: int, tile: int) -> void:
	for y in range(y_start, y_end + 1):
		if x >= 0 and x < ROOM_WIDTH and y >= 0 and y < ROOM_HEIGHT:
			room[y][x] = tile


## Helper to fill a rectangle
func _fill_rect(room: Array, x1: int, y1: int, x2: int, y2: int, tile: int) -> void:
	for y in range(y1, y2 + 1):
		for x in range(x1, x2 + 1):
			if x >= 0 and x < ROOM_WIDTH and y >= 0 and y < ROOM_HEIGHT:
				room[y][x] = tile


# ============ BASIC SHAPES (21x12 tiles) ============

func _flat_corridor() -> Array:
	## Simple horizontal corridor with doors left & right
	## Layout (21x12):
	##   XXXXXXXXXXXXXXXXXXXXX  (ceiling)
	##   X                   X
	##   D                   D  (doors at y=3-8)
	##   D                   D
	##   D                   D
	##   D                   D
	##   D                   D
	##   D                   D
	##   X                   X
	##   XXXXXXXXXXXXXXXXXXXXX  (floor 3 tiles thick)
	##   XXXXXXXXXXXXXXXXXXXXX
	##   XXXXXXXXXXXXXXXXXXXXX
	var room = _create_empty_room()
	
	# Ceiling
	_h_line(room, 0, 0, 20, SOLID)
	
	# Floor (3 tiles thick for safety)
	_fill_rect(room, 0, 9, 20, 11, SOLID)
	
	# Left wall with door opening
	_v_line(room, 0, 0, 11, SOLID)
	_fill_rect(room, 0, 3, 0, 8, EMPTY)  # Door opening
	room[5][0] = DOOR
	
	# Right wall with door opening
	_v_line(room, 20, 0, 11, SOLID)
	_fill_rect(room, 20, 3, 20, 8, EMPTY)  # Door opening
	room[5][20] = DOOR
	
	room[8][10] = PLAYER_SPAWN
	
	return room


func _vertical_shaft() -> Array:
	## Tall room with top/bottom exits for climbing
	var room = _create_empty_room()
	
	# Left wall
	_v_line(room, 0, 0, 11, SOLID)
	_v_line(room, 1, 0, 11, SOLID)
	_v_line(room, 2, 0, 11, SOLID)
	
	# Right wall
	_v_line(room, 20, 0, 11, SOLID)
	_v_line(room, 19, 0, 11, SOLID)
	_v_line(room, 18, 0, 11, SOLID)
	
	# Top with opening
	_h_line(room, 0, 0, 20, SOLID)
	_fill_rect(room, 7, 0, 13, 0, EMPTY)
	room[0][10] = DOOR
	
	# Bottom with opening
	_h_line(room, 11, 0, 20, SOLID)
	_fill_rect(room, 7, 11, 13, 11, EMPTY)
	room[11][10] = DOOR
	
	# Climbing platforms
	_h_line(room, 3, 4, 8, SOLID)
	_h_line(room, 6, 12, 16, SOLID)
	_h_line(room, 9, 4, 8, SOLID)
	
	room[8][6] = PLAYER_SPAWN
	
	return room


func _l_corner_left() -> Array:
	## L-shaped room: enter from right, exit top
	var room = _create_empty_room()
	
	# Fill solid first
	_fill_rect(room, 0, 0, 20, 11, SOLID)
	
	# Carve interior L shape
	_fill_rect(room, 1, 1, 19, 8, EMPTY)  # Main area
	_fill_rect(room, 1, 1, 8, 10, EMPTY)   # Vertical part going up
	
	# Floor
	_fill_rect(room, 9, 9, 19, 11, SOLID)
	
	# Right door
	_fill_rect(room, 20, 3, 20, 8, EMPTY)
	room[5][20] = DOOR
	
	# Top door (on left side)
	_fill_rect(room, 3, 0, 6, 0, EMPTY)
	room[0][4] = DOOR
	
	room[8][14] = PLAYER_SPAWN
	
	return room


func _l_corner_right() -> Array:
	## L-shaped room: enter from left, exit top
	var room = _create_empty_room()
	
	_fill_rect(room, 0, 0, 20, 11, SOLID)
	
	# Carve interior L shape
	_fill_rect(room, 1, 1, 19, 8, EMPTY)
	_fill_rect(room, 12, 1, 19, 10, EMPTY)  # Vertical part going up
	
	# Floor
	_fill_rect(room, 0, 9, 11, 11, SOLID)
	
	# Left door
	_fill_rect(room, 0, 3, 0, 8, EMPTY)
	room[5][0] = DOOR
	
	# Top door (on right side)
	_fill_rect(room, 14, 0, 17, 0, EMPTY)
	room[0][16] = DOOR
	
	room[8][6] = PLAYER_SPAWN
	
	return room


func _t_intersection() -> Array:
	## T-junction: left, right, and bottom exits
	var room = _create_empty_room()
	
	# Ceiling
	_h_line(room, 0, 0, 20, SOLID)
	
	# Upper walls
	_fill_rect(room, 0, 0, 1, 4, SOLID)
	_fill_rect(room, 19, 0, 20, 4, SOLID)
	
	# Middle section walls
	_v_line(room, 0, 0, 8, SOLID)
	_v_line(room, 20, 0, 8, SOLID)
	
	# Floor with center opening
	_fill_rect(room, 0, 9, 6, 11, SOLID)
	_fill_rect(room, 14, 9, 20, 11, SOLID)
	
	# Bottom center opening
	_fill_rect(room, 7, 9, 13, 11, EMPTY)
	room[11][10] = DOOR
	
	# Left door
	_fill_rect(room, 0, 3, 0, 8, EMPTY)
	room[5][0] = DOOR
	
	# Right door
	_fill_rect(room, 20, 3, 20, 8, EMPTY)
	room[5][20] = DOOR
	
	room[8][10] = PLAYER_SPAWN
	
	return room


func _open_arena() -> Array:
	## Open combat room with minimal obstacles
	var room = _create_empty_room()
	
	# Border walls
	_h_line(room, 0, 0, 20, SOLID)
	_v_line(room, 0, 0, 11, SOLID)
	_v_line(room, 20, 0, 11, SOLID)
	
	# Floor
	_fill_rect(room, 0, 9, 20, 11, SOLID)
	
	# Left door
	_fill_rect(room, 0, 4, 0, 8, EMPTY)
	room[6][0] = DOOR
	
	# Right door
	_fill_rect(room, 20, 4, 20, 8, EMPTY)
	room[6][20] = DOOR
	
	# Small platforms for verticality
	_h_line(room, 5, 5, 8, SOLID)
	_h_line(room, 5, 12, 15, SOLID)
	
	room[8][4] = PLAYER_SPAWN
	room[8][16] = ENEMY_SPAWN
	
	return room


# ============ PLATFORMING CHALLENGES ============

func _staircase_up() -> Array:
	## Ascending platforms from bottom-left to top-right
	var room = _create_empty_room()
	
	# Walls
	_v_line(room, 0, 0, 11, SOLID)
	_v_line(room, 20, 0, 11, SOLID)
	_h_line(room, 0, 0, 20, SOLID)
	
	# Floor at bottom left
	_fill_rect(room, 0, 9, 6, 11, SOLID)
	
	# Staircase platforms
	_h_line(room, 7, 5, 8, SOLID)
	_h_line(room, 5, 9, 12, SOLID)
	_h_line(room, 3, 14, 17, SOLID)
	
	# Top right landing
	_fill_rect(room, 16, 1, 19, 2, SOLID)
	
	# Bottom left door
	_fill_rect(room, 0, 4, 0, 8, EMPTY)
	room[6][0] = DOOR
	
	# Top right door
	_fill_rect(room, 20, 1, 20, 3, EMPTY)
	room[2][20] = DOOR
	
	room[8][3] = PLAYER_SPAWN
	
	return room


func _floating_platforms() -> Array:
	## Platforms over a pit
	var room = _create_empty_room()
	
	# Walls
	_v_line(room, 0, 0, 11, SOLID)
	_v_line(room, 20, 0, 11, SOLID)
	_h_line(room, 0, 0, 20, SOLID)
	
	# Pit bottom (deadly fall)
	_h_line(room, 11, 0, 20, SOLID)
	
	# Starting platform (left)
	_fill_rect(room, 1, 8, 4, 8, SOLID)
	
	# Floating platforms
	_h_line(room, 6, 6, 8, SOLID)
	_h_line(room, 7, 11, 13, SOLID)
	_h_line(room, 5, 15, 17, SOLID)
	
	# End platform (right)
	_fill_rect(room, 17, 8, 19, 8, SOLID)
	
	# Collectible on hard platform
	room[4][16] = ITEM_SPAWN
	
	# Doors
	_fill_rect(room, 0, 3, 0, 7, EMPTY)
	room[5][0] = DOOR
	
	_fill_rect(room, 20, 3, 20, 7, EMPTY)
	room[5][20] = DOOR
	
	room[7][2] = PLAYER_SPAWN
	
	return room


func _wall_jump_corridor() -> Array:
	## Narrow shaft for wall jumping
	var room = _create_empty_room()
	
	# Fill solid
	_fill_rect(room, 0, 0, 20, 11, SOLID)
	
	# Narrow vertical shaft (6 tiles wide)
	_fill_rect(room, 7, 1, 13, 10, EMPTY)
	
	# Small ledges to encourage wall jumps
	_h_line(room, 8, 7, 8, SOLID)
	_h_line(room, 5, 12, 13, SOLID)
	_h_line(room, 2, 7, 8, SOLID)
	
	# Top exit
	_fill_rect(room, 9, 0, 11, 0, EMPTY)
	room[0][10] = DOOR
	
	# Bottom entrance
	_fill_rect(room, 9, 11, 11, 11, EMPTY)
	room[11][10] = DOOR
	
	room[9][10] = PLAYER_SPAWN
	
	return room


func _pit_jump() -> Array:
	## Single big pit to cross
	var room = _create_empty_room()
	
	# Ceiling
	_h_line(room, 0, 0, 20, SOLID)
	
	# Walls
	_v_line(room, 0, 0, 11, SOLID)
	_v_line(room, 20, 0, 11, SOLID)
	
	# Left platform
	_fill_rect(room, 0, 8, 5, 11, SOLID)
	
	# Right platform
	_fill_rect(room, 15, 8, 20, 11, SOLID)
	
	# Pit bottom
	_h_line(room, 11, 6, 14, SOLID)
	
	# Single floating platform in middle
	_h_line(room, 6, 9, 11, SOLID)
	
	# Doors
	_fill_rect(room, 0, 3, 0, 7, EMPTY)
	room[5][0] = DOOR
	
	_fill_rect(room, 20, 3, 20, 7, EMPTY)
	room[5][20] = DOOR
	
	room[7][3] = PLAYER_SPAWN
	
	return room


func _climb_room() -> Array:
	## Room focused on climbing up with wall jumps
	var room = _create_empty_room()
	
	# Outer walls
	_v_line(room, 0, 0, 11, SOLID)
	_v_line(room, 20, 0, 11, SOLID)
	
	# Floor
	_fill_rect(room, 0, 9, 20, 11, SOLID)
	
	# Interior walls to climb between
	_fill_rect(room, 5, 4, 6, 8, SOLID)
	_fill_rect(room, 14, 1, 15, 5, SOLID)
	
	# Top opening
	_h_line(room, 0, 0, 20, SOLID)
	_fill_rect(room, 9, 0, 11, 0, EMPTY)
	room[0][10] = DOOR
	
	# Bottom entrance
	_fill_rect(room, 0, 4, 0, 8, EMPTY)
	room[6][0] = DOOR
	
	room[8][3] = PLAYER_SPAWN
	
	return room


# ============ SPECIAL ROOMS ============

func _save_room() -> Array:
	## Small cozy save room (single entrance)
	var room = _create_empty_room()
	
	# Fill solid
	_fill_rect(room, 0, 0, 20, 11, SOLID)
	
	# Cozy interior
	_fill_rect(room, 2, 2, 18, 8, EMPTY)
	
	# Floor
	_fill_rect(room, 2, 9, 18, 11, SOLID)
	
	# Left entrance
	_fill_rect(room, 0, 4, 1, 7, EMPTY)
	room[5][0] = DOOR
	
	# Save point in center
	room[8][10] = ITEM_SPAWN
	room[8][6] = PLAYER_SPAWN
	
	return room


func _treasure_room() -> Array:
	## Dead-end with treasure
	var room = _create_empty_room()
	
	# Fill solid
	_fill_rect(room, 0, 0, 20, 11, SOLID)
	
	# Interior
	_fill_rect(room, 2, 2, 18, 8, EMPTY)
	
	# Floor
	_fill_rect(room, 2, 9, 18, 11, SOLID)
	
	# Pedestal for treasure
	_fill_rect(room, 9, 7, 11, 8, SOLID)
	room[6][10] = ITEM_SPAWN
	
	# Left entrance only (dead end)
	_fill_rect(room, 0, 4, 1, 7, EMPTY)
	room[5][0] = DOOR
	
	room[8][5] = PLAYER_SPAWN
	
	return room


func _hub_room_3way() -> Array:
	## Hub with 3 exits (left, right, bottom)
	var room = _create_empty_room()
	
	# Ceiling
	_h_line(room, 0, 0, 20, SOLID)
	
	# Side walls with openings
	_v_line(room, 0, 0, 11, SOLID)
	_fill_rect(room, 0, 3, 0, 7, EMPTY)
	room[5][0] = DOOR
	
	_v_line(room, 20, 0, 11, SOLID)
	_fill_rect(room, 20, 3, 20, 7, EMPTY)
	room[5][20] = DOOR
	
	# Floor with center opening
	_fill_rect(room, 0, 9, 7, 11, SOLID)
	_fill_rect(room, 13, 9, 20, 11, SOLID)
	
	# Bottom door
	_fill_rect(room, 8, 9, 12, 11, EMPTY)
	room[11][10] = DOOR
	
	# Center platform
	_fill_rect(room, 8, 5, 12, 6, SOLID)
	
	room[4][10] = PLAYER_SPAWN
	
	return room


func _transition_corridor() -> Array:
	## Simple short connector
	var room = _create_empty_room()
	
	# Fill solid
	_fill_rect(room, 0, 0, 20, 11, SOLID)
	
	# Narrow corridor
	_fill_rect(room, 0, 4, 20, 7, EMPTY)
	
	# Left door
	room[5][0] = DOOR
	
	# Right door
	room[5][20] = DOOR
	
	room[6][10] = PLAYER_SPAWN
	
	return room


func _boss_arena() -> Array:
	## Larger arena for boss fights (might want double-wide room)
	var room = _create_empty_room()
	
	# Thick walls
	_fill_rect(room, 0, 0, 1, 11, SOLID)
	_fill_rect(room, 19, 0, 20, 11, SOLID)
	_fill_rect(room, 0, 0, 20, 1, SOLID)
	
	# Floor
	_fill_rect(room, 0, 9, 20, 11, SOLID)
	
	# Side platforms
	_h_line(room, 6, 3, 5, SOLID)
	_h_line(room, 6, 15, 17, SOLID)
	
	# Entry (left only - boss door)
	_fill_rect(room, 0, 4, 1, 7, EMPTY)
	room[5][0] = DOOR
	
	room[8][14] = ENEMY_SPAWN  # Boss
	room[8][6] = PLAYER_SPAWN
	
	return room
