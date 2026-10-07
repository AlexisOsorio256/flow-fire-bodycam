extends Node

signal roster_changed
signal match_started
signal closed(reason: String)

const PORT := 47820
const SIZES := [1, 2, 4]

var team_size := 1
var roster := {}
var hosting := false
var in_match := false
var game: Node
var discovery := LanDiscovery.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(discovery)
	multiplayer.peer_disconnected.connect(_on_peer_left)
	multiplayer.connected_to_server.connect(func() -> void: _hello.rpc_id(1, Settings.player_name))
	multiplayer.connection_failed.connect(_close.bind("No se pudo entrar a la partida."))
	multiplayer.server_disconnected.connect(_close.bind("Quien creó la partida la ha cerrado."))


func active() -> bool:
	return multiplayer.multiplayer_peer is ENetMultiplayerPeer


func me() -> int:
	return multiplayer.get_unique_id()


func team_of(id: int) -> int:
	return int(roster.get(id, {}).get("team", 0))


func full() -> bool:
	return roster.size() >= team_size * 2


func ready_to_start() -> bool:
	var teams := [0, 0]
	for id: int in roster:
		teams[team_of(id)] += 1
	return teams[0] > 0 and teams[1] > 0


func host(size: int) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, size * 2 - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	hosting = true
	team_size = size
	roster = {1: {"name": Settings.player_name, "team": 0}}
	discovery.announce(_beacon)
	roster_changed.emit()
	return OK


func join(ip: String) -> Error:
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err == OK:
		multiplayer.multiplayer_peer = peer
	return err


func leave() -> void:
	discovery.quiet()
	if active():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	hosting = false
	in_match = false
	roster = {}
	game = null


func switch_team() -> void:
	_ask_team.rpc_id(1)


func start_match() -> void:
	if hosting and not in_match and ready_to_start():
		_start.rpc()


func end_match(winner: int) -> void:
	if hosting and in_match:
		_end.rpc(winner)


func send_state(pos: Vector3, yaw: float, crouch: bool, alive: bool) -> void:
	_state.rpc(pos, yaw, crouch, alive)


func send_shot(from: Vector3, dir: Vector3) -> void:
	_shot.rpc(from, dir)


func send_hit(target: int, zone: String, dir: Vector3, impulse: float) -> void:
	if roster.has(target):
		_hit.rpc_id(target, zone, dir, impulse)


func report_down(killer: int, region: String, dir: Vector3) -> void:
	_down.rpc(killer, region, dir)


func push_score(score: Array, clock: float) -> void:
	if hosting:
		_score.rpc(score, clock)


func _beacon() -> Dictionary:
	return {"name": Settings.player_name, "size": team_size, "count": roster.size(), "open": not in_match and not full()}


func _sender() -> int:
	var id := multiplayer.get_remote_sender_id()
	return me() if id == 0 else id


func _on_peer_left(id: int) -> void:
	roster.erase(id)
	if is_instance_valid(game):
		game.on_left(id)
	if hosting:
		_push_roster()
	roster_changed.emit()


func _close(reason: String) -> void:
	leave()
	closed.emit(reason)


func _push_roster() -> void:
	_set_roster.rpc(roster, team_size)


@rpc("any_peer", "call_remote", "reliable")
func _hello(player_name: String) -> void:
	var id := _sender()
	if not hosting:
		return
	if in_match or full():
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)
		return
	var teams := [0, 0]
	for other: int in roster:
		teams[team_of(other)] += 1
	roster[id] = {"name": player_name.left(16), "team": 0 if teams[0] <= teams[1] else 1}
	_push_roster()


@rpc("any_peer", "call_local", "reliable")
func _ask_team() -> void:
	var id := _sender()
	if not hosting or in_match or not roster.has(id):
		return
	var other := 1 - team_of(id)
	var count := 0
	for peer: int in roster:
		count += 1 if team_of(peer) == other else 0
	if count < team_size:
		roster[id]["team"] = other
		_push_roster()


@rpc("authority", "call_local", "reliable")
func _set_roster(new_roster: Dictionary, size: int) -> void:
	roster = new_roster
	team_size = size
	roster_changed.emit()


@rpc("authority", "call_local", "reliable")
func _start() -> void:
	in_match = true
	match_started.emit()


@rpc("authority", "call_local", "reliable")
func _end(winner: int) -> void:
	in_match = false
	if is_instance_valid(game):
		game.on_end(winner)


@rpc("authority", "call_local", "reliable")
func _score(score: Array, clock: float) -> void:
	if is_instance_valid(game):
		game.on_score(score, clock)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _state(pos: Vector3, yaw: float, crouch: bool, alive: bool) -> void:
	if is_instance_valid(game):
		game.on_state(_sender(), pos, yaw, crouch, alive)


@rpc("any_peer", "call_remote", "unreliable")
func _shot(from: Vector3, dir: Vector3) -> void:
	if is_instance_valid(game):
		game.on_shot(_sender(), from, dir)


@rpc("any_peer", "call_remote", "reliable")
func _hit(zone: String, dir: Vector3, impulse: float) -> void:
	if is_instance_valid(game):
		game.on_hit(_sender(), zone, dir, impulse)


@rpc("any_peer", "call_local", "reliable")
func _down(killer: int, region: String, dir: Vector3) -> void:
	if is_instance_valid(game):
		game.on_down(_sender(), killer, region, dir)
