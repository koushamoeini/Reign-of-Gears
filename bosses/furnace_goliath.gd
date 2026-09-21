class_name FurnaceGoliath
extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)
signal phase_changed(new_phase: int)
signal died

enum State { IDLE, SHOOTING, DASH_ATTACK }

const MAX_HEALTH := 250
const PHASE_TWO_THRESHOLD := 170
const PHASE_THREE_THRESHOLD := 70
const IDLE_DURATION := 0.6
const PHASE_TRANSITION_SHIELD_DURATION := 0.5
const PHASE_ONE_SPREAD_ANGLE := 0.22
const PHASE_TWO_BURST_COUNT := 3
const PHASE_TWO_BURST_INTERVAL := 0.16
const PHASE_THREE_STREAM_INTERVAL := 0.85
const PHASE_THREE_FIRE_RATE_MULTIPLIER := 1.5
const DASH_SPEED := 820.0
const DASH_DURATION := 0.65
const SPRITE_IDLE := Rect2(20, 500, 180, 190)
const SPRITE_TELEGRAPH := Rect2(820, 500, 180, 190)
const SPRITE_SHOOT := Rect2(20, 680, 180, 190)
const SPRITE_DASH := Rect2(1210, 500, 180, 190)
const SPRITE_RAGE := Rect2(850, 680, 180, 190)
const SPRITE_DAMAGE := Rect2(330, 834, 180, 190)
const SPRITE_DEATH := Rect2(510, 834, 180, 190)

@export var fireball_scene: PackedScene = preload("res://bosses/fireball.tscn")

@onready var muzzle: Marker2D = $Muzzle
@onready var phase_shift_sfx: AudioStreamPlayer2D = $PhaseShiftSfx
@onready var hit_flash: Polygon2D = $HitFlash
@onready var telegraph_flash: Polygon2D = $TelegraphFlash
@onready var rage_glow: Polygon2D = $RageGlow
@onready var transition_shield: Polygon2D = $TransitionShield
@onready var rage_fire_timer: Timer = $RageFireTimer
@onready var damage_sparks: GPUParticles2D = $DamageSparks
@onready var victory_explosion: GPUParticles2D = $VictoryExplosion
@onready var victory_explosion_wide: GPUParticles2D = $VictoryExplosionWide
@onready var victory_explosion_core: GPUParticles2D = $VictoryExplosionCore
@onready var sprite_art: Sprite2D = $SpriteArt

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
var is_transition_shield_active: bool = false
var rage_stream_shot_index: int = 0


func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D
	_change_state(State.IDLE)


func _physics_process(delta: float) -> void:
	_face_player()
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
	if is_transition_shield_active or amount <= 0 or health <= 0:
		return

	health = maxi(health - amount, 0)
	health_changed.emit(health, MAX_HEALTH)
	SoundManager.play_hit_sfx()
	_show_hit_flash()
	damage_sparks.restart()

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
	transition_shield.hide()
	rage_fire_timer.stop()
	sprite_art.region_rect = SPRITE_DEATH
	_spawn_explosion()

	var fade_tween := create_tween()
	fade_tween.tween_interval(1.25)
	fade_tween.tween_property(self, "modulate:a", 0.0, 0.7)
	await get_tree().create_timer(2.0).timeout
	died.emit()
	queue_free()


func _spawn_explosion() -> void:
	SoundManager.play_boss_explosion_sfx()
	victory_explosion.restart()
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
	await get_tree().create_timer(0.55).timeout
	victory_explosion_wide.restart()
	SoundManager.play_boss_explosion_sfx()
	await get_tree().create_timer(0.55).timeout
	victory_explosion_core.restart()
	SoundManager.play_boss_explosion_sfx()


func _choose_attack() -> void:
	if is_telegraphing:
		return

	var next_state: State
	if phase == 3:
		next_state = State.DASH_ATTACK
	elif phase >= 2 and next_attack_is_dash:
		next_attack_is_dash = false
		next_state = State.DASH_ATTACK
	else:
		next_attack_is_dash = phase >= 2
		next_state = State.SHOOTING
	_telegraph_attack(next_state)


func _telegraph_attack(next_state: State) -> void:
	is_telegraphing = true
	state_time_remaining = 999.0
	sprite_art.region_rect = SPRITE_TELEGRAPH
	var telegraph_tween := create_tween()
	telegraph_tween.tween_property(sprite_art, "scale", Vector2(1.22, 1.22), 0.22)
	telegraph_tween.tween_property(sprite_art, "scale", Vector2(1.15, 1.15), 0.22)
	await get_tree().create_timer(0.5).timeout
	is_telegraphing = false
	if health > 0:
		_change_state(next_state)


