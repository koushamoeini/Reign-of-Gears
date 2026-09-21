class_name FurnaceFireball
extends Area2D

@export var speed: float = 360.0
@export var damage: int = 1

var direction: Vector2 = Vector2.LEFT
var is_parryable: bool = false
var was_parried: bool = false


func _ready() -> void:
	if is_parryable:
		add_to_group("pink_projectiles")
		$Glow.color = Color(1.0, 0.12, 0.62, 1.0)
		$Core.color = Color(1.0, 0.76, 0.9, 1.0)


func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta


func _on_body_entered(body: Node) -> void:
	if was_parried or not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()


func _on_screen_exited() -> void:
	queue_free()


func parry() -> void:
	if not is_parryable or was_parried:
		return
	was_parried = true
	monitoring = false
	$CollisionShape2D.set_deferred("disabled", true)
	queue_free()
