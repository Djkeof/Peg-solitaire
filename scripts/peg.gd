extends Node2D

## Peg - 棋子（小猫）控制脚本
class_name Peg

@export var board_position: Vector2i = Vector2i(0, 0)
var is_selected: bool = false
var is_moving: bool = false

func _ready() -> void:
	pass

func play_idle() -> void:
	var sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.play("idle")

func play_jump() -> void:
	var sprite = get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if sprite:
		sprite.play("jump")
