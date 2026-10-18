extends CharacterBody3D

# 玩家控制器
# 第一人称移动、射击、换弹

# 移动参数 - 战区手游手感调校
@export var walk_speed: float = 6.5
@export var run_speed: float = 9.0
@export var jump_velocity: float = 5.5
@export var mouse_sensitivity: float = 0.0022
@export var touch_sensitivity: float = 0.004
@export var gravity: float = 22.0
@export var acceleration: float = 12.0  # 移动加速度
@export var deceleration: float = 10.0

# 武器参数 - M4 满改
@export var max_ammo: int = 30
@export var reserve_ammo: int = 120
@export var fire_rate: float = 0.085  # M4 射速
@export var reload_time: float = 1.2  # 快速换弹
@export var damage: float = 28.0
@export var range: float = 250.0
@export var recoil_amount: float = 0.018  # 后坐力大小
@export var recoil_recovery: float = 10.0  # 后坐力恢复速度

# 内部状态
var current_ammo: int = 30
var is_reloading: bool = false
var can_shoot: bool = true
var health: int = 100
var kills: int = 0
var deaths: int = 0

# 节点引用
@onready var camera: Camera3D = $Camera3D
@onready var weapon_holder: Node3D = $Camera3D/WeaponHolder
@onready var muzzle: Node3D = $Camera3D/WeaponHolder/Muzzle

# 触屏控制状态
var touch_move_vector: Vector2 = Vector2.ZERO
var touch_look_delta: Vector2 = Vector2.ZERO
var is_touch_device: bool = false

# 后坐力
var recoil_pitch: float = 0.0
var target_recoil: float = 0.0

func _ready() -> void:
	is_touch_device = DisplayServer.get_name() == "android" or DisplayServer.get_name() == "ios"
	
	if not is_touch_device:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	current_ammo = max_ammo
	_update_hud()

func _physics_process(delta: float) -> void:
	# 重力
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	# 移动输入
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	
	# 触屏移动
	if is_touch_device:
		input_dir += touch_move_vector
	
	var direction: Vector3 = (camera.global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	direction.y = 0
	
	var speed: float = walk_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed = run_speed
	
	# 平滑加速/减速
	var target_vel: Vector3 = direction * speed
	var accel_rate: float = acceleration if input_dir.length() > 0.1 else deceleration
	velocity.x = lerp(velocity.x, target_vel.x, accel_rate * delta)
	velocity.z = lerp(velocity.z, target_vel.z, accel_rate * delta)
	
	# 跳跃
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity
	
	move_and_slide()
	
	# 后坐力恢复
	if recoil_pitch > 0:
		recoil_pitch = lerp(recoil_pitch, 0, delta * recoil_recovery)
		camera.rotation.x = recoil_pitch

func _input(event: InputEvent) -> void:
	# 鼠标视角（电脑端）
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_view(event.relative)
	
	# 触屏视角
	if event is InputEventScreenDrag and is_touch_device:
		if event.index == 1:  # 第二根手指 = 视角
			touch_look_delta = event.relative * touch_sensitivity
			_rotate_view(touch_look_delta)
	
	# 射击
	if event.is_action_pressed("shoot"):
		_shoot()
	
	# 换弹
	if event.is_action_pressed("reload"):
		_reload()

func _rotate_view(relative: Vector2) -> void:
	# 水平旋转（身体）
	rotation.y -= relative.x * mouse_sensitivity
	
	# 垂直旋转（相机）
	camera.rotation.x = clamp(camera.rotation.x - relative.y * mouse_sensitivity, -1.4, 1.4)
	# 加上后坐力
	camera.rotation.x += recoil_pitch

func _shoot() -> void:
	if is_reloading or not can_shoot:
		return
	
	if current_ammo <= 0:
		_reload()
		return
	
	current_ammo -= 1
	can_shoot = false
	
	# 后坐力（随机左右偏一点，更真实）
	recoil_pitch += recoil_amount
	camera.rotation.y += randf_range(-0.005, 0.005)
	
	# 射线检测
	var from: Vector3 = camera.global_position
	var dir: Vector3 = -camera.global_transform.basis.z
	var to: Vector3 = from + dir * range
	
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var hit_body: Node3D = result.collider
		if hit_body and hit_body.has_method("take_damage"):
			hit_body.take_damage(damage)
			# 显示命中标记
			emit_signal("hit_marker")
	
	# 武器后坐动画
	weapon_holder.position.z = -0.45
	_tween_weapon_return()
	
	_update_hud()
	
	# 射击冷却
	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true

func _tween_weapon_return() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(weapon_holder, "position:z", -0.5, 0.1).set_trans(Tween.TRANS_SPRING)

func _reload() -> void:
	if is_reloading or current_ammo == max_ammo or reserve_ammo <= 0:
		return
	
	is_reloading = true
	emit_signal("reloading_started")
	
	await get_tree().create_timer(reload_time).timeout
	
	var need: int = max_ammo - current_ammo
	var take: int = min(need, reserve_ammo)
	current_ammo += take
	reserve_ammo -= take
	is_reloading = false
	
	_update_hud()
	emit_signal("reloading_finished")

func take_damage(amount: float) -> void:
	health -= int(amount)
	emit_signal("damaged")
	
	if health <= 0:
		die()

func die() -> void:
	deaths += 1
	emit_signal("died")
	# 重生位置
	global_position = Vector3(0, 2, 10)
	health = 100
	_update_hud()

func add_kill() -> void:
	kills += 1
	_update_hud()

func _update_hud() -> void:
	# 更新HUD（通过信号通知游戏场景）
	emit_signal("ammo_changed", current_ammo, reserve_ammo)
	emit_signal("health_changed", health)
	emit_signal("score_changed", kills, deaths)

# 信号
signal hit_marker()
signal reloading_started()
signal reloading_finished()
signal damaged()
signal died()
signal ammo_changed(current, reserve)
signal health_changed(hp)
signal score_changed(kills, deaths)

# 触屏控制接口（供HUD按钮调用）
func set_touch_move(vector: Vector2) -> void:
	touch_move_vector = vector

func trigger_touch_shoot() -> void:
	_shoot()

func trigger_touch_reload() -> void:
	_reload()

func trigger_touch_jump() -> void:
	if is_on_floor():
		velocity.y = jump_velocity
