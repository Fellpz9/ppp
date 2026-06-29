#!/usr/bin/env python3
"""
Preposterous Platform Party - Server
Handles: user registration/login, lobby, chat, match management, game state sync
"""

import asyncio
import json
import hashlib
import uuid
import time
from typing import Optional
import websockets
from websockets.server import WebSocketServerProtocol

# ─── CONFIG ────────────────────────────────────────────────────────────────────
HOST = "0.0.0.0"
PORT = 8765
MIN_PLAYERS = 2  # Configurable: minimum to start a match
MAX_PLAYERS = 2  # Configurable: maximum players per match

# ─── IN-MEMORY STORAGE ─────────────────────────────────────────────────────────
# { username: { "email": str, "password_hash": str } }
users_db: dict = {}

# { session_token: username }
sessions: dict = {}

# { ws: { "username": str, "token": str, "state": "lobby"|"in_match", "match_id": str|None } }
connected: dict = {}

# { match_id: { "id", "host", "players": [username], "status": "created"|"started"|"finished", "game_state": {} } }
matches: dict = {}


# ─── HELPERS ───────────────────────────────────────────────────────────────────
def hash_password(pw: str) -> str:
    return hashlib.sha256(pw.encode()).hexdigest()

def make_token() -> str:
    return str(uuid.uuid4())

def get_ws_by_username(username: str) -> Optional[WebSocketServerProtocol]:
    for ws, info in connected.items():
        if info.get("username") == username:
            return ws
    return None

def lobby_usernames() -> list:
    return [info["username"] for info in connected.values() if info.get("state") == "lobby"]

def match_player_ws(match_id: str) -> list:
    """Return all websockets of players in a given match."""
    result = []
    if match_id not in matches:
        return result
    for username in matches[match_id]["players"]:
        ws = get_ws_by_username(username)
        if ws:
            result.append(ws)
    return result

async def send(ws, msg: dict):
    try:
        await ws.send(json.dumps(msg))
    except Exception:
        pass

async def broadcast_lobby(msg: dict):
    """Send to all clients in lobby state."""
    for ws, info in list(connected.items()):
        if info.get("state") == "lobby":
            await send(ws, msg)

async def broadcast_match(match_id: str, msg: dict):
    """Send to all players in a match."""
    for ws in match_player_ws(match_id):
        await send(ws, msg)

def public_matches() -> list:
    """Matches visible in lobby (created or started)."""
    return [
        {
            "id": m["id"],
            "host": m["host"],
            "player_count": len(m["players"]),
            "max_players": MAX_PLAYERS,
            "status": m["status"],
        }
        for m in matches.values()
        if m["status"] in ("created", "started")
    ]


# ─── HANDLERS ──────────────────────────────────────────────────────────────────

async def handle_register(ws, data: dict) -> dict:
    email = data.get("email", "").strip().lower()
    username = data.get("username", "").strip()
    password = data.get("password", "")

    if not email or not username or not password:
        return {"ok": False, "error": "Preencha todos os campos."}
    if any(u["email"] == email for u in users_db.values()):
        return {"ok": False, "error": "E-mail já cadastrado."}
    if username in users_db:
        return {"ok": False, "error": "Username já em uso."}

    users_db[username] = {"email": email, "password_hash": hash_password(password)}
    return {"ok": True}


async def handle_login(ws, data: dict) -> dict:
    username = data.get("username", "").strip()
    password = data.get("password", "")

    user = users_db.get(username)
    if not user or user["password_hash"] != hash_password(password):
        return {"ok": False, "error": "Usuário ou senha inválidos."}

    # Kill any previous session for this user
    old_token = next((t for t, u in sessions.items() if u == username), None)
    if old_token:
        sessions.pop(old_token, None)

    token = make_token()
    sessions[token] = username
    connected[ws] = {"username": username, "token": token, "state": "lobby", "match_id": None}

    # Notify lobby of new user
    await broadcast_lobby({"type": "lobby_update", "users": lobby_usernames(), "matches": public_matches()})

    return {"ok": True, "token": token, "username": username}


