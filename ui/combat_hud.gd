class_name CombatHUD
extends CanvasLayer

signal start_game_requested
signal brightness_changed(value: float)
signal master_volume_changed(value: float)
signal sfx_volume_changed(value: float)

@onready var player_health_label: Label = $Interface/PlayerHealth
@onready var overclock_label: Label = $Interface/OverclockLabel
@onready var overclock_bar: ProgressBar = $Interface/OverclockBar
@onready var overclock_value: Label = $Interface/OverclockValue
@onready var boss_name_label: Label = $Interface/BossName
@onready var boss_health_bar: ProgressBar = $Interface/BossHealthBar
@onready var boss_health_label: Label = $Interface/BossHealthValue
@onready var result_overlay: ColorRect = $Interface/ResultOverlay
@onready var result_title: Label = $Interface/ResultOverlay/ResultTitle
@onready var result_detail: Label = $Interface/ResultOverlay/ResultDetail
@onready var retry_button: Button = $Interface/ResultOverlay/RetryButton
@onready var main_menu_button: Button = $Interface/ResultOverlay/MainMenuButton
@onready var main_menu_overlay: ColorRect = $Interface/MainMenuOverlay
@onready var start_button: Button = $Interface/MainMenuOverlay/StartButton
@onready var settings_panel: ColorRect = $Interface/MainMenuOverlay/SettingsPanel

var rebind_buttons: Dictionary = {}
var rebinding_action: StringName

var player: Node
var boss: Node
var is_game_over: bool = false


func _ready() -> void:
	_register_rebind_buttons()
	# Waiting one frame ensures every combatant has completed its own _ready().
	call_deferred("_connect_combatants")


func _connect_combatants() -> void:
	player = get_tree().get_first_node_in_group("player")
	boss = get_tree().get_first_node_in_group("bosses")

	if is_instance_valid(player):
		player.connect("health_changed", _on_player_health_changed)
		player.connect("overclock_changed", _on_overclock_changed)
		player.connect("overclock_mode_changed", _on_overclock_mode_changed)
		player.connect("died", _on_player_died)
		_on_player_health_changed(player.get("health"), player.get("max_health"))
		_on_overclock_changed(player.get("overclock_meter"), 100)

	if is_instance_valid(boss):
		boss.connect("health_changed", _on_boss_health_changed)
		boss.connect("phase_changed", _on_boss_phase_changed)
		boss.connect("died", _on_boss_died)
		_on_boss_health_changed(boss.get("health"), boss.call("get_max_health"))


func _on_player_health_changed(current_health: int, max_health: int) -> void:
	player_health_label.text = "HP: %d/%d" % [current_health, max_health]


func _on_player_died() -> void:
	player_health_label.text = "HP: 0/3"


func _on_overclock_changed(current_value: int, max_value: int) -> void:
	overclock_bar.max_value = max_value
	overclock_bar.value = current_value
	overclock_value.text = "%d / %d" % [current_value, max_value]


func _on_overclock_mode_changed(is_active: bool) -> void:
	overclock_label.text = "OVERCLOCK  //  ACTIVE" if is_active else "OVERCLOCK"
	overclock_value.text = "5.0s" if is_active else "%d / 100" % overclock_bar.value


func _on_boss_health_changed(current_health: int, max_health: int) -> void:
	boss_health_bar.max_value = max_health
	boss_health_bar.value = current_health
	boss_health_label.text = "%d / %d" % [current_health, max_health]


func _on_boss_phase_changed(new_phase: int) -> void:
	boss_name_label.text = "FURNACE GOLIATH  //  PHASE %d" % new_phase


func _on_boss_died() -> void:
	boss_health_bar.value = 0
	boss_health_label.text = "DEFEATED"


func show_main_menu() -> void:
	result_overlay.hide()
	main_menu_overlay.show()
	start_button.grab_focus()


func hide_main_menu() -> void:
	main_menu_overlay.hide()


func _on_settings_button_pressed() -> void:
	_refresh_binding_buttons()
	settings_panel.show()


