class_name Pip
extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)
signal died
signal overclock_changed(current_value: int, max_value: int)
signal overclock_mode_changed(is_active: bool)

# Movement tuning: adjust these three constants to change how Pip feels.
const SPEED := 260.0 # Horizontal movement speed.
const JUMP_VELOCITY := -520.0 # More negative means a higher jump.
const DASH_SPEED := 760.0 # Horizontal speed during a dash.
const OVERCLOCK_MAX := 100
const OVERCLOCK_GAIN := 25
const OVERCLOCK_DURATION := 5.0
const OVERCLOCK_SPEED_MULTIPLIER := 1.5
const OVERCLOCK_FIRE_RATE_MULTIPLIER := 2.0

@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.8
@export var fire_interval: float = 0.24

@export_group("Combat")
@export var max_health: int = 3
@export var invincibility_duration: float = 1.0
@export var bullet_scene: PackedScene = preload("res://projectiles/bullet.tscn")

@onready var muzzle: Marker2D = $Muzzle
@onready var dash_duration_timer: Timer = $DashDurationTimer
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer
@onready var invincibility_timer: Timer = $InvincibilityTimer
@onready var flash_timer: Timer = $FlashTimer
@onready var hit_flash: Polygon2D = $HitFlash
@onready var absorb_area: Area2D = $AbsorbArea
@onready var shoot_cooldown_timer: Timer = $ShootCooldownTimer
@onready var overclock_timer: Timer = $OverclockTimer
@onready var overclock_aura: Polygon2D = $OverclockAura
@onready var overclock_trail: CPUParticles2D = $OverclockTrail

var health: int
var facing_direction: float = 1.0
var is_invincible: bool = false
var hit_flash_version: int = 0
var overclock_meter: int = 0
var is_overclock_active: bool = false


func _ready() -> void:
	health = max_health
	dash_duration_timer.wait_time = dash_duration
	dash_cooldown_timer.wait_time = dash_cooldown
	invincibility_timer.wait_time = invincibility_duration
	overclock_timer.wait_time = OVERCLOCK_DURATION
	_register_controls()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("pip_jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("pip_move_left", "pip_move_right")
	if not is_zero_approx(direction):
		facing_direction = signf(direction)
		muzzle.position.x = absf(muzzle.position.x) * facing_direction

	if Input.is_action_just_pressed("pip_dash"):
		_start_dash()

	if dash_duration_timer.time_left > 0.0:
		velocity.x = facing_direction * DASH_SPEED
	else:
		velocity.x = direction * _current_move_speed()

	if Input.is_action_pressed("pip_shoot"):
		shoot()
	if Input.is_action_just_pressed("pip_special"):
		_try_activate_overclock()

	move_and_slide()
	if _is_dashing():
		_absorb_blue_projectiles()


func shoot() -> void:
	if shoot_cooldown_timer.time_left > 0.0:
		return

	var bullet := bullet_scene.instantiate()
	bullet.set("direction", Vector2(facing_direction, 0.0))
	bullet.set("is_overclocked", is_overclock_active)
	bullet.rotation = PI if facing_direction < 0.0 else 0.0
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	SoundManager.play_shoot_sfx()
	shoot_cooldown_timer.start(_current_fire_interval())


func take_damage(amount: int) -> void:
	if is_invincible or amount <= 0 or health <= 0:
		return

	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	SoundManager.play_hit_sfx()
	_show_hit_flash()

	if health == 0:
		died.emit()
		queue_free()
		return

	is_invincible = true
	invincibility_timer.start()
	flash_timer.start()


func _start_dash() -> void:
	if dash_cooldown_timer.time_left > 0.0 or _is_dashing():
		return

	dash_duration_timer.start()
	dash_cooldown_timer.start()
	SoundManager.play_dash_sfx()


func try_absorb_projectile(projectile: Area2D) -> bool:
	if not _is_dashing() or not projectile.is_in_group("blue_projectiles"):
		return false
	if not projectile.has_method("absorb") or not projectile.absorb():
		return false

	dash_cooldown_timer.stop()
	overclock_meter = mini(overclock_meter + OVERCLOCK_GAIN, OVERCLOCK_MAX)
	overclock_changed.emit(overclock_meter, OVERCLOCK_MAX)
	return true


func _absorb_blue_projectiles() -> void:
	for area in absorb_area.get_overlapping_areas():
		try_absorb_projectile(area)


func _try_activate_overclock() -> void:
	if overclock_meter < OVERCLOCK_MAX or is_overclock_active:
		return

	overclock_meter = 0
	is_overclock_active = true
	overclock_changed.emit(overclock_meter, OVERCLOCK_MAX)
	overclock_mode_changed.emit(true)
	overclock_aura.show()
	overclock_trail.emitting = true
	overclock_timer.start()


func _on_overclock_timer_timeout() -> void:
	overclock_timer.stop()
	is_overclock_active = false
	overclock_aura.hide()
	overclock_trail.emitting = false
	overclock_mode_changed.emit(false)


func _is_dashing() -> bool:
	return dash_duration_timer.time_left > 0.0


func _current_move_speed() -> float:
	return SPEED * OVERCLOCK_SPEED_MULTIPLIER if is_overclock_active else SPEED


func _current_fire_interval() -> float:
	return fire_interval / OVERCLOCK_FIRE_RATE_MULTIPLIER if is_overclock_active else fire_interval


func _show_hit_flash() -> void:
	hit_flash_version += 1
	var current_version := hit_flash_version
	hit_flash.show()
	await get_tree().create_timer(0.1).timeout
	if current_version == hit_flash_version:
		hit_flash.hide()


func _on_flash_timer_timeout() -> void:
	modulate.a = 0.35 if is_equal_approx(modulate.a, 1.0) else 1.0


func _on_invincibility_timer_timeout() -> void:
	is_invincible = false
	flash_timer.stop()
	modulate.a = 1.0


func _register_controls() -> void:
	_add_key_action("pip_move_left", KEY_LEFT)
	_add_key_action("pip_move_right", KEY_RIGHT)
	_add_key_action("pip_dash", KEY_A)
	_add_key_action("pip_jump", KEY_F)
	_add_key_action("pip_shoot", KEY_D)
	_add_key_action("pip_special", KEY_E)


func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	if not InputMap.action_has_event(action, key_event):
		InputMap.action_add_event(action, key_event)
