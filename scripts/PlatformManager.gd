extends Node2D

# PlatformManager.gd
# Manages the grid of platforms that the Hand player manipulates

const GRID_COLS := 12
const GRID_ROWS := 8
const CELL_SIZE := Vector2(80, 32)
@export var GRID_ORIGIN := Vector2(160, 300)

# Platform scene to instance
@export var platform_scene: PackedScene
@export var spike_platform_scene: PackedScene

# Grid stores platform nodes (null = empty)
var grid: Array = []

func _ready() -> void:
	_init_grid()
	_create_default_layout()

func _init_grid() -> void:
	grid = []
	for row in range(GRID_ROWS):
		grid.append([])
		for col in range(GRID_COLS):
			grid[row].append(null)

func _create_default_layout() -> void:
	# Starting platform layout - a few rows to give the character somewhere to stand
	var default_rows = [6, 4, 2]
	for row in default_rows:
		for col in range(GRID_COLS):
			if col % 3 != 1:  # gaps in platforms
				_place_at(row, col, false)

func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local = world_pos - GRID_ORIGIN
	var col = int(local.x / CELL_SIZE.x)
	var row = int(local.y / CELL_SIZE.y)
	col = clamp(col, 0, GRID_COLS - 1)
	row = clamp(row, 0, GRID_ROWS - 1)
	return Vector2i(col, row)

func grid_to_world(grid_pos: Vector2i) -> Vector2:
	return GRID_ORIGIN + Vector2(grid_pos.x * CELL_SIZE.x, grid_pos.y * CELL_SIZE.y)

func place_platform(grid_pos: Vector2i, with_spikes: bool = false) -> void:
	var col = grid_pos.x
	var row = grid_pos.y
	if grid[row][col] != null:
		return  # Already occupied
	_place_at(row, col, with_spikes)

func _place_at(row: int, col: int, with_spikes: bool) -> void:
	var scene = spike_platform_scene if with_spikes else platform_scene
	if scene == null:
		# Fallback: create a simple platform with code
		var plat = _create_code_platform(with_spikes)
		add_child(plat)
		plat.position = grid_to_world(Vector2i(col, row))
		grid[row][col] = plat
		return
	
	var plat = scene.instantiate()
	add_child(plat)
	plat.position = grid_to_world(Vector2i(col, row))
	grid[row][col] = plat

func _create_code_platform(with_spikes: bool) -> StaticBody2D:
	var body = StaticBody2D.new()
	
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = CELL_SIZE
	shape.shape = rect
	body.add_child(shape)
	
	# Visual
	var sprite = ColorRect.new()
	sprite.size = CELL_SIZE
	sprite.position = -CELL_SIZE / 2
	sprite.color = Color(0.8, 0.2, 0.2) if with_spikes else Color(0.4, 0.6, 0.9)
	body.add_child(sprite)
	
	if with_spikes:
		body.set_meta("is_spike", true)
	
	return body

func remove_platform(grid_pos: Vector2i) -> void:
	var col = grid_pos.x
	var row = grid_pos.y
	if grid[row][col] == null:
		return
	grid[row][col].queue_free()
	grid[row][col] = null

func tilt_platform(grid_pos: Vector2i) -> void:
	var col = grid_pos.x
	var row = grid_pos.y
	var plat = grid[row][col]
	if plat == null:
		return
	
	# Tilt 15 degrees and slide the character off
	var tween = create_tween()
	tween.tween_property(plat, "rotation_degrees", 20.0, 0.3)
	tween.tween_property(plat, "rotation_degrees", 0.0, 0.3)

func shake_platform(grid_pos: Vector2i) -> void:
	var col = grid_pos.x
	var row = grid_pos.y
	var plat = grid[row][col]
	if plat == null:
		return
	
	var original_pos = plat.position
	var tween = create_tween()
	for i in range(6):
		tween.tween_property(plat, "position", original_pos + Vector2(randf_range(-8, 8), 0), 0.05)
	tween.tween_property(plat, "position", original_pos, 0.05)

func flip_all_platforms() -> void:
	# Power-up: flip platform positions vertically (chaos!)
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var plat = grid[row][col]
			if plat != null:
				var tween = create_tween()
				var new_row = GRID_ROWS - 1 - row
				var new_pos = grid_to_world(Vector2i(col, new_row))
				tween.tween_property(plat, "position", new_pos, 0.5)

func earthquake() -> void:
	# Shake ALL platforms
	for row in range(GRID_ROWS):
		for col in range(GRID_COLS):
			var plat = grid[row][col]
			if plat != null:
				shake_platform(Vector2i(col, row))

func clear_row(row: int) -> void:
	for col in range(GRID_COLS):
		remove_platform(Vector2i(col, row))

func get_platform_count() -> int:
	var count := 0
	for row in grid:
		for cell in row:
			if cell != null:
				count += 1
	return count
