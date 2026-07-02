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
	var meus_botoes = [
		play_button,quit_button
	]	
	for btn in meus_botoes:
		_setup_button_wobble(btn)

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/OnlineMenu.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _setup_button_wobble(btn: Button) -> void:
	# Centraliza o eixo de rotação no meio do botão
	btn.pivot_offset = btn.size / 2.0
	
	# Quando o mouse entra, começa a balançar
	btn.mouse_entered.connect(func():
		# Cria uma animação em loop repetitivo
		var tween = create_tween().set_loops()
		tween.tween_property(btn, "rotation_degrees", 2.0, 0.8).set_trans(Tween.TRANS_SINE)
		tween.tween_property(btn, "rotation_degrees", -2.0, 0.8).set_trans(Tween.TRANS_SINE)
		
		# Guarda o tween dentro do botão para podermos parar depois
		btn.set_meta("wobble_tween", tween)
	)
	
	# Quando o mouse sai, para de balançar e volta ao normal
	btn.mouse_exited.connect(func():
		if btn.has_meta("wobble_tween"):
			var tween = btn.get_meta("wobble_tween")
			if tween:
				tween.kill() # Para a animação atual
		
		# Volta a rotação para 0 suavemente
		create_tween().tween_property(btn, "rotation_degrees", 0.0, 0.1)
	)
