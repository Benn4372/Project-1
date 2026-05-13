extends Control

@onready var title_label: Label = $CenterContainer/VBoxContainer/Title
@onready var subtitle_label: Label = $CenterContainer/VBoxContainer/Subtitle

@onready var easy_button: Button = $CenterContainer/VBoxContainer/EasyRow/Button
@onready var medium_button: Button = $CenterContainer/VBoxContainer/MediumRow/Button
@onready var hard_button: Button = $CenterContainer/VBoxContainer/HardRow/Button
@onready var adaptive_button: Button = $CenterContainer/VBoxContainer/AdaptiveRow/Button
@onready var custom_button: Button = $CenterContainer/VBoxContainer/CustomRow/Button

@onready var easy_high: Label = $CenterContainer/VBoxContainer/EasyRow/HighLabel
@onready var medium_high: Label = $CenterContainer/VBoxContainer/MediumRow/HighLabel
@onready var hard_high: Label = $CenterContainer/VBoxContainer/HardRow/HighLabel
@onready var adaptive_high: Label = $CenterContainer/VBoxContainer/AdaptiveRow/HighLabel
@onready var custom_high: Label = $CenterContainer/VBoxContainer/CustomRow/HighLabel

@onready var back_button: Button = $CenterContainer/VBoxContainer/BackButton


func _ready() -> void:
	easy_button.pressed.connect(_start_game.bind(GameState.Difficulty.EASY))
	medium_button.pressed.connect(_start_game.bind(GameState.Difficulty.MEDIUM))
	hard_button.pressed.connect(_start_game.bind(GameState.Difficulty.HARD))
	adaptive_button.pressed.connect(_start_game.bind(GameState.Difficulty.ADAPTIVE))
	custom_button.pressed.connect(_open_custom_config)
	back_button.pressed.connect(_on_back_pressed)

	title_label.text = GameState.mode_name(GameState.current_mode)
	_refresh_high_scores()


func _refresh_high_scores() -> void:
	# Only Single Player saves high scores — hide the labels for Multi and Versus AI.
	var show_scores: bool = GameState.current_mode == GameState.Mode.SINGLE
	easy_high.visible = show_scores
	medium_high.visible = show_scores
	hard_high.visible = show_scores
	adaptive_high.visible = show_scores
	custom_high.visible = show_scores
	if not show_scores:
		return
	easy_high.text = "High: %d" % GameState.get_high_score(GameState.Difficulty.EASY)
	medium_high.text = "High: %d" % GameState.get_high_score(GameState.Difficulty.MEDIUM)
	hard_high.text = "High: %d" % GameState.get_high_score(GameState.Difficulty.HARD)
	adaptive_high.text = "High: %d" % GameState.get_high_score(GameState.Difficulty.ADAPTIVE)
	custom_high.text = "High: %d" % GameState.get_high_score(GameState.Difficulty.CUSTOM)


func _start_game(difficulty: int) -> void:
	GameState.current_difficulty = difficulty
	get_tree().change_scene_to_file("res://main.tscn")


func _open_custom_config() -> void:
	GameState.current_difficulty = GameState.Difficulty.CUSTOM
	get_tree().change_scene_to_file("res://custom_config.tscn")


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://home.tscn")
