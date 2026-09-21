class_name FallingSteamPipe
extends Area2D

@export var warning_duration: float = 0.8
@export var fall_speed: float = 520.0

@onready var warning: Node2D = $Warning
@onready var pipe_visual: Polygon2D = $PipeVisual
@onready var pipe_sprite: Sprite2D = $PipeSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_falling: bool = false
var has_exploded: bool = false


func _ready() -> void:
	$WarningTimer.start(warning_duration)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if not is_falling:
		warning.modulate.a = 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.018)
		return

	position.y += fall_speed * delta
	if position.y >= 650.0:
		_trigger_floor_explosion()


func _on_warning_timer_timeout() -> void:
	warning.hide()
	pipe_sprite.show()
	collision_shape.set_deferred("disabled", false)
	monitoring = true
	is_falling = true


func _on_body_entered(body: Node) -> void:
	if not is_falling or has_exploded:
		return
	_trigger_floor_explosion()


func _trigger_floor_explosion() -> void:
	if has_exploded:
		return
	has_exploded = true
	is_falling = false
	pipe_sprite.hide()
	velocity_warning_setup()
	await get_tree().create_timer(0.5).timeout
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(1)
	$ExplosionSprite.show()
	await get_tree().create_timer(0.18).timeout
	queue_free()


func velocity_warning_setup() -> void:
	$ExplosionZone.show()
	$ExplosionZone.scale = Vector2(0.2, 0.2)
	var zone_tween := create_tween()
	zone_tween.tween_property($ExplosionZone, "scale", Vector2.ONE, 0.16)
	var aoe_shape := CircleShape2D.new()
	aoe_shape.radius = 105.0
	collision_shape.position = Vector2.ZERO
	collision_shape.set_deferred("shape", aoe_shape)
	collision_shape.set_deferred("disabled", false)
	monitoring = true
