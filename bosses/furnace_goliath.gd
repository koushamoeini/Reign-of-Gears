class_name FurnaceGoliath
extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)
signal phase_changed(new_phase: int)
signal died

enum State { IDLE, SHOOTING, DASH_ATTACK }

const MAX_HEALTH := 50
const PHASE_TWO_THRESHOLD := 25
const PHASE_THREE_THRESHOLD := 15
const IDLE_DURATION := 2.0
const SHOT_COUNT := 3
const SHOT_INTERVAL := 0.4
const PHASE_THREE_FIRE_RATE_MULTIPLIER := 1.5
const DASH_SPEED := 820.0
const DASH_DURATION := 0.65

@export var fireball_scene: PackedScene = preload("res://bosses/fireball.tscn")

@onready var muzzle: Marker2D = $Muzzle
@onready var phase_shift_sfx: AudioStreamPlayer2D = $PhaseShiftSfx
@onready var hit_flash: Polygon2D = $HitFlash
@onready var telegraph_flash: Polygon2D = $TelegraphFlash
@onready var rage_glow: Polygon2D = $RageGlow

var health: int = MAX_HEALTH
var phase: int = 1
var state: State = State.IDLE
var player: Node2D
var state_time_remaining: float = IDLE_DURATION
var dash_direction: float = -1.0
var next_attack_is_dash: bool = false
var is_telegraphing: bool = false
var hit_flash_version: int = 0
var rage_tween: Tween


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	_change_state(State.IDLE)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	match state:
		State.IDLE:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
			state_time_remaining -= delta
			if state_time_remaining <= 0.0:
				_choose_attack()
		State.SHOOTING:
			velocity.x = move_toward(velocity.x, 0.0, 1200.0 * delta)
		State.DASH_ATTACK:
			velocity.x = dash_direction * DASH_SPEED
			state_time_remaining -= delta
			if state_time_remaining <= 0.0:
				_change_state(State.IDLE)

	move_and_slide()
	if state == State.DASH_ATTACK:
		_damage_dash_collisions()


func take_damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return

	health = maxi(health - amount, 0)
	health_changed.emit(health, MAX_HEALTH)
	SoundManager.play_hit_sfx()
	_show_hit_flash()

	_update_phase()

	if health == 0:
		_defeat()


func _defeat() -> void:
	state = State.IDLE
	velocity = Vector2.ZERO
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	hit_flash.hide()
	telegraph_flash.hide()
	rage_glow.hide()
	_spawn_explosion()
	died.emit()

	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.7)
	await get_tree().create_timer(0.75).timeout
	queue_free()


func _spawn_explosion() -> void:
	for spark_index in 16:
		var spark := Polygon2D.new()
		spark.polygon = PackedVector2Array([
			Vector2(-6, -4), Vector2(7, 0), Vector2(-6, 4)
		])
		spark.color = Color(1.0, randf_range(0.25, 0.7), 0.05, 1.0)
		spark.global_position = global_position
		spark.z_index = 10
		get_tree().current_scene.add_child(spark)

		var angle := TAU * float(spark_index) / 16.0 + randf_range(-0.12, 0.12)
		var distance := randf_range(100.0, 210.0)
		var destination := global_position + Vector2.RIGHT.rotated(angle) * distance
		var spark_tween := spark.create_tween().set_parallel(true)
		spark_tween.tween_property(spark, "global_position", destination, 0.65)
		spark_tween.tween_property(spark, "rotation", randf_range(-5.0, 5.0), 0.65)
		spark_tween.tween_property(spark, "scale", Vector2(0.2, 0.2), 0.65)
		spark_tween.tween_property(spark, "modulate:a", 0.0, 0.65)
		spark_tween.chain().tween_callback(spark.queue_free)


func _choose_attack() -> void:
	if is_telegraphing:
		return

	var next_state: State
	if phase >= 2 and next_attack_is_dash:
		next_attack_is_dash = false
		next_state = State.DASH_ATTACK
	else:
		next_attack_is_dash = phase >= 2
		next_state = State.SHOOTING
	_telegraph_attack(next_state)


func _telegraph_attack(next_state: State) -> void:
	is_telegraphing = true
	state_time_remaining = 999.0
	telegraph_flash.color = Color(1.0, 0.12, 0.08, 0.82) if next_state == State.DASH_ATTACK else Color(1.0, 0.84, 0.12, 0.82)
	telegraph_flash.show()
	await get_tree().create_timer(0.5).timeout
	telegraph_flash.hide()
	is_telegraphing = false
	if health > 0:
		_change_state(next_state)


func _show_hit_flash() -> void:
	hit_flash_version += 1
	var current_version := hit_flash_version
	hit_flash.show()
	await get_tree().create_timer(0.1).timeout
	if current_version == hit_flash_version:
		hit_flash.hide()


func _change_state(new_state: State) -> void:
	state = new_state

	match state:
		State.IDLE:
			state_time_remaining = IDLE_DURATION
		State.SHOOTING:
			_shooting_sequence()
		State.DASH_ATTACK:
			state_time_remaining = DASH_DURATION
			dash_direction = _direction_to_player()


func _shooting_sequence() -> void:
	for shot_index in SHOT_COUNT:
		if state != State.SHOOTING or not is_instance_valid(player):
			break
		_fire_at_player()
		if shot_index < SHOT_COUNT - 1:
			await get_tree().create_timer(_current_shot_interval()).timeout

	if state == State.SHOOTING:
		_change_state(State.IDLE)


func _fire_at_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		return

	var fireball := fireball_scene.instantiate()
	fireball.set("direction", muzzle.global_position.direction_to(player.global_position))
	fireball.set("is_absorbable", randf() < 0.2)
	get_tree().current_scene.add_child(fireball)
	fireball.global_position = muzzle.global_position


func _direction_to_player() -> float:
	if is_instance_valid(player):
		var horizontal_distance := player.global_position.x - global_position.x
		if not is_zero_approx(horizontal_distance):
			return signf(horizontal_distance)
	return -1.0


func _update_phase() -> void:
	if health < PHASE_THREE_THRESHOLD and phase < 3:
		_enter_phase(3)
	elif health < PHASE_TWO_THRESHOLD and phase < 2:
		_enter_phase(2)


func _enter_phase(new_phase: int) -> void:
	phase = new_phase
	next_attack_is_dash = true
	phase_shift_sfx.play()
	if phase == 3:
		_start_rage_glow()
	phase_changed.emit(phase)


func _start_rage_glow() -> void:
	rage_glow.show()
	if rage_tween and rage_tween.is_valid():
		rage_tween.kill()
	rage_tween = create_tween().set_loops()
	rage_tween.tween_property(rage_glow, "modulate:a", 0.38, 0.22)
	rage_tween.tween_property(rage_glow, "modulate:a", 0.9, 0.22)


func _current_shot_interval() -> float:
	return SHOT_INTERVAL / PHASE_THREE_FIRE_RATE_MULTIPLIER if phase == 3 else SHOT_INTERVAL


func _damage_dash_collisions() -> void:
	for collision_index in get_slide_collision_count():
		var collider := get_slide_collision(collision_index).get_collider()
		if collider is Node and collider.is_in_group("player") and collider.has_method("take_damage"):
			collider.take_damage(1)
