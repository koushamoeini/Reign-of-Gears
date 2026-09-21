extends Node2D

@onready var player: Node = $Pip
@onready var boss: Node = $FurnaceGoliath
@onready var combat_hud: CombatHUD = $CombatHUD

var encounter_finished: bool = false
var arena_origin: Vector2
var shake_tween: Tween


func _ready() -> void:
	arena_origin = position
	player.connect("died", _on_player_died)
	player.connect("health_changed", _on_player_health_changed)
	boss.connect("died", _on_boss_died)
	boss.connect("phase_changed", _on_boss_phase_changed)
	combat_hud.next_boss_requested.connect(_on_next_boss_requested)


func _on_player_health_changed(_current_health: int, _max_health: int) -> void:
	_shake_arena(7.0, 0.22)


func _on_boss_phase_changed(_new_phase: int) -> void:
	_shake_arena(13.0, 0.45)


func _on_player_died() -> void:
	if encounter_finished:
		return
	encounter_finished = true
	combat_hud.show_game_over()
	get_tree().paused = true


func _on_boss_died() -> void:
	if encounter_finished:
		return
	encounter_finished = true
	_shake_arena(12.0, 0.4)
	combat_hud.show_victory()


func _on_next_boss_requested() -> void:
	# Replace this reload with change_scene_to_file() when boss two is ready.
	get_tree().reload_current_scene()


func _shake_arena(max_strength: float, duration: float) -> void:
	if shake_tween and shake_tween.is_valid():
		shake_tween.kill()
	position = arena_origin
	var shake_count := maxi(1, ceili(duration / 0.035))
	shake_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for shake_index in shake_count:
		var strength := max_strength * (1.0 - float(shake_index) / float(shake_count))
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		shake_tween.tween_property(self, "position", arena_origin + offset, 0.035)
	shake_tween.tween_property(self, "position", arena_origin, 0.05)
