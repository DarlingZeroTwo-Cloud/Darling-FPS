extends Node3D

# 游戏主控制器
# 生成地图、管理敌人、HUD更新

@onready var player: CharacterBody3D = $Player
@onready var health_label: Label = $HUD/HealthLabel
@onready var ammo_label: Label = $HUD/AmmoLabel
@onready var score_label: Label = $HUD/ScoreLabel
@onready var hit_marker: Label = $HUD/HitMarker
@onready var damage_overlay: ColorRect = $HUD/DamageOverlay
@onready var touch_controls: Control = $HUD/TouchControls
@onready var fire_btn: Button = $HUD/TouchControls/FireButton
@onready var aim_btn: Button = $HUD/TouchControls/AimButton
@onready var jump_btn: Button = $HUD/TouchControls/JumpButton
@onready var reload_btn: Button = $HUD/TouchControls/ReloadButton

var enemies: Array = []
var is_touch_device: bool = false

func _ready() -> void:
	is_touch_device = DisplayServer.get_name() == "android" or DisplayServer.get_name() == "ios"
	
	if is_touch_device:
		touch_controls.visible = true
		_setup_touch_buttons()
	
	# 连接玩家信号
	player.ammo_changed.connect(_on_ammo_changed)
	player.health_changed.connect(_on_health_changed)
	player.score_changed.connect(_on_score_changed)
	player.hit_marker.connect(_show_hit_marker)
	player.damaged.connect(_show_damage)
	player.died.connect(_on_player_died)
	
	# 生成地图
	_generate_map()
	
	# 生成敌人
	_spawn_enemies(12)

# ========== 地图生成 ==========

func _generate_map() -> void:
	# 地面 - 混凝土
	var ground = _create_box(Vector3(100, 0.5, 100), Vector3(0, -0.25, 0), Color(0.4, 0.4, 0.42))
	add_child(ground)
	
	# === 仓库建筑 ===
	# 主仓库（左侧）
	_create_building(Vector3(-25, 0, -10), Vector3(20, 8, 15), Color(0.5, 0.45, 0.4))
	
	# 右侧仓库
	_create_building(Vector3(25, 0, -5), Vector3(18, 6, 12), Color(0.45, 0.45, 0.48))
	
	# 后方仓库
	_create_building(Vector3(0, 0, -30), Vector3(30, 7, 10), Color(0.48, 0.42, 0.38))
	
	# === 集装箱 ===
	# 蓝色集装箱组
	_create_container(Vector3(-15, 0, 5), Color(0.15, 0.35, 0.7))
	_create_container(Vector3(-15, 2.6, 5), Color(0.15, 0.35, 0.7))  # 叠起来
	_create_container(Vector3(-10, 0, 5), Color(0.15, 0.35, 0.7))
	
	# 红色集装箱
	_create_container(Vector3(15, 0, 8), Color(0.7, 0.2, 0.15))
	_create_container(Vector3(20, 0, 8), Color(0.7, 0.2, 0.15))
	
	# 绿色集装箱
	_create_container(Vector3(5, 0, -15), Color(0.2, 0.5, 0.25))
	_create_container(Vector3(5, 2.6, -15), Color(0.2, 0.5, 0.25))
	
	# 黄色集装箱
	_create_container(Vector3(-5, 0, -20), Color(0.8, 0.65, 0.1))
	
	# === 装卸平台 ===
	var platform = _create_box(Vector3(12, 1, 4), Vector3(-20, 0.5, 15), Color(0.55, 0.55, 0.55))
	add_child(platform)
	
	# === 卡车 ===
	_create_truck(Vector3(20, 0, 18), Color(0.8, 0.8, 0.8))
	
	# === 掩体/矮墙 ===
	_create_cover(Vector3(0, 0, 0), Vector3(3, 1.2, 0.5))
	_create_cover(Vector3(-8, 0, -5), Vector3(0.5, 1.2, 3))
	_create_cover(Vector3(8, 0, -8), Vector3(0.5, 1.2, 3))
	_create_cover(Vector3(0, 0, 15), Vector3(3, 1.2, 0.5))
	
	# === 边界围墙 ===
	_create_wall(Vector3(0, 2, -45), Vector3(100, 4, 1))
	_create_wall(Vector3(-50, 2, 0), Vector3(1, 4, 90))
	_create_wall(Vector3(50, 2, 0), Vector3(1, 4, 90))

