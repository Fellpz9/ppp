extends Node2D

# PowerUpManager.gd
# Spawns and manages power-ups for both players

signal powerup_spawned(type, for_player)

# Power-ups for Character (Player 1)
const CHARACTER_POWERUPS := ["invincible", "speed", "double_jump"]
# Power-ups for Hands (Player 2)
const HANDS_POWERUPS := ["rapid_fire", "spike_mode", "earthquake", "platform_flip"]

@export var powerup_scene: PackedScene
@export var spawn_interval_base := 8.0  # seconds between spawns

var spawn_timer := 0.0
var active_pickups: Array = []
var character_ref: Node2D = null
var hand_ref: Node2D = null

func _ready() -> void:
	spawn_timer = spawn_interval_base

func _process(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0:
		_spawn_powerup()
		# Interval gets shorter as rounds progress
		var difficulty = GameManager.get_round_difficulty()
		spawn_timer = spawn_interval_base / difficulty

func _spawn_powerup() -> void:
	# Alternate between spawning for character and hands
	var for_character = randf() > 0.4  # Slightly more hand powerups
	var type: String
	var pos: Vector2
	
	if for_character:
		type = CHARACTER_POWERUPS[randi() % CHARACTER_POWERUPS.size()]
		pos = _get_platform_spawn_pos()
	else:
		type = HANDS_POWERUPS[randi() % HANDS_POWERUPS.size()]
		pos = _get_hands_spawn_pos()
	
	_create_pickup(type, pos, for_character)
	emit_signal("powerup_spawned", type, "character" if for_character else "hands")

func _create_pickup(type: String, pos: Vector2, for_character: bool) -> void:
	var pickup: Node2D
	
	if powerup_scene != null:
		pickup = powerup_scene.instantiate()
	else:
		pickup = _create_code_pickup(type, for_character)
	
	pickup.position = pos
	pickup.set_meta("powerup_type", type)
	pickup.set_meta("for_character", for_character)
	add_child(pickup)
	active_pickups.append(pickup)
	
	# Auto-despawn after 10 seconds
	var despawn = get_tree().create_timer(10.0)
	despawn.timeout.connect(func():
		if is_instance_valid(pickup):
			pickup.queue_free()
			active_pickups.erase(pickup)
	)

func _create_code_pickup(type: String, for_character: bool) -> Area2D:
	var area = Area2D.new()
	
	var shape = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = 16.0
	shape.shape = circle
	area.add_child(shape)
	
	var visual = ColorRect.new()
	visual.size = Vector2(24, 24)
	visual.position = Vector2(-12, -12)
	visual.color = Color(0.2, 0.9, 0.3) if for_character else Color(0.9, 0.4, 0.1)
	area.add_child(visual)
	
	# Label for type
	var label = Label.new()
	label.text = type.substr(0, 3).to_upper()
	label.position = Vector2(-12, -30)
	label.add_theme_font_size_override("font_size", 10)
	area.add_child(label)
	
	# Bob animation
	var tween = create_tween().set_loops()
	tween.tween_property(area, "position:y", area.position.y - 8, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(area, "position:y", area.position.y, 0.6).set_trans(Tween.TRANS_SINE)
	
	area.body_entered.connect(func(body):
		_on_pickup_body_entered(area, body)
	)
	
	return area

func _on_pickup_body_entered(pickup: Area2D, body: Node) -> void:
	var type = pickup.get_meta("powerup_type")
	var for_character = pickup.get_meta("for_character")
	
	if for_character and body.is_in_group("character"):
		body.apply_powerup(type)
		pickup.queue_free()
		active_pickups.erase(pickup)
	elif not for_character and body.is_in_group("hand"):
		body.apply_powerup(type)
		pickup.queue_free()
		active_pickups.erase(pickup)

func _get_platform_spawn_pos() -> Vector2:
	# Spawn on a random platform surface
	var viewport_size = get_viewport_rect().size
	return Vector2(
		randf_range(80, viewport_size.x - 80),
		randf_range(100, viewport_size.y - 150)
	)

func _get_hands_spawn_pos() -> Vector2:
	# Spawn at a position reachable by the hand cursor
	var viewport_size = get_viewport_rect().size
	return Vector2(
		randf_range(40, viewport_size.x - 40),
		randf_range(40, viewport_size.y - 40)
	)

func clear_all_pickups() -> void:
	for pickup in active_pickups:
		if is_instance_valid(pickup):
			pickup.queue_free()
	active_pickups.clear()
