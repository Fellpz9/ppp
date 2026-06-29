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

var selected_match_id = ""

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
	
	lobby_panel.hide()
	login_panel.show()
	btn_start_match.disabled = true

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

func _on_join_match_pressed():
	if selected_match_id != "":
		NetworkManager.join_match(selected_match_id)

func _on_start_match_pressed():
	NetworkManager.start_match()
	# O servidor enviará "match_started" para o NetworkManager, que trocará de cena automaticamente!
