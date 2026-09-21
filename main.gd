extends Node2D

@onready var player: Node = $Pip
@onready var boss: Node = $FurnaceGoliath
@onready var combat_hud: CombatHUD = $CombatHUD

var encounter_finished: bool = false


func _ready() -> void:
	player.connect("died", _on_player_died)
	boss.connect("died", _on_boss_died)
	combat_hud.next_boss_requested.connect(_on_next_boss_requested)


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
	_shake_arena()
	combat_hud.show_victory()


func _on_next_boss_requested() -> void:
	# Replace this reload with change_scene_to_file() when boss two is ready.
	get_tree().reload_current_scene()


func _shake_arena() -> void:
	var original_position := position
	var shake_tween := create_tween()
	for shake_index in 10:
		var strength := 12.0 * (1.0 - float(shake_index) / 10.0)
		var offset := Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		shake_tween.tween_property(self, "position", original_position + offset, 0.035)
	shake_tween.tween_property(self, "position", original_position, 0.05)