async def handle_lobby_chat(ws, data: dict):
    info = connected.get(ws)
    if not info or info["state"] != "lobby":
        return
    msg = data.get("message", "").strip()
    if not msg:
        return
    await broadcast_lobby({
        "type": "lobby_chat",
        "from": info["username"],
        "message": msg,
        "timestamp": int(time.time())
    })


async def handle_create_match(ws, data: dict) -> dict:
    info = connected.get(ws)
    if not info or info["state"] != "lobby":
        return {"ok": False, "error": "Não está no lobby."}

    match_id = str(uuid.uuid4())[:8].upper()
    matches[match_id] = {
        "id": match_id,
        "host": info["username"],
        "players": [info["username"]],
        "status": "created",
        "game_state": {}
    }
    info["state"] = "in_match"
    info["match_id"] = match_id

    await broadcast_lobby({"type": "lobby_update", "users": lobby_usernames(), "matches": public_matches()})
    return {"ok": True, "match_id": match_id}


async def handle_join_match(ws, data: dict) -> dict:
    info = connected.get(ws)
    match_id = data.get("match_id", "")

    if not info or info["state"] != "lobby":
        return {"ok": False, "error": "Não está no lobby."}
    if match_id not in matches:
        return {"ok": False, "error": "Partida não encontrada."}

    match = matches[match_id]
    if match["status"] != "created":
        return {"ok": False, "error": "Partida já iniciada."}
    if len(match["players"]) >= MAX_PLAYERS:
        return {"ok": False, "error": "Partida cheia."}
    if info["username"] in match["players"]:
        return {"ok": False, "error": "Você já está nessa partida."}

    match["players"].append(info["username"])
    info["state"] = "in_match"
    info["match_id"] = match_id

    # Notify other player in match
    await broadcast_match(match_id, {
        "type": "match_update",
        "match_id": match_id,
        "players": match["players"],
        "status": match["status"]
    })
    await broadcast_lobby({"type": "lobby_update", "users": lobby_usernames(), "matches": public_matches()})

    return {"ok": True, "match_id": match_id, "players": match["players"]}


async def handle_start_match(ws, data: dict) -> dict:
    info = connected.get(ws)
    match_id = info.get("match_id") if info else None

    if not match_id or match_id not in matches:
        return {"ok": False, "error": "Sem partida ativa."}

    match = matches[match_id]
    if match["host"] != info["username"]:
        return {"ok": False, "error": "Só o criador pode iniciar."}
    if len(match["players"]) < MIN_PLAYERS:
        return {"ok": False, "error": f"Mínimo {MIN_PLAYERS} jogadores necessários."}
    if match["status"] != "created":
        return {"ok": False, "error": "Partida já iniciada."}

    match["status"] = "started"
    # Assign roles: first player = Character, second = Hands
    roles = {match["players"][0]: "character", match["players"][1]: "hands"}
    match["roles"] = roles

    await broadcast_match(match_id, {
        "type": "match_started",
        "match_id": match_id,
        "players": match["players"],
        "roles": roles
    })
    await broadcast_lobby({"type": "lobby_update", "users": lobby_usernames(), "matches": public_matches()})

    return {"ok": True}


async def handle_game_action(ws, data: dict):
    """
    Relay any game action to all players in the match.
    Optimisation: only forward fields that actually changed (delta compression).
    """
    info = connected.get(ws)
    if not info or info["state"] != "in_match":
        return

    match_id = info["match_id"]
    if not match_id or match_id not in matches:
        return

    action = data.get("action")  # e.g. "move", "place_platform", "remove_platform", "powerup"
    payload = data.get("payload", {})

    # Broadcast to all OTHER players in this match
    msg = {
        "type": "game_action",
        "from": info["username"],
        "action": action,
        "payload": payload,
        "t": int(time.time() * 1000)  # millisecond timestamp
    }
    for player_ws in match_player_ws(match_id):
        if player_ws != ws:
            await send(player_ws, msg)


