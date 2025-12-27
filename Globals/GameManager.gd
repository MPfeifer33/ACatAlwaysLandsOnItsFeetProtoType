extends Node
## GameManager - Handles game state, level loading, and menu transitions.
## Add to AutoLoad as "GameManager"

# ============ SIGNALS ============
signal level_loaded(level_name: String)
signal level_unloaded(level_name: String)
signal game_paused
signal game_resumed
signal game_state_changed(new_state: GameState)

# ============ ENUMS ============
enum GameState {
	MAIN_MENU,
	PLAYING,
	PAUSED,
	CUTSCENE,
	GAME_OVER
}

# ============ CONFIGURATION ============
const LEVELS_PATH: String = "res://Levels/"
const MAIN_MENU_PATH: String = "res://UI/main_menu.tscn"
const PAUSE_MENU_PATH: String = "res://UI/pause_menu.tscn"
const DEFAULT_FIRST_LEVEL: String = "shadow_world_one_proto"

# ============ STATE ============
var current_state: GameState = GameState.MAIN_MENU
var current_level: Node = null
var current_level_name: String = ""
var player: Player = null

# References
var _main_node: Node = null  # The Main scene root
var _level_container: Node = null  # Where levels get loaded
var _ui_layer: CanvasLayer = null  # For menus
var _pause_menu: Node = null  # Can be Control or CanvasLayer
var _main_menu: Node = null  # Can be Control or CanvasLayer
var _initialized: bool = false


func _ready() -> void:
	# Start unpaused
	get_tree().paused = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # GameManager always runs


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()


# ============ INITIALIZATION ============

func initialize(main_node: Node, level_container: Node, ui_layer: CanvasLayer = null) -> void:
	"""Call this from Main scene's _ready() to set up references."""
	_main_node = main_node
	_level_container = level_container
	_ui_layer = ui_layer
	
	# Find player (should be in Main scene, hidden initially)
	_find_player()
	
	# Hide player until a game is started/loaded
	if player:
		player.visible = false
		player.set_physics_process(false)
		player.set_process_input(false)
	
	_initialized = true
	
	# Start at main menu - no level loaded yet
	change_state(GameState.MAIN_MENU)
	
	print("GameManager initialized - awaiting save slot selection")


func _find_player() -> void:
	"""Find the player node in the scene tree."""
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		player = players[0] as Player
	else:
		# Try to find by class
		player = _find_node_by_class(_main_node, "Player") as Player


func _find_node_by_class(node: Node, target_class: String) -> Node:
	"""Recursively find a node by class name."""
	if node.get_class() == target_class or node is Player:
		return node
	for child in node.get_children():
		var result = _find_node_by_class(child, target_class)
		if result:
			return result
	return null


# ============ STATE MANAGEMENT ============

func change_state(new_state: GameState) -> void:
	"""Change the game state and handle transitions."""
	current_state = new_state
	
	match new_state:
		GameState.MAIN_MENU:
			_enter_main_menu()
		GameState.PLAYING:
			_enter_playing()
		GameState.PAUSED:
			_enter_paused()
		GameState.CUTSCENE:
			_enter_cutscene()
		GameState.GAME_OVER:
			_enter_game_over()
	
	game_state_changed.emit(new_state)
	print("Game state: ", GameState.keys()[new_state])


func _enter_main_menu() -> void:
	get_tree().paused = false
	_show_main_menu()
	# Hide player during main menu
	if player and is_instance_valid(player):
		player.visible = false
		player.set_physics_process(false)
		player.set_process_input(false)


func _enter_playing() -> void:
	get_tree().paused = false
	_hide_pause_menu()
	_hide_main_menu()
	# Show player when playing
	if player and is_instance_valid(player):
		player.visible = true
		player.set_physics_process(true)
		player.set_process_input(true)


func _enter_paused() -> void:
	get_tree().paused = true
	_show_pause_menu()
	game_paused.emit()


func _enter_cutscene() -> void:
	# Player can't move during cutscenes but physics still runs
	get_tree().paused = false
	# TODO: Disable player input


func _enter_game_over() -> void:
	get_tree().paused = true
	# TODO: Show game over screen


# ============ PAUSE SYSTEM ============

