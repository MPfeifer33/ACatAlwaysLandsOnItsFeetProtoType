@tool
extends Node2D

# ============ BIOME PRESETS ============
enum Biome { CUSTOM, FOREST, SHADOW_CAVES, MT_FUJI, HAUNTED_CASTLE, CITY }

const BIOME_PRESETS = {
	Biome.FOREST: {
		"name": "Forest",
		"description": "Organic caves with roots, uneven terrain, natural feel",
		"wall_thickness": 5,
		"floor_thickness": 5,
		"ceiling_thickness": 4,
		"wall_variance": 3,      # How wavy the walls are
		"floor_variance": 2,     # How uneven the floor is
		"ceiling_variance": 2,
		"platforms_per_zone": 2,
		"min_platform_length": 6,
		"max_platform_length": 14,
		"pillar_chance": 0.3,    # Chance of floor pillars (tree roots)
		"stalactite_chance": 0.4, # Hanging formations
		"ledge_count": [4, 8],   # Min/max wall ledges
		"organic_walls": true,   # Extra wall bulges
		"floor_holes": 0.1,      # Chance of gaps in floor
	},
	Biome.SHADOW_CAVES: {
		"name": "Shadow Caves",
		"description": "Deep vertical shafts, tight corridors, oppressive",
		"wall_thickness": 6,
		"floor_thickness": 4,
		"ceiling_thickness": 4,
		"wall_variance": 2,
		"floor_variance": 1,
		"ceiling_variance": 1,
		"platforms_per_zone": 3,
		"min_platform_length": 4,
		"max_platform_length": 10,
		"pillar_chance": 0.15,
		"stalactite_chance": 0.6,
		"ledge_count": [6, 12],
		"organic_walls": false,
		"floor_holes": 0.2,
	},
	Biome.MT_FUJI: {
		"name": "Mt. Fuji",
		"description": "Rocky mountain terrain, wide platforms, open spaces",
		"wall_thickness": 4,
		"floor_thickness": 6,
		"ceiling_thickness": 3,
		"wall_variance": 4,
		"floor_variance": 3,
		"ceiling_variance": 2,
		"platforms_per_zone": 2,
		"min_platform_length": 10,
		"max_platform_length": 22,
		"pillar_chance": 0.4,
		"stalactite_chance": 0.1,
		"ledge_count": [2, 5],
		"organic_walls": true,
		"floor_holes": 0.05,
	},
	Biome.HAUNTED_CASTLE: {
		"name": "Haunted Castle",
		"description": "Angular architecture, regular platforms, structured",
		"wall_thickness": 5,
		"floor_thickness": 5,
		"ceiling_thickness": 5,
		"wall_variance": 1,
		"floor_variance": 0,
		"ceiling_variance": 0,
		"platforms_per_zone": 2,
		"min_platform_length": 8,
		"max_platform_length": 16,
		"pillar_chance": 0.5,
		"stalactite_chance": 0.0,
		"ledge_count": [2, 4],
		"organic_walls": false,
		"floor_holes": 0.0,
	},
	Biome.CITY: {
		"name": "City",
		"description": "Urban rooftops, scaffolding, precise geometry",
		"wall_thickness": 4,
		"floor_thickness": 4,
		"ceiling_thickness": 4,
		"wall_variance": 0,
		"floor_variance": 0,
		"ceiling_variance": 0,
		"platforms_per_zone": 3,
		"min_platform_length": 6,
		"max_platform_length": 12,
		"pillar_chance": 0.6,
		"stalactite_chance": 0.0,
		"ledge_count": [4, 8],
		"organic_walls": false,
		"floor_holes": 0.15,
	},
}

# ============ GENERATION SETTINGS ============
@export_group("Generation")
@export var generate: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_do_generate()
		generate = false

@export var regenerate_same_seed: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			if last_seed != 0:
				seed_value = last_seed
				_do_generate()
				seed_value = 0  # Reset so next generate is random
			else:
				push_warning("No previous seed to regenerate!")
		regenerate_same_seed = false

@export var generate_and_stamp: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_do_generate()
			_do_stamp()
		generate_and_stamp = false

@export var clear_rooms: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_do_clear()
		clear_rooms = false

@export var clear_all: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_do_clear()
			_do_clear_tiles()
		clear_all = false

@export var bake_to_scene: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_do_bake()
		bake_to_scene = false

@export var seed_value: int = 0
@export var last_seed: int = 0
@export_range(3, 50) var min_rooms: int = 8
@export_range(5, 100) var max_rooms: int = 15
@export_range(0.0, 1.0, 0.05) var terminal_chance: float = 0.2
@export var force_boss: bool = true
@export var force_save: bool = true

# ============ LAYOUT DIRECTION ============
@export_group("Layout")
enum GrowthDirection { RIGHT, LEFT, UP, DOWN, ANY }
@export var growth_direction: GrowthDirection = GrowthDirection.RIGHT
@export_range(0.0, 1.0, 0.05) var sprawl: float = 0.5  ## 0 = clustered/compact, 1 = sprawling/linear
@export var prefer_horizontal: bool = true  # Bias towards horizontal corridors
@export_range(0.0, 1.0, 0.1) var vertical_chance: float = 0.3  # Chance to go vertical when horizontal preferred
@export var fill_margin: int = 1  # Extra cells of solid around the level bounds

# ============ ROOM INTERIOR ============
@export_group("Room Interior")
@export var biome: Biome = Biome.CUSTOM:
	set(value):
		biome = value
		if value != Biome.CUSTOM and Engine.is_editor_hint():
			_apply_biome_preset(value)

@export var apply_biome: bool = false:
	set(value):
		if value and Engine.is_editor_hint() and biome != Biome.CUSTOM:
			_apply_biome_preset(biome)
			print("[LevelGen] Applied biome: %s" % Biome.keys()[biome])
		apply_biome = false