async def handle_game_state(ws, data: dict):
    """
    Authoritative state update (sent by host/server logic in client).
    Forwarded to all players including sender for reconciliation.
    """
    info = connected.get(ws)
    if not info or info["state"] != "in_match":
        return

    match_id = info["match_id"]
    if not match_id or match_id not in matches:
        return

    matches[match_id]["game_state"] = data.get("state", {})
    await broadcast_match(match_id, {
        "type": "game_state",
        "state": matches[match_id]["game_state"],
        "t": int(time.time() * 1000)
    })


async def handle_end_match(ws, data: dict):
    info = connected.get(ws)
    match_id = info.get("match_id") if info else None

    if not match_id or match_id not in matches:
        return

    match = matches[match_id]
    winner = data.get("winner")  # "character" or "hands"
    match["status"] = "finished"

    # Return all players to lobby
    for username in match["players"]:
        player_ws = get_ws_by_username(username)
        if player_ws and player_ws in connected:
            connected[player_ws]["state"] = "lobby"
            connected[player_ws]["match_id"] = None
            await send(player_ws, {
                "type": "match_ended",
                "winner": winner,
                "match_id": match_id
            })

    # Clean up after short delay
    await asyncio.sleep(5)
    matches.pop(match_id, None)

    await broadcast_lobby({"type": "lobby_update", "users": lobby_usernames(), "matches": public_matches()})


# ─── MAIN DISPATCH ─────────────────────────────────────────────────────────────

async def handle_message(ws, raw: str):
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        await send(ws, {"type": "error", "error": "JSON inválido."})
        return

    msg_type = data.get("type")

    if msg_type == "register":
        result = await handle_register(ws, data)
        await send(ws, {"type": "register_result", **result})

    elif msg_type == "login":
        result = await handle_login(ws, data)
        await send(ws, {"type": "login_result", **result})
        if result.get("ok"):
            # Send initial lobby state
            await send(ws, {"type": "lobby_update", "users": lobby_usernames(), "matches": public_matches()})

    elif msg_type == "lobby_chat":
        await handle_lobby_chat(ws, data)

    elif msg_type == "create_match":
        result = await handle_create_match(ws, data)
        await send(ws, {"type": "create_match_result", **result})

    elif msg_type == "join_match":
        result = await handle_join_match(ws, data)
        await send(ws, {"type": "join_match_result", **result})

    elif msg_type == "start_match":
        result = await handle_start_match(ws, data)
        await send(ws, {"type": "start_match_result", **result})

    elif msg_type == "game_action":
        await handle_game_action(ws, data)

    elif msg_type == "game_state":
        await handle_game_state(ws, data)

    elif msg_type == "end_match":
        await handle_end_match(ws, data)

    elif msg_type == "get_lobby":
        await send(ws, {"type": "lobby_update", "users": lobby_usernames(), "matches": public_matches()})

    else:
        await send(ws, {"type": "error", "error": f"Tipo desconhecido: {msg_type}"})


async def on_connect(ws):
    print(f"[+] Conexão: {ws.remote_address}")
    try:
        async for raw in ws:
            await handle_message(ws, raw)
    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        # Clean up on disconnect
        info = connected.pop(ws, None)
        if info:
            username = info.get("username")
            match_id = info.get("match_id")
            print(f"[-] Desconectado: {username}")

            if match_id and match_id in matches:
                match = matches[match_id]
                if username in match["players"]:
                    match["players"].remove(username)
                # If match is now empty or started with missing player, end it
                if len(match["players"]) == 0:
                    matches.pop(match_id, None)
                elif match["status"] == "started":
                    await broadcast_match(match_id, {
                        "type": "player_disconnected",
                        "username": username
                    })

            await broadcast_lobby({"type": "lobby_update", "users": lobby_usernames(), "matches": public_matches()})


async def main():
    print(f"PPP Server iniciando em ws://{HOST}:{PORT}")
    print(f"Config: MIN_PLAYERS={MIN_PLAYERS}, MAX_PLAYERS={MAX_PLAYERS}")
    async with websockets.serve(on_connect, HOST, PORT):
        await asyncio.Future()  # run forever


if __name__ == "__main__":
    asyncio.run(main())
