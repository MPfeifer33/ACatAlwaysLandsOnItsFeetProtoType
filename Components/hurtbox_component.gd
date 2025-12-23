class_name HurtboxComponent
extends Area2D
## Receives damage from hitboxes. Attach to any entity that can be hurt.
## Requires a HealthComponent sibling or specify a custom health node path.

## Emitted when this hurtbox is hit (before damage is applied)
signal hurt(hitbox: HitboxComponent)

## Path to the HealthComponent (auto-detects sibling if empty)
@export var health_component_path: NodePath = ""

## If true, shows debug collision shape in-game
@export var debug_visible: bool = false

var _health: HealthComponent = null


func _ready() -> void:
	# Find health component
	if health_component_path.is_empty():
		# Look for sibling HealthComponent
		var parent = get_parent()
		if parent:
			for child in parent.get_children():
				if child is HealthComponent:
					_health = child
					break
	else:
		_health = get_node_or_null(health_component_path)
	
	if not _health:
		push_warning("HurtboxComponent: No HealthComponent found for " + get_parent().name)
	
	# Connect area detection
	area_entered.connect(_on_area_entered)
	
	# Debug visibility
	if not debug_visible:
		for child in get_children():
			if child is CollisionShape2D:
				child.visible = false


func _on_area_entered(area: Area2D) -> void:
	if area is HitboxComponent:
		var hitbox = area as HitboxComponent
		hurt.emit(hitbox)
		
		if _health:
			_health.take_damage(hitbox.damage)


## Call this to manually apply damage (bypasses hitbox)
func apply_damage(amount: int) -> void:
	if _health:
		_health.take_damage(amount)
