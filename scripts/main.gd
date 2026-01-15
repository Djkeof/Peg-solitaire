extends Node2D

## Main - 游戏主场景控制脚本

@onready var board: Board = $Board
@onready var pegs_container: Node2D = $PegsContainer
@onready var ui: CanvasLayer = $UI
@onready var move_count_label: Label = $UI/UIRoot/GameInfo/MoveCount
@onready var peg_count_label: Label = $UI/UIRoot/GameInfo/PegCount
@onready var rating_label: Label = $UI/UIRoot/GameInfo/Rating
@onready var game_over_panel: Panel = $UI/UIRoot/GameOverPanel
@onready var game_over_rating: Label = $UI/UIRoot/GameOverPanel/VBoxContainer/RatingResult
@onready var game_over_count: Label = $UI/UIRoot/GameOverPanel/VBoxContainer/PegCountResult
@onready var bgm_player: AudioStreamPlayer = $BGMPlayer
@onready var meow_player: AudioStreamPlayer = $MeowPlayer
@onready var hiss_player: AudioStreamPlayer = $HissPlayer
@onready var about_panel: Panel = $UI/UIRoot/AboutPanel
@onready var undo_btn: Button = $UI/UIRoot/UndoBtn
@onready var confirm_dialog: Panel = $UI/UIRoot/ConfirmDialog
@onready var confirm_message: Label = $UI/UIRoot/ConfirmDialog/VBoxContainer/Message

# 确认弹窗的操作类型
enum ConfirmAction { RESTART, MENU }
var pending_confirm_action: ConfirmAction = ConfirmAction.RESTART

var game_manager: GameManager
var peg_scene: PackedScene
var pegs: Dictionary = {}  # Vector2i -> Peg

const CAT_TYPES: Array[String] = [
	"Classical",
	"BlackCat",
	"Brown",
	"White",
	"Siamese",
	"ThreeColorFree",
	"TigerCatFree"
]

func _ready() -> void:
	game_manager = GameManager.new()
	add_child(game_manager)
	
	game_manager.peg_count_changed.connect(_on_peg_count_changed)
	game_manager.move_count_changed.connect(_on_move_count_changed)
	game_manager.game_over.connect(_on_game_over)
	game_manager.chain_jump_available.connect(_on_chain_jump_available)
	game_manager.undo_available_changed.connect(_on_undo_available_changed)
	game_manager.undo_performed.connect(_on_undo_performed)
	
	board.cell_clicked.connect(_on_cell_clicked)
	
	game_over_panel.visible = false
	confirm_dialog.visible = false
	
	# Web 平台不支持关闭游戏，隐藏关闭按钮
	var close_btn = get_node_or_null("UI/UIRoot/CloseBtn")
	if close_btn and OS.has_feature("web"):
		close_btn.visible = false
	
	# 加载音频资源
	if bgm_player:
		var bgm = load("res://assets/sound/backgroung.mp3")
		if bgm:
			bgm_player.stream = bgm
			bgm_player.play()
	
	if meow_player:
		var meow = load("res://assets/sound/cat-meow.wav")
		if meow:
			meow_player.stream = meow
	
	if hiss_player:
		var hiss = load("res://assets/sound/cat-hissing.wav")
		if hiss:
			hiss_player.stream = hiss
	
	# 从主菜单获取棋盘类型
	var board_type = GameManager.BoardType.ENGLISH_33  # 默认英式33格
	if get_tree().has_meta("game_data"):
		var game_data = get_tree().get_meta("game_data")
		if game_data.has("board_type"):
			board_type = game_data["board_type"]
	
	# 设置棋盘类型（游戏逻辑和显示）
	game_manager.set_board_type(board_type)
	# 同步设置棋盘显示的类型
	var display_board_type = Board.BoardType.ENGLISH_33
	if board_type == GameManager.BoardType.FRENCH_37:
		display_board_type = Board.BoardType.FRENCH_37
	board.set_board_type(display_board_type)
	
	_create_pegs()
	_center_board()

