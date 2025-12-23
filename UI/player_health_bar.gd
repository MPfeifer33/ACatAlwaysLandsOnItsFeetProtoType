extends Node2D
## Player health bar - floats above Tama and shows current health

@onready var health_bar: ProgressBar = $ProgressBar
@onready var background: ColorRect = $Background

@export var bar_width: float = 40.0
@export var bar_height: float = 6.0
@export var offset_y: float = -30.0

var _health_component: HealthComponent = null


func _ready() -> void:
	# Set up bar size
	health_bar.custom_minimum_size = Vector2(bar_width, bar_height)
	health_bar.size = Vector2(bar_width, bar_height)
	background.custom_minimum_size = Vector2(bar_width + 2, bar_height + 2)
	background.size = Vector2(bar_width + 2, bar_height + 2)
	
	# Center the bar
	health_bar.position = Vector2(-bar_width / 2, offset_y)
	background.position = Vector2(-bar_width / 2 - 1, offset_y - 1)
	
	# Find health component on parent (Player)
	var parent = get_parent()
	if parent and parent.has_node("HealthComponent"):
		_health_component = parent.get_node("HealthComponent")
	
	if _health_component:
		_health_component.health_changed.connect(_on_health_changed)
		# Initialize
		_on_health_changed(_health_component.current_health, _health_component.max_health)
	else:
		push_warning("PlayerHealthBar: No HealthComponent found on parent")


func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
