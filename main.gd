extends Node2D


func _ready() -> void:
	print("Reign of Gears connected to Godot successfully!")
	if DisplayServer.get_name() == "headless":
		get_tree().quit()