func _on_close_settings_button_pressed() -> void:
	rebinding_action = &""
	settings_panel.hide()


func _on_brightness_slider_value_changed(value: float) -> void:
	brightness_changed.emit(value)


func _on_master_volume_slider_value_changed(value: float) -> void:
	master_volume_changed.emit(value)


func _on_sfx_volume_slider_value_changed(value: float) -> void:
	sfx_volume_changed.emit(value)


func _register_rebind_buttons() -> void:
	rebind_buttons = {
		&"pip_move_left": $Interface/MainMenuOverlay/SettingsPanel/MoveLeftButton,
		&"pip_move_right": $Interface/MainMenuOverlay/SettingsPanel/MoveRightButton,
		&"pip_dash": $Interface/MainMenuOverlay/SettingsPanel/DashButton,
		&"pip_jump": $Interface/MainMenuOverlay/SettingsPanel/JumpButton,
		&"pip_shoot": $Interface/MainMenuOverlay/SettingsPanel/ShootButton,
		&"pip_special": $Interface/MainMenuOverlay/SettingsPanel/SpecialButton,
	}
	_refresh_binding_buttons()


func _on_rebind_button_pressed(action: StringName) -> void:
	rebinding_action = action
	for binding_action: StringName in rebind_buttons:
		var button: Button = rebind_buttons[binding_action]
		button.text = "PRESS A KEY" if binding_action == action else _binding_button_text(binding_action)


func _on_reset_bindings_button_pressed() -> void:
	rebinding_action = &""
	Pip.reset_default_key_bindings()
	_refresh_binding_buttons()


func _refresh_binding_buttons() -> void:
	for action: StringName in rebind_buttons:
		var button: Button = rebind_buttons[action]
		button.text = _binding_button_text(action)


func _binding_button_text(action: StringName) -> String:
	var action_names := {
		&"pip_move_left": "MOVE LEFT",
		&"pip_move_right": "MOVE RIGHT",
		&"pip_dash": "DASH",
		&"pip_jump": "JUMP",
		&"pip_shoot": "SHOOT",
		&"pip_special": "OVERCLOCK",
	}
	var events := InputMap.action_get_events(action)
	var key_name := "UNBOUND"
	if not events.is_empty() and events[0] is InputEventKey:
		key_name = OS.get_keycode_string((events[0] as InputEventKey).physical_keycode)
	return "%s: %s" % [action_names.get(action, action), key_name]


func show_game_over() -> void:
	is_game_over = true
	result_title.text = "YOU CRASHED"
	result_detail.text = "Press R or retry the bounty."
	retry_button.offset_left = -75.0
	retry_button.offset_right = 75.0
	main_menu_button.hide()
	result_overlay.show()
	retry_button.grab_focus()


func show_victory() -> void:
	is_game_over = false
	result_title.text = "BOUNTY COLLECTED!"
	result_detail.text = "Furnace Goliath has been scrapped."
	retry_button.offset_left = -160.0
	retry_button.offset_right = -10.0
	main_menu_button.show()
	result_overlay.show()
	retry_button.grab_focus()


func _input(event: InputEvent) -> void:
	if settings_panel.visible and not rebinding_action.is_empty() and event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE:
			rebinding_action = &""
			_refresh_binding_buttons()
			return
		Pip.set_key_binding(rebinding_action, event.physical_keycode)
		rebinding_action = &""
		_refresh_binding_buttons()
		return

	if is_game_over and result_overlay.visible and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_R:
			get_viewport().set_input_as_handled()
			_retry_fight()


func _on_start_button_pressed() -> void:
	start_game_requested.emit()


func _on_retry_button_pressed() -> void:
	_retry_fight()


func _retry_fight() -> void:
	get_tree().paused = false
	get_tree().set_meta("start_immediately", true)
	get_tree().reload_current_scene()


func _on_main_menu_button_pressed() -> void:
	get_tree().paused = false
	if get_tree().has_meta("start_immediately"):
		get_tree().remove_meta("start_immediately")
	get_tree().reload_current_scene()
