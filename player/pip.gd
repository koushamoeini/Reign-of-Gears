class_name Pip
extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)
signal died
signal special_ability_requested

# Movement tuning: adjust these three constants to change how Pip feels.
const SPEED := 260.0 # Horizontal movement speed.
const JUMP_VELOCITY := -520.0 # More negative means a higher jump.
const DASH_SPEED := 760.0 # Horizontal speed during a dash.

@export var dash_duration: float = 0.16
@export var dash_cooldown: float = 0.8

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
@onready var parry_area: Area2D = $ParryArea

var health: int
var facing_direction: float = 1.0
var is_invincible: bool = false
var bonus_jump_available: bool = false
var hit_flash_version: int = 0


func _ready() -> void:
	health = max_health
	dash_duration_timer.wait_time = dash_duration
	dash_cooldown_timer.wait_time = dash_cooldown
	invincibility_timer.wait_time = invincibility_duration
	_register_controls()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		bonus_jump_available = false

	if Input.is_action_just_pressed("pip_jump"):
		_try_jump()
	if Input.is_action_just_pressed("pip_parry"):
		_try_parry()

	var direction := Input.get_axis("pip_move_left", "pip_move_right")
	if not is_zero_approx(direction):
		facing_direction = signf(direction)
		muzzle.position.x = absf(muzzle.position.x) * facing_direction

	if Input.is_action_just_pressed("pip_dash"):
		_start_dash()

	if dash_duration_timer.time_left > 0.0:
		velocity.x = facing_direction * DASH_SPEED
	else:
		velocity.x = direction * SPEED

	if Input.is_action_just_pressed("pip_shoot"):
		shoot()
	if Input.is_action_just_pressed("pip_special"):
		special_ability_requested.emit()

	move_and_slide()


func shoot() -> void:
	var bullet := bullet_scene.instantiate()
	bullet.set("direction", Vector2(facing_direction, 0.0))
	bullet.rotation = PI if facing_direction < 0.0 else 0.0
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = muzzle.global_position
	SoundManager.play_shoot_sfx()


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
	if dash_cooldown_timer.time_left > 0.0:
		return

	dash_duration_timer.start()
	dash_cooldown_timer.start()
	SoundManager.play_dash_sfx()


func _try_jump() -> void:
	if is_on_floor():
		velocity.y = JUMP_VELOCITY
	elif bonus_jump_available:
		bonus_jump_available = false
		velocity.y = JUMP_VELOCITY


func _try_parry() -> void:
	if is_on_floor():
		return

	for area in parry_area.get_overlapping_areas():
		if area.is_in_group("pink_projectiles") and area.has_method("parry"):
			area.parry()
			bonus_jump_available = true
			velocity.y = JUMP_VELOCITY * 0.65
			break


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
	_add_key_action("pip_special", KEY_S)
	_add_key_action("pip_parry", KEY_SPACE)


func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	if not InputMap.action_has_event(action, key_event):
		InputMap.action_add_event(action, key_event)
