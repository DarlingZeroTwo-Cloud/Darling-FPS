extends Control

# 主菜单控制器
# 处理菜单按钮点击和场景切换

@onready var start_button: Button = $MenuContainer/StartButton
@onready var mode_button: Button = $MenuContainer/ModeButton
@onready var room_button: Button = $MenuContainer/CustomRoomButton
@onready var settings_button: Button = $MenuContainer/SettingsButton

func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	mode_button.pressed.connect(_on_mode_pressed)
	room_button.pressed.connect(_on_room_pressed)
	settings_button.pressed.connect(_on_settings_pressed)

func _on_start_pressed() -> void:
	# 直接开始人机团战模式
	change_scene_to_game()

func _on_mode_pressed() -> void:
	# 模式选择（暂时只有人机团战）
	show_message("当前模式：人机团战\n（更多模式即将开放）")

func _on_room_pressed() -> void:
	# 自建房间（先留按钮功能）
	show_message("自建房间功能开发中...\n敬请期待")

func _on_settings_pressed() -> void:
	show_settings_dialog()

func change_scene_to_game() -> void:
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func show_message(text: String) -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "提示"
	dialog.dialog_text = text
	dialog.ok_button_text = "确定"
	add_child(dialog)
	dialog.popup_centered()

func show_settings_dialog() -> void:
	var dialog = AcceptDialog.new()
	dialog.title = "设置"
	dialog.dialog_text = "设置功能开发中...\n\n当前默认配置：\n- 灵敏度：中等\n- 画质：自动\n- 音量：100%"
	dialog.ok_button_text = "确定"
	add_child(dialog)
	dialog.popup_centered()
