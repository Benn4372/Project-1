extends CharacterBody2D

@export var speed: float = 2000.0
# Action prefix used for input: "ui" = arrow keys (default for P1 / single player),
# "p2" = WASD (for P2 in multiplayer).
@export var input_prefix: String = "ui"

# Set externally by main.gd so we can check the round-grace state.
var main_ref: Node = null
# True while the player is holding a stale direction from the previous round.
# Locks all movement until they release the key, preventing instant-deaths
# and auto-resolving rounds.
var input_locked: bool = false
var was_paused_last_frame: bool = false


func _ready() -> void:
	if GameState.current_difficulty == GameState.Difficulty.CUSTOM:
		speed = float(GameState.custom_config["player_speed"])


func _physics_process(_delta: float) -> void:
	var input_direction: Vector2 = Input.get_vector(
		input_prefix + "_left",
		input_prefix + "_right",
		input_prefix + "_up",
		input_prefix + "_down"
	)
	var pressing: bool = input_direction != Vector2.ZERO
	var paused: bool = main_ref != null and main_ref.is_hazard_movement_paused

	if paused:
		# Lock only on the transition into paused state, and only if a key was already held.
		# Fresh presses during grace (e.g., the first key press of the game) are not locked.
		if not was_paused_last_frame and pressing:
			input_locked = true
		# Releasing during grace clears the lock so the next press is fresh.
		if input_locked and not pressing:
			input_locked = false
		velocity = Vector2.ZERO
		was_paused_last_frame = true
		return

	was_paused_last_frame = false

	if input_locked:
		# Must release before fresh input counts.
		if not pressing:
			input_locked = false
		velocity = Vector2.ZERO
		move_and_slide()
		return

	velocity = input_direction.normalized() * speed
	move_and_slide()
