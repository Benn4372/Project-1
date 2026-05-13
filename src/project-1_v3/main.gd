extends Node2D

const WALL_THICKNESS: float = 32.0
const SINGLE_START_RATIO := Vector2(0.5, 0.5)
# Arrow-keys player (P1 / human) on the right, WASD player (P2) on the left —
# matches typical hand position on the keyboard. AI takes the P2 slot in Versus.
const MULTI_P1_START_RATIO := Vector2(0.75, 0.5)
const MULTI_P2_START_RATIO := Vector2(0.25, 0.5)
const BOX_SIZE: float = 32.0
const FLASH_DURATION: float = 0.2
const ROUND_PAUSE_DURATION: float = 1.0
const POSITION_ATTEMPTS: int = 32
const HAZARD_COUNTS := {
	GameState.Difficulty.EASY: 5,
	GameState.Difficulty.MEDIUM: 10,
	GameState.Difficulty.HARD: 15,
	GameState.Difficulty.ADAPTIVE: 5,
}
const ADAPTIVE_MAX_REDS: int = 15
const ADAPTIVE_MAX_PURPLES: int = 5
const ADAPTIVE_PURPLE_START_SCORE: int = 20
const ADAPTIVE_SPEED_START_SCORE: int = 45
const RED_HAZARD_COLOR := Color(1, 0.2, 0.2, 1)
const PURPLE_HAZARD_COLOR := Color(0.6, 0.2, 1, 1)
const HAZARD_SPEED: float = 150.0
const HAZARD_MIN_TICKS: int = 20
const HAZARD_MAX_TICKS: int = 90
const SUCCESS_FLASH_COLOR := Color(0, 1, 0, 0.4)
const FAILURE_FLASH_COLOR := Color(1, 0, 0, 0.4)
# Multiplayer round-result flashes — match the winning player's tint so it's
# obvious who scored. Tie = neutral gray. Versus AI uses player-color for
# player wins and AI-color (orange) for AI wins.
const P1_FLASH_COLOR := Color(0.3, 0.9, 1.0, 0.4)
const P2_FLASH_COLOR := Color(1.0, 0.85, 0.2, 0.4)
const AI_FLASH_COLOR := Color(1.0, 0.7, 0.2, 0.4)
const TIE_FLASH_COLOR := Color(0.7, 0.7, 0.7, 0.4)
const DIAGONAL_COMPONENT: float = 0.70710678
const HAZARD_DIRECTIONS := [
	Vector2.LEFT,
	Vector2.RIGHT,
	Vector2.UP,
	Vector2.DOWN,
	Vector2(-DIAGONAL_COMPONENT, -DIAGONAL_COMPONENT),
	Vector2(DIAGONAL_COMPONENT, -DIAGONAL_COMPONENT),
	Vector2(-DIAGONAL_COMPONENT, DIAGONAL_COMPONENT),
	Vector2(DIAGONAL_COMPONENT, DIAGONAL_COMPONENT)
]

const PLAYER_SCENE: PackedScene = preload("res://player.tscn")
const AI_SCENE: PackedScene = preload("res://ai.tscn")
# Multiplayer tints — distinct, and clearly different from hazards (red/purple),
# AI (orange), and goal (green).
const PLAYER1_TINT := Color(0.3, 0.9, 1.0, 1.0)   # cyan
const PLAYER2_TINT := Color(1.0, 0.85, 0.2, 1.0)  # yellow

var is_level_completing: bool = false
var is_hazard_movement_paused: bool = false
# `score` is the adaptive-driving running counter:
# Single: this IS the player's score (increments on goal, resets on death).
# Multi:  shared progression counter (any goal increments, any death resets).
var score: int = 0
var p1_round_wins: int = 0
var p2_round_wins: int = 0
var round_sequence_id: int = 0
var current_hazard_speed: float = HAZARD_SPEED

# players[i] = {"node": CharacterBody2D, "id": 1 or 2, "starting_position": Vector2}
var players: Array = []
var pending_events: Array = []

