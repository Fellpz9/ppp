extends Node

# GameManager.gd
# Singleton autoload - add to Project > AutoLoad as "GameManager"

signal round_started(round_number)
signal round_ended(winner)
signal game_over(final_winner)
signal lives_changed(new_lives)

const MAX_ROUNDS := 5
const PLAYER_LIVES := 3
const ROUND_TIME := 30.0  # seconds per round

var current_round := 0
var player_lives := PLAYER_LIVES
var round_timer := 0.0
var game_active := false

enum Winner { NONE, CHARACTER, HANDS }

func start_game() -> void:
	current_round = 0
	player_lives = PLAYER_LIVES
	game_active = true
	start_next_round()

func start_next_round() -> void:
	current_round += 1
	round_timer = ROUND_TIME
	emit_signal("round_started", current_round)

func player_died() -> void:
	player_lives -= 1
	emit_signal("lives_changed", player_lives)
	if player_lives <= 0:
		end_round(Winner.HANDS)
	else:
		# Respawn after short delay
		pass

func end_round(winner: Winner) -> void:
	game_active = false
	emit_signal("round_ended", winner)
	
	if winner == Winner.CHARACTER:
		# Character survived - check if all rounds done
		if current_round >= MAX_ROUNDS:
			emit_signal("game_over", Winner.CHARACTER)
		else:
			# Small break then next round
			await get_tree().create_timer(2.0).timeout
			game_active = true
			start_next_round()
	else:
		# Hands won
		emit_signal("game_over", Winner.HANDS)

func tick(delta: float) -> void:
	if not game_active:
		return
	round_timer -= delta
	if round_timer <= 0:
		end_round(Winner.CHARACTER)

func get_round_difficulty() -> float:
	# Returns 1.0 to 2.0 based on round
	return 1.0 + (float(current_round - 1) / float(MAX_ROUNDS - 1))