@export_range(1, 8) var platforms_per_zone: int = 2
@export_range(5, 20) var min_platform_length: int = 8
@export_range(10, 30) var max_platform_length: int = 18
@export_range(3, 10) var wall_thickness: int = 5
@export_range(3, 12) var floor_thickness: int = 6
@export_range(3, 10) var ceiling_thickness: int = 5
@export_range(0, 5) var wall_variance: int = 2  ## How wavy/organic walls are
@export_range(0, 4) var floor_variance: int = 1  ## How uneven floors are
@export_range(0, 4) var ceiling_variance: int = 1  ## How uneven ceilings are
@export_range(6, 20) var exit_width: int = 10
@export_range(8, 24) var exit_height: int = 12
@export_range(0.0, 1.0, 0.05) var pillar_chance: float = 0.2
@export_range(0.0, 1.0, 0.05) var stalactite_chance: float = 0.3
@export var ledge_count_min: int = 3
@export var ledge_count_max: int = 6
@export_range(0.0, 0.3, 0.05) var floor_hole_chance: float = 0.0

# ============ TILE STAMPING ============
@export_group("Tile Stamping")
@export var tilemap_layer: TileMapLayer
@export var stamp_tiles: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_do_stamp()
		stamp_tiles = false
@export var clear_tiles: bool = false:
	set(value):
		if value and Engine.is_editor_hint():
			_do_clear_tiles()
		clear_tiles = false
@export var terrain_set: int = 0
@export var terrain_id: int = 0
@export var tile_size: int = 16

# ============ GRID SETTINGS ============
@export_group("Grid")
@export var cell_size: Vector2 = Vector2(1152, 648)
@export var show_grid: bool = true
@export var grid_color: Color = Color(1, 1, 1, 0.1)

# ============ ROOM COLORS ============
@export_group("Colors")
@export var color_start: Color = Color(0.2, 0.9, 0.3, 0.6)
@export var color_boss: Color = Color(0.9, 0.2, 0.2, 0.6)
@export var color_save: Color = Color(0.3, 0.6, 1.0, 0.6)
@export var color_treasure: Color = Color(1.0, 0.85, 0.0, 0.6)
@export var color_corridor: Color = Color(0.5, 0.5, 0.5, 0.4)
@export var color_junction: Color = Color(0.7, 0.5, 0.9, 0.5)
@export var color_arena: Color = Color(0.9, 0.5, 0.3, 0.5)

# ============ VISUALIZATION ============
@export_group("Visualization")
@export var show_labels: bool = true
@export var show_exits: bool = true
@export_range(10, 24) var label_size: int = 14

# ============ INTERNALS ============
enum Dir { TOP, RIGHT, BOTTOM, LEFT }

const DIR_VECTORS = {0: Vector2i(0, -1), 1: Vector2i(1, 0), 2: Vector2i(0, 1), 3: Vector2i(-1, 0)}
const OPPOSITE = {0: 2, 1: 3, 2: 0, 3: 1}

var _rooms: Array = []
var _grid: Dictionary = {}
var _rng: RandomNumberGenerator

# Room definitions: {size, exits, tags, terminal, weight, template}
const ROOM_DEFS = {
	"start": {"size": Vector2i(1,1), "exits": [1], "tags": ["start"], "weight": 0.0, "template": "flat_corridor"},
	"corridor_h": {"size": Vector2i(1,1), "exits": [1,3], "tags": ["corridor"], "weight": 10.0, "template": "flat_corridor"},
	"corridor_v": {"size": Vector2i(1,1), "exits": [0,2], "tags": ["corridor"], "weight": 10.0, "template": "vertical_shaft"},
	"corner_br": {"size": Vector2i(1,1), "exits": [2,1], "tags": ["corner"], "weight": 6.0, "template": "l_corner_right"},
	"corner_bl": {"size": Vector2i(1,1), "exits": [2,3], "tags": ["corner"], "weight": 6.0, "template": "l_corner_left"},
	"corner_tr": {"size": Vector2i(1,1), "exits": [0,1], "tags": ["corner"], "weight": 6.0, "template": "l_corner_right"},
	"corner_tl": {"size": Vector2i(1,1), "exits": [0,3], "tags": ["corner"], "weight": 6.0, "template": "l_corner_left"},
	"t_down": {"size": Vector2i(1,1), "exits": [2,1,3], "tags": ["junction"], "weight": 4.0, "template": "t_intersection"},
	"t_up": {"size": Vector2i(1,1), "exits": [0,1,3], "tags": ["junction"], "weight": 4.0, "template": "t_intersection"},
	"t_right": {"size": Vector2i(1,1), "exits": [0,1,2], "tags": ["junction"], "weight": 4.0, "template": "t_intersection"},
	"t_left": {"size": Vector2i(1,1), "exits": [0,2,3], "tags": ["junction"], "weight": 4.0, "template": "t_intersection"},
	"arena": {"size": Vector2i(2,1), "exits": [1,3], "tags": ["arena"], "weight": 3.0, "template": "open_arena"},
	"shaft": {"size": Vector2i(1,2), "exits": [0,2], "tags": ["shaft"], "weight": 3.0, "template": "vertical_shaft"},
	"save": {"size": Vector2i(1,1), "exits": [3], "tags": ["save"], "terminal": true, "weight": 2.0, "template": "save_room"},
	"treasure": {"size": Vector2i(1,1), "exits": [3], "tags": ["treasure"], "terminal": true, "weight": 2.0, "template": "treasure_room"},
	"boss": {"size": Vector2i(2,2), "exits": [3], "tags": ["boss"], "terminal": true, "weight": 0.0, "template": "boss_arena"},
}

# Tile markers from RoomTemplates
const TILE_EMPTY = 0
const TILE_SOLID = 1


