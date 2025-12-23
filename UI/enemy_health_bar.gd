extends Node2D
## Enemy health bar - floats above enemy and shows current health

@onready var health_bar: ProgressBar = $ProgressBar
@onready var background: ColorRect = $Background

@export var bar_width: float = 32.0
@export var bar_height: float = 4.0
@export var offset_y: float = -20.0
@export var hide_when_full: bool = true

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
	
	# Find health component on parent
	var parent = get_parent()
	if parent:
		for child in parent.get_children():
			if child is HealthComponent:
				_health_component = child
				break
	
	if _health_component:
		_health_component.health_changed.connect(_on_health_changed)
		_health_component.died.connect(_on_died)
		# Initialize
		_on_health_changed(_health_component.current_health, _health_component.max_health)
	else:
		push_warning("EnemyHealthBar: No HealthComponent found on parent")
	
	# Start hidden if at full health
	if hide_when_full:
		_set_bar_visible(false)


func _on_health_changed(current: int, maximum: int) -> void:
	health_bar.max_value = maximum
	health_bar.value = current
	
	# Show bar when damaged, hide when full
	if hide_when_full:
		_set_bar_visible(current < maximum)


func _on_died() -> void:
	_set_bar_visible(false)


func _set_bar_visible(visible_state: bool) -> void:
	health_bar.visible = visible_state
	background.visible = visible_state
