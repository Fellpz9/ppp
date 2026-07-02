extends Control

# Referências do Login
@onready var login_panel = $LoginPanel
@onready var email_input = $LoginPanel/VBoxContainer/EmailInput
@onready var username_input = $LoginPanel/VBoxContainer/UsernameInput
@onready var password_input = $LoginPanel/VBoxContainer/PasswordInput
@onready var btn_login = $LoginPanel/VBoxContainer/LoginButton
@onready var btn_register = $LoginPanel/VBoxContainer/RegisterButton
@onready var error_label = $LoginPanel/VBoxContainer/ErrorLabel

# Referências do Lobby
@onready var lobby_panel = $LobbyPanel
@onready var chat_history = $LobbyPanel/HBoxContainer/ChatArea/ChatHistory
@onready var chat_input = $LobbyPanel/HBoxContainer/ChatArea/ChatInput
@onready var btn_send_chat = $LobbyPanel/HBoxContainer/ChatArea/SendChatButton
@onready var matches_list = $LobbyPanel/HBoxContainer/MatchesArea/MatchesList
@onready var btn_create_match = $LobbyPanel/HBoxContainer/MatchesArea/CreateMatchButton
@onready var btn_join_match = $LobbyPanel/HBoxContainer/MatchesArea/JoinMatchButton
@onready var btn_start_match = $LobbyPanel/HBoxContainer/MatchesArea/StartMatchButton

@onready var current_user_label = $LobbyPanel/CurrentUserLabel

var selected_match_id = ""

var known_lobby_users: Array = []
var is_first_lobby_update: bool = true

func _ready() -> void:
	# Conectar botões da interface
	btn_login.pressed.connect(_on_login_pressed)
	btn_register.pressed.connect(_on_register_pressed)
	btn_send_chat.pressed.connect(_on_send_chat_pressed)
	btn_create_match.pressed.connect(_on_create_match_pressed)
	btn_join_match.pressed.connect(_on_join_match_pressed)
	btn_start_match.pressed.connect(_on_start_match_pressed)
	
	matches_list.item_selected.connect(_on_match_selected)
	
	# Conectar sinais do NetworkManager
	NetworkManager.login_response.connect(_on_login_response)
	NetworkManager.register_response.connect(_on_register_response)
	NetworkManager.lobby_updated.connect(_on_lobby_updated)
	NetworkManager.lobby_chat_received.connect(_on_chat_received)
	NetworkManager.match_created.connect(_on_match_created)
	NetworkManager.match_player_joined.connect(_on_match_player_joined)
	
	lobby_panel.hide()
	login_panel.show()
	btn_start_match.disabled = true
	
	var meus_botoes = [
		btn_login, btn_register, btn_send_chat, 
		btn_create_match, btn_join_match, btn_start_match
	]
	
	# Espera um frame para garantir que os tamanhos (sizes) dos botões foram calculados
	await get_tree().process_frame 
	
	for btn in meus_botoes:
		_setup_button_wobble(btn)

# --- LÓGICA DE AUTENTICAÇÃO ---
func _on_register_pressed():
	NetworkManager.register(email_input.text, username_input.text, password_input.text)

func _on_login_pressed():
	NetworkManager.login(username_input.text, password_input.text)

func _on_register_response(ok: bool, msg: String):
	error_label.text = "Registrado com sucesso! Faça login." if ok else msg

func _on_login_response(ok: bool, msg: String):
	if ok:
		login_panel.hide()
		lobby_panel.show()
		current_user_label.text = "Logado como: " + username_input.text
		
		is_first_lobby_update = true
		known_lobby_users.clear()
	else:
		error_label.text = msg

# --- LÓGICA DE CHAT ---
func _on_send_chat_pressed():
	if chat_input.text != "":
		NetworkManager.send_chat(chat_input.text)
		chat_input.text = ""

func _on_chat_received(sender: String, message: String, time: int):
	chat_history.text += "\n[" + sender + "]: " + message

# --- LÓGICA DE PARTIDAS ---
func _on_lobby_updated(users: Array, matches: Array):
	if is_first_lobby_update:
		# Na primeira vez, apenas memoriza quem já estava lá
		known_lobby_users = users.duplicate()
		is_first_lobby_update = false
	else:
		# Compara quem chegou de novo
		for u in users:
			if not u in known_lobby_users:
				# Usa a própria função de chat para exibir a mensagem do sistema!
				_on_chat_received("SISTEMA", u + " entrou no lobby!", 0)
		known_lobby_users = users.duplicate()
	matches_list.clear()
	for m in matches:
		var status = " (" + str(m.get("player_count", 1)) + "/2)"
		matches_list.add_item(m["id"] + " - Host: " + m["host"] + status)
		matches_list.set_item_metadata(matches_list.item_count - 1, m["id"])

func _on_match_selected(index: int):
	selected_match_id = matches_list.get_item_metadata(index)

func _on_create_match_pressed():
	NetworkManager.create_match()
	btn_start_match.disabled = false # Habilita para o criador
	btn_create_match.disabled = true 

func _on_join_match_pressed():
	if selected_match_id != "":
		NetworkManager.join_match(selected_match_id)

func _on_start_match_pressed():
	NetworkManager.start_match()
	# O servidor enviará "match_started" para o NetworkManager, que trocará de cena automaticamente!

func _on_match_created(m_id: String):
	# Habilita o botão de Start agora que temos confirmação
	btn_start_match.disabled = false
	
	# Manda o aviso no chat local do criador
	_on_chat_received("SISTEMA", "Você criou a partida [" + m_id + "] com sucesso! Aguardando oponente...", 0)

func _on_match_player_joined(players: Array):
	print("[UI] Sinal de match_player_joined chegou no menu. Players: ", players)
	if players.size() > 1:
		# Pega o último jogador que entrou e garante que é do tipo String
		var novo_jogador = str(players[players.size() - 1]) 
		_on_chat_received("SISTEMA", novo_jogador + " entrou na sua partida! Você já pode iniciar.", 0)

# --- EFEITOS VISUAIS (WOBBLE) ---
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
