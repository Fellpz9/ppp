extends Control

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton
@onready var title_label: Label = $CenterContainer/VBoxContainer/TitleLabel

func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
	# Animate title
	var tween = create_tween().set_loops()
	tween.tween_property(title_label, "rotation_degrees", 2.0, 0.8).set_trans(Tween.TRANS_SINE)
	tween.tween_property(title_label, "rotation_degrees", -2.0, 0.8).set_trans(Tween.TRANS_SINE)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/OnlineMenu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
