@tool
extends EditorScript
## Level Generator Runner - Generates a procedural level layout
##
## HOW TO USE:
## 1. Open your level scene
## 2. Configure settings below
## 3. Run this script: Script menu → Run (Ctrl+Shift+X)
##
## This will generate Room nodes in your scene based on the walker algorithm.

# ============ SETTINGS ============

## Random seed (0 = random each time)
const SEED := 0

## Generation parameters
const MIN_ROOMS := 8
const MAX_ROOMS := 15
const BRANCH_CHANCE := 0.3
const TERMINAL_CHANCE := 0.2

## Whether to clear existing Room nodes first
const CLEAR_EXISTING := true

## Whether to print debug grid to console
const PRINT_DEBUG := true

# ============ SCRIPT ============

func _run() -> void:
	print("\n=== Level Generator ===")
	
	var scene_root = get_scene()
	if not scene_root:
		push_error("❌ No scene open! Open a level scene first.")
		return
	
	print("✓ Scene: ", scene_root.name)
	
	# Clear existing rooms if requested
	if CLEAR_EXISTING:
		_clear_rooms(scene_root)
	
	# Create and configure generator
	var generator := LevelGenerator.new()
	
	if SEED != 0:
		generator.set_seed(SEED)
		print("✓ Using seed: ", SEED)
	else:
		var random_seed := randi()
		generator.set_seed(random_seed)
		print("✓ Using random seed: ", random_seed)
	
	generator.set_setting("min_rooms", MIN_ROOMS)
	generator.set_setting("max_rooms", MAX_ROOMS)
	generator.set_setting("branch_chance", BRANCH_CHANCE)
	generator.set_setting("terminal_chance", TERMINAL_CHANCE)
	
	# Generate!
	var result := generator.generate()
	
	if PRINT_DEBUG:
		generator.print_grid()
	
	# Create Room nodes
	var rooms_created := 0
	var room_script = preload("res://Levels/Components/room.gd")
	
	# Track unique rooms (multi-cell rooms are in grid multiple times)
	var processed_rooms: Array = []
	
	for room_placement in result.rooms:
		if room_placement in processed_rooms:
			continue
		processed_rooms.append(room_placement)
		
		# Create Room node
		var room := Area2D.new()
		room.set_script(room_script)
		room.name = _generate_room_name(room_placement)
		room.room_id = room.name
		room.room_size = room_placement.pixel_size
		room.position = room_placement.pixel_pos
		
		# Mark start room
		if room_placement.type == "start_room":
			room.is_starting_room = true
			room.editor_color = Color(0.2, 0.8, 0.3, 0.3)
		elif room_placement.type == "boss_room":
			room.editor_color = Color(0.8, 0.2, 0.2, 0.3)
		elif room_placement.type == "save_room":
			room.editor_color = Color(0.2, 0.5, 0.9, 0.3)
		elif room_placement.type == "treasure_room":
			room.editor_color = Color(0.9, 0.8, 0.2, 0.3)
		elif "corridor" in room_placement.type:
			room.editor_color = Color(0.5, 0.5, 0.5, 0.2)
		
		scene_root.add_child(room)
		room.owner = scene_root
		rooms_created += 1
	
	print("")
	print("✓ Created %d Room nodes" % rooms_created)
	print("")
	print("📋 ROOM SUMMARY:")
	
	# Print room list
	for room_placement in result.rooms:
		print("   %s at grid %s → pixel %s (%dx%d)" % [
			room_placement.type,
			room_placement.grid_pos,
			room_placement.pixel_pos,
			int(room_placement.pixel_size.x),
			int(room_placement.pixel_size.y),
		])
	
	print("")
	print("📋 NEXT STEPS:")
	print("   1. Review the generated layout in 2D view")
	print("   2. Add TileMapLayer and stamp room templates")
	print("   3. Adjust room positions/sizes as needed")
	print("   4. Add enemies, items, and decorations")
	print("")
	print("=== Done! ===")


func _clear_rooms(parent: Node) -> void:
	var removed := 0
	for child in parent.get_children():
		if child.has_method("get_bounds") and "room_id" in child:
			child.queue_free()
			removed += 1
	
	if removed > 0:
		print("✓ Cleared %d existing Room nodes" % removed)


func _generate_room_name(placement: LevelGenerator.RoomPlacement) -> String:
	# Create readable name like "room_corridor_h_0_1"
	return "room_%s_%d_%d" % [
		placement.type,
		placement.grid_pos.x,
		placement.grid_pos.y
	]
