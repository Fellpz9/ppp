extends Node2D

@onready var platform_manager: Node2D = $PlatformManager
@onready var powerup_manager: Node2D = $PowerUpManager
@onready var hand_controller: Node2D = $HandController
@onready var hud: CanvasLayer = $HUD
@onready var character_spawn: Marker2D = $CharacterSpawn
@onready var background: ColorRect = $Background

@export var character_scene: PackedScene

var character: CharacterBody2D = null

func _ready() -> void:
	# Wire up references
	hand_controller.platform_manager = platform_manager
	powerup_manager.hand_ref = hand_controller
	
	NetworkManager.game_action_received.connect(_on_network_action)
	if NetworkManager.my_role == "character":
		hand_controller.set_process(false)
		hand_controller.visible = true
	# Connect signals
	GameManager.round_started.connect(_on_round_started)
	GameManager.round_ended.connect(_on_round_ended)
	GameManager.game_over.connect(_on_game_over)
	
	# Start!
	GameManager.start_game()

func _process(delta: float) -> void:
	GameManager.tick(delta)

func _on_round_started(round_number: int) -> void:
	# Rebuild the scene for the new round
	_spawn_character()
	powerup_manager.clear_all_pickups()
	
	# Increase difficulty visually: tint background redder each round
	var t = float(round_number - 1) / float(GameManager.MAX_ROUNDS - 1)
	var tween = create_tween()
	tween.tween_property(background, "color", 
		Color(0.06 + t * 0.15, 0.06, 0.12), 1.0)

func _on_round_ended(_winner: int) -> void:
	# Brief pause before announcing
	pass

func _on_game_over(_winner: int) -> void:
	# Disable inputs
	hand_controller.set_process(false)
	if is_instance_valid(character):
		character.set_physics_process(false)

func _spawn_character() -> void:
	# Remove old character if exists
	if is_instance_valid(character):
		character.queue_free()
	
	if character_scene != null:
		character = character_scene.instantiate()
	else:
		character = _create_code_character()
	
	add_child(character)
	character.position = character_spawn.position
	character.add_to_group("character")
	character.died.connect(_on_character_died)
	powerup_manager.character_ref = character

func _on_character_died() -> void:
	GameManager.player_died()
	# Respawn if still alive
	if GameManager.player_lives > 0:
		await get_tree().create_timer(1.0).timeout
		if GameManager.game_active:
			_spawn_character()

func _create_code_character() -> CharacterBody2D:
	# Fallback character using code (no scene file needed to test)
	var body = CharacterBody2D.new()
	body.set_script(load("res://scripts/Character.gd"))
	
	# Collision
	var shape = CollisionShape2D.new()
	var capsule = CapsuleShape2D.new()
	capsule.radius = 12
	capsule.height = 28
	shape.shape = capsule
	body.add_child(shape)
	
	# Visual placeholder (replace with your sprite)
	var sprite = AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	# You'll add your spritesheet frames here
	body.add_child(sprite)
	
	# Fallback: colored rect until sprites are added
	var rect = ColorRect.new()
	rect.size = Vector2(24, 40)
	rect.position = Vector2(-12, -20)
	rect.color = Color(0.2, 0.7, 1.0)
	body.add_child(rect)
	
	# Timers required by Character.gd
	var inv_timer = Timer.new()
	inv_timer.name = "InvincibleTimer"
	inv_timer.one_shot = true
	body.add_child(inv_timer)
	
	var spd_timer = Timer.new()
	spd_timer.name = "SpeedTimer"
	spd_timer.one_shot = true
	body.add_child(spd_timer)
	
	return body

func _on_network_action(action: String, payload: Dictionary):
	# Se a Mão fez algo, o Personagem precisa ver a plataforma aparecendo/sumindo
	if action == "place_platform":
		platform_manager.place_platform(Vector2i(payload.x, payload.y), payload.get("spikes", false))
		
	elif action == "remove_platform":
		platform_manager.remove_platform(Vector2i(payload.x, payload.y))
		
	elif action == "shake_platform":
		platform_manager.shake_platform(Vector2i(payload.x, payload.y))
		
	elif action == "tilt_platform":
		platform_manager.tilt_platform(Vector2i(payload.x, payload.y))
	
	elif action == "sync_hand" and NetworkManager.my_role == "character":
		hand_controller.position = Vector2(payload.x, payload.y)
		
	# Se o Personagem se moveu, a Mão precisa ver ele andando
	elif action == "sync_char" and NetworkManager.my_role == "hands":
		if is_instance_valid(character):
			character.position = Vector2(payload.x, payload.y)
			character.sprite.animation = payload.anim
			character.sprite.flip_h = payload.flip

	elif action == "spawn_powerup" and NetworkManager.my_role == "hands":
		powerup_manager.spawn_from_network(payload.id, payload.type, Vector2(payload.x, payload.y), payload.for_char)
		
	elif action == "collect_powerup":
		powerup_manager.collect_from_network(payload.id)