func _center_board() -> void:
	# 将棋盘居中
	var viewport_size = get_viewport_rect().size
	var board_size = Vector2(7, 7) * board.cell_size
	board.position = (viewport_size - board_size) / 2
	pegs_container.position = board.position

func _create_pegs() -> void:
	# 清除现有棋子
	for peg in pegs.values():
		peg.queue_free()
	pegs.clear()
	
	var cat_index = 0
	
	for y in range(GameManager.BOARD_SIZE):
		for x in range(GameManager.BOARD_SIZE):
			var pos = Vector2i(x, y)
			if game_manager.has_peg(pos):
				var peg = _create_peg(pos, cat_index % CAT_TYPES.size())
				pegs[pos] = peg
				cat_index += 1

func _create_peg(pos: Vector2i, cat_type_index: int) -> Peg:
	var peg_node = Node2D.new()
	peg_node.set_script(preload("res://scripts/peg.gd"))
	
	# 创建 AnimatedSprite2D
	var sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	
	# 创建 SpriteFrames
	var frames = SpriteFrames.new()
	
	# 硬编码的猫素材路径（Web 导出不支持 DirAccess）
	var cat_textures: Array[Dictionary] = [
		{"idle": "res://assets/cat/Classical/IdleCat.png", "jump": "res://assets/cat/Classical/JumpCat.png"},
		{"idle": "res://assets/cat/BlackCat/IdleCatb.png", "jump": "res://assets/cat/BlackCat/JumpCabt.png"},
		{"idle": "res://assets/cat/Brown/IdleCattt.png", "jump": "res://assets/cat/Brown/JumpCatttt.png"},
		{"idle": "res://assets/cat/White/IdleCatttt.png", "jump": "res://assets/cat/White/JumpCattttt.png"},
		{"idle": "res://assets/cat/Siamese/IdleCattt.png", "jump": "res://assets/cat/Siamese/JumpCatttt.png"},
		{"idle": "res://assets/cat/ThreeColorFree/IdleCatt.png", "jump": "res://assets/cat/ThreeColorFree/JumpCattt.png"},
		{"idle": "res://assets/cat/TigerCatFree/IdleCatt.png", "jump": "res://assets/cat/TigerCatFree/JumpCattt.png"},
	]
	
	var tex_index = cat_type_index % cat_textures.size()
	var idle_tex: Texture2D = load(cat_textures[tex_index]["idle"])
	var jump_tex: Texture2D = load(cat_textures[tex_index]["jump"])
	
	# 如果加载失败，使用默认的 Classical
	if idle_tex == null:
		idle_tex = load("res://assets/cat/Classical/IdleCat.png")
	if jump_tex == null:
		jump_tex = load("res://assets/cat/Classical/JumpCat.png")
	
	# 设置 idle 动画
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 8)
	frames.set_animation_loop("idle", true)
	_add_spritesheet_frames(frames, "idle", idle_tex, 32, 32)
	
	# 设置 jump 动画
	frames.add_animation("jump")
	frames.set_animation_speed("jump", 12)
	frames.set_animation_loop("jump", true)
	_add_spritesheet_frames(frames, "jump", jump_tex, 32, 32)
	
	sprite.sprite_frames = frames
	sprite.play("idle")
	sprite.scale = Vector2(1.2, 1.2)
	
	peg_node.add_child(sprite)
	
	# 创建点击区域
	var click_area = Area2D.new()
	click_area.name = "ClickArea"
	
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 16
	collision.shape = shape
	click_area.add_child(collision)
	
	peg_node.add_child(click_area)
	
	# 设置位置
	peg_node.position = Vector2(pos.x * board.cell_size.x, pos.y * board.cell_size.y) + board.cell_size / 2
	peg_node.set("board_position", pos)
	
	pegs_container.add_child(peg_node)
	
	# 连接信号
	click_area.input_event.connect(func(_viewport, event, _shape_idx):
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_on_peg_clicked(peg_node)
	)
	
	return peg_node