func toggle_pause() -> void:
	"""Toggle pause state."""
	if current_state == GameState.PLAYING:
		change_state(GameState.PAUSED)
	elif current_state == GameState.PAUSED:
		change_state(GameState.PLAYING)


func pause() -> void:
	"""Pause the game."""
	if current_state == GameState.PLAYING:
		change_state(GameState.PAUSED)


func resume() -> void:
	"""Resume the game."""
	if current_state == GameState.PAUSED:
		change_state(GameState.PLAYING)
		game_resumed.emit()


func _show_pause_menu() -> void:
	"""Show the pause menu UI."""
	if _pause_menu:
		_pause_menu.visible = true
		return
	
	# Load pause menu scene
	if ResourceLoader.exists(PAUSE_MENU_PATH):
		var pause_scene = load(PAUSE_MENU_PATH)
		_pause_menu = pause_scene.instantiate()
		_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
		if _ui_layer:
			_ui_layer.add_child(_pause_menu)
		elif _main_node:
			_main_node.add_child(_pause_menu)
	else:
		print("PAUSED - Press pause again to resume (no pause menu scene found)")


func _hide_pause_menu() -> void:
	"""Hide the pause menu UI."""
	if _pause_menu:
		_pause_menu.visible = false


func _show_main_menu() -> void:
	"""Show the main menu UI."""
	if _main_menu:
		_main_menu.visible = true
		return
	
	# Load main menu scene
	if ResourceLoader.exists(MAIN_MENU_PATH):
		var menu_scene = load(MAIN_MENU_PATH)
		_main_menu = menu_scene.instantiate()
		if _ui_layer:
			_ui_layer.add_child(_main_menu)
		elif _main_node:
			_main_node.add_child(_main_menu)
	else:
		print("No main menu scene found at: ", MAIN_MENU_PATH)


func _hide_main_menu() -> void:
	"""Hide the main menu UI."""
	if _main_menu:
		_main_menu.queue_free()
		_main_menu = null


# ============ LEVEL MANAGEMENT ============

func load_level(level_name: String) -> void:
	"""Load a level by name (without path or extension)."""
	var level_path = LEVELS_PATH + level_name + ".tscn"
	
	if not ResourceLoader.exists(level_path):
		push_error("Level not found: " + level_path)
		return
	
	# Unload current level first
	if current_level:
		unload_current_level()
	
	# Load new level
	var level_scene = load(level_path)
	current_level = level_scene.instantiate()
	current_level_name = level_name
	
	if _level_container:
		_level_container.add_child(current_level)
	elif _main_node:
		_main_node.add_child(current_level)
	else:
		push_error("No level container set! Call initialize() first.")
		return
	
	# Update SaveManager's current level
	SaveManager.current_level = level_name
	
	level_loaded.emit(level_name)
	print("Loaded level: ", level_name)


func load_level_with_transition(level_name: String, position_callback: Callable = Callable()) -> void:
	"""Load a level with fade transition. Optionally provide a callback to position player."""
	await SceneManager.transition_with_callback(func():
		load_level(level_name)
		if position_callback.is_valid():
			position_callback.call()
	)


func unload_current_level() -> void:
	"""Unload the current level."""
	if current_level:
		var old_name = current_level_name
		current_level.queue_free()
		current_level = null
		current_level_name = ""
		level_unloaded.emit(old_name)
		print("Unloaded level: ", old_name)


func reload_current_level() -> void:
	"""Reload the current level (useful for retrying)."""
	if current_level_name != "":
		var level_to_reload = current_level_name
		unload_current_level()
		load_level(level_to_reload)


func transition_to_level(level_name: String) -> void:
	"""Transition to a new level with optional effects."""
	# TODO: Add screen transition/fade effect
	load_level(level_name)


# ============ GAME FLOW ============

func go_to_main_menu() -> void:
	"""Return to the main menu with fade transition."""
	await SceneManager.transition_with_callback(func():
		unload_current_level()
	)
	change_state(GameState.MAIN_MENU)


