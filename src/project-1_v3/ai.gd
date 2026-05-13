extends CharacterBody2D

# Reactive AI — walks toward the goal, steers around nearby hazards.
# Several "human-feeling" imperfections: waits for player to move first,
# wanders around the goal instead of locking on, applies direction wobble,
# and varies speed slightly over time.

const REACTION_RADIUS: float = 260.0           # AI starts dodging from way further away
const STEERING_WEIGHT: float = 4.0             # avoidance dominates more over goal-attraction
const FINAL_APPROACH_DISTANCE: float = 100.0   # within this distance of goal, AI commits — no jitter, no panic freeze
const FINAL_REACTION_RADIUS: float = 60.0      # on final approach, only very close hazards push back
const FINAL_STEERING_WEIGHT: float = 1.0       # on final approach, goal pull dominates the dodge
const JITTER_REFRESH_INTERVAL: float = 0.8     # seconds between new goal-offset rolls
const SPEED_OSC_RATE: float = 1.8              # rad/sec — slow ebb/flow

# Difficulty-scaled imperfections — flaws shrink on harder modes so the AI
# stays competitive when the board has more hazards. Speed is also nerfed on
# easier modes so the player can simply outrun the AI in clear lanes.
const DIFFICULTY_FLAWS := {
	GameState.Difficulty.EASY: {
		"speed": 1500.0,
		"jitter_magnitude": 180.0,
		"direction_noise": 0.25,
		"speed_variance": 0.25,
		"velocity_lerp_rate": 4.0,
		"panic_count": 2,
	},
	GameState.Difficulty.MEDIUM: {
		"speed": 1750.0,
		"jitter_magnitude": 110.0,
		"direction_noise": 0.16,
		"speed_variance": 0.15,
		"velocity_lerp_rate": 6.0,
		"panic_count": 3,
	},
	GameState.Difficulty.HARD: {
		"speed": 2000.0,
		"jitter_magnitude": 40.0,
		"direction_noise": 0.06,
		"speed_variance": 0.05,
		"velocity_lerp_rate": 10.0,
		"panic_count": 5,
	},
	GameState.Difficulty.ADAPTIVE: {
		"speed": 1800.0,
		"jitter_magnitude": 110.0,
		"direction_noise": 0.16,
		"speed_variance": 0.15,
		"velocity_lerp_rate": 6.0,
		"panic_count": 3,
	},
	GameState.Difficulty.CUSTOM: {
		"speed": 1800.0,
		"jitter_magnitude": 110.0,
		"direction_noise": 0.16,
		"speed_variance": 0.15,
		"velocity_lerp_rate": 6.0,
		"panic_count": 3,
	},
}

@export var speed: float = 2000.0

# These get filled in from DIFFICULTY_FLAWS in _ready based on the current mode.
var jitter_magnitude: float = 70.0
var direction_noise_radians: float = 0.12
var speed_variance: float = 0.10
var velocity_lerp_rate: float = 8.0
var panic_hazard_count: int = 4

# Set externally by main.gd when the AI is spawned.
var goal_node: Node2D = null
var hazard_container: Node2D = null
var main_ref: Node = null
var human_player: CharacterBody2D = null

# Internal state
var has_player_moved: bool = false
var goal_offset: Vector2 = Vector2.ZERO
var jitter_timer: float = 0.0
var speed_phase: float = 0.0


func _ready() -> void:
	var flaws: Dictionary = DIFFICULTY_FLAWS.get(
		GameState.current_difficulty,
		DIFFICULTY_FLAWS[GameState.Difficulty.MEDIUM]
	)
	speed = flaws["speed"]
	jitter_magnitude = flaws["jitter_magnitude"]
	direction_noise_radians = flaws["direction_noise"]
	speed_variance = flaws["speed_variance"]
	velocity_lerp_rate = flaws["velocity_lerp_rate"]
	panic_hazard_count = flaws["panic_count"]


