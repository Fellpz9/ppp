extends Node

var socket := WebSocketPeer.new()
var url := "ws://127.0.0.1:8765"

var username := ""
var token := ""
var match_id := ""
var my_role := "" # "character" ou "hands"

# Sinais para conectar com a interface e o jogo
signal register_response(ok: bool, msg: String)
signal lobby_chat_received(sender: String, message: String, time: int)
signal login_response(ok: bool, msg: String)
signal lobby_updated(users: Array, matches: Array)
signal match_joined(m_id: String, players: Array)
signal match_started(roles: Dictionary)
signal game_action_received(action: String, payload: Dictionary)

func _ready():
	socket.connect_to_url(url)

func _process(_delta):
	socket.poll()
	var state = socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while socket.get_available_packet_count():
			var packet = socket.get_packet()
			var text = packet.get_string_from_utf8()
			var data = JSON.parse_string(text)
			if data != null:
				_handle_message(data)

func _handle_message(data: Dictionary):
	var msg_type = data.get("type", "")
	
	if msg_type == "login_result":
		if data.get("ok"):
			username = data.get("username")
			token = data.get("token")
			login_response.emit(true, "")
		else:
			login_response.emit(false, data.get("error", "Erro no login"))
			
	elif msg_type == "lobby_update":
		lobby_updated.emit(data.get("users", []), data.get("matches", []))
		
	elif msg_type == "match_started":
		var roles = data.get("roles", {})
		my_role = roles.get(username, "")
		match_started.emit(roles)
		get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
		
	elif msg_type == "game_action":
		game_action_received.emit(data.get("action"), data.get("payload"))
		
	elif msg_type == "register_result":
		register_response.emit(data.get("ok"), data.get("error", "Erro ao registrar"))
		
	elif msg_type == "lobby_chat":
		lobby_chat_received.emit(data.get("from", ""), data.get("message", ""), data.get("timestamp", 0))
		
	elif msg_type == "match_update":
		# APAGUE a linha que estava aqui (lobby_updated.emit...)
		# Apenas avisamos internamente que alguém entrou na sala
		var players_na_sala = data.get("players", [])
		print("Atualização da sala! Jogadores: ", players_na_sala)
		
	elif msg_type == "join_match_result":
		# Quando o Player 2 tenta entrar na sala
		if data.get("ok"):
			print("Você entrou na partida com sucesso! Aguardando o host iniciar...")
			# Opcional: Aqui você poderia emitir um sinal para a UI desativar os botões 
			# e mostrar um aviso de "Aguardando Host..."
		else:
			print("Erro ao entrar na partida: ", data.get("error", ""))

# -- Funções para enviar dados ao servidor --
func send_msg(dict: Dictionary):
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.put_packet(JSON.stringify(dict).to_utf8_buffer())

func login(user: String, pswd: String):
	send_msg({"type": "login", "username": user, "password": pswd})

func create_match():
	send_msg({"type": "create_match"})

func join_match(m_id: String):
	send_msg({"type": "join_match", "match_id": m_id})

func start_match():
	send_msg({"type": "start_match"})

func send_action(action: String, payload: Dictionary):
	send_msg({"type": "game_action", "action": action, "payload": payload})

func register(email: String, user: String, pswd: String):
	send_msg({"type": "register", "email": email, "username": user, "password": pswd})

func send_chat(msg: String):
	send_msg({"type": "lobby_chat", "message": msg})
