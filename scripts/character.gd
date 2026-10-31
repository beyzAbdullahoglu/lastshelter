extends CharacterBody2D

signal arrived(target: Node)

@export var speed := 180.0
@export var arrive_distance := 4.0

@onready var sprite: Sprite2D = $Sprite2D

var _target_point := Vector2.ZERO
var _target_node: Node = null
var _moving := false


func move_to(point: Vector2, target: Node = null) -> void:
	_target_point = point
	_target_node = target
	_moving = true


func _physics_process(_delta: float) -> void:
	if not _moving:
		return

	var to := _target_point - global_position
	if to.length() <= arrive_distance:
		global_position = _target_point
		velocity = Vector2.ZERO
		_moving = false
		arrived.emit(_target_node)
		return

	velocity = to.normalized() * speed
	move_and_slide()

	# Hook point for AnimatedSprite2D walk directions later.
	if absf(velocity.x) > 0.1:
		sprite.flip_h = velocity.x < 0