func _physics_process(delta: float) -> void:
	# Pause during round transitions / grace period and reset the "wait for input" gate.
	if main_ref != null and main_ref.is_hazard_movement_paused:
		velocity = Vector2.ZERO
		has_player_moved = false
		return

	# Don't move until the human player has actually started moving this round.
	# Watching their velocity (rather than raw input) means stale held keys
	# from a previous round won't prematurely activate the AI — the player
	# script gates input the same way.
	if not has_player_moved:
		if human_player != null and human_player.velocity.length() > 0.001:
			has_player_moved = true
		else:
			velocity = Vector2.ZERO
			return

	if goal_node == null or hazard_container == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# How far from the true goal? If we're committing to the final approach,
	# skip both jitter and panic-freeze — just go.
	var distance_to_goal: float = goal_node.global_position.distance_to(global_position)
	var final_approach: bool = distance_to_goal < FINAL_APPROACH_DISTANCE

	# Refresh the "where I think the goal is" jitter periodically (skip during final approach).
	if not final_approach:
		jitter_timer -= delta
		if jitter_timer <= 0.0:
			_roll_goal_offset()
			jitter_timer = JITTER_REFRESH_INTERVAL * randf_range(0.7, 1.3)
	else:
		goal_offset = Vector2.ZERO
		jitter_timer = 0.0  # roll a fresh offset the moment we leave the approach zone

	var target_position: Vector2 = goal_node.global_position + goal_offset
	var to_goal: Vector2 = target_position - global_position
	if to_goal.length() < 0.001:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var goal_dir: Vector2 = to_goal.normalized()

	# Sum repulsion from each hazard within the active reaction radius.
	# On the final approach, the radius shrinks and the steering weight drops
	# so the goal pull dominates — AI commits.
	var active_radius: float = FINAL_REACTION_RADIUS if final_approach else REACTION_RADIUS
	var active_weight: float = FINAL_STEERING_WEIGHT if final_approach else STEERING_WEIGHT
	var avoidance: Vector2 = Vector2.ZERO
	var nearby_count: int = 0
	for hazard_node in hazard_container.get_children():
		var hazard: Node2D = hazard_node
		var to_hazard: Vector2 = hazard.global_position - global_position
		var dist: float = to_hazard.length()
		if dist < active_radius and dist > 0.001:
			var weight: float = (active_radius - dist) / active_radius
			avoidance -= to_hazard.normalized() * weight
			nearby_count += 1

	# Panic escape — when surrounded, retreat away from the cluster AND back
	# away from the goal. Standing still gets the AI killed; better to bail out
	# and re-approach from a clearer angle. Final-approach zone always commits.
	if nearby_count >= panic_hazard_count and not final_approach:
		var escape_dir: Vector2 = avoidance
		if escape_dir.length() > 0.001:
			escape_dir = escape_dir.normalized()
		else:
			escape_dir = -goal_dir
		# Bias away from goal so the AI commits to retreating rather than orbiting.
		escape_dir = (escape_dir - goal_dir)
		if escape_dir.length() > 0.001:
			escape_dir = escape_dir.normalized()
		else:
			escape_dir = -goal_dir

		var desired_escape: Vector2 = escape_dir * speed
		velocity = velocity.lerp(desired_escape, clampf(velocity_lerp_rate * delta, 0.0, 1.0))
		move_and_slide()
		return

	var dir: Vector2 = goal_dir + avoidance * active_weight
	if dir.length() > 0.001:
		dir = dir.normalized()
	else:
		dir = goal_dir

	# Direction wobble — small rotational noise each frame (skipped on final approach).
	if not final_approach:
		var wobble: float = randf_range(-direction_noise_radians, direction_noise_radians)
		dir = dir.rotated(wobble)

	# Speed oscillation — slow sine, ±speed_variance. Locked to full speed on final approach.
	speed_phase += delta * SPEED_OSC_RATE
	var speed_mult: float = 1.0 if final_approach else (1.0 + sin(speed_phase) * speed_variance)

	# Momentum — actual velocity converges toward desired velocity over time.
	# On final approach, snap-track much more quickly so the AI doesn't overshoot the goal.
	var desired_velocity: Vector2 = dir * speed * speed_mult
	var lerp_rate: float = velocity_lerp_rate * 4.0 if final_approach else velocity_lerp_rate
	velocity = velocity.lerp(desired_velocity, clampf(lerp_rate * delta, 0.0, 1.0))
	move_and_slide()


func _roll_goal_offset() -> void:
	var angle: float = randf() * TAU
	var magnitude: float = randf() * jitter_magnitude
	goal_offset = Vector2(cos(angle), sin(angle)) * magnitude