func _do_generate() -> void:
	_do_clear()
	
	_rng = RandomNumberGenerator.new()
	if seed_value == 0:
		last_seed = randi()
	else:
		last_seed = seed_value
	_rng.seed = last_seed
	
	# Determine start room exits based on growth direction
	var start_exits = [1]  # Default: right
	match growth_direction:
		GrowthDirection.RIGHT:
			start_exits = [1]  # Exit right
		GrowthDirection.LEFT:
			start_exits = [3]  # Exit left
		GrowthDirection.UP:
			start_exits = [0]  # Exit top
		GrowthDirection.DOWN:
			start_exits = [2]  # Exit bottom
		GrowthDirection.ANY:
			start_exits = [0, 1, 2, 3]  # All directions
	
	# Place start room with custom exits
	var start_def = ROOM_DEFS["start"].duplicate()
	start_def.exits = start_exits
	var start_room = {"type": "start", "pos": Vector2i.ZERO, "size": start_def.size, "exits": start_exits.duplicate()}
	_rooms.append(start_room)
	_grid[Vector2i.ZERO] = start_room
	
	var open: Array = []
	_add_open_exits(_rooms[0], open)
	
	var iters = 0
	while _rooms.size() < max_rooms and open.size() > 0 and iters < max_rooms * 10:
		iters += 1
		
		# Sort open exits by direction preference
		if growth_direction != GrowthDirection.ANY:
			open = _sort_exits_by_preference(open)
		
		# Pick from front (preferred) or random
		var idx = 0
		if growth_direction == GrowthDirection.ANY or _rng.randf() < 0.3:
			idx = _rng.randi() % open.size()
		
		var exit = open[idx]
		open.remove_at(idx)
		_try_place(exit, open)
	
	if force_boss and not _has_tag("boss"):
		_force_terminal("boss", open)
	if force_save and not _has_tag("save"):
		_force_terminal("save", open)
	
	print("[LevelGen] Created %d rooms (seed: %d, direction: %s)" % [_rooms.size(), last_seed, GrowthDirection.keys()[growth_direction]])
	queue_redraw()


func _sort_exits_by_preference(exits: Array) -> Array:
	## Sort exits based on growth direction and sprawl setting
	var dominated_dir = -1
	match growth_direction:
		GrowthDirection.RIGHT: dominated_dir = 1
		GrowthDirection.LEFT: dominated_dir = 3
		GrowthDirection.UP: dominated_dir = 0
		GrowthDirection.DOWN: dominated_dir = 2
	
	if dominated_dir == -1:
		return exits
	
	# Calculate center of current rooms for sprawl calculation
	var center = Vector2.ZERO
	for room in _rooms:
		center += Vector2(room.pos)
	center /= _rooms.size()
	
	# Score each exit based on direction preference and sprawl
	var scored_exits: Array = []
	for exit in exits:
		var travel_dir = OPPOSITE[exit.entry]
		var score = 0.0
		
		# Direction preference
		if travel_dir == dominated_dir:
			score += 100.0
		elif prefer_horizontal and (travel_dir == 1 or travel_dir == 3):
			score += 50.0
		elif not prefer_horizontal and (travel_dir == 0 or travel_dir == 2):
			score += 50.0
		
		# Sprawl factor: distance from center
		var dist_from_center = Vector2(exit.pos).distance_to(center)
		if sprawl > 0.5:
			# High sprawl: prefer exits far from center (more spread out)
			score += dist_from_center * (sprawl - 0.5) * 20.0
		else:
			# Low sprawl: prefer exits close to center (more clustered)
			score -= dist_from_center * (0.5 - sprawl) * 20.0
		
		# Add some randomness
		score += _rng.randf() * 10.0
		
		scored_exits.append({"exit": exit, "score": score})
	
	# Sort by score descending
	scored_exits.sort_custom(func(a, b): return a.score > b.score)
	
	# Extract sorted exits
	var result: Array = []
	for item in scored_exits:
		result.append(item.exit)
	
	return result


func _do_clear() -> void:
	_rooms.clear()
	_grid.clear()
	for child in get_children():
		if child.has_meta("generated"):
			child.queue_free()
	queue_redraw()


func _apply_biome_preset(biome_type: Biome) -> void:
	## Apply a biome preset to all room interior settings
	if not BIOME_PRESETS.has(biome_type):
		return
	
	var preset = BIOME_PRESETS[biome_type]
	
	wall_thickness = preset.wall_thickness
	floor_thickness = preset.floor_thickness
	ceiling_thickness = preset.ceiling_thickness
	wall_variance = preset.wall_variance
	floor_variance = preset.floor_variance
	ceiling_variance = preset.ceiling_variance
	platforms_per_zone = preset.platforms_per_zone
	min_platform_length = preset.min_platform_length
	max_platform_length = preset.max_platform_length
	pillar_chance = preset.pillar_chance
	stalactite_chance = preset.stalactite_chance
	ledge_count_min = preset.ledge_count[0]
	ledge_count_max = preset.ledge_count[1]
	floor_hole_chance = preset.floor_holes
	
	print("[LevelGen] Applied biome preset: %s" % preset.name)


func _do_bake() -> void:
	if _rooms.is_empty():
		push_warning("Generate first!")
		return
	var room_script = load("res://Levels/Components/room.gd")
	if not room_script:
		push_error("Could not load room.gd")
		return
	for room in _rooms:
		var node = Area2D.new()
		node.set_script(room_script)
		node.name = "Room_%s_%d_%d" % [room.type, room.pos.x, room.pos.y]
		node.set_meta("generated", true)
		node.room_id = node.name
		node.room_size = Vector2(room.size) * cell_size
		node.position = Vector2(room.pos) * cell_size
		node.editor_color = _get_color(room.type)
		if room.type == "start":
			node.is_starting_room = true
		add_child(node)
		node.owner = get_tree().edited_scene_root
	print("[LevelGen] Baked %d rooms" % _rooms.size())


