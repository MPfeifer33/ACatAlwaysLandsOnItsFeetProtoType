@tool
extends EditorScript
## Room Template Stamper - Stamps pre-made room layouts into your TileMapLayer
## 
## HOW TO USE:
## 1. Open your level scene (e.g., shadow_world_one_proto.tscn)
## 2. Select your TileMapLayer node in the scene tree
## 3. Modify TEMPLATE_NAME and ROOM_OFFSET below
## 4. Run this script: Script menu → Run (or Ctrl+Shift+X)
##
## The template will be stamped using terrain autotiling!

# ============ SETTINGS - MODIFY THESE ============

## Which template to stamp (see AVAILABLE TEMPLATES below)
const TEMPLATE_NAME := "flat_corridor"

## Where to place the room (in TILE coordinates, not pixels)
## Example: Vector2i(0, 0) = top-left, Vector2i(21, 0) = one room to the right
const ROOM_OFFSET := Vector2i(0, 0)

## Your terrain set ID (check your TileSet - usually 0 or 1)
## In your shadow tileset, terrain_set 1 appears to be configured
const TERRAIN_SET := 1

## Your terrain ID within that set (usually 0)
const TERRAIN_ID := 0

# ============ AVAILABLE TEMPLATES ============
#
# BASIC SHAPES:
#   "flat_corridor"      - Horizontal passage, doors left & right
#   "vertical_shaft"     - Tall climbing room, doors top & bottom
#   "l_corner_left"      - L-turn, entries from right and top
#   "l_corner_right"     - L-turn, entries from left and top
#   "t_intersection"     - 3-way junction (left, right, bottom)
#   "open_arena"         - Large open combat room
#
# PLATFORMING CHALLENGES:
#   "staircase_up"       - Ascending platforms, bottom-left to top-right
#   "staircase_down"     - Descending platforms, top-left to bottom-right
#   "floating_platforms" - Platforms over a pit
#   "wall_jump_corridor" - Narrow vertical shaft for wall jumping
#   "pit_crossing"       - Wide pit with stepping stones
#   "zigzag_climb"       - Zigzag pattern going up
#
# SPECIAL ROOMS:
#   "save_room"          - Small cozy save point room
#   "treasure_room"      - Dead-end with item pedestal
#   "hub_room"           - 4 exits (all directions)
#   "transition_corridor"- Simple horizontal connector
#   "boss_arena"         - Large boss fight arena
#
# ============ END SETTINGS ============


func _run() -> void:
	print("=== Room Template Stamper ===")
	
	# Get selected node
	var selection = EditorInterface.get_selection()
	var selected = selection.get_selected_nodes()
	
	if selected.is_empty():
		push_error("❌ No node selected! Please select a TileMapLayer in your scene.")
		return
	
	var tilemap: TileMapLayer = selected[0] as TileMapLayer
	if not tilemap:
		push_error("❌ Selected node '%s' is not a TileMapLayer!" % selected[0].name)
		return
	
	print("✓ Using TileMapLayer: ", tilemap.name)
	
	# Load templates
	var templates = RoomTemplates.new()
	var layout = templates.get_template(TEMPLATE_NAME)
	
	if layout.is_empty():
		push_error("❌ Template '%s' not found!" % TEMPLATE_NAME)
		print("Available templates:")
		for category in templates.get_all_templates():
			print("  ", category, ": ", templates.get_all_templates()[category])
		return
	
	print("✓ Template: ", TEMPLATE_NAME)
	print("✓ Size: ", RoomTemplates.ROOM_WIDTH, "x", RoomTemplates.ROOM_HEIGHT, " tiles")
	print("✓ Offset: ", ROOM_OFFSET)
	
	# Collect positions for terrain painting
	var solid_positions: Array[Vector2i] = []
	var empty_positions: Array[Vector2i] = []
	
	# Track spawn markers
	var spawns := {
		"player": [],
		"enemy": [],
		"item": [],
		"door": [],
	}
	
	# Process the template
	for y in range(layout.size()):
		var row = layout[y]
		for x in range(row.size()):
			var tile_type = row[x]
			var tile_pos = Vector2i(x, y) + ROOM_OFFSET
			
			match tile_type:
				RoomTemplates.EMPTY:
					empty_positions.append(tile_pos)
				RoomTemplates.SOLID:
					solid_positions.append(tile_pos)
				RoomTemplates.PLATFORM:
					# Platforms treated as solid (no one-way in shadow tileset)
					solid_positions.append(tile_pos)
				RoomTemplates.SPIKE:
					# No spikes in shadow tileset, leave empty
					empty_positions.append(tile_pos)
				RoomTemplates.PLAYER_SPAWN:
					spawns.player.append(tile_pos)
					empty_positions.append(tile_pos)
				RoomTemplates.ENEMY_SPAWN:
					spawns.enemy.append(tile_pos)
					empty_positions.append(tile_pos)
				RoomTemplates.ITEM_SPAWN:
					spawns.item.append(tile_pos)
					empty_positions.append(tile_pos)
				RoomTemplates.DOOR:
					spawns.door.append(tile_pos)
					empty_positions.append(tile_pos)
	
	# Clear empty positions first
	for pos in empty_positions:
		tilemap.erase_cell(pos)
	
	# Use terrain painting for solid tiles (this makes autotiling work!)
	if solid_positions.size() > 0:
		tilemap.set_cells_terrain_connect(solid_positions, TERRAIN_SET, TERRAIN_ID)
	
	print("")
	print("✓ Stamped ", solid_positions.size(), " solid tiles")
	print("✓ Cleared ", empty_positions.size(), " empty tiles")
	print("")
	
	# Report spawn positions
	print("📍 SPAWN MARKERS (tile coordinates):")
	if spawns.player.size() > 0:
		print("   Player: ", spawns.player)
		print("   → Pixel position: ", Vector2(spawns.player[0]) * 16)
	if spawns.enemy.size() > 0:
		print("   Enemies: ", spawns.enemy)
	if spawns.item.size() > 0:
		print("   Items: ", spawns.item)
	if spawns.door.size() > 0:
		print("   Doors: ", spawns.door)
	
	print("")
	print("📋 NEXT STEPS:")
	print("   1. Add a Room node at position (", ROOM_OFFSET.x * 16, ", ", ROOM_OFFSET.y * 16, ")")
	print("      with size ", RoomTemplates.ROOM_WIDTH * 16, "x", RoomTemplates.ROOM_HEIGHT * 16, " pixels")
	print("   2. Place your Player at the player spawn position")
	print("   3. Add enemies/items at their marker positions")
	print("   4. Set up door transitions at door positions")
	print("")
	print("=== Done! ===")
