extends Node

const SHOOT_STREAM: AudioStream = preload("res://audio/shoot.wav")
const HIT_STREAM: AudioStream = preload("res://audio/player_hit.wav")
const DASH_STREAM: AudioStream = preload("res://audio/dash.wav")

var _shoot_player: AudioStreamPlayer
var _hit_player: AudioStreamPlayer
var _dash_player: AudioStreamPlayer
var _sfx_volume: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_shoot_player = _create_player(SHOOT_STREAM, -6.0, 4)
	_hit_player = _create_player(HIT_STREAM, -4.0, 4)
	_dash_player = _create_player(DASH_STREAM, -5.0, 2)


func play_shoot_sfx() -> void:
	_shoot_player.play()


func play_hit_sfx() -> void:
	_hit_player.play()


func play_dash_sfx() -> void:
	_dash_player.play()


func set_sfx_volume(volume: float) -> void:
	_sfx_volume = clampf(volume, 0.0, 1.0)
	_shoot_player.volume_db = -6.0 + linear_to_db(maxf(_sfx_volume, 0.001))
	_hit_player.volume_db = -4.0 + linear_to_db(maxf(_sfx_volume, 0.001))
	_dash_player.volume_db = -5.0 + linear_to_db(maxf(_sfx_volume, 0.001))


func _create_player(stream: AudioStream, volume_db: float, polyphony: int) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.max_polyphony = polyphony
	add_child(player)
	return player