func _do_stamp() -> void:
	if _rooms.is_empty():
		push_warning("Generate rooms first!")
		return
	if not tilemap_layer:
		push_warning("Assign a TileMapLayer first!")
		return
	if not tilemap_layer.tile_set:
		push_warning("TileMapLayer has no TileSet assigned!")
		return
	
	var ts = tilemap_layer.tile_set
	if terrain_set >= ts.get_terrain_sets_count():
		push_warning("Terrain set %d doesn't exist!" % terrain_set)
		return
	if terrain_id >= ts.get_terrains_count(terrain_set):
		push_warning("Terrain %d doesn't exist in set %d!" % [terrain_id, terrain_set])
		return
	
	var tiles_w = int(cell_size.x / tile_size)  # tiles per room width
	var tiles_h = int(cell_size.y / tile_size)  # tiles per room height
	
	print("[LevelGen] Stamping Hollow Knight style rooms (%dx%d tiles each)" % [tiles_w, tiles_h])
	
	var all_solid: Array[Vector2i] = []
	
	# First: fill the entire bounding area with solid tiles (background fill)
	var bounds = _get_bounds()
	
	var min_tile_x = (bounds.position.x - fill_margin) * tiles_w
	var max_tile_x = (bounds.end.x + fill_margin) * tiles_w
	var min_tile_y = (bounds.position.y - fill_margin) * tiles_h
	var max_tile_y = (bounds.end.y + fill_margin) * tiles_h
	
	# Fill background
	for y in range(min_tile_y, max_tile_y):
		for x in range(min_tile_x, max_tile_x):
			all_solid.append(Vector2i(x, y))
	
	print("[LevelGen] Filled background: %d tiles" % all_solid.size())
	
	# Second: carve out room interiors
	var carved: Dictionary = {}  # Track which tiles to remove
	
	for room in _rooms:
		var room_offset = Vector2i(room.pos.x * tiles_w, room.pos.y * tiles_h)
		var room_w = room.size.x * tiles_w
		var room_h = room.size.y * tiles_h
		var exits = room.exits
		var room_type = room.type
		
		# Get the air/empty tiles for this room (inverse of solid)
		var air_tiles = _generate_room_air(room_w, room_h, exits, room_type)
		
		for tile_pos in air_tiles:
			var world_pos = tile_pos + room_offset
			carved[world_pos] = true
	
	# Remove carved tiles from solid
	var final_solid: Array[Vector2i] = []
	for pos in all_solid:
		if not carved.has(pos):
			final_solid.append(pos)
	
	# Add interior platforms/features back
	for room in _rooms:
		var room_offset = Vector2i(room.pos.x * tiles_w, room.pos.y * tiles_h)
		var room_w = room.size.x * tiles_w
		var room_h = room.size.y * tiles_h
		
		var interior = _generate_room_interior(room_w, room_h)
		for tile_pos in interior:
			final_solid.append(tile_pos + room_offset)
	
	# Stamp all solid tiles at once for proper terrain connections
	if final_solid.size() > 0:
		tilemap_layer.set_cells_terrain_connect(final_solid, terrain_set, terrain_id)
	
	print("[LevelGen] Stamped %d tiles for %d rooms" % [final_solid.size(), _rooms.size()])


func _generate_room_air(w: int, h: int, exits: Array, room_type: String) -> Array[Vector2i]:
	## Generate the AIR (empty) tiles inside a room - this is what gets carved out
	var air: Array[Vector2i] = []
	
	# Use exported exit sizes, clamped to room size
	var ex_width = mini(exit_width, w / 3)
	var ex_height = mini(exit_height, h / 3)
	
	var has_exit_top = 0 in exits
	var has_exit_right = 1 in exits
	var has_exit_bottom = 2 in exits
	var has_exit_left = 3 in exits
	
	# Use exported thickness and variance values
	var wall_thick = wall_thickness
	var floor_thick = floor_thickness
	var ceil_thick = ceiling_thickness
	var wall_var = wall_variance
	var floor_var = floor_variance
	var ceil_var = ceiling_variance
	
	# Generate boundaries with biome-appropriate variance
	var floor_heights: Array[int] = []
	var ceiling_heights: Array[int] = []
	var left_widths: Array[int] = []
	var right_widths: Array[int] = []
	
	for x in range(w):
		# Floor height with variance
		var fh = floor_thick
		if floor_var > 0:
			fh += _rng.randi_range(-floor_var, floor_var)
		floor_heights.append(clampi(fh, floor_thick - floor_var, floor_thick + floor_var + 1))
		
		# Ceiling height with variance
		var ch = ceil_thick
		if ceil_var > 0:
			ch += _rng.randi_range(-ceil_var, ceil_var)
		ceiling_heights.append(clampi(ch, ceil_thick - ceil_var, ceil_thick + ceil_var + 1))
	
	for y in range(h):
		# Wall width with variance
		var lw = wall_thick
		if wall_var > 0:
			lw += _rng.randi_range(-wall_var, wall_var)
		left_widths.append(clampi(lw, maxi(2, wall_thick - wall_var), wall_thick + wall_var + 1))
		
		var rw = wall_thick
		if wall_var > 0:
			rw += _rng.randi_range(-wall_var, wall_var)
		right_widths.append(clampi(rw, maxi(2, wall_thick - wall_var), wall_thick + wall_var + 1))
	
	# Smooth based on variance (more smoothing for organic, less for angular)
	var smooth_passes = 1 if wall_var <= 1 else 2
	for _i in range(smooth_passes):
		floor_heights = _smooth_heights(floor_heights)
		ceiling_heights = _smooth_heights(ceiling_heights)
		left_widths = _smooth_heights(left_widths)
		right_widths = _smooth_heights(right_widths)
	
	var center_x = w / 2
	var center_y = h / 2
	
	# Determine air tiles (inside the room, not in walls)
	for y in range(h):
		for x in range(w):
			var is_air = true
			
			# Check if in floor
			if y >= h - floor_heights[x]:
				is_air = false
			
			# Check if in ceiling  
			if y < ceiling_heights[x]:
				is_air = false
			
			# Check if in left wall
			if x < left_widths[y]:
				is_air = false
			
			# Check if in right wall
			if x >= w - right_widths[y]:
				is_air = false
			
			# Carve exits (these ARE air even if in wall area)
			if has_exit_top:
				if x >= center_x - ex_width/2 and x < center_x + ex_width/2:
					if y < ex_height:
						is_air = true
			
			if has_exit_bottom:
				if x >= center_x - ex_width/2 and x < center_x + ex_width/2:
					if y >= h - ex_height:
						is_air = true
			
			if has_exit_left:
				if y >= center_y - ex_height/2 and y < center_y + ex_height/2:
					if x < ex_width:
						is_air = true
			
			if has_exit_right:
				if y >= center_y - ex_height/2 and y < center_y + ex_height/2:
					if x >= w - ex_width:
						is_air = true
			
			if is_air:
				air.append(Vector2i(x, y))
	
	return air


