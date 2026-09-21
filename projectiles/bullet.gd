class_name PipBullet
extends Area2D

@export var speed: float = 700.0
@export var lifetime: float = 2.0
@export var damage: int = 1

var direction: Vector2 = Vector2.RIGHT


func _ready() -> void:
	$Lifetime.wait_time = lifetime
	$Lifetime.start()
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()
