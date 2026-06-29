extends CharacterBody2D

# Character.gd
# Player 1 controls: WASD or Arrow Keys

signal died
signal powerup_collected(type)

const SPEED := 200.0
const JUMP_VELOCITY := -420.0
const GRAVITY := 980.0
const COYOTE_TIME := 0.1
const JUMP_BUFFER_TIME := 0.1

# Power-up states
var is_invincible := false
var speed_boost := 1.0
var double_jump_available := false
var has_double_jumped := false

var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var is_alive := true

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var invincible_timer: Timer = $InvincibleTimer
@onready var speed_timer: Timer = $SpeedTimer

func _ready() -> void:
	invincible_timer.timeout.connect(_on_invincible_end)
	speed_timer.timeout.connect(_on_speed_end)

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	
	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		coyote_timer -= delta
	else:
		coyote_timer = COYOTE_TIME
		has_double_jumped = false
	
	# Jump buffer
	if jump_buffer_timer > 0:
		jump_buffer_timer -= delta
	
	# Horizontal movement
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * SPEED * speed_boost
	
	# Flip sprite
	if direction != 0:
		sprite.flip_h = direction < 0
	
	# Jump input buffering
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = JUMP_BUFFER_TIME
	
	# Jump logic
	if jump_buffer_timer > 0:
		if coyote_timer > 0 or is_on_floor():
			_do_jump()
		elif double_jump_available and not has_double_jumped:
			_do_jump()
			has_double_jumped = true
			double_jump_available = false
	
	# Animate
	_update_animation(direction)
	
	move_and_slide()
	
	# Check fell off screen
	if position.y > get_viewport_rect().size.y + 100:
		die()
		
	NetworkManager.send_action("sync_char", {
		"x": position.x,
		"y": position.y,
		"anim": sprite.animation,
		"flip": sprite.flip_h
	})

func _do_jump() -> void:
	velocity.y = JUMP_VELOCITY
	jump_buffer_timer = 0.0
	coyote_timer = 0.0

func _update_animation(direction: float) -> void:
	if not is_on_floor():
		#print("jumped")
		sprite.play("jump")
	elif direction != 0:
		#print("run")
		sprite.play("run")
	else:
		#print("idle")
		sprite.play("idle")

func die() -> void:
	if is_invincible or not is_alive:
		return
	is_alive = false
#	sprite.play("die")
	emit_signal("died")
	await get_tree().create_timer(0.5).timeout
	queue_free()

func respawn(spawn_pos: Vector2) -> void:
	is_alive = true
	position = spawn_pos
	velocity = Vector2.ZERO
	# Brief invincibility on respawn
	apply_powerup("invincible")

func apply_powerup(type: String) -> void:
	match type:
		"invincible":
			is_invincible = true
			invincible_timer.start(3.0)
			_flash_invincible()
		"speed":
			speed_boost = 1.6
			speed_timer.start(5.0)
		"double_jump":
			double_jump_available = true
	emit_signal("powerup_collected", type)

func _flash_invincible() -> void:
	if not is_invincible:
		sprite.modulate.a = 1.0
		return
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "modulate:a", 0.3, 0.15)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.15)
	invincible_timer.timeout.connect(func(): tween.kill(); sprite.modulate.a = 1.0, CONNECT_ONE_SHOT)

func _on_invincible_end() -> void:
	is_invincible = false

func _on_speed_end() -> void:
	speed_boost = 1.0