@onready var player: CharacterBody2D = $Player
@onready var goal_box: Area2D = $GoalBox
@onready var hazard_container: Node2D = $Hazards
@onready var score_label: Label = $CanvasLayer/ScoresVBox/ScoreLabel
@onready var high_score_label: Label = $CanvasLayer/ScoresVBox/HighScoreLabel
@onready var last_score_label: Label = $CanvasLayer/ScoresVBox/LastScoreLabel
@onready var average_score_label: Label = $CanvasLayer/ScoresVBox/AverageScoreLabel
@onready var p1_label: Label = $CanvasLayer/ScoresVBox/P1Label
@onready var p2_label: Label = $CanvasLayer/ScoresVBox/P2Label
@onready var flash_overlay: ColorRect = $CanvasLayer/FlashOverlay
@onready var flash_timer: Timer = $FlashTimer
@onready var top_wall: StaticBody2D = $TopWall
@onready var bottom_wall: StaticBody2D = $BottomWall
@onready var left_wall: StaticBody2D = $LeftWall
@onready var right_wall: StaticBody2D = $RightWall
@onready var top_shape: RectangleShape2D = $TopWall/CollisionShape2D.shape
@onready var bottom_shape: RectangleShape2D = $BottomWall/CollisionShape2D.shape
@onready var left_shape: RectangleShape2D = $LeftWall/CollisionShape2D.shape
@onready var right_shape: RectangleShape2D = $RightWall/CollisionShape2D.shape


func _ready() -> void:
	get_viewport().size_changed.connect(_update_play_area)
	goal_box.body_entered.connect(_on_goal_box_body_entered)
	$CanvasLayer/CloseButton.pressed.connect(_on_menu_button_pressed)
	flash_timer.wait_time = FLASH_DURATION
	_update_play_area()
	_setup_ui_for_mode()
	_setup_players()
	_refresh_score_labels()

	_place_goal_box()
	_create_hazards()
	_sync_adaptive_hazards(score)
	_place_hazards()
	await _start_initial_round()


func _is_multi() -> bool:
	return GameState.current_mode == GameState.Mode.MULTIPLAYER


func _is_versus() -> bool:
	return GameState.current_mode == GameState.Mode.VERSUS_AI


func _setup_ui_for_mode() -> void:
	var multi: bool = _is_multi()
	var versus: bool = _is_versus()
	# Single Player uses all four single-mode labels.
	score_label.visible = not multi and not versus
	last_score_label.visible = not multi and not versus
	average_score_label.visible = not multi and not versus
	# High score only shows in Single Player now.
	high_score_label.visible = not multi and not versus
	# P1/P2 (re-labeled in Versus) used by both Multi and Versus.
	p1_label.visible = multi or versus
	p2_label.visible = multi or versus
	# (The VBoxContainer auto-stacks visible labels — no manual positioning needed.)


func _setup_players() -> void:
	players.clear()
	var viewport: Vector2 = get_viewport_rect().size
	var multi: bool = _is_multi()
	var versus: bool = _is_versus()
	var two_actor: bool = multi or versus

	# Player 1 — existing scene node
	var p1_start: Vector2 = viewport * (MULTI_P1_START_RATIO if two_actor else SINGLE_START_RATIO)
	player.input_prefix = "ui"
	player.global_position = p1_start
	player.velocity = Vector2.ZERO
	player.main_ref = self
	# Tint P1 cyan in multi and versus so the win flash matches the player's color.
	# Single Player stays default.
	if multi or versus:
		player.modulate = PLAYER1_TINT
	else:
		player.modulate = Color(1, 1, 1, 1)
	players.append({"node": player, "id": 1, "starting_position": p1_start})

	if multi:
		var p2: CharacterBody2D = PLAYER_SCENE.instantiate()
		p2.input_prefix = "p2"
		p2.modulate = PLAYER2_TINT
		p2.main_ref = self
		var p2_start: Vector2 = viewport * MULTI_P2_START_RATIO
		add_child(p2)
		p2.global_position = p2_start
		players.append({"node": p2, "id": 2, "starting_position": p2_start})

		# Players should not collide with each other (per spec — can overlap).
		player.add_collision_exception_with(p2)
		p2.add_collision_exception_with(player)
	elif versus:
		var ai: CharacterBody2D = AI_SCENE.instantiate()
		ai.goal_node = goal_box
		ai.hazard_container = hazard_container
		ai.main_ref = self
		ai.human_player = player
		var ai_start: Vector2 = viewport * MULTI_P2_START_RATIO
		add_child(ai)
		ai.global_position = ai_start
		players.append({"node": ai, "id": 2, "starting_position": ai_start})

		# Player and AI should not collide with each other (per spec — can overlap).
		player.add_collision_exception_with(ai)
		ai.add_collision_exception_with(player)