func _show_hit_flash() -> void:
	hit_flash_version += 1
	var current_version := hit_flash_version
	sprite_art.region_rect = SPRITE_DAMAGE
	await get_tree().create_timer(0.1).timeout
	if current_version == hit_flash_version and health > 0:
		_set_state_sprite()


func _change_state(new_state: State) -> void:
	state = new_state

	match state:
		State.IDLE:
			state_time_remaining = IDLE_DURATION
			_set_state_sprite()
		State.SHOOTING:
			sprite_art.region_rect = SPRITE_SHOOT
			_shooting_sequence()
		State.DASH_ATTACK:
			sprite_art.region_rect = SPRITE_RAGE if phase == 3 else SPRITE_DASH
			state_time_remaining = DASH_DURATION
			dash_direction = _direction_to_player()


func _shooting_sequence() -> void:
	if phase == 1:
		_fire_spread_shot()
		await get_tree().create_timer(0.22).timeout
	elif phase == 2:
		for burst_index in PHASE_TWO_BURST_COUNT:
			if state != State.SHOOTING or not is_instance_valid(player):
				break
			_fire_at_player()
			if burst_index < PHASE_TWO_BURST_COUNT - 1:
				await get_tree().create_timer(PHASE_TWO_BURST_INTERVAL).timeout
		await get_tree().create_timer(0.18).timeout

	if state == State.SHOOTING:
		_change_state(State.IDLE)


func _fire_at_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		return

	_spawn_fireball(muzzle.global_position.direction_to(player.global_position))


func _fire_spread_shot() -> void:
	if not is_instance_valid(player):
		return
	var target_direction := muzzle.global_position.direction_to(player.global_position)
	for spread_offset in [-PHASE_ONE_SPREAD_ANGLE, 0.0, PHASE_ONE_SPREAD_ANGLE]:
		_spawn_fireball(target_direction.rotated(spread_offset))


func _spawn_fireball(direction: Vector2, blue_override: int = -1) -> void:
	var fireball := fireball_scene.instantiate()
	var is_blue := randf() < 0.2 if blue_override == -1 else blue_override == 1
	fireball.set("direction", direction)
	fireball.set("is_absorbable", is_blue)
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
		sprite_art.region_rect = SPRITE_RAGE
		rage_fire_timer.start(PHASE_THREE_STREAM_INTERVAL)
	phase_changed.emit(phase)
	_start_transition_shield()


func _start_rage_glow() -> void:
	_set_state_sprite()


func _start_transition_shield() -> void:
	is_transition_shield_active = true
	await get_tree().create_timer(PHASE_TRANSITION_SHIELD_DURATION).timeout
	is_transition_shield_active = false


func _set_state_sprite() -> void:
	if phase == 3:
		sprite_art.region_rect = SPRITE_RAGE
	elif state == State.SHOOTING:
		sprite_art.region_rect = SPRITE_SHOOT
	elif state == State.DASH_ATTACK:
		sprite_art.region_rect = SPRITE_DASH
	else:
		sprite_art.region_rect = SPRITE_IDLE


func _face_player() -> void:
	if not is_instance_valid(player):
		return
	var faces_left := player.global_position.x < global_position.x
	sprite_art.flip_h = faces_left
	muzzle.position.x = -absf(muzzle.position.x) if faces_left else absf(muzzle.position.x)


func _on_rage_fire_timer_timeout() -> void:
	if phase != 3 or not is_instance_valid(player):
		return
	var target_direction := muzzle.global_position.direction_to(player.global_position)
	# Two electric-blue shots for every orange shot maintain Overclock openings.
	var is_blue := rage_stream_shot_index % 3 != 0
	_spawn_fireball(target_direction, 1 if is_blue else 0)
	rage_stream_shot_index += 1


func _current_shot_interval() -> float:
	return PHASE_TWO_BURST_INTERVAL / PHASE_THREE_FIRE_RATE_MULTIPLIER if phase == 3 else PHASE_TWO_BURST_INTERVAL


func get_max_health() -> int:
	return MAX_HEALTH


func _damage_dash_collisions() -> void:
	for collision_index in get_slide_collision_count():
		var collider := get_slide_collision(collision_index).get_collider()
		if collider is Node and collider.is_in_group("player") and collider.has_method("take_damage"):
			collider.take_damage(1)
