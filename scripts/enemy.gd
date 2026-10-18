extends CharacterBody3D

# 敌人AI控制器
# 巡逻、追击、射击玩家

@export var max_health: float = 100.0
@export var move_speed: float = 3.0
@export var chase_speed: float = 5.0
@export var attack_range: float = 30.0
@export var stop_range: float = 15.0
@export var attack_damage: float = 8.0
@export var attack_rate: float = 1.0  # 秒/次
@export var gravity: float = 20.0

var health: float = 100.0
var target: Node3D = null
var can_attack: bool = true
var state: String = "patrol"  # patrol / chase / attack
var patrol_point: Vector3 = Vector3.ZERO
var patrol_timer: float = 0.0
var walk_phase: float = 0.0

@onready var left_leg: MeshInstance3D = $LeftLeg
@onready var right_leg: MeshInstance3D = $RightLeg

func _ready() -> void:
	health = max_health
	_pick_new_patrol_point()

func set_target(t: Node3D) -> void:
	target = t

func _physics_process(delta: float) -> void:
	# 重力
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	if not target or not is_instance_valid(target):
		return
	
	var dist_to_target: float = global_position.distance_to(target.global_position)
	
	# 状态切换
	if dist_to_target < attack_range:
		state = "chase"
	else:
		state = "patrol"
	
	# 行为
	match state:
		"patrol":
			_do_patrol(delta)
		"chase":
			_do_chase(delta, dist_to_target)
		"attack":
			_do_attack(delta, dist_to_target)
	
	# 走路动画
	if velocity.length() > 0.5:
		walk_phase += delta * 8
		left_leg.position.y = 0.4 + sin(walk_phase) * 0.1
		right_leg.position.y = 0.4 + sin(walk_phase + PI) * 0.1
	
	move_and_slide()

func _do_patrol(delta: float) -> void:
	# 巡逻：走向巡逻点，到了就换一个
	var dir: Vector3 = patrol_point - global_position
	dir.y = 0
	dir = dir.normalized()
	
	if global_position.distance_to(patrol_point) < 2.0:
		patrol_timer -= delta
		if patrol_timer <= 0:
			_pick_new_patrol_point()
		velocity.x = 0
		velocity.z = 0
	else:
		velocity.x = dir.x * move_speed
		velocity.z = dir.z * move_speed
		# 面向移动方向
		look_at(Vector3(patrol_point.x, global_position.y, patrol_point.z), Vector3.UP)

func _do_chase(delta: float, dist: float) -> void:
	if dist > stop_range:
		# 追上去
		var dir: Vector3 = target.global_position - global_position
		dir.y = 0
		dir = dir.normalized()
		
		velocity.x = dir.x * chase_speed
		velocity.z = dir.z * chase_speed
	else:
		# 停下，攻击
		state = "attack"
		velocity.x = 0
		velocity.z = 0
	
	# 面向玩家
	look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)

func _do_attack(delta: float, dist: float) -> void:
	# 面向玩家
	look_at(Vector3(target.global_position.x, global_position.y, target.global_position.z), Vector3.UP)
	
	# 太远就追
	if dist > attack_range:
		state = "chase"
		return
	
	# 射击
	if can_attack:
		can_attack = false
		_attack_player()
		await get_tree().create_timer(attack_rate).timeout
		can_attack = true

func _attack_player() -> void:
	if target and target.has_method("take_damage"):
		# 简单的命中判定（有概率打不中）
		if randf() < 0.6:  # 60%命中率
			target.take_damage(attack_damage)

func _pick_new_patrol_point() -> void:
	# 在附近随机选一个巡逻点
	var angle: float = randf() * TAU
	var radius: float = randf_range(10, 25)
	patrol_point = Vector3(
		global_position.x + cos(angle) * radius,
		0,
		global_position.z + sin(angle) * radius
	)
	patrol_timer = randf_range(3, 6)

func take_damage(amount: float) -> void:
	health -= amount
	
	# 受伤后立刻追击玩家
	state = "chase"
	
	if health <= 0:
		die()

func die() -> void:
	emit_signal("enemy_died", self)
	queue_free()

# 信号
signal enemy_died(enemy)
