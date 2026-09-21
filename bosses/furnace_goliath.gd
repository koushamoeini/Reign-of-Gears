class_name FurnaceGoliath
extends CharacterBody2D

signal health_changed(current_health: int, max_health: int)
signal phase_changed(new_phase: int)
signal died

enum State { IDLE, SHOOTING, DASH_ATTACK }

const MAX_HEALTH := 50
const PHASE_TWO_THRESHOLD := 25
const IDLE_DURATION := 2.0
const SHOT_COUNT := 3
const SHOT_INTERVAL := 0.4
const DASH_SPEED := 820.0
const DASH_DURATION := 0.65

@export var fireball_scene: PackedScene = preload("res://bosses/fireball.tscn")

@onready var muzzle: Marker2D = $Muzzle

var health: int = MAX_HEALTH
var phase: int = 1
var state: State = State.IDLE
var player: Node2D
var state_time_remaining: float = IDLE_DURATION
var dash_direction: float = -1.0
var next_attack_is_dash: bool = false


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

	if phase == 1 and health < PHASE_TWO_THRESHOLD:
		phase = 2
		next_attack_is_dash = true
		phase_changed.emit(phase)

	if health == 0:
		died.emit()
		queue_free()


func _choose_attack() -> void:
	if phase == 2 and next_attack_is_dash:
		next_attack_is_dash = false
		_change_state(State.DASH_ATTACK)
	else:
		next_attack_is_dash = phase == 2
		_change_state(State.SHOOTING)


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
			await get_tree().create_timer(SHOT_INTERVAL).timeout

	if state == State.SHOOTING:
		_change_state(State.IDLE)


func _fire_at_player() -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node2D
	if not is_instance_valid(player):
		return

	var fireball := fireball_scene.instantiate()
	fireball.set("direction", muzzle.global_position.direction_to(player.global_position))
	get_tree().current_scene.add_child(fireball)
	fireball.global_position = muzzle.global_position


func _direction_to_player() -> float:
	if is_instance_valid(player):
		var horizontal_distance := player.global_position.x - global_position.x
		if not is_zero_approx(horizontal_distance):
			return signf(horizontal_distance)
	return -1.0


func _damage_dash_collisions() -> void:
	for collision_index in get_slide_collision_count():
		var collider := get_slide_collision(collision_index).get_collider()
		if collider is Node and collider.is_in_group("player") and collider.has_method("take_damage"):
			collider.take_damage(1)
