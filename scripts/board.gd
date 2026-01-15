extends Node2D

## Board - 棋盘控制脚本
class_name Board

signal cell_clicked(pos: Vector2i)

@export var cell_size: Vector2 = Vector2(48, 48)
@export var board_color: Color = Color(0.6, 0.4, 0.2)
@export var cell_color: Color = Color(0.8, 0.7, 0.5)
@export var highlight_color: Color = Color(0.5, 0.8, 0.5, 0.5)

var valid_cells: Array[Vector2i] = []
var highlighted_cells: Array[Vector2i] = []

const BOARD_SIZE: int = 7

## 棋盘类型枚举
enum BoardType { ENGLISH_33, FRENCH_37 }

# 英式33棋盘模板
const ENGLISH_BOARD: Array = [
	[-1, -1,  1,  1,  1, -1, -1],
	[-1, -1,  1,  1,  1, -1, -1],
	[ 1,  1,  1,  1,  1,  1,  1],
	[ 1,  1,  1,  1,  1,  1,  1],
	[ 1,  1,  1,  1,  1,  1,  1],
	[-1, -1,  1,  1,  1, -1, -1],
	[-1, -1,  1,  1,  1, -1, -1]
]

# 法式37棋盘模板
const FRENCH_BOARD: Array = [
	[-1, -1,  1,  1,  1, -1, -1],
	[-1,  1,  1,  1,  1,  1, -1],
	[ 1,  1,  1,  1,  1,  1,  1],
	[ 1,  1,  1,  1,  1,  1,  1],
	[ 1,  1,  1,  1,  1,  1,  1],
	[-1,  1,  1,  1,  1,  1, -1],
	[-1, -1,  1,  1,  1, -1, -1]
]

var current_board_type: BoardType = BoardType.ENGLISH_33

func _ready() -> void:
	pass  # 等待 set_board_type 调用

## 设置棋盘类型
func set_board_type(board_type: BoardType) -> void:
	current_board_type = board_type
	_calculate_valid_cells()

## 获取当前使用的棋盘布局
func _get_current_board() -> Array:
	match current_board_type:
		BoardType.FRENCH_37:
			return FRENCH_BOARD
		_:
			return ENGLISH_BOARD

func _calculate_valid_cells() -> void:
	valid_cells.clear()
	var board_template = _get_current_board()
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			if board_template[y][x] != -1:
				valid_cells.append(Vector2i(x, y))
	queue_redraw()

func _draw() -> void:
	# 绘制棋盘背景
	var board_rect = Rect2(Vector2.ZERO, Vector2(BOARD_SIZE, BOARD_SIZE) * cell_size)
	
	# 绘制有效格子
	for cell_pos in valid_cells:
		var rect = Rect2(Vector2(cell_pos) * cell_size, cell_size)
		draw_rect(rect, cell_color)
		# 绘制边框
		draw_rect(rect, board_color, false, 2.0)
	
	# 绘制高亮格子（可移动位置）
	for cell_pos in highlighted_cells:
		var rect = Rect2(Vector2(cell_pos) * cell_size, cell_size)
		draw_rect(rect, highlight_color)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var local_pos = get_local_mouse_position()
			var cell_pos = Vector2i(int(local_pos.x / cell_size.x), int(local_pos.y / cell_size.y))
			
			if cell_pos in valid_cells:
				cell_clicked.emit(cell_pos)

func set_highlighted_cells(cells: Array[Vector2i]) -> void:
	highlighted_cells = cells
	queue_redraw()

func clear_highlights() -> void:
	highlighted_cells.clear()
	queue_redraw()

func get_world_position(board_pos: Vector2i) -> Vector2:
	return Vector2(board_pos) * cell_size

func get_cell_size() -> Vector2:
	return cell_size

func get_board_center() -> Vector2:
	return Vector2(BOARD_SIZE, BOARD_SIZE) * cell_size / 2
