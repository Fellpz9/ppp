extends CanvasLayer

# HUD.gd
# Displays: lives, round number, round timer, active powerups

@onready var lives_container: HBoxContainer = $MarginContainer/VBoxContainer/TopBar/LivesContainer
@onready var round_label: Label = $MarginContainer/VBoxContainer/TopBar/RoundLabel
@onready var timer_label: Label = $MarginContainer/VBoxContainer/TopBar/TimerLabel
@onready var powerup_label_char: Label = $MarginContainer/VBoxContainer/PowerupBar/CharPowerup
@onready var powerup_label_hand: Label = $MarginContainer/VBoxContainer/PowerupBar/HandPowerup
@onready var round_announce: Label = $MarginContainer/RoundAnnounce
@onready var game_over_panel: Panel = $MarginContainer/GameOverPanel
@onready var game_over_label: Label = $MarginContainer/GameOverPanel/Label

const HEART_FULL := "❤"
const HEART_EMPTY := "🖤"
const MAX_LIVES := 3

func _ready() -> void:
	GameManager.round_started.connect(_on_round_started)
	GameManager.round_ended.connect(_on_round_ended)
	GameManager.game_over.connect(_on_game_over)
	GameManager.lives_changed.connect(_on_lives_changed)
	game_over_panel.hide()

func _process(_delta: float) -> void:
	# Update timer every frame
	if GameManager.game_active:
		var t = int(GameManager.round_timer)
		timer_label.text = "%02d" % t
		# Turn red when low on time
		timer_label.modulate = Color.RED if t <= 10 else Color.WHITE

func _on_round_started(round_number: int) -> void:
	round_label.text = "ROUND %d / %d" % [round_number, GameManager.MAX_ROUNDS]
	_update_lives(GameManager.player_lives)
	_show_round_announce("ROUND %d" % round_number)

func _on_round_ended(winner: int) -> void:
	if winner == GameManager.Winner.CHARACTER:
		_show_round_announce("SURVIVED!")
	else:
		_show_round_announce("GOTCHA!")

func _on_game_over(winner: int) -> void:
	game_over_panel.show()
	if winner == GameManager.Winner.CHARACTER:
		game_over_label.text = "🎉 CHARACTER WINS!\nSurvived all 5 rounds!"
	else:
		game_over_label.text = "👏 HANDS WIN!\nThe character has fallen!"

func _on_lives_changed(new_lives: int) -> void:
	_update_lives(new_lives)

func _update_lives(count: int) -> void:
	lives_container.get_children().map(func(c): c.queue_free())
	for i in MAX_LIVES:
		var heart = Label.new()
		heart.text = HEART_FULL if i < count else HEART_EMPTY
		heart.add_theme_font_size_override("font_size", 24)
		lives_container.add_child(heart)

func show_powerup(player: String, type: String) -> void:
	if player == "character":
		powerup_label_char.text = "✨ " + type.replace("_", " ").to_upper()
		_fade_label(powerup_label_char)
	else:
		powerup_label_hand.text = "🔥 " + type.replace("_", " ").to_upper()
		_fade_label(powerup_label_hand)

func _fade_label(label: Label) -> void:
	label.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)

func _show_round_announce(text: String) -> void:
	round_announce.text = text
	round_announce.modulate.a = 1.0
	round_announce.scale = Vector2(0.5, 0.5)
	var tween = create_tween()
	tween.tween_property(round_announce, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(1.2)
	tween.tween_property(round_announce, "modulate:a", 0.0, 0.4)
