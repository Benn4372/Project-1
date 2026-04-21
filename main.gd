extends Node2D

const WALL_THICKNESS: float = 32.0
const DEFAULT_PLAYER_START_RATIO := Vector2(0.5, 0.5)

@onready var player: CharacterBody2D = $Player
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
	_update_play_area()

	if player.global_position == Vector2.ZERO:
		player.global_position = get_viewport_rect().size * DEFAULT_PLAYER_START_RATIO


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