func _generate_room_interior(w: int, h: int) -> Array[Vector2i]:
	## Generate platforms and features INSIDE the room (added back as solid)
	var interior: Array[Vector2i] = []
	
	# Safe area for platforms (avoid edges based on wall thickness)
	var margin = wall_thickness + 5
	var safe_left = margin
	var safe_right = w - margin
	var safe_top = ceiling_thickness + 5
	var safe_bottom = h - floor_thickness - 5
	
	if safe_right <= safe_left or safe_bottom <= safe_top:
		return interior
	
	# Vertical zones for platform distribution
	var zone_count = 4
	var zone_height = (safe_bottom - safe_top) / zone_count
	
	if zone_height < 3:
		return interior
	
	# Generate platforms in each zone using exported settings
	for zone in range(zone_count):
		var zone_top_y = safe_top + zone * zone_height
		var zone_bot_y = zone_top_y + zone_height
		
		# Use exported platforms_per_zone
		var num_plats = _rng.randi_range(1, platforms_per_zone)
		
		for _p in range(num_plats):
			# Use exported platform length settings
			var plat_len = _rng.randi_range(min_platform_length, max_platform_length)
			if safe_right - safe_left <= plat_len:
				continue
			
			var plat_x = _rng.randi_range(safe_left, safe_right - plat_len)
			var plat_y = _rng.randi_range(int(zone_top_y), int(zone_bot_y))
			
			# Platform is 1 tile thick
			for x in range(plat_x, plat_x + plat_len):
				if x >= 0 and x < w and plat_y >= 0 and plat_y < h:
					interior.append(Vector2i(x, plat_y))
	
	# Add wall ledges using exported settings
	var num_ledges = _rng.randi_range(ledge_count_min, ledge_count_max)
	for _i in range(num_ledges):
		var ledge_y = _rng.randi_range(safe_top, safe_bottom)
		var ledge_len = _rng.randi_range(5, 12)
		
		# Left or right side
		if _rng.randf() > 0.5:
			# Left ledge - starts from wall
			var start_x = wall_thickness + 2
			for x in range(start_x, start_x + ledge_len):
				if x >= 0 and x < w/3 and ledge_y >= 0 and ledge_y < h:
					interior.append(Vector2i(x, ledge_y))
		else:
			# Right ledge - ends at wall
			var end_x = w - wall_thickness - 2
			for x in range(end_x - ledge_len, end_x):
				if x >= w*2/3 and x < w and ledge_y >= 0 and ledge_y < h:
					interior.append(Vector2i(x, ledge_y))
	
	# Pillars from floor (using exported pillar_chance)
	if _rng.randf() < pillar_chance:
		var num_pillars = _rng.randi_range(1, 3)
		for _i in range(num_pillars):
			var pillar_x = _rng.randi_range(int(w * 0.25), int(w * 0.75))
			var pillar_w = _rng.randi_range(2, 4)
			var pillar_h = _rng.randi_range(6, 14)
			var pillar_y = safe_bottom - pillar_h
			
			for py in range(pillar_y, pillar_y + pillar_h):
				for px in range(pillar_x, pillar_x + pillar_w):
					if px >= 0 and px < w and py >= 0 and py < h:
						interior.append(Vector2i(px, py))
	
	# Stalactites from ceiling (using exported stalactite_chance)
	if _rng.randf() < stalactite_chance:
		var num_stalactites = _rng.randi_range(2, 5)
		for _i in range(num_stalactites):
			var stal_x = _rng.randi_range(safe_left, safe_right)
			var stal_w = _rng.randi_range(1, 3)
			var stal_h = _rng.randi_range(4, 10)
			var stal_y = ceiling_thickness + 2
			
			# Stalactite tapers - wider at top
			for dy in range(stal_h):
				var taper = int(dy * 0.3)  # Gradually narrow
				var row_w = maxi(1, stal_w - taper)
				var row_x = stal_x + taper / 2
				for px in range(row_x, row_x + row_w):
					if px >= 0 and px < w and (stal_y + dy) >= 0 and (stal_y + dy) < h:
						interior.append(Vector2i(px, stal_y + dy))
	
	return interior


