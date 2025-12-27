extends Area2D

var direction: float = 1.0
var direction_vector: Vector2 = Vector2.RIGHT  # For angled shots
var speed: float = 400.0
var damage: int = 2
var _use_vector: bool = false  # Whether to use direction_vector instead of simple direction

func _ready():
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func set_direction(dir: float):
	direction = sign(dir)
	_use_vector = false
	if dir < 0:
		scale.x = -0.25
	else:
		scale.x = 0.25


func set_direction_vector(dir: Vector2):
	"""Set direction as a vector for angled shots (shotgun burst)."""
	direction_vector = dir.normalized()
	_use_vector = true
	# Flip sprite based on x direction
	if dir.x < 0:
		scale.x = -0.25
	else:
		scale.x = 0.25
	# Rotate sprite to match direction
	rotation = dir.angle()


func _physics_process(delta):
	if _use_vector:
		position += direction_vector * speed * delta
	else:
		position.x += direction * speed * delta
	



func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	# Hit enemy hurtbox
	var parent = area.get_parent()
	if parent and parent.has_method("take_damage"):
		parent.take_damage(damage)
	queue_free()
