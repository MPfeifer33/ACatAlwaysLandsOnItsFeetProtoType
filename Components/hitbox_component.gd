class_name HitboxComponent
extends Area2D
## Deals damage to hurtboxes. Attach to attacks, projectiles, hazards.

## Damage this hitbox deals
@export var damage: int = 1

## If true, hitbox is actively dealing damage
@export var active: bool = true:
	set(value):
		active = value
		# Always use call_deferred during gameplay to avoid physics callback issues
		call_deferred("_apply_active_state", value)


func _apply_active_state(value: bool) -> void:
	monitoring = value
	monitorable = value

## If true, disables after first hit
@export var one_shot: bool = false

## Emitted when this hitbox hits a hurtbox
signal hit(hurtbox: HurtboxComponent)


func _ready() -> void:
	# Apply initial active state
	monitoring = active
	monitorable = active
	
	# Connect to detect when we hit something
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if area is HurtboxComponent:
		hit.emit(area as HurtboxComponent)
		
		if one_shot:
			active = false


## Activate the hitbox (for attacks that turn on/off)
func activate() -> void:
	active = true


## Deactivate the hitbox
func deactivate() -> void:
	active = false