func _generate_hollow_knight_room(w: int, h: int, exits: Array, room_type: String) -> Array[Vector2i]:
	## Generate organic Hollow Knight-style room geometry
	## ALL tiles must stay within 0 to w-1 (x) and 0 to h-1 (y)
	var solid: Array[Vector2i] = []
	
	# Exit sizes (in tiles) - must be smaller than room dimensions
	var exit_width = mini(8, w / 4)   # horizontal exit width
	var exit_height = mini(10, h / 4)  # vertical exit height
	
	# Determine room style based on type
	var has_exit_top = 0 in exits     # Dir.TOP
	var has_exit_right = 1 in exits   # Dir.RIGHT  
	var has_exit_bottom = 2 in exits  # Dir.BOTTOM
	var has_exit_left = 3 in exits    # Dir.LEFT
	
	# Wall thickness varies for organic feel
	var wall_base = 4
	var floor_base = 5
	var ceiling_base = 4
	
	# Generate floor (bottom) with more variation
	var floor_heights: Array[int] = []
	for x in range(w):
		var base_h = floor_base
		base_h += _rng.randi_range(-2, 3)
		base_h = clampi(base_h, 3, 8)
		floor_heights.append(base_h)
	
	floor_heights = _smooth_heights(floor_heights)
	floor_heights = _smooth_heights(floor_heights)
	
	# Generate ceiling (top)
	var ceiling_heights: Array[int] = []
	for x in range(w):
		var base_h = ceiling_base
		base_h += _rng.randi_range(-1, 2)
		base_h = clampi(base_h, 2, 6)
		ceiling_heights.append(base_h)
	
	ceiling_heights = _smooth_heights(ceiling_heights)
	ceiling_heights = _smooth_heights(ceiling_heights)
	
	# Generate left wall with bulges
	var left_wall_widths: Array[int] = []
	for y in range(h):
		var base_w = wall_base
		base_w += _rng.randi_range(-2, 3)
		base_w = clampi(base_w, 2, 7)
		left_wall_widths.append(base_w)
	
	left_wall_widths = _smooth_heights(left_wall_widths)
	
	# Generate right wall
	var right_wall_widths: Array[int] = []
	for y in range(h):
		var base_w = wall_base
		base_w += _rng.randi_range(-2, 3)
		base_w = clampi(base_w, 2, 7)
		right_wall_widths.append(base_w)
	
	right_wall_widths = _smooth_heights(right_wall_widths)
	
	# Calculate exit positions (center of each edge)
	var center_x = w / 2
	var center_y = h / 2
	
	# Fill in solid tiles - STRICT BOUNDS CHECK
	for y in range(h):  # 0 to h-1 only
		for x in range(w):  # 0 to w-1 only
			var is_solid = false
			
			# Floor (bottom rows)
			if y >= h - floor_heights[x]:
				is_solid = true
			
			# Ceiling (top rows)
			if y < ceiling_heights[x]:
				is_solid = true
			
			# Left wall
			if x < left_wall_widths[y]:
				is_solid = true
			
			# Right wall
			if x >= w - right_wall_widths[y]:
				is_solid = true
			
			# Carve out exits - these create openings at room edges
			# Top exit (y = 0 to exit_height)
			if has_exit_top:
				if x >= center_x - exit_width/2 and x < center_x + exit_width/2:
					if y < exit_height:
						is_solid = false
			
			# Bottom exit (y = h-exit_height to h-1)
			if has_exit_bottom:
				if x >= center_x - exit_width/2 and x < center_x + exit_width/2:
					if y >= h - exit_height:
						is_solid = false
			
			# Left exit (x = 0 to exit_width)
			if has_exit_left:
				if y >= center_y - exit_height/2 and y < center_y + exit_height/2:
					if x < exit_width:
						is_solid = false
			
			# Right exit (x = w-exit_width to w-1)
			if has_exit_right:
				if y >= center_y - exit_height/2 and y < center_y + exit_height/2:
					if x >= w - exit_width:
						is_solid = false
			
			if is_solid:
				# Final bounds check - MUST be inside room
				if x >= 0 and x < w and y >= 0 and y < h:
					solid.append(Vector2i(x, y))
	
	# Add interior features - pass room bounds for clamping
	solid.append_array(_generate_platforms(w, h, floor_heights, ceiling_heights, left_wall_widths, right_wall_widths))
	solid.append_array(_generate_wall_ledges(w, h, floor_heights, ceiling_heights, left_wall_widths, right_wall_widths))
	solid.append_array(_generate_floor_pillars(w, h, floor_heights, ceiling_heights))
	
	return solid


func _smooth_heights(heights: Array[int]) -> Array[int]:
	## Simple smoothing pass
	if heights.size() < 3:
		return heights
	
	var smoothed: Array[int] = []
	smoothed.append(heights[0])
	
	for i in range(1, heights.size() - 1):
		var avg = (heights[i-1] + heights[i] + heights[i+1]) / 3
		smoothed.append(avg)
	
	smoothed.append(heights[heights.size() - 1])
	return smoothed


func _generate_platforms(w: int, h: int, floor_h: Array[int], ceil_h: Array[int], left_w: Array[int], right_w: Array[int]) -> Array[Vector2i]:
	## Generate floating platforms inside the room
	## All positions must be within 0 to w-1 (x) and 0 to h-1 (y)
	var platforms: Array[Vector2i] = []
	
	# Calculate safe area (not in walls/floor/ceiling)
	var safe_top = 0
	var safe_bottom = h
	var safe_left = 0
	var safe_right = w
	
	for i in range(ceil_h.size()):
		safe_top = maxi(safe_top, ceil_h[i])
	for i in range(floor_h.size()):
		safe_bottom = mini(safe_bottom, h - floor_h[i])
	for i in range(left_w.size()):
		safe_left = maxi(safe_left, left_w[i])
	for i in range(right_w.size()):
		safe_right = mini(safe_right, w - right_w[i])
	
	safe_top += 4
	safe_bottom -= 4
	safe_left += 3
	safe_right -= 3
	
	# Clamp to room bounds
	safe_top = clampi(safe_top, 0, h - 1)
	safe_bottom = clampi(safe_bottom, 0, h - 1)
	safe_left = clampi(safe_left, 0, w - 1)
	safe_right = clampi(safe_right, 0, w - 1)
	
	if safe_bottom <= safe_top or safe_right <= safe_left:
		return platforms
	
	# Divide room into vertical zones for better platform distribution
	var zone_height = (safe_bottom - safe_top) / 3
	if zone_height < 1:
		return platforms
	
	# Generate 3-6 platforms spread across the room
	var num_platforms = _rng.randi_range(3, 6)
	
	for p in range(num_platforms):
		var plat_w = _rng.randi_range(5, 12)
		
		# Make sure platform fits
		if safe_right - safe_left <= plat_w:
			continue
		
		var plat_x = _rng.randi_range(safe_left, safe_right - plat_w)
		
		# Distribute platforms vertically in zones
		var zone = p % 3
		var zone_top = safe_top + zone * zone_height
		var zone_bot = zone_top + zone_height
		var plat_y = _rng.randi_range(int(zone_top), int(zone_bot))
		
		# Single row platform - with bounds check
		for x in range(plat_x, plat_x + plat_w):
			if x >= 0 and x < w and plat_y >= 0 and plat_y < h:
				platforms.append(Vector2i(x, plat_y))
	
	return platforms


