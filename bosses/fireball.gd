class_name FurnaceFireball
extends Area2D

@export var speed: float = 360.0
@export var damage: int = 1

var direction: Vector2 = Vector2.LEFT


func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()


func _on_screen_exited() -> void:
	queue_free()
