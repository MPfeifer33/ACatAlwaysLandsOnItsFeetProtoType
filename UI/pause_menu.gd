extends Control
## Pause Menu - shown when game is paused

@onready var resume_button: Button = $VBoxContainer/ResumeButton


func _ready() -> void:
	# Grab focus when pause menu appears
	await get_tree().process_frame
	resume_button.grab_focus()


func _input(event: InputEvent) -> void:
	# Allow unpausing with B button or pause button
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()
		return
	
	# Allow A button (jump) to activate focused button in menus
	if event.is_action_pressed("jump"):
		var focused = get_viewport().gui_get_focus_owner()
		if focused is Button:
			focused.emit_signal("pressed")
			get_viewport().set_input_as_handled()


func _on_resume_pressed() -> void:
	GameManager.resume()


func _on_restart_pressed() -> void:
	GameManager.resume()
	GameManager.reload_current_level()


func _on_main_menu_pressed() -> void:
	GameManager.resume()
	GameManager.go_to_main_menu()


func _on_quit_pressed() -> void:
	GameManager.quit_game()
