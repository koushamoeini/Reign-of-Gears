class_name StageHazardController
extends Node2D

@export var steam_pipe_scene: PackedScene = preload("res://hazards/steam_pipe.tscn")

@onready var pipe_timer: Timer = $PipeTimer
@onready var pressure_hazards: Node2D = $PressureHazards
@onready var left_collision: CollisionShape2D = $PressureHazards/LeftPressure/CollisionShape2D
@onready var right_collision: CollisionShape2D = $PressureHazards/RightPressure/CollisionShape2D

var current_phase: int = 1


func _process(_delta: float) -> void:
	if current_phase >= 3:
		pressure_hazards.modulate.a = 0.72 + 0.2 * sin(Time.get_ticks_msec() * 0.014)


func set_phase(new_phase: int) -> void:
	current_phase = new_phase
	if current_phase >= 2 and pipe_timer.is_stopped():
		call_deferred("_spawn_pipe_warning")
		pipe_timer.start()
	if current_phase >= 3:
		_enable_pressure_hazards()


func _spawn_pipe_warning() -> void:
	if current_phase < 2:
		return
	var pipe := steam_pipe_scene.instantiate()
	add_child(pipe)
	pipe.position = Vector2(randf_range(150.0, 1130.0), 0.0)


func _on_pipe_timer_timeout() -> void:
	call_deferred("_spawn_pipe_warning")


func _enable_pressure_hazards() -> void:
	pressure_hazards.show()
	left_collision.set_deferred("disabled", false)
	right_collision.set_deferred("disabled", false)


func stop_all() -> void:
	current_phase = 1
	pipe_timer.stop()
	pressure_hazards.hide()
	left_collision.set_deferred("disabled", true)
	right_collision.set_deferred("disabled", true)
	for child in get_children():
		if child is FallingSteamPipe:
			child.queue_free()


func _on_pressure_body_entered(body: Node) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