func _create_box(size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body = StaticBody3D.new()
	body.position = pos
	
	var mesh_instance = MeshInstance3D.new()
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	mesh_instance.material_override = mat
	body.add_child(mesh_instance)
	
	var col_shape = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size
	col_shape.shape = shape
	body.add_child(col_shape)
	
	return body

func _create_building(pos: Vector3, size: Vector3, color: Color) -> void:
	var building = _create_box(size, pos + Vector3(0, size.y / 2, 0), color)
	add_child(building)
	
	# 门（用深色矩形表示）
	var door = _create_box(Vector3(2, 3, 0.2), pos + Vector3(-size.x/4, 1.5, size.z/2 + 0.1), Color(0.2, 0.15, 0.1))
	add_child(door)

func _create_container(pos: Vector3, color: Color) -> void:
	var container = _create_box(Vector3(6, 2.5, 2.5), pos + Vector3(0, 1.25, 0), color)
	add_child(container)

func _create_truck(pos: Vector3, color: Color) -> void:
	# 车头
	var cab = _create_box(Vector3(2, 2, 2), pos + Vector3(0, 1, -2), Color(0.7, 0.15, 0.15))
	add_child(cab)
	
	# 货箱
	var cargo = _create_box(Vector3(2.2, 2.2, 5), pos + Vector3(0, 1.1, 1.5), color)
	add_child(cargo)

func _create_cover(pos: Vector3, size: Vector3) -> void:
	var cover = _create_box(size, pos + Vector3(0, size.y/2, 0), Color(0.5, 0.5, 0.52))
	add_child(cover)

func _create_wall(pos: Vector3, size: Vector3) -> void:
	var wall = _create_box(size, pos, Color(0.6, 0.6, 0.62))
	add_child(wall)

# ========== 敌人系统 ==========

func _spawn_enemies(count: int) -> void:
	for i in range(count):
		_spawn_enemy()

func _spawn_enemy() -> void:
	var enemy = preload("res://scenes/Enemy.tscn").instantiate()
	
	# 随机出生位置（远离玩家）
	var spawn_pos: Vector3
	match randi() % 4:
		0: spawn_pos = Vector3(randf_range(-30, 30), 0, -35)
		1: spawn_pos = Vector3(-40, 0, randf_range(-20, 20))
		2: spawn_pos = Vector3(40, 0, randf_range(-20, 20))
		_: spawn_pos = Vector3(randf_range(-30, 30), 0, 35)
	
	enemy.position = spawn_pos
	enemy.set_target(player)
	enemy.enemy_died.connect(_on_enemy_died)
	add_child(enemy)
	enemies.append(enemy)

func _on_enemy_died(enemy: Node3D) -> void:
	enemies.erase(enemy)
	player.add_kill()
	
	# 延迟重生
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree():
		_spawn_enemy()

# ========== HUD 更新 ==========

func _on_ammo_changed(current: int, reserve: int) -> void:
	ammo_label.text = "%d / %d" % [current, reserve]

func _on_health_changed(hp: int) -> void:
	health_label.text = "HP: %d" % hp
	# 低血量变红
	if hp < 30:
		health_label.modulate = Color(1, 0.3, 0.3)
	else:
		health_label.modulate = Color(1, 1, 1)

func _on_score_changed(kills: int, deaths: int) -> void:
	score_label.text = "击杀: %d | 阵亡: %d" % [kills, deaths]

func _show_hit_marker() -> void:
	hit_marker.visible = true
	var tween = create_tween()
	tween.tween_interval(0.1)
	tween.tween_callback(func(): hit_marker.visible = false)

func _show_damage() -> void:
	damage_overlay.visible = true
	var tween = create_tween()
	tween.tween_interval(0.2)
	tween.tween_callback(func(): damage_overlay.visible = false)

func _on_player_died() -> void:
	# 短暂显示死亡画面
	pass

func _setup_touch_buttons() -> void:
	fire_btn.pressed.connect(func(): player.trigger_touch_shoot())
	jump_btn.pressed.connect(func(): player.trigger_touch_jump())
	reload_btn.pressed.connect(func(): player.trigger_touch_reload())

# ========== 触屏控制 ==========

func _unhandled_input(event: InputEvent) -> void:
	if not is_touch_device:
		return
	
	# 虚拟摇杆
	if event is InputEventScreenTouch:
		if event.index == 0 and event.position.x < 200 and event.position.y > 300:
			# 摇杆开始
			pass
	
	if event is InputEventScreenDrag:
		if event.index == 0:
			var joy_delta: Vector2 = event.relative * 0.02
			joy_delta = joy_delta.limit_length(1.0)
			player.set_touch_move(Vector2(joy_delta.x, joy_delta.y))
