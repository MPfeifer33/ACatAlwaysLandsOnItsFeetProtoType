extends Area2D

var direction: float = 1.0
var speed: float = 400.0
var damage: int = 2

func _ready():
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func set_direction(dir: float):
	direction = sign(dir)
	if dir < 0:
		scale.x = -0.25
	else:
		scale.x = 0.25
	

func _physics_process(delta):
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