func _start_initial_round() -> void:
	is_level_completing = true
	is_hazard_movement_paused = true
	goal_box.monitoring = false

	await _wait_for_round_start(ROUND_PAUSE_DURATION)

	goal_box.monitoring = true
	is_hazard_movement_paused = false
	is_level_completing = false


func _wait_for_round_start(duration: float) -> void:
	# Waits up to `duration` seconds, but ends early as soon as ANY player
	# presses a fresh direction. If a key is already held when the round
	# starts, the player must release first — prevents the previous round's
	# held input from instantly ending the grace into a hazard.
	if not is_inside_tree():
		return
	var timer: SceneTreeTimer = get_tree().create_timer(duration)
	var must_release_first: bool = _any_player_pressing_direction()
	while timer.time_left > 0.0:
		if not is_inside_tree():
			return
		var pressing: bool = _any_player_pressing_direction()
		if must_release_first:
			if not pressing:
				must_release_first = false
		elif pressing:
			return
		await get_tree().process_frame


func _any_player_pressing_direction() -> bool:
	if Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") != Vector2.ZERO:
		return true
	if _is_multi() and Input.get_vector("p2_left", "p2_right", "p2_up", "p2_down") != Vector2.ZERO:
		return true
	return false


func _physics_process(delta: float) -> void:
	if is_hazard_movement_paused:
		return

	_move_hazards(delta)


func _update_play_area() -> void:
	var viewport_size := get_viewport_rect().size
	var half_thickness := WALL_THICKNESS * 0.5

	top_shape.size = Vector2(viewport_size.x, WALL_THICKNESS)
	bottom_shape.size = Vector2(viewport_size.x, WALL_THICKNESS)
	left_shape.size = Vector2(WALL_THICKNESS, viewport_size.y)
	right_shape.size = Vector2(WALL_THICKNESS, viewport_size.y)

	top_wall.position = Vector2(viewport_size.x * 0.5, -half_thickness)
	bottom_wall.position = Vector2(viewport_size.x * 0.5, viewport_size.y + half_thickness)
	left_wall.position = Vector2(-half_thickness, viewport_size.y * 0.5)
	right_wall.position = Vector2(viewport_size.x + half_thickness, viewport_size.y * 0.5)
	flash_overlay.size = viewport_size


func _place_goal_box() -> void:
	goal_box.position = _get_random_box_position()


func _create_hazards() -> void:
	for child in hazard_container.get_children():
		child.queue_free()

	for _index in range(_initial_red_count()):
		_spawn_hazard(false)


func _initial_red_count() -> int:
	if GameState.current_difficulty == GameState.Difficulty.CUSTOM:
		return maxi(0, int(GameState.custom_config["red_count"]))
	return HAZARD_COUNTS.get(GameState.current_difficulty, 10)


func _spawn_hazard(is_purple: bool) -> void:
	var hazard := Area2D.new()
	var collision_shape := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	var visual := Polygon2D.new()
	var half_box := BOX_SIZE * 0.5

	shape.size = Vector2(BOX_SIZE, BOX_SIZE)
	collision_shape.shape = shape
	hazard.body_entered.connect(_on_hazard_body_entered)
	hazard.set_meta("direction", Vector2.ZERO)
	hazard.set_meta("ticks_remaining", 0)
	hazard.set_meta("kind", "purple" if is_purple else "red")
	visual.polygon = PackedVector2Array([
		Vector2(-half_box, -half_box),
		Vector2(half_box, -half_box),
		Vector2(half_box, half_box),
		Vector2(-half_box, half_box)
	])
	visual.color = PURPLE_HAZARD_COLOR if is_purple else RED_HAZARD_COLOR

	hazard.add_child(collision_shape)
	hazard.add_child(visual)
	hazard_container.add_child(hazard)


