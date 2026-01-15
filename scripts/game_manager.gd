extends Node

## Game Manager - 处理游戏核心逻辑
class_name GameManager

signal game_over(remaining_pegs: int, rating: String)
signal peg_count_changed(count: int)

# 英式33棋盘布局 (7x7, 但角落4格各去掉)
# 1 = 有棋子, 0 = 空位, -1 = 无效位置
const ENGLISH_BOARD: Array = [
	[-1, -1,  1,  1,  1, -1, -1],
	[-1, -1,  1,  1,  1, -1, -1],
	[ 1,  1,  1,  1,  1,  1,  1],
	[ 1,  1,  1,  0,  1,  1,  1],  # 中心为空
	[ 1,  1,  1,  1,  1,  1,  1],
	[-1, -1,  1,  1,  1, -1, -1],
	[-1, -1,  1,  1,  1, -1, -1]
]

const BOARD_SIZE: int = 7
const CENTER_POS: Vector2i = Vector2i(3, 3)

var board_state: Array = []
var selected_peg_pos: Vector2i = Vector2i(-1, -1)
var peg_count: int = 0

func _ready() -> void:
	reset_game()

func reset_game() -> void:
	board_state = []
	peg_count = 0
	selected_peg_pos = Vector2i(-1, -1)
	
	for y in range(BOARD_SIZE):
		var row: Array = []
		for x in range(BOARD_SIZE):
			row.append(ENGLISH_BOARD[y][x])
			if ENGLISH_BOARD[y][x] == 1:
				peg_count += 1
		board_state.append(row)
	
	peg_count_changed.emit(peg_count)

func is_valid_position(pos: Vector2i) -> bool:
	if pos.x < 0 or pos.x >= BOARD_SIZE or pos.y < 0 or pos.y >= BOARD_SIZE:
		return false
	return board_state[pos.y][pos.x] != -1

func has_peg(pos: Vector2i) -> bool:
	if not is_valid_position(pos):
		return false
	return board_state[pos.y][pos.x] == 1

func is_empty(pos: Vector2i) -> bool:
	if not is_valid_position(pos):
		return false
	return board_state[pos.y][pos.x] == 0

func get_valid_moves(from_pos: Vector2i) -> Array[Vector2i]:
	var moves: Array[Vector2i] = []
	if not has_peg(from_pos):
		return moves
	
	# 检查四个方向：上、下、左、右
	var directions: Array[Vector2i] = [
		Vector2i(0, -2),  # 上
		Vector2i(0, 2),   # 下
		Vector2i(-2, 0),  # 左
		Vector2i(2, 0)    # 右
	]
	
	for dir in directions:
		var target_pos: Vector2i = from_pos + dir
		var middle_pos: Vector2i = from_pos + dir / 2
		
		if is_empty(target_pos) and has_peg(middle_pos):
			moves.append(target_pos)
	
	return moves

func can_move(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	var valid_moves = get_valid_moves(from_pos)
	return to_pos in valid_moves

func make_move(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if not can_move(from_pos, to_pos):
		return false
	
	var middle_pos: Vector2i = (from_pos + to_pos) / 2
	
	# 移动棋子
	board_state[from_pos.y][from_pos.x] = 0
	board_state[middle_pos.y][middle_pos.x] = 0
	board_state[to_pos.y][to_pos.x] = 1
	
	peg_count -= 1
	peg_count_changed.emit(peg_count)
	
	# 检查游戏是否结束
	if not has_any_valid_moves():
		var rating = get_rating()
		game_over.emit(peg_count, rating)
	
	return true

func has_any_valid_moves() -> bool:
	for y in range(BOARD_SIZE):
		for x in range(BOARD_SIZE):
			var pos = Vector2i(x, y)
			if has_peg(pos) and get_valid_moves(pos).size() > 0:
				return true
	return false

func get_rating() -> String:
	if peg_count == 1:
		# 检查是否在正中央
		if has_peg(CENTER_POS):
			return "天才"
		return "大师"
	elif peg_count == 2:
		return "尖子"
	elif peg_count == 3:
		return "聪明"
	elif peg_count == 4:
		return "很好"
	elif peg_count == 5:
		return "颇好"
	else:
		return "一般"

func select_peg(pos: Vector2i) -> bool:
	if has_peg(pos):
		selected_peg_pos = pos
		return true
	return false

func deselect_peg() -> void:
	selected_peg_pos = Vector2i(-1, -1)

func get_selected_peg() -> Vector2i:
	return selected_peg_pos

func try_move_to(pos: Vector2i) -> int:
	# 返回: 0 = 无效, 1 = 选中棋子, 2 = 成功移动
	if selected_peg_pos == Vector2i(-1, -1):
		if has_peg(pos):
			select_peg(pos)
			return 1
		return 0
	else:
		if pos == selected_peg_pos:
			deselect_peg()
			return 0
		elif has_peg(pos):
			# 选择另一个棋子
			select_peg(pos)
			return 1
		elif can_move(selected_peg_pos, pos):
			var from = selected_peg_pos
			deselect_peg()
			make_move(from, pos)
			return 2
		else:
			return 0
