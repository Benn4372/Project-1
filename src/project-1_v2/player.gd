extends CharacterBody2D

@export var speed: float = 2000.0


func _ready() -> void:
	if GameState.current_difficulty == GameState.Difficulty.CUSTOM:
		speed = float(GameState.custom_config["player_speed"])


func _physics_process(_delta: float) -> void:
	var input_direction := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	velocity = input_direction.normalized() * speed
	move_and_slide()
