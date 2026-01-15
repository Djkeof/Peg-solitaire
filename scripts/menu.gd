extends Control

## Menu - 主菜单控制脚本

@onready var about_panel: Panel = $AboutPanel

func _ready() -> void:
	about_panel.visible = false

func _on_english_33_btn_pressed() -> void:
	_start_game(GameManager.BoardType.ENGLISH_33)

func _on_french_37_btn_pressed() -> void:
	_start_game(GameManager.BoardType.FRENCH_37)

func _start_game(board_type: GameManager.BoardType) -> void:
	# 使用全局变量传递棋盘类型
	var game_data = {
		"board_type": board_type
	}
	# 保存到自动加载的单例或使用 meta
	get_tree().set_meta("game_data", game_data)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_about_btn_pressed() -> void:
	about_panel.visible = true

func _on_close_about_btn_pressed() -> void:
	about_panel.visible = false