func _generate_wall_ledges(w: int, h: int, floor_h: Array[int], ceil_h: Array[int], left_w: Array[int], right_w: Array[int]) -> Array[Vector2i]:
	## Generate ledges that stick out from walls
	## All positions must be within 0 to w-1 (x) and 0 to h-1 (y)
	var ledges: Array[Vector2i] = []
	
	# Calculate safe vertical range
	var safe_top = 0
	var safe_bottom = h
	for i in range(ceil_h.size()):
		safe_top = maxi(safe_top, ceil_h[i])
	for i in range(floor_h.size()):
		safe_bottom = mini(safe_bottom, h - floor_h[i])
	
	safe_top += 5
	safe_bottom -= 5
	
	# Clamp to room bounds
	safe_top = clampi(safe_top, 0, h - 1)
	safe_bottom = clampi(safe_bottom, 0, h - 1)
	
	if safe_bottom <= safe_top:
		return ledges
	
	# Left wall ledges (2-4 of them)
	var num_left = _rng.randi_range(2, 4)
	for _i in range(num_left):
		var ledge_y = _rng.randi_range(safe_top, safe_bottom)
		var ledge_len = _rng.randi_range(4, 10)
		var wall_x = left_w[ledge_y] if ledge_y < left_w.size() else 3
		
		for x in range(wall_x, wall_x + ledge_len):
			# Bounds check: stay inside room and don't go past middle
			if x >= 0 and x < w / 2 and ledge_y >= 0 and ledge_y < h:
				ledges.append(Vector2i(x, ledge_y))
	
	# Right wall ledges (2-4 of them)
	var num_right = _rng.randi_range(2, 4)
	for _i in range(num_right):
		var ledge_y = _rng.randi_range(safe_top, safe_bottom)
		var ledge_len = _rng.randi_range(4, 10)
		var wall_x = w - (right_w[ledge_y] if ledge_y < right_w.size() else 3)
		
		for x in range(wall_x - ledge_len, wall_x):
			# Bounds check: stay inside room and don't go past middle
			if x >= w / 2 and x < w and ledge_y >= 0 and ledge_y < h:
				ledges.append(Vector2i(x, ledge_y))
	
	return ledges


func _generate_floor_pillars(w: int, h: int, floor_h: Array[int], ceil_h: Array[int]) -> Array[Vector2i]:
	## Generate pillars/columns rising from the floor
	## All positions must be within 0 to w-1 (x) and 0 to h-1 (y)
	var pillars: Array[Vector2i] = []
	
	# 30% chance per room to have pillars
	if _rng.randf() > 0.3:
		return pillars
	
	# 1-3 pillars
	var num_pillars = _rng.randi_range(1, 3)
	
	for _i in range(num_pillars):
		# Random x position (avoid edges)
		var pillar_x = _rng.randi_range(int(w * 0.2), int(w * 0.8))
		var pillar_width = _rng.randi_range(2, 4)
		
		# Height from floor
		var floor_y = h - floor_h[clampi(pillar_x, 0, floor_h.size() - 1)] if floor_h.size() > 0 else h - 5
		var pillar_height = _rng.randi_range(5, 12)
		
		# Build pillar - with bounds check
		for y in range(floor_y - pillar_height, floor_y):
			for x in range(pillar_x, pillar_x + pillar_width):
				if x >= 0 and x < w and y >= 0 and y < h:
					pillars.append(Vector2i(x, y))
	
	return pillars


func _do_clear_tiles() -> void:
	if not tilemap_layer:
		push_warning("Assign a TileMapLayer first!")
		return
	tilemap_layer.clear()
	print("[LevelGen] Cleared tilemap")


func _place_room(type: String, pos: Vector2i) -> Dictionary:
	var def = ROOM_DEFS[type]
	var room = {"type": type, "pos": pos, "size": def.size, "exits": def.exits.duplicate()}
	_rooms.append(room)
	for y in range(def.size.y):
		for x in range(def.size.x):
			_grid[Vector2i(pos.x + x, pos.y + y)] = room
	return room


func _add_open_exits(room: Dictionary, open: Array) -> void:
	var def = ROOM_DEFS[room.type]
	if def.get("terminal", false):
		return
	for dir in room.exits:
		var cell = _get_exit_cell(room, dir)
		var neighbor = cell + DIR_VECTORS[dir]
		if not _grid.has(neighbor):
			open.append({"pos": neighbor, "entry": OPPOSITE[dir], "from": room})


func _get_exit_cell(room: Dictionary, dir: int) -> Vector2i:
	var p = room.pos
	var s = room.size
	match dir:
		0: return Vector2i(p.x + s.x/2, p.y)
		1: return Vector2i(p.x + s.x - 1, p.y + s.y/2)
		2: return Vector2i(p.x + s.x/2, p.y + s.y - 1)
		3: return Vector2i(p.x, p.y + s.y/2)
	return p