func _place_hazards() -> void:
	for hazard_node in hazard_container.get_children():
		var hazard: Area2D = hazard_node
		hazard.position = _get_random_box_position()
		_assign_hazard_direction(hazard)


func _move_hazards(delta: float) -> void:
	for hazard_node in hazard_container.get_children():
		var hazard: Area2D = hazard_node
		if hazard.get_meta("kind", "red") == "purple":
			_move_purple_hazard(hazard, delta)
			continue

		var ticks_remaining: int = hazard.get_meta("ticks_remaining", 0)
		if ticks_remaining <= 0:
			_assign_hazard_direction(hazard)
			ticks_remaining = hazard.get_meta("ticks_remaining", 0)

		var direction: Vector2 = hazard.get_meta("direction", Vector2.ZERO)
		var new_position := hazard.position + direction * current_hazard_speed * delta
		var clamped_position := _clamp_box_position(new_position)

		if clamped_position != new_position:
			_assign_hazard_direction(hazard)
		else:
			hazard.position = clamped_position
			hazard.set_meta("ticks_remaining", ticks_remaining - 1)


func _move_purple_hazard(hazard: Area2D, delta: float) -> void:
	var target_position := _nearest_player_position(hazard.position)
	var to_target := target_position - hazard.position
	if to_target.length() < 0.001:
		return
	var direction := to_target.normalized()
	var new_position := hazard.position + direction * current_hazard_speed * delta
	hazard.position = _clamp_box_position(new_position)


func _nearest_player_position(from: Vector2) -> Vector2:
	var nearest: Vector2 = from
	var min_dist_sq: float = INF
	for p in players:
		var node: Node2D = p["node"]
		var d: float = (node.global_position - from).length_squared()
		if d < min_dist_sq:
			min_dist_sq = d
			nearest = node.global_position
	return nearest


func _sync_adaptive_hazards(current_score: int) -> void:
	var diff: int = GameState.current_difficulty
	if diff != GameState.Difficulty.ADAPTIVE and diff != GameState.Difficulty.CUSTOM:
		current_hazard_speed = HAZARD_SPEED
		return

	var composition: Dictionary = _target_composition(current_score)
	var target_reds: int = composition["reds"]
	var target_purples: int = composition["purples"]
	current_hazard_speed = composition["speed"]

	var reds: Array = []
	var purples: Array = []
	for hazard_node in hazard_container.get_children():
		if hazard_node.get_meta("kind", "red") == "purple":
			purples.append(hazard_node)
		else:
			reds.append(hazard_node)

	while reds.size() > target_reds:
		var doomed: Node = reds.pop_back()
		doomed.queue_free()
	while purples.size() > target_purples:
		var doomed: Node = purples.pop_back()
		doomed.queue_free()

	for _i in range(target_reds - reds.size()):
		_spawn_hazard(false)
	for _i in range(target_purples - purples.size()):
		_spawn_hazard(true)


func _target_composition(current_score: int) -> Dictionary:
	var diff: int = GameState.current_difficulty
	if diff == GameState.Difficulty.ADAPTIVE:
		var reds: int = mini(5 + current_score / 2, ADAPTIVE_MAX_REDS)
		var purples: int = clampi(
			(current_score - ADAPTIVE_PURPLE_START_SCORE) / 5,
			0,
			ADAPTIVE_MAX_PURPLES
		)
		var speed_bonus: float = float(maxi(0, current_score - ADAPTIVE_SPEED_START_SCORE))
		return {"reds": reds, "purples": purples, "speed": HAZARD_SPEED + speed_bonus}

	# CUSTOM
	var c: Dictionary = GameState.custom_config
	var base_reds: int = maxi(0, int(c["red_count"]))
	var red_cap: int = maxi(base_reds, int(c["red_cap"]))
	var red_interval: int = maxi(1, int(c["red_increment_interval"]))
	var target_reds: int = base_reds
	if bool(c["increase_reds"]):
		target_reds = mini(base_reds + current_score / red_interval, red_cap)

	var target_purples: int = 0
	if bool(c["use_purples"]):
		var purple_start: int = maxi(0, int(c["purple_start_score"]))
		var purple_interval: int = maxi(1, int(c["purple_increment_interval"]))
		var purple_cap: int = maxi(1, int(c["purple_cap"]))
		if current_score >= purple_start:
			target_purples = mini(
				1 + (current_score - purple_start) / purple_interval,
				purple_cap
			)

	var base_speed: float = maxf(1.0, float(c["hazard_speed"]))
	if bool(c["speed_scaling"]):
		var red_cap_score: int = 0
		if bool(c["increase_reds"]):
			red_cap_score = (red_cap - base_reds) * red_interval
		var purple_cap_score: int = 0
		if bool(c["use_purples"]):
			purple_cap_score = (
				maxi(0, int(c["purple_start_score"]))
				+ (maxi(1, int(c["purple_cap"])) - 1)
				* maxi(1, int(c["purple_increment_interval"]))
			)
		var scaling_start: int = maxi(red_cap_score, purple_cap_score)
		if current_score > scaling_start:
			base_speed += float(current_score - scaling_start)

	return {"reds": target_reds, "purples": target_purples, "speed": base_speed}


