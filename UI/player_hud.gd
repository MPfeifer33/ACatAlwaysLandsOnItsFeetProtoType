extends Control
## Player HUD - shows health bar and other player info

@onready var health_bar: ProgressBar = $MarginContainer/VBoxContainer/HealthBar
@onready var health_label: Label = $MarginContainer/VBoxContainer/HealthBar/HealthLabel

var _player: Player = null


func _ready() -> void:
	# Find player and connect to health signals
	await get_tree().process_frame
	_connect_to_player()


func _connect_to_player() -> void:
	_player = GameManager.get_player()
	if _player and _player.health:
		_player.health.health_changed.connect(_on_health_changed)
		# Initialize the bar
		_on_health_changed(_player.health.current_health, _player.health.max_health)
	else:
		# Retry next frame if player not ready yet
		await get_tree().process_frame
		_connect_to_player()


func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	health_label.text = str(current) + " / " + str(maximum)
