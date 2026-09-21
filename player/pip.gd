class_name Pip
extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)
signal died

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

var health: int
var facing_direction: float = 1.0
var is_invincible: bool = false


func _ready() -> void:
	health = max_health
	dash_duration_timer.wait_time = dash_duration
	dash_cooldown_timer.wait_time = dash_cooldown
	invincibility_timer.wait_time = invincibility_duration
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
		velocity.x = direction * SPEED

	if Input.is_action_just_pressed("pip_shoot"):
		shoot()

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


func _on_flash_timer_timeout() -> void:
	modulate.a = 0.35 if is_equal_approx(modulate.a, 1.0) else 1.0


func _on_invincibility_timer_timeout() -> void:
	is_invincible = false
	flash_timer.stop()
	modulate.a = 1.0


func _register_controls() -> void:
	_add_key_action("pip_move_left", KEY_LEFT)
	_add_key_action("pip_move_right", KEY_RIGHT)
	_add_key_action("pip_jump", KEY_SPACE)
	_add_key_action("pip_dash", KEY_SHIFT)
	_add_key_action("pip_shoot", KEY_Z)

	var mouse_event := InputEventMouseButton.new()
	mouse_event.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("pip_shoot", mouse_event)


func _add_key_action(action: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	InputMap.action_add_event(action, key_event)