func _assign_hazard_direction(hazard: Area2D) -> void:
	hazard.set_meta("direction", HAZARD_DIRECTIONS[randi_range(0, HAZARD_DIRECTIONS.size() - 1)])
	hazard.set_meta("ticks_remaining", randi_range(HAZARD_MIN_TICKS, HAZARD_MAX_TICKS))


func _get_random_box_position() -> Vector2:
	var half_box := BOX_SIZE * 0.5
	var viewport_size := get_viewport_rect().size
	var min_position := Vector2(WALL_THICKNESS + half_box, WALL_THICKNESS + half_box)
	var max_position := viewport_size - Vector2(WALL_THICKNESS + half_box, WALL_THICKNESS + half_box)

	if max_position.x < min_position.x or max_position.y < min_position.y:
		return min_position

	for _attempt in range(POSITION_ATTEMPTS):
		var candidate := Vector2(
			randf_range(min_position.x, max_position.x),
			randf_range(min_position.y, max_position.y)
		)

		if not _box_overlaps_any_player(candidate):
			return candidate

	return min_position


func _clamp_box_position(box_center: Vector2) -> Vector2:
	var half_box := BOX_SIZE * 0.5
	var viewport_size := get_viewport_rect().size
	return Vector2(
		clampf(box_center.x, WALL_THICKNESS + half_box, viewport_size.x - WALL_THICKNESS - half_box),
		clampf(box_center.y, WALL_THICKNESS + half_box, viewport_size.y - WALL_THICKNESS - half_box)
	)


func _box_overlaps_any_player(box_center: Vector2) -> bool:
	for p in players:
		if _box_overlaps_point(box_center, p["node"].global_position):
			return true
	return false


func _box_overlaps_point(box_center: Vector2, player_position: Vector2) -> bool:
	# Use the player's 96x96 collision plus a 16px breathing-room buffer so
	# hazards don't spawn touching the player.
	var player_half_size := Vector2(48.0 + 16.0, 48.0 + 16.0)
	var box_half_size := Vector2(BOX_SIZE * 0.5, BOX_SIZE * 0.5)
	var player_min := player_position - player_half_size
	var player_max := player_position + player_half_size
	var box_min := box_center - box_half_size
	var box_max := box_center + box_half_size

	return (
		box_min.x < player_max.x
		and box_max.x > player_min.x
		and box_min.y < player_max.y
		and box_max.y > player_min.y
	)


func _identify_player(body: Node) -> int:
	for p in players:
		if body == p["node"]:
			return p["id"]
	return 0


func _on_goal_box_body_entered(body: Node2D) -> void:
	var pid: int = _identify_player(body)
	if pid == 0:
		return
	if is_level_completing and not _can_interrupt_pause():
		return
	pending_events.append({"type": "goal", "player": pid})
	if pending_events.size() == 1:
		call_deferred("_resolve_pending_events")


func _on_hazard_body_entered(body: Node2D) -> void:
	var pid: int = _identify_player(body)
	if pid == 0:
		return
	if is_level_completing and not _can_interrupt_pause():
		return
	pending_events.append({"type": "death", "player": pid})
	if pending_events.size() == 1:
		call_deferred("_resolve_pending_events")


