extends Control
## Main Menu - title screen with save slot selection

enum MenuState { TITLE, SLOT_SELECT, CONFIRM_DELETE }

var _current_state: MenuState = MenuState.TITLE
var _selected_slot: int = 0
var _is_new_game: bool = false

@onready var title_container: Control = $CenterContainer/TitleContainer
@onready var slot_container: Control = $CenterContainer/SlotContainer
@onready var confirm_container: Control = $CenterContainer/ConfirmContainer

# Button references for focus
@onready var new_game_button: Button = $CenterContainer/TitleContainer/ButtonContainer/NewGameButton
@onready var slot_button_1: Button = $CenterContainer/SlotContainer/SlotButton1
@onready var no_button: Button = $CenterContainer/ConfirmContainer/ButtonRow/NoButton


func _ready() -> void:
	_show_title()
	_update_slot_buttons()


func _input(event: InputEvent) -> void:
	# Allow A button (jump) to activate focused button in menus
	if event.is_action_pressed("jump"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused is Button and not focused.disabled:
			focused.emit_signal("pressed")
			get_viewport().set_input_as_handled()
			return
	
	# Handle back/cancel with B button or Escape
	if event.is_action_pressed("ui_cancel"):
		match _current_state:
			MenuState.SLOT_SELECT:
				_show_title()
			MenuState.CONFIRM_DELETE:
				_on_confirm_no_pressed()


func _show_title() -> void:
	_current_state = MenuState.TITLE
	title_container.visible = true
	slot_container.visible = false
	confirm_container.visible = false
	# Grab focus for controller navigation
	await get_tree().process_frame
	new_game_button.grab_focus()


func _show_slot_select(is_new_game: bool) -> void:
	_current_state = MenuState.SLOT_SELECT
	_is_new_game = is_new_game
	title_container.visible = false
	slot_container.visible = true
	confirm_container.visible = false
	_update_slot_buttons()
	
	# Update header text
	var header = slot_container.get_node("Header")
	header.text = "Select Slot for New Game" if is_new_game else "Select Save to Load"
	
	# Grab focus for controller navigation
	await get_tree().process_frame
	slot_button_1.grab_focus()


func _show_confirm_delete() -> void:
	_current_state = MenuState.CONFIRM_DELETE
	confirm_container.visible = true
	# Grab focus on No button (safer default)
	await get_tree().process_frame
	no_button.grab_focus()


func _update_slot_buttons() -> void:
	for i in range(1, 4):
		var button = slot_container.get_node("SlotButton" + str(i))
		var info = SaveManager.get_slot_info(i)
		
		if info.get("empty", true):
			button.text = "Slot " + str(i) + " - Empty"
			button.disabled = not _is_new_game  # Can't load empty slot
		else:
			var play_time = SaveManager.format_play_time(info.get("play_time", 0))
			var powerups = info.get("powerups_collected", 0)
			button.text = "Slot " + str(i) + " - " + play_time + " | " + str(powerups) + " powerups"
			button.disabled = false


# ============ TITLE BUTTONS ============

func _on_new_game_pressed() -> void:
	_show_slot_select(true)


func _on_continue_pressed() -> void:
	# Check if any saves exist
	var has_saves = false
	for i in range(1, 4):
		if SaveManager.has_save_data(i):
			has_saves = true
			break
	
	if has_saves:
		_show_slot_select(false)
	else:
		print("No save data found")


func _on_quit_pressed() -> void:
	GameManager.quit_game()


# ============ SLOT BUTTONS ============

func _on_slot_1_pressed() -> void:
	_select_slot(1)


func _on_slot_2_pressed() -> void:
	_select_slot(2)


func _on_slot_3_pressed() -> void:
	_select_slot(3)


func _select_slot(slot: int) -> void:
	_selected_slot = slot
	
	if _is_new_game:
		# Check if slot has existing data
		if SaveManager.has_save_data(slot):
			_show_confirm_delete()
		else:
			_start_new_game(slot)
	else:
		_load_game(slot)


func _on_back_pressed() -> void:
	_show_title()


# ============ CONFIRM OVERWRITE ============

func _on_confirm_yes_pressed() -> void:
	SaveManager.delete_save(_selected_slot)
	_start_new_game(_selected_slot)


func _on_confirm_no_pressed() -> void:
	confirm_container.visible = false
	_current_state = MenuState.SLOT_SELECT
	# Return focus to the slot buttons
	await get_tree().process_frame
	var slot_button = slot_container.get_node("SlotButton" + str(_selected_slot))
	if slot_button:
		slot_button.grab_focus()
	else:
		slot_button_1.grab_focus()


# ============ GAME START ============

func _start_new_game(slot: int) -> void:
	# GameManager handles save init, level load, and state change
	GameManager.start_new_game(slot)


func _load_game(slot: int) -> void:
	# GameManager handles save load, level load, player positioning, and state change
	GameManager.continue_game(slot)