func start_new_game(slot: int) -> void:
	"""Start a new game from the beginning in the specified slot."""
	# Initialize fresh save data
	SaveManager.start_new_game(slot)
	
	# Load the first level with transition
	await load_level_with_transition(DEFAULT_FIRST_LEVEL, _position_player_for_new_game)
	
	# Start playing
	change_state(GameState.PLAYING)
	
	print("Started new game in slot ", slot)


func continue_game(slot: int) -> bool:
	"""Continue a saved game from the specified slot. Returns false if no save exists."""
	if not SaveManager.has_save_data(slot):
		push_warning("No save data in slot ", slot)
		return false
	
	# Load save data
	if not SaveManager.load_game(slot):
		push_error("Failed to load save from slot ", slot)
		return false
	
	# Load the saved level (or default if none saved)
	var level_to_load = SaveManager.current_level
	if level_to_load.is_empty():
		level_to_load = DEFAULT_FIRST_LEVEL
	
	# Load level with transition
	await load_level_with_transition(level_to_load, _position_player_from_save)
	
	# Start playing
	change_state(GameState.PLAYING)
	SaveManager.start_play_timer()
	
	print("Continued game from slot ", slot, " - level: ", level_to_load)
	return true


func _position_player_for_new_game() -> void:
	"""Position player at level's starting point for a new game."""
	if not player:
		_find_player()
	if not player:
		return
	
	# Look for a designated start position in the level
	var start_pos = _find_level_start_position()
	if start_pos != Vector2.ZERO:
		player.global_position = start_pos
		# Set both default and respawn for new games
		SaveManager.set_default_respawn(start_pos)
		SaveManager.respawn_position = start_pos
		print("New game: Player spawned at PlayerStart ", start_pos)
	else:
		# Fallback: find first hospital/checkpoint
		var hospitals = get_tree().get_nodes_in_group("Hospital")
		if hospitals.size() > 0:
			var hospital_pos = hospitals[0].global_position
			player.global_position = hospital_pos
			SaveManager.set_default_respawn(hospital_pos)
			SaveManager.respawn_position = hospital_pos
			print("New game: Player spawned at Hospital ", hospital_pos)
		else:
			push_warning("No start position found in level!")


func _position_player_from_save() -> void:
	"""Position player based on saved respawn position (from hospital saves)."""
	if not player:
		_find_player()
	if not player:
		return
	
	# Always set the level's default respawn as fallback
	var level_start = _find_level_start_position()
	if level_start != Vector2.ZERO:
		SaveManager.set_default_respawn(level_start)
	
	# Use saved hospital position if available, otherwise use level start
	var saved_pos = SaveManager.respawn_position
	if saved_pos != Vector2.ZERO:
		player.global_position = saved_pos
		print("Continue: Player spawned at saved position ", saved_pos)
	elif level_start != Vector2.ZERO:
		player.global_position = level_start
		print("Continue: No saved position, using level start ", level_start)
	else:
		push_warning("No spawn position available!")


func _find_level_start_position() -> Vector2:
	"""Find the designated starting position in the current level."""
	# Look for a node named "PlayerStart" or in group "player_start"
	var start_nodes = get_tree().get_nodes_in_group("player_start")
	if start_nodes.size() > 0:
		return start_nodes[0].global_position
	
	# Look for a Marker2D named PlayerStart
	if current_level:
		var start_marker = current_level.find_child("PlayerStart", true, false)
		if start_marker:
			return start_marker.global_position
	
	return Vector2.ZERO


func quit_game() -> void:
	"""Quit the application."""
	get_tree().quit()


func quick_play_level(level_name: String) -> void:
	"""Quick play a level without save data (for testing/level select)."""
	# Load the level with transition
	await load_level_with_transition(level_name, _position_player_for_new_game)
	
	# Start playing
	change_state(GameState.PLAYING)
	
	print("Quick play: ", level_name)


func return_to_menu() -> void:
	"""Return to main menu from quick play or normal gameplay."""
	go_to_main_menu()


# ============ UTILITY ============

func get_player() -> Player:
	"""Get the player node, finding it if necessary."""
	if not player or not is_instance_valid(player):
		_find_player()
	return player


func is_playing() -> bool:
	return current_state == GameState.PLAYING


func is_paused() -> bool:
	return current_state == GameState.PAUSED


func is_initialized() -> bool:
	return _initialized
