extends Node

## Game Manager - 处理游戏核心逻辑
class_name GameManager

signal game_over(remaining_pegs: int, rating: String)
signal peg_count_changed(count: int)
signal move_count_changed(count: int)
signal chain_jump_available(pos: Vector2i, can_continue: bool)  # 通知是否可以继续连跳
signal undo_available_changed(can_undo: bool)  # 通知是否可以撤销
signal undo_performed()  # 通知撤销已执行

## 棋盘类型枚举
enum BoardType { ENGLISH_33, FRENCH_37 }

# 英式33格棋盘布局 (7x7, 角落各去掉4格，共33格)
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

# 法式37格棋盘布局 (7x7, 四角各去掉3格，共37格)
const FRENCH_BOARD: Array = [
	[-1, -1,  1,  1,  1, -1, -1],
	[-1,  1,  1,  1,  1,  1, -1],
	[ 1,  1,  1,  1,  1,  1,  1],
	[ 1,  1,  1,  0,  1,  1,  1],  # 中心为空
	[ 1,  1,  1,  1,  1,  1,  1],
	[-1,  1,  1,  1,  1,  1, -1],
	[-1, -1,  1,  1,  1, -1, -1]
]

const BOARD_SIZE: int = 7
const CENTER_POS: Vector2i = Vector2i(3, 3)

var current_board_type: BoardType = BoardType.ENGLISH_33

var board_state: Array = []
var selected_peg_pos: Vector2i = Vector2i(-1, -1)
var peg_count: int = 0
var move_count: int = 0
var is_chain_jumping: bool = false  # 是否正在连跳中
var chain_jump_pos: Vector2i = Vector2i(-1, -1)  # 连跳中的棋子位置

# 撤销功能：保存每步的移动记录
# 每个元素格式: {"moves": [{"from": Vector2i, "to": Vector2i, "eaten": Vector2i}, ...], "peg_count_before": int}
var move_history: Array = []
var current_step_moves: Array = []  # 当前步骤的移动（用于连跳）
var peg_count_before_step: int = 0  # 当前步骤开始前的棋子数

func _ready() -> void:
	pass  # 不自动初始化，等待外部调用 set_board_type

## 设置棋盘类型并重置游戏
func set_board_type(board_type: BoardType) -> void:
	current_board_type = board_type
	reset_game()

## 获取当前使用的棋盘布局
func _get_current_board() -> Array:
	match current_board_type:
		BoardType.FRENCH_37:
			return FRENCH_BOARD
		_:
			return ENGLISH_BOARD

func reset_game() -> void:
	board_state = []
	peg_count = 0
	move_count = 0
	selected_peg_pos = Vector2i(-1, -1)
	is_chain_jumping = false
	chain_jump_pos = Vector2i(-1, -1)
	move_history.clear()
	current_step_moves.clear()
	peg_count_before_step = 0
	
	var board_template = _get_current_board()
	
	for y in range(BOARD_SIZE):
		var row: Array = []
		for x in range(BOARD_SIZE):
			row.append(board_template[y][x])
			if board_template[y][x] == 1:
				peg_count += 1
		board_state.append(row)
	
	peg_count_changed.emit(peg_count)
	move_count_changed.emit(move_count)
	undo_available_changed.emit(false)

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
	
	# 如果这是新的一步（不是连跳），记录当前棋子数
	if current_step_moves.is_empty():
		peg_count_before_step = peg_count
	
	# 记录这次移动
	current_step_moves.append({
		"from": from_pos,
		"to": to_pos,
		"eaten": middle_pos
	})
	
	# 移动棋子
	board_state[from_pos.y][from_pos.x] = 0
	board_state[middle_pos.y][middle_pos.x] = 0
	board_state[to_pos.y][to_pos.x] = 1
	
	peg_count -= 1
	peg_count_changed.emit(peg_count)
	
	# 检查是否可以继续连跳
	var can_continue = get_valid_moves(to_pos).size() > 0
	
	if can_continue:
		# 开始或继续连跳
		is_chain_jumping = true
		chain_jump_pos = to_pos
		selected_peg_pos = to_pos
		chain_jump_available.emit(to_pos, true)
	else:
		# 无法继续连跳，结束当前步
		_finish_move()
		chain_jump_available.emit(to_pos, false)
	
	return true

## 结束连跳（玩家选择不继续跳）
func end_chain_jump() -> void:
	if is_chain_jumping:
		_finish_move()

## 完成一步移动（内部方法）
func _finish_move() -> void:
	# 保存当前步骤到历史记录
	if not current_step_moves.is_empty():
		move_history.append({
			"moves": current_step_moves.duplicate(true),
			"peg_count_before": peg_count_before_step
		})
		current_step_moves.clear()
		undo_available_changed.emit(true)
	
	is_chain_jumping = false
	chain_jump_pos = Vector2i(-1, -1)
	move_count += 1
	move_count_changed.emit(move_count)
	deselect_peg()
	
	# 检查游戏是否结束
	if not has_any_valid_moves():
		var rating = get_rating()
		game_over.emit(peg_count, rating)

## 检查是否可以撤销
func can_undo() -> bool:
	return not move_history.is_empty() and not is_chain_jumping

## 撤销上一步
func undo_move() -> bool:
	if not can_undo():
		return false
	
	var last_step = move_history.pop_back()
	var moves_to_undo: Array = last_step["moves"]
	var peg_count_before: int = last_step["peg_count_before"]
	
	# 倒序撤销每个移动
	for i in range(moves_to_undo.size() - 1, -1, -1):
		var move_data = moves_to_undo[i]
		var from_pos: Vector2i = move_data["from"]
		var to_pos: Vector2i = move_data["to"]
		var eaten_pos: Vector2i = move_data["eaten"]
		
		# 恢复棋盘状态
		board_state[to_pos.y][to_pos.x] = 0
		board_state[eaten_pos.y][eaten_pos.x] = 1
		board_state[from_pos.y][from_pos.x] = 1
	
	# 恢复棋子数和步数
	peg_count = peg_count_before
	move_count -= 1
	
	peg_count_changed.emit(peg_count)
	move_count_changed.emit(move_count)
	undo_available_changed.emit(not move_history.is_empty())
	undo_performed.emit()
	
	return true

## 检查是否正在连跳中
func is_in_chain_jump() -> bool:
	return is_chain_jumping

## 获取连跳中的棋子位置
func get_chain_jump_pos() -> Vector2i:
	return chain_jump_pos

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
