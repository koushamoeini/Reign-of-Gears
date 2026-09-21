class_name FallingSteamPipe
extends Area2D

@export var warning_duration: float = 0.8
@export var fall_speed: float = 520.0

@onready var warning: Node2D = $Warning
@onready var pipe_visual: Polygon2D = $PipeVisual
@onready var pipe_sprite: Sprite2D = $PipeSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var is_falling: bool = false


func _ready() -> void:
	$WarningTimer.start(warning_duration)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if not is_falling:
		warning.modulate.a = 0.35 + 0.25 * sin(Time.get_ticks_msec() * 0.018)
		return

	position.y += fall_speed * delta
	if position.y > 830.0:
		queue_free()


func _on_warning_timer_timeout() -> void:
	warning.hide()
	pipe_visual.show()
	pipe_sprite.show()
	collision_shape.set_deferred("disabled", false)
	monitoring = true
	is_falling = true


func _on_body_entered(body: Node) -> void:
	if not is_falling or not body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(1)
	queue_free()
