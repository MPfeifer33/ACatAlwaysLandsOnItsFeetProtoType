extends AnimatedSprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	play("Dust")
	animation_finished.connect(_on_ani_finished)

func _on_ani_finished():
	queue_free()
