extends Node2D

@onready var player: Node = $Pip
@onready var boss: Node = $FurnaceGoliath
@onready var combat_hud: CombatHUD = $CombatHUD

var encounter_finished: bool = false


func _ready() -> void:
	player.connect("died", _on_player_died)
	boss.connect("died", _on_boss_died)


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
	combat_hud.show_victory()
