class_name PipBullet
extends Area2D

@export var speed: float = 700.0

var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta


func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("bosses"):
		return

	if body.has_method("take_damage"):
		body.take_damage(1)
	queue_free()


func _on_screen_exited() -> void:
	queue_free()