func _resolve_pending_events() -> void:
	if pending_events.is_empty():
		return
	var events: Array = pending_events.duplicate()
	pending_events.clear()

	# Aggregate: first goal wins; collect unique deaths.
	var goal_player: int = 0
	var dead_players: Array = []
	for e in events:
		if e["type"] == "goal" and goal_player == 0:
			goal_player = e["player"]
		elif e["type"] == "death":
			if not (e["player"] in dead_players):
				dead_players.append(e["player"])

	if _is_multi() or _is_versus():
		_handle_multi_outcome(goal_player, dead_players)
	else:
		_handle_single_outcome(goal_player, dead_players)


func _handle_single_outcome(goal_player: int, dead_players: Array) -> void:
	if goal_player > 0:
		score += 1
		_refresh_score_labels()
		_complete_round(SUCCESS_FLASH_COLOR, [])
	elif dead_players.size() > 0:
		GameState.record_round(score)
		score = 0
		_refresh_score_labels()
		_complete_round(FAILURE_FLASH_COLOR, dead_players)


func _handle_multi_outcome(goal_player: int, dead_players: Array) -> void:
	# Shared by Multiplayer and Versus AI — both use round-wins counters that
	# persist across deaths. Reaching the goal first or having the opponent
	# die both count as a round win.
	var winner: int = 0

	if goal_player > 0:
		winner = goal_player
		# Goal reached: adaptive progression continues.
		score += 1
	elif dead_players.size() == 1:
		winner = 2 if dead_players[0] == 1 else 1
		# No score reset — hazard count and Custom/Adaptive progression
		# persist across deaths in two-actor modes.
	# Both died: also no reset.

	if winner == 1:
		p1_round_wins += 1
	elif winner == 2:
		p2_round_wins += 1

	# Flash color matches the winning side. Multi uses P1/P2 tints; Versus uses
	# the player's cyan and the AI's orange. Tie = gray.
	var flash: Color = TIE_FLASH_COLOR
	if winner == 1:
		flash = P1_FLASH_COLOR
	elif winner == 2:
		flash = AI_FLASH_COLOR if _is_versus() else P2_FLASH_COLOR

	_refresh_score_labels()
	_complete_round(flash, dead_players)


func _can_interrupt_pause() -> bool:
	return is_level_completing and is_hazard_movement_paused and not flash_overlay.visible


func _complete_round(flash_color: Color, dead_players: Array) -> void:
	round_sequence_id += 1
	var active_round_id := round_sequence_id

	is_level_completing = true
	is_hazard_movement_paused = true
	goal_box.set_deferred("monitoring", false)

	flash_overlay.color = flash_color
	flash_overlay.visible = true
	flash_timer.start()
	await flash_timer.timeout
	if not is_inside_tree() or active_round_id != round_sequence_id:
		return

	flash_overlay.visible = false

	# Respawn dead players at their starting positions (per spec).
	for pid in dead_players:
		for p in players:
			if p["id"] == pid:
				p["node"].global_position = p["starting_position"]
				p["node"].velocity = Vector2.ZERO

	_place_goal_box()
	_sync_adaptive_hazards(score)
	_place_hazards()
	goal_box.monitoring = true
	await get_tree().physics_frame
	if not is_inside_tree() or active_round_id != round_sequence_id:
		return

	await _wait_for_round_start(ROUND_PAUSE_DURATION)
	if not is_inside_tree() or active_round_id != round_sequence_id:
		return

	is_hazard_movement_paused = false
	is_level_completing = false


func _refresh_score_labels() -> void:
	if _is_multi():
		p1_label.text = "P1: %d" % p1_round_wins
		p2_label.text = "P2: %d" % p2_round_wins
	elif _is_versus():
		p1_label.text = "You: %d" % p1_round_wins
		p2_label.text = "AI: %d" % p2_round_wins
	else:
		score_label.text = "Score: %d" % score
		high_score_label.text = "High Score: %d" % GameState.get_high_score(GameState.current_difficulty)
		last_score_label.text = "Last: %d" % GameState.get_last_score(GameState.current_difficulty)
		average_score_label.text = "Avg: %.1f" % GameState.get_average_score(GameState.current_difficulty)


func _on_menu_button_pressed() -> void:
	get_tree().change_scene_to_file("res://difficulty_select.tscn")
