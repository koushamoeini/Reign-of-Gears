class_name FurnaceFireball
extends Area2D

@export var speed: float = 468.0
@export var damage: int = 1

var direction: Vector2 = Vector2.LEFT
var is_absorbable: bool = false
var was_absorbed: bool = false


func _ready() -> void:
	if is_absorbable:
		add_to_group("blue_projectiles")
		$Aura.show()
		$SpriteArt.region_rect = Rect2(555, 805, 215, 155)


func _physics_process(delta: float) -> void:
	global_position += direction.normalized() * speed * delta


func _on_body_entered(body: Node) -> void:
	if was_absorbed or not body.is_in_group("player"):
		return
	if is_absorbable and body.has_method("try_absorb_projectile") and body.try_absorb_projectile(self):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage)
	queue_free()


func _on_screen_exited() -> void:
	queue_free()


func absorb() -> bool:
	if not is_absorbable or was_absorbed:
		return false
	was_absorbed = true
	monitoring = false
	$CollisionShape2D.set_deferred("disabled", true)
	queue_free()
	return true
