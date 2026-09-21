extends Node2D

@onready var player: Node = $Pip
@onready var boss: Node = $FurnaceGoliath
@onready var stage_hazards: StageHazardController = $StageHazards
@onready var combat_hud: CombatHUD = $CombatHUD
@onready var background_music: AudioStreamPlayer = $AudioHooks/BackgroundMusic
@onready var victory_sound: AudioStreamPlayer = $AudioHooks/VictorySound
@onready var brightness_modulate: CanvasModulate = $BrightnessModulate

var encounter_finished: bool = false
var arena_origin: Vector2
var shake_tween: Tween


func _ready() -> void:
	arena_origin = position
	player.connect("died", _on_player_died)
	player.connect("health_changed", _on_player_health_changed)
	boss.connect("died", _on_boss_died)
	boss.connect("phase_changed", _on_boss_phase_changed)
	combat_hud.start_game_requested.connect(_on_start_game_requested)
	combat_hud.brightness_changed.connect(_on_brightness_changed)
	combat_hud.master_volume_changed.connect(_on_master_volume_changed)
	combat_hud.sfx_volume_changed.connect(_on_sfx_volume_changed)

	var start_immediately := get_tree().has_meta("start_immediately") and bool(get_tree().get_meta("start_immediately"))
	if get_tree().has_meta("start_immediately"):
		get_tree().remove_meta("start_immediately")
	if start_immediately:
		_begin_fight()
	else:
		combat_hud.show_main_menu()
		get_tree().paused = true


func _on_player_health_changed(_current_health: int, _max_health: int) -> void:
	_shake_arena(7.0, 0.22)


func _on_boss_phase_changed(_new_phase: int) -> void:
	_shake_arena(13.0, 0.45)
	stage_hazards.set_phase(_new_phase)


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
	stage_hazards.stop_all()
	_shake_arena(12.0, 0.4)
	if victory_sound.stream:
		victory_sound.play()
	combat_hud.show_victory()


func _on_start_game_requested() -> void:
	_begin_fight()


func _begin_fight() -> void:
	combat_hud.hide_main_menu()
	get_tree().paused = false
	if background_music.stream and not background_music.playing:
		background_music.play()


func _on_brightness_changed(value: float) -> void:
	brightness_modulate.color = Color(value, value, value, 1.0)


func _on_master_volume_changed(value: float) -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(value, 0.001)))


func _on_sfx_volume_changed(value: float) -> void:
	SoundManager.set_sfx_volume(value)
	boss.get_node("PhaseShiftSfx").volume_db = -3.0 + linear_to_db(maxf(value, 0.001))
	$AudioHooks/ShootSound.volume_db = -6.0 + linear_to_db(maxf(value, 0.001))
	$AudioHooks/HitSound.volume_db = -4.0 + linear_to_db(maxf(value, 0.001))
	$AudioHooks/DashSound.volume_db = -5.0 + linear_to_db(maxf(value, 0.001))
	$AudioHooks/VictorySound.volume_db = linear_to_db(maxf(value, 0.001))


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
