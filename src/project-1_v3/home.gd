extends Control

@onready var single_button: Button = $CenterContainer/VBoxContainer/SingleButton
@onready var versus_button: Button = $CenterContainer/VBoxContainer/VersusButton
@onready var multi_button: Button = $CenterContainer/VBoxContainer/MultiButton


func _ready() -> void:
	single_button.pressed.connect(_select_mode.bind(GameState.Mode.SINGLE))
	versus_button.pressed.connect(_select_mode.bind(GameState.Mode.VERSUS_AI))
	multi_button.pressed.connect(_select_mode.bind(GameState.Mode.MULTIPLAYER))


func _select_mode(mode: int) -> void:
	GameState.current_mode = mode
	get_tree().change_scene_to_file("res://difficulty_select.tscn")
