class_name CombatHUD
extends CanvasLayer

@onready var player_health_label: Label = $Interface/PlayerHealth
@onready var boss_name_label: Label = $Interface/BossName
@onready var boss_health_bar: ProgressBar = $Interface/BossHealthBar
@onready var boss_health_label: Label = $Interface/BossHealthValue

var player: Node
var boss: Node


func _ready() -> void:
	# Waiting one frame ensures every combatant has completed its own _ready().
	call_deferred("_connect_combatants")


func _connect_combatants() -> void:
	player = get_tree().get_first_node_in_group("player")
	boss = get_tree().get_first_node_in_group("bosses")

	if is_instance_valid(player):
		player.connect("health_changed", _on_player_health_changed)
		player.connect("died", _on_player_died)
		_on_player_health_changed(player.get("health"), player.get("max_health"))

	if is_instance_valid(boss):
		boss.connect("health_changed", _on_boss_health_changed)
		boss.connect("phase_changed", _on_boss_phase_changed)
		boss.connect("died", _on_boss_died)
		_on_boss_health_changed(boss.get("health"), 50)


func _on_player_health_changed(current_health: int, max_health: int) -> void:
	player_health_label.text = "PIP  HP  %d / %d" % [current_health, max_health]


func _on_player_died() -> void:
	player_health_label.text = "PIP  HP  0 / 3"


func _on_boss_health_changed(current_health: int, max_health: int) -> void:
	boss_health_bar.max_value = max_health
	boss_health_bar.value = current_health
	boss_health_label.text = "%d / %d" % [current_health, max_health]


func _on_boss_phase_changed(new_phase: int) -> void:
	boss_name_label.text = "FURNACE GOLIATH  //  PHASE %d" % new_phase


func _on_boss_died() -> void:
	boss_health_bar.value = 0
	boss_health_label.text = "DEFEATED"