func _try_place(exit: Dictionary, open: Array) -> bool:
	var pos = exit.pos
	var entry = exit.entry
	if _grid.has(pos):
		return false
	
	var valid = _get_valid_types(entry)
	if valid.is_empty():
		return false
	
	if _rng.randf() < terminal_chance and _rooms.size() >= min_rooms:
		var terms = valid.filter(func(t): return ROOM_DEFS[t].get("terminal", false))
		if not terms.is_empty():
			valid = terms
	else:
		valid = valid.filter(func(t): return not ROOM_DEFS[t].get("terminal", false))
		if valid.is_empty():
			valid = _get_valid_types(entry)
	
	var type = _pick_weighted(valid)
	if type.is_empty():
		return false
	
	var def = ROOM_DEFS[type]
	var place_pos = _calc_pos(pos, entry, def.size)
	if not _can_place(place_pos, def.size):
		return false
	
	var room = _place_room(type, place_pos)
	_add_open_exits(room, open)
	return true


func _get_valid_types(entry: int) -> Array:
	var valid = []
	for type in ROOM_DEFS:
		var def = ROOM_DEFS[type]
		if entry in def.exits and def.weight > 0:
			valid.append(type)
	return valid


func _pick_weighted(types: Array) -> String:
	if types.is_empty():
		return ""
	
	# Adjust weights based on sprawl
	# Low sprawl = more junctions/corners (branching)
	# High sprawl = more corridors (linear)
	var adjusted_weights: Dictionary = {}
	for t in types:
		var base_weight = ROOM_DEFS[t].weight
		var tags = ROOM_DEFS[t].tags
		
		if "junction" in tags:
			# Junctions favored at low sprawl
			base_weight *= (1.0 + (0.5 - sprawl) * 2.0)
		elif "corridor" in tags:
			# Corridors favored at high sprawl
			base_weight *= (1.0 + (sprawl - 0.5) * 2.0)
		elif "corner" in tags:
			# Corners slightly favored at low sprawl
			base_weight *= (1.0 + (0.5 - sprawl) * 1.0)
		
		adjusted_weights[t] = maxf(base_weight, 0.1)
	
	var total = 0.0
	for t in types:
		total += adjusted_weights[t]
	
	var roll = _rng.randf() * total
	var cur = 0.0
	for t in types:
		cur += adjusted_weights[t]
		if roll <= cur:
			return t
	return types[-1]


func _calc_pos(target: Vector2i, entry: int, size: Vector2i) -> Vector2i:
	if size == Vector2i(1,1):
		return target
	match entry:
		0: return Vector2i(target.x - size.x/2, target.y)
		1: return Vector2i(target.x, target.y - size.y/2)
		2: return Vector2i(target.x - size.x/2, target.y - size.y + 1)
		3: return Vector2i(target.x - size.x + 1, target.y - size.y/2)
	return target


func _can_place(pos: Vector2i, size: Vector2i) -> bool:
	for y in range(size.y):
		for x in range(size.x):
			if _grid.has(Vector2i(pos.x + x, pos.y + y)):
				return false
	return true


func _has_tag(tag: String) -> bool:
	for room in _rooms:
		if tag in ROOM_DEFS[room.type].tags:
			return true
	return false


func _force_terminal(type: String, open: Array) -> void:
	var def = ROOM_DEFS.get(type)
	if not def:
		return
	for i in range(open.size() - 1, -1, -1):
		var exit = open[i]
		if exit.entry in def.exits:
			var pos = _calc_pos(exit.pos, exit.entry, def.size)
			if _can_place(pos, def.size):
				_place_room(type, pos)
				return


func _get_color(type: String) -> Color:
	var tags = ROOM_DEFS[type].tags
	if "start" in tags: return color_start
	if "boss" in tags: return color_boss
	if "save" in tags: return color_save
	if "treasure" in tags: return color_treasure
	if "junction" in tags: return color_junction
	if "arena" in tags: return color_arena
	if "corridor" in tags: return color_corridor
	return color_corridor


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	
	if show_grid and not _rooms.is_empty():
		var bounds = _get_bounds()
		for x in range(bounds.position.x - 1, bounds.end.x + 2):
			draw_line(Vector2(x, bounds.position.y - 1) * cell_size, Vector2(x, bounds.end.y + 1) * cell_size, grid_color)
		for y in range(bounds.position.y - 1, bounds.end.y + 2):
			draw_line(Vector2(bounds.position.x - 1, y) * cell_size, Vector2(bounds.end.x + 1, y) * cell_size, grid_color)
	
	for room in _rooms:
		var rect = Rect2(Vector2(room.pos) * cell_size, Vector2(room.size) * cell_size)
		var col = _get_color(room.type)
		draw_rect(rect, col, true)
		draw_rect(rect, Color(col, 1.0), false, 3.0)
		
		if show_labels:
			var font = ThemeDB.fallback_font
			draw_string(font, rect.position + Vector2(8, label_size + 4), room.type.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, Color.WHITE)
		
		if show_exits:
			for dir in room.exits:
				var exit_rect = _get_exit_rect(room, dir, rect)
				draw_rect(exit_rect, Color.WHITE, true)


func _get_exit_rect(room: Dictionary, dir: int, rect: Rect2) -> Rect2:
	var s = 16.0
	match dir:
		0: return Rect2(rect.position.x + rect.size.x/2 - s/2, rect.position.y - 2, s, 6)
		1: return Rect2(rect.end.x - 4, rect.position.y + rect.size.y/2 - s/2, 6, s)
		2: return Rect2(rect.position.x + rect.size.x/2 - s/2, rect.end.y - 4, s, 6)
		3: return Rect2(rect.position.x - 2, rect.position.y + rect.size.y/2 - s/2, 6, s)
	return Rect2()


func _get_bounds() -> Rect2i:
	var min_p = Vector2i(999999, 999999)
	var max_p = Vector2i(-999999, -999999)
	for room in _rooms:
		min_p.x = mini(min_p.x, room.pos.x)
		min_p.y = mini(min_p.y, room.pos.y)
		max_p.x = maxi(max_p.x, room.pos.x + room.size.x)
		max_p.y = maxi(max_p.y, room.pos.y + room.size.y)
	return Rect2i(min_p, max_p - min_p)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()