func _add_spritesheet_frames(frames: SpriteFrames, anim_name: String, texture: Texture2D, frame_width: int, frame_height: int) -> void:
	if texture == null:
		return
	
	var tex_width = texture.get_width()
	var tex_height = texture.get_height()
	var cols = tex_width / frame_width
	var rows = tex_height / frame_height
	
	for row in range(rows):
		for col in range(cols):
			var atlas_tex = AtlasTexture.new()
			atlas_tex.atlas = texture
			atlas_tex.region = Rect2(col * frame_width, row * frame_height, frame_width, frame_height)
			frames.add_frame(anim_name, atlas_tex)

func _on_peg_clicked(peg: Node2D) -> void:
	var pos: Vector2i = peg.get("board_position")
	_handle_interaction(pos)

func _on_cell_clicked(pos: Vector2i) -> void:
	_handle_interaction(pos)

func _handle_interaction(pos: Vector2i) -> void:
	var selected_pos = game_manager.get_selected_peg()
	
	# 处于连跳状态时的特殊逻辑
	if game_manager.is_in_chain_jump():
		var chain_pos = game_manager.get_chain_jump_pos()
		
		if pos == chain_pos:
			# 点击当前连跳的棋子，结束连跳
			game_manager.end_chain_jump()
			_update_selection()
			return
		elif game_manager.can_move(chain_pos, pos):
			# 继续连跳
			_execute_move(chain_pos, pos)
			return
		else:
			# 连跳中不允许其他操作
			_play_hiss()
			return
	
	# 正常状态的操作逻辑
	if selected_pos == Vector2i(-1, -1):
		# 没有选中棋子，尝试选中
		if game_manager.has_peg(pos):
			game_manager.select_peg(pos)
			_update_selection()
			_play_meow()
		else:
			# 点击空白格子，无效操作
			_play_hiss()
	else:
		if pos == selected_pos:
			# 取消选中
			game_manager.deselect_peg()
			_update_selection()
		elif game_manager.has_peg(pos):
			# 选择另一个棋子
			game_manager.deselect_peg()
			game_manager.select_peg(pos)
			_update_selection()
			_play_meow()
		elif game_manager.can_move(selected_pos, pos):
			# 执行移动
			_execute_move(selected_pos, pos)
		else:
			# 无效移动
			_play_hiss()

func _update_selection() -> void:
	var selected_pos = game_manager.get_selected_peg()
	
	# 重置所有棋子状态
	for peg_pos in pegs:
		var peg = pegs[peg_pos]
		if peg and is_instance_valid(peg):
			peg.modulate = Color.WHITE
	
	# 清除高亮
	board.clear_highlights()
	
	if selected_pos != Vector2i(-1, -1):
		# 高亮选中的棋子
		if pegs.has(selected_pos):
			var selected_peg = pegs[selected_pos]
			if selected_peg and is_instance_valid(selected_peg):
				selected_peg.modulate = Color(1.3, 1.3, 0.7)
		
		# 高亮可移动位置
		var valid_moves = game_manager.get_valid_moves(selected_pos)
		board.set_highlighted_cells(valid_moves)

