
extends CharacterBody2D

signal arrived(target: Node)

@export var speed := 180.0
@export var arrive_distance := 4.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _target_point := Vector2.ZERO
var _target_node: Node = null
var _moving := false


func _ready() -> void:
	sprite.play("idle")


func move_to(point: Vector2, target: Node = null) -> void:
	_target_point = point
	_target_node = target
	_moving = true


func _physics_process(_delta: float) -> void:
	if not _moving:
		velocity = Vector2.ZERO
		sprite.play("idle")
		return

	var to := _target_point - global_position

	if to.length() <= arrive_distance:
		global_position = _target_point
		velocity = Vector2.ZERO
		_moving = false
		sprite.play("idle")
		arrived.emit(_target_node)
		return

	velocity = to.normalized() * speed
	move_and_slide()

	update_animation()


func update_animation() -> void:
	if absf(velocity.x) > absf(velocity.y):
		if velocity.x > 0:
			sprite.play("right_walk")
		else:
			sprite.play("left_walk")
	else:
		if velocity.y > 0:
			sprite.play("forward_walk")
		else:
			sprite.play("backward_walk")
