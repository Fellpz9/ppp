extends Node2D

# HandController.gd
# Player 2 controls: Mouse + Mouse Buttons (or gamepad)
# Left click: grab/place platform
# Right click: remove platform
# Scroll wheel or Q/E: cycle platform types

signal powerup_used(type)

const PLACE_COOLDOWN := 0.3
const REMOVE_COOLDOWN := 0.2

var selected_action := 0  # 0=place, 1=tilt, 2=shake
var place_cooldown_timer := 0.0
var remove_cooldown_timer := 0.0

# Power-up states
var active_powerups := []
var rapid_fire := false
var spike_mode := false

# References
var platform_manager: Node2D
var cursor_indicator: Node2D

@onready var hand_sprite: Sprite2D = $Sprite2D
@onready var action_cooldown: Timer = $ActionCooldownTimer

func _ready() -> void:
	# Hide system cursor, we'll draw our own
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _process(delta: float) -> void:
	# Move hand to mouse position
	var mouse_pos = get_global_mouse_position()
	position = position.lerp(mouse_pos, 0.25)  # Smooth follow
	
	# Update cooldowns
	if place_cooldown_timer > 0:
		place_cooldown_timer -= delta
	if remove_cooldown_timer > 0:
		remove_cooldown_timer -= delta
	
	# Input
	_handle_input()

func _handle_input() -> void:
	if NetworkManager.my_role != "hands":
		return
		
	# Left click - place/interact
	if Input.is_action_pressed("hand_place") and place_cooldown_timer <= 0:
		_try_place_platform()
		place_cooldown_timer = 0.1 if rapid_fire else PLACE_COOLDOWN
	
	# Right click - remove
	if Input.is_action_pressed("hand_remove") and remove_cooldown_timer <= 0:
		_try_remove_platform()
		remove_cooldown_timer = REMOVE_COOLDOWN
	
	# Middle click / Q key - tilt platform
	if Input.is_action_just_pressed("hand_tilt"):
		_try_tilt_platform()
	
	# E key - shake platform
	if Input.is_action_just_pressed("hand_shake"):
		_try_shake_platform()
		
	var tempo = Time.get_ticks_msec() * 0.005
	hand_sprite.rotation_degrees = sin(tempo) * 15.0 
	
	# NOVO: Envia a posição atual para o outro jogador!
	NetworkManager.send_action("sync_hand", {"x": position.x, "y": position.y})

func _try_place_platform() -> void:
	if platform_manager == null:
		return
	var grid_pos = platform_manager.world_to_grid(get_global_mouse_position())
	platform_manager.place_platform(grid_pos, spike_mode)
	
	NetworkManager.send_action("place_platform", {"x": grid_pos.x, "y": grid_pos.y, "spikes": spike_mode})
	
	await get_tree().create_timer(0.2).timeout

func _try_remove_platform() -> void:
	if platform_manager == null:
		return
	var grid_pos = platform_manager.world_to_grid(get_global_mouse_position())
	platform_manager.remove_platform(grid_pos)
	
	NetworkManager.send_action("remove_platform", {"x": grid_pos.x, "y": grid_pos.y})

func _try_tilt_platform() -> void:
	if platform_manager == null:
		return
	var grid_pos = platform_manager.world_to_grid(get_global_mouse_position())
	platform_manager.tilt_platform(grid_pos)
	
	NetworkManager.send_action("tilt_platform", {"x": grid_pos.x, "y": grid_pos.y})

func _try_shake_platform() -> void:
	if platform_manager == null:
		return
	var grid_pos = platform_manager.world_to_grid(get_global_mouse_position())
	platform_manager.shake_platform(grid_pos)
	
	NetworkManager.send_action("shake_platform", {"x": grid_pos.x, "y": grid_pos.y})

func apply_powerup(type: String) -> void:
	active_powerups.append(type)
	match type:
		"rapid_fire":
			rapid_fire = true
			await get_tree().create_timer(6.0).timeout
			rapid_fire = false
			active_powerups.erase("rapid_fire")
		"spike_mode":
			spike_mode = true
			await get_tree().create_timer(8.0).timeout
			spike_mode = false
			active_powerups.erase("spike_mode")
		"earthquake":
			_do_earthquake()
		"platform_flip":
			platform_manager.flip_all_platforms()
	emit_signal("powerup_used", type)

func _do_earthquake() -> void:
	# Shake all platforms violently
	if platform_manager:
		platform_manager.earthquake()