func _execute_move(from_pos: Vector2i, to_pos: Vector2i) -> void:
	var middle_pos = (from_pos + to_pos) / 2
	
	# 移动棋子
	var moving_peg = pegs[from_pos]
	var removed_peg = pegs[middle_pos]
	
	# 更新游戏状态（不再调用 deselect_peg，make_move 会处理）
	game_manager.make_move(from_pos, to_pos)
	
	# 更新棋子字典
	pegs.erase(from_pos)
	pegs.erase(middle_pos)
	pegs[to_pos] = moving_peg
	
	# 动画：移动棋子
	if moving_peg and is_instance_valid(moving_peg):
		var sprite = moving_peg.get_node("AnimatedSprite2D") as AnimatedSprite2D
		if sprite:
			sprite.play("jump")
		
		var target_pos = Vector2(to_pos.x * board.cell_size.x, to_pos.y * board.cell_size.y) + board.cell_size / 2
		var start_pos = moving_peg.position
		
		var tween = create_tween()
		tween.set_ease(Tween.EASE_OUT)
		tween.set_trans(Tween.TRANS_QUAD)
		
		# 跳跃动画
		var mid_y = min(start_pos.y, target_pos.y) - 30
		
		tween.tween_method(
			func(t: float):
				var x = lerp(start_pos.x, target_pos.x, t)
				var y: float
				if t < 0.5:
					y = lerp(start_pos.y, mid_y, t * 2)
				else:
					y = lerp(mid_y, target_pos.y, (t - 0.5) * 2)
				moving_peg.position = Vector2(x, y),
			0.0, 1.0, 0.3
		)
		
		tween.tween_callback(func():
			moving_peg.set("board_position", to_pos)
			if sprite:
				sprite.play("idle")
		)
	
	# 动画：移除被吃的棋子
	if removed_peg and is_instance_valid(removed_peg):
		var remove_tween = create_tween()
		remove_tween.tween_property(removed_peg, "scale", Vector2.ZERO, 0.2)
		remove_tween.tween_property(removed_peg, "modulate:a", 0.0, 0.1)
		remove_tween.tween_callback(removed_peg.queue_free)

func _on_chain_jump_available(pos: Vector2i, can_continue: bool) -> void:
	# 延迟更新选中状态，等待动画完成
	await get_tree().create_timer(0.35).timeout
	_update_selection()
	
	if can_continue:
		# 可以继续连跳，播放提示音
		_play_meow()

func _on_move_count_changed(count: int) -> void:
	if move_count_label:
		move_count_label.text = "步数: " + str(count)

func _on_peg_count_changed(count: int) -> void:
	if peg_count_label:
		peg_count_label.text = "剩余棋子: " + str(count)

func _on_game_over(remaining: int, rating: String) -> void:
	if game_over_panel:
		game_over_panel.visible = true
	if game_over_rating:
		game_over_rating.text = "评级: " + rating
	if game_over_count:
		game_over_count.text = "剩余棋子: " + str(remaining)
	
	if rating_label:
		rating_label.text = rating

func _play_meow() -> void:
	if meow_player and not meow_player.playing:
		meow_player.play()

func _play_hiss() -> void:
	if hiss_player:
		hiss_player.play()

func _on_restart_pressed() -> void:
	# 显示确认弹窗
	pending_confirm_action = ConfirmAction.RESTART
	confirm_message.text = "确定要重新开始吗？"
	confirm_dialog.visible = true

func _on_close_pressed() -> void:
	get_tree().quit()

func _on_about_pressed() -> void:
	if about_panel:
		about_panel.visible = true

func _on_close_about_pressed() -> void:
	if about_panel:
		about_panel.visible = false

func _on_menu_pressed() -> void:
	# 显示确认弹窗
	pending_confirm_action = ConfirmAction.MENU
	confirm_message.text = "确定要返回主菜单吗？"
	confirm_dialog.visible = true

func _on_confirm_yes_pressed() -> void:
	confirm_dialog.visible = false
	match pending_confirm_action:
		ConfirmAction.RESTART:
			game_manager.reset_game()
			game_over_panel.visible = false
			_create_pegs()
			_update_selection()
		ConfirmAction.MENU:
			get_tree().change_scene_to_file("res://scenes/menu.tscn")

func _on_confirm_no_pressed() -> void:
	confirm_dialog.visible = false

func _on_undo_pressed() -> void:
	if game_manager.can_undo():
		game_manager.undo_move()

func _on_undo_available_changed(can_undo: bool) -> void:
	if undo_btn:
		undo_btn.disabled = not can_undo

func _on_undo_performed() -> void:
	# 撤销后重新创建棋子显示
	_create_pegs()
	_update_selection()
