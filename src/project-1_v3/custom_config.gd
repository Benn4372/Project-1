extends Control

@onready var player_speed_spin: SpinBox = $CenterContainer/VBoxContainer/PlayerSpeedRow/SpinBox
@onready var hazard_speed_spin: SpinBox = $CenterContainer/VBoxContainer/HazardSpeedRow/SpinBox
@onready var red_count_spin: SpinBox = $CenterContainer/VBoxContainer/RedCountRow/SpinBox

@onready var increase_reds_check: CheckBox = $CenterContainer/VBoxContainer/IncreaseRedsCheck
@onready var increase_reds_group: VBoxContainer = $CenterContainer/VBoxContainer/IncreaseRedsGroup
@onready var red_interval_spin: SpinBox = $CenterContainer/VBoxContainer/IncreaseRedsGroup/RedIntervalRow/SpinBox
@onready var red_cap_spin: SpinBox = $CenterContainer/VBoxContainer/IncreaseRedsGroup/RedCapRow/SpinBox

@onready var use_purples_check: CheckBox = $CenterContainer/VBoxContainer/UsePurplesCheck
@onready var use_purples_group: VBoxContainer = $CenterContainer/VBoxContainer/UsePurplesGroup
@onready var purple_start_spin: SpinBox = $CenterContainer/VBoxContainer/UsePurplesGroup/PurpleStartRow/SpinBox
@onready var purple_interval_spin: SpinBox = $CenterContainer/VBoxContainer/UsePurplesGroup/PurpleIntervalRow/SpinBox
@onready var purple_cap_spin: SpinBox = $CenterContainer/VBoxContainer/UsePurplesGroup/PurpleCapRow/SpinBox

@onready var speed_scaling_check: CheckBox = $CenterContainer/VBoxContainer/SpeedScalingCheck

@onready var back_button: Button = $CenterContainer/VBoxContainer/ButtonRow/BackButton
@onready var start_button: Button = $CenterContainer/VBoxContainer/ButtonRow/StartButton


const HAZARD_LIMIT: int = 50


func _ready() -> void:
	_configure_spin(player_speed_spin, 1, 999999.0, true)
	_configure_spin(hazard_speed_spin, 1, 999999.0, true)
	_configure_spin(red_count_spin, 0, float(HAZARD_LIMIT), false)
	_configure_spin(red_interval_spin, 1, 999999.0, true)
	_configure_spin(red_cap_spin, 0, float(HAZARD_LIMIT), false)
	_configure_spin(purple_start_spin, 0, 999999.0, true)
	_configure_spin(purple_interval_spin, 1, 999999.0, true)
	_configure_spin(purple_cap_spin, 1, float(HAZARD_LIMIT), false)

	_load_from_state()
	increase_reds_check.toggled.connect(_on_increase_reds_toggled)
	use_purples_check.toggled.connect(_on_use_purples_toggled)
	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_pressed)
	_refresh_visibility()


func _configure_spin(spin: SpinBox, min_value: float, max_value: float, allow_greater: bool) -> void:
	spin.min_value = min_value
	spin.max_value = max_value
	spin.allow_greater = allow_greater
	spin.step = 1.0
	spin.rounded = true


func _load_from_state() -> void:
	var c: Dictionary = GameState.custom_config
	player_speed_spin.value = float(c["player_speed"])
	hazard_speed_spin.value = float(c["hazard_speed"])
	red_count_spin.value = float(c["red_count"])
	increase_reds_check.button_pressed = bool(c["increase_reds"])
	red_interval_spin.value = float(c["red_increment_interval"])
	red_cap_spin.value = float(c["red_cap"])
	use_purples_check.button_pressed = bool(c["use_purples"])
	purple_start_spin.value = float(c["purple_start_score"])
	purple_interval_spin.value = float(c["purple_increment_interval"])
	purple_cap_spin.value = float(c["purple_cap"])
	speed_scaling_check.button_pressed = bool(c["speed_scaling"])


func _refresh_visibility() -> void:
	increase_reds_group.visible = increase_reds_check.button_pressed
	use_purples_group.visible = use_purples_check.button_pressed


func _on_increase_reds_toggled(_pressed: bool) -> void:
	_refresh_visibility()


func _on_use_purples_toggled(_pressed: bool) -> void:
	_refresh_visibility()


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://difficulty_select.tscn")


func _on_start_pressed() -> void:
	GameState.custom_config = {
		"player_speed": maxf(1.0, player_speed_spin.value),
		"hazard_speed": maxf(1.0, hazard_speed_spin.value),
		"red_count": clampi(int(red_count_spin.value), 0, HAZARD_LIMIT),
		"increase_reds": increase_reds_check.button_pressed,
		"red_increment_interval": maxi(1, int(red_interval_spin.value)),
		"red_cap": clampi(int(red_cap_spin.value), 0, HAZARD_LIMIT),
		"use_purples": use_purples_check.button_pressed,
		"purple_start_score": maxi(0, int(purple_start_spin.value)),
		"purple_increment_interval": maxi(1, int(purple_interval_spin.value)),
		"purple_cap": clampi(int(purple_cap_spin.value), 1, HAZARD_LIMIT),
		"speed_scaling": speed_scaling_check.button_pressed,
	}
	GameState.current_difficulty = GameState.Difficulty.CUSTOM
	get_tree().change_scene_to_file("res://main.tscn")
