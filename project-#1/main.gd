extends Node2D

const WALL_THICKNESS: float = 32.0
const DEFAULT_PLAYER_START_RATIO := Vector2(0.5, 0.5)
const BOX_SIZE: float = 32.0
const FLASH_DURATION: float = 0.2
const ROUND_PAUSE_DURATION: float = 1.0
const HAZARD_COUNT: int = 10
const POSITION_ATTEMPTS: int = 32
const HAZARD_SPEED: float = 150.0
const HAZARD_MIN_TICKS: int = 20
const HAZARD_MAX_TICKS: int = 90
const SUCCESS_FLASH_COLOR := Color(0, 1, 0, 0.4)
const FAILURE_FLASH_COLOR := Color(1, 0, 0, 0.4)
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

var is_level_completing: bool = false
var is_hazard_movement_paused: bool = false
var score: int = 0
var high_score: int = 0
var round_sequence_id: int = 0

@onready var player: CharacterBody2D = $Player
@onready var goal_box: Area2D = $GoalBox
@onready var hazard_container: Node2D = $Hazards
@onready var score_label: Label = $CanvasLayer/ScoreLabel
@onready var high_score_label: Label = $CanvasLayer/HighScoreLabel
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
	$CanvasLayer/CloseButton.pressed.connect(_on_close_button_pressed)
	flash_timer.wait_time = FLASH_DURATION
	_update_score_label()
	_update_high_score_label()
	_update_play_area()

	if player.global_position == Vector2.ZERO:
		player.global_position = get_viewport_rect().size * DEFAULT_PLAYER_START_RATIO

	_place_goal_box()
	_create_hazards()
	_place_hazards()


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

	for _index in range(HAZARD_COUNT):
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
		visual.polygon = PackedVector2Array([
			Vector2(-half_box, -half_box),
			Vector2(half_box, -half_box),
			Vector2(half_box, half_box),
			Vector2(-half_box, half_box)
		])
		visual.color = Color(1, 0.2, 0.2, 1)

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
		var ticks_remaining: int = hazard.get_meta("ticks_remaining", 0)
		if ticks_remaining <= 0:
			_assign_hazard_direction(hazard)
			ticks_remaining = hazard.get_meta("ticks_remaining", 0)

		var direction: Vector2 = hazard.get_meta("direction", Vector2.ZERO)
		var new_position := hazard.position + direction * HAZARD_SPEED * delta
		var clamped_position := _clamp_box_position(new_position)

		if clamped_position != new_position:
			_assign_hazard_direction(hazard)
		else:
			hazard.position = clamped_position
			hazard.set_meta("ticks_remaining", ticks_remaining - 1)


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

		if not _box_overlaps_player(candidate):
			return candidate

	return min_position


func _clamp_box_position(box_center: Vector2) -> Vector2:
	var half_box := BOX_SIZE * 0.5
	var viewport_size := get_viewport_rect().size
	return Vector2(
		clampf(box_center.x, WALL_THICKNESS + half_box, viewport_size.x - WALL_THICKNESS - half_box),
		clampf(box_center.y, WALL_THICKNESS + half_box, viewport_size.y - WALL_THICKNESS - half_box)
	)


func _box_overlaps_player(box_center: Vector2) -> bool:
	var player_half_size := Vector2(48.0, 48.0)
	var box_half_size := Vector2(BOX_SIZE * 0.5, BOX_SIZE * 0.5)
	var player_min := player.global_position - player_half_size
	var player_max := player.global_position + player_half_size
	var box_min := box_center - box_half_size
	var box_max := box_center + box_half_size

	return (
		box_min.x < player_max.x
		and box_max.x > player_min.x
		and box_min.y < player_max.y
		and box_max.y > player_min.y
	)


func _on_goal_box_body_entered(body: Node2D) -> void:
	if body != player:
		return
	if is_level_completing and not _can_interrupt_pause():
		return

	score += 1
	_update_score_label()
	_complete_round(SUCCESS_FLASH_COLOR)


func _on_hazard_body_entered(body: Node2D) -> void:
	if body != player:
		return
	if is_level_completing and not _can_interrupt_pause():
		return

	if score > high_score:
		high_score = score
		_update_high_score_label()

	score = 0
	_update_score_label()
	_complete_round(FAILURE_FLASH_COLOR)


func _can_interrupt_pause() -> bool:
	return is_level_completing and is_hazard_movement_paused and not flash_overlay.visible


func _complete_round(flash_color: Color) -> void:
	round_sequence_id += 1
	var active_round_id := round_sequence_id

	is_level_completing = true
	is_hazard_movement_paused = true
	goal_box.set_deferred("monitoring", false)

	flash_overlay.color = flash_color
	flash_overlay.visible = true
	flash_timer.start()
	await flash_timer.timeout
	if active_round_id != round_sequence_id:
		return

	flash_overlay.visible = false
	_place_goal_box()
	_place_hazards()
	goal_box.monitoring = true
	await get_tree().physics_frame
	if active_round_id != round_sequence_id:
		return

	await get_tree().create_timer(ROUND_PAUSE_DURATION).timeout
	if active_round_id != round_sequence_id:
		return

	is_hazard_movement_paused = false
	is_level_completing = false


func _update_score_label() -> void:
	score_label.text = "Score: %d" % score


func _update_high_score_label() -> void:
	high_score_label.text = "High Score: %d" % high_score


func _on_close_button_pressed() -> void:
	get_tree().quit()
