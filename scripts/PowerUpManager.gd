extends Node2D

signal powerup_spawned(type, for_player)

const CHARACTER_POWERUPS := ["invincible", "speed", "double_jump"]
const HANDS_POWERUPS := ["rapid_fire", "spike_mode", "earthquake", "platform_flip"]

@export var powerup_scene: PackedScene
@export var spawn_interval_base := 8.0

var spawn_timer := 0.0
var active_pickups_dict := {} # Dicionário
var character_ref: Node2D = null
var hand_ref: Node2D = null
var next_id := 0

func _ready() -> void:
	spawn_timer = spawn_interval_base

func _process(delta: float) -> void:
	# Somente o "Character" (Host) toma as decisões de spawn
	if NetworkManager.my_role != "character":
		return
		
	spawn_timer -= delta
	if spawn_timer <= 0:
		_decide_and_send_powerup()
		var difficulty = GameManager.get_round_difficulty()
		spawn_timer = spawn_interval_base / difficulty

func _decide_and_send_powerup() -> void:
	var for_character = randf() > 0.4
	var type = CHARACTER_POWERUPS[randi() % CHARACTER_POWERUPS.size()] if for_character else HANDS_POWERUPS[randi() % HANDS_POWERUPS.size()]
	var pos = _get_platform_spawn_pos() if for_character else _get_hands_spawn_pos()
	next_id += 1
	
	# Avisa a rede
	NetworkManager.send_action("spawn_powerup", {
		"id": next_id, "type": type, "x": pos.x, "y": pos.y, "for_char": for_character
	})
	
	# Spawna localmente para o Host
	spawn_from_network(next_id, type, pos, for_character)

func spawn_from_network(p_id: int, p_type: String, p_pos: Vector2, p_for_char: bool) -> void:
	var pickup: Node2D
	if powerup_scene != null:
		pickup = powerup_scene.instantiate()
	else:
		pickup = _create_code_pickup(p_type, p_for_char)
	
	pickup.position = p_pos
	pickup.set_meta("id", p_id)
	pickup.set_meta("powerup_type", p_type)
	pickup.set_meta("for_character", p_for_char)
	
	add_child(pickup)
	active_pickups_dict[p_id] = pickup
	emit_signal("powerup_spawned", p_type, "character" if p_for_char else "hands")
	
	# Auto-despawn
	var despawn = get_tree().create_timer(10.0)
	despawn.timeout.connect(func():
		if is_instance_valid(pickup):
			pickup.queue_free()
			active_pickups_dict.erase(p_id)
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
	
	var label = Label.new()
	label.text = type.substr(0, 3).to_upper()
	label.position = Vector2(-12, -30)
	label.add_theme_font_size_override("font_size", 10)
	area.add_child(label)
	
	var tween = create_tween().set_loops()
	tween.tween_property(area, "position:y", area.position.y - 8, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(area, "position:y", area.position.y, 0.6).set_trans(Tween.TRANS_SINE)
	
	area.body_entered.connect(func(body): _on_pickup_body_entered(area, body))
	return area

func _on_pickup_body_entered(pickup: Area2D, body: Node) -> void:
	var p_id = pickup.get_meta("id")
	var for_char = pickup.get_meta("for_character")
	
	# O Powerup só é processado por quem tem o direito de pegá-lo
	if for_char and body.is_in_group("character") and NetworkManager.my_role == "character":
		NetworkManager.send_action("collect_powerup", {"id": p_id})
		collect_from_network(p_id)
	elif not for_char and body.is_in_group("hand") and NetworkManager.my_role == "hands":
		NetworkManager.send_action("collect_powerup", {"id": p_id})
		collect_from_network(p_id)

func collect_from_network(p_id: int) -> void:
	if active_pickups_dict.has(p_id):
		var pickup = active_pickups_dict[p_id]
		if is_instance_valid(pickup):
			var type = pickup.get_meta("powerup_type")
			var for_char = pickup.get_meta("for_character")
			
			if for_char and is_instance_valid(character_ref):
				character_ref.apply_powerup(type)
			elif not for_char and is_instance_valid(hand_ref):
				hand_ref.apply_powerup(type)
				
			pickup.queue_free()
		active_pickups_dict.erase(p_id)

func _get_platform_spawn_pos() -> Vector2:
	var viewport_size = get_viewport_rect().size
	return Vector2(randf_range(80, viewport_size.x - 80), randf_range(100, viewport_size.y - 150))

func _get_hands_spawn_pos() -> Vector2:
	var viewport_size = get_viewport_rect().size
	return Vector2(randf_range(40, viewport_size.x - 40), randf_range(40, viewport_size.y - 40))

func clear_all_pickups() -> void:
	for pickup in active_pickups_dict.values():
		if is_instance_valid(pickup):
			pickup.queue_free()
	active_pickups_dict.clear()
