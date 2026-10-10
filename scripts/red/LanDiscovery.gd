class_name LanDiscovery
extends Node

const PORT := 47821
const ASK_PORT := 47829
const EVERY := 1.0
const ASK_EVERY := 2.0
const FORGET := 3.5
const TAG := "flowfire"
const GROUP := "239.255.47.82"
const SWEEP := Vector2i(1, 254)
const BATCH := 24

var groups := {}
var _out: PacketPeerUDP
var _in: PacketPeerUDP
var _asks: PacketPeerUDP
var _beacon := Callable()
var _wait := 0.0
var _sweep := PackedStringArray()
var _next := 0
var _packet := PackedByteArray()


static func addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for address: String in IP.get_local_addresses():
		if address.contains(":") or address.begins_with("127.") or out.has(address):
			continue
		out.append(address)
	return out


static func swept(address: String) -> bool:
	var parts := address.split(".")
	if parts.size() != 4:
		return false
	var head := int(parts[0])
	var tail := int(parts[1])
	var home := head == 192 and tail == 168
	var carrier := head == 100 and tail >= 64 and tail <= 127
	var bare := head == 169 and tail == 254
	var block := head == 172 and tail >= 16 and tail <= 31
	return head == 10 or home or carrier or bare or block


static func bases() -> PackedStringArray:
	var out := PackedStringArray()
	for address: String in addresses():
		if not swept(address):
			continue
		var base := address.substr(0, address.rfind("."))
		if not out.has(base):
			out.append(base)
	return out


static func targets() -> PackedStringArray:
	var out := PackedStringArray(["255.255.255.255", GROUP])
	for address: String in addresses():
		var broadcast := address.substr(0, address.rfind(".")) + ".255"
		if not out.has(broadcast):
			out.append(broadcast)
	return out


static func neighbors() -> PackedStringArray:
	var own := addresses()
	var out := PackedStringArray()
	for base: String in bases():
		for n in range(SWEEP.x, SWEEP.y + 1):
			var ip := base + "." + str(n)
			if not own.has(ip) and not out.has(ip):
				out.append(ip)
	return out


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func announce(beacon: Callable) -> void:
	quiet()
	_beacon = beacon
	_out = PacketPeerUDP.new()
	_out.set_broadcast_enabled(true)
	_asks = _ask_socket()
	_wait = 0.0


func listen() -> bool:
	quiet()
	_in = PacketPeerUDP.new()
	if _in.bind(PORT) != OK:
		_in = null
		return false
	_in.set_broadcast_enabled(true)
	_join_group(_in)
	_wait = 0.0
	return true


func listening() -> bool:
	return _in != null


func quiet() -> void:
	if _in != null:
		_in.close()
	if _asks != null:
		_asks.close()
	if _out != null:
		_out.close()
	_in = null
	_asks = null
	_out = null
	_beacon = Callable()
	groups.clear()
	_sweep = PackedStringArray()
	_next = 0


func _ask_socket() -> PacketPeerUDP:
	var socket := PacketPeerUDP.new()
	if socket.bind(ASK_PORT) != OK:
		return null
	_join_group(socket)
	return socket


func _join_group(socket: PacketPeerUDP) -> void:
	for entry: Dictionary in IP.get_local_interfaces():
		socket.join_multicast_group(GROUP, str(entry.get("name", "")))


func _process(delta: float) -> void:
	if _out != null:
		_burst(delta, EVERY, PORT, _packet_of_beacon)
	elif _in != null:
		_burst(delta, ASK_EVERY, ASK_PORT, _packet_of_ask)
	_absorb_all()


func _burst(delta: float, every: float, port: int, packet: Callable) -> void:
	var sender := _out if _out != null else _in
	_wait -= delta
	if _wait <= 0.0:
		_wait = every
		_packet = packet.call()
		_sweep = neighbors()
		_next = 0
		for target in targets():
			sender.set_dest_address(target, port)
			sender.put_packet(_packet)
	elif _next < _sweep.size():
		var stop := mini(_next + BATCH, _sweep.size())
		while _next < stop:
			sender.set_dest_address(_sweep[_next], port)
			sender.put_packet(_packet)
			_next += 1


func _absorb_all() -> void:
	var now := Time.get_ticks_msec() * 0.001
	if _in != null:
		_absorb(_in, now)
	if _asks != null:
		_absorb(_asks, now)
	for key: String in groups.keys():
		if now - float(groups[key]["seen"]) > FORGET:
			groups.erase(key)


func _absorb(socket: PacketPeerUDP, now: float) -> void:
	while socket.get_available_packet_count() > 0:
		var info = JSON.parse_string(socket.get_packet().get_string_from_utf8())
		if not (info is Dictionary) or info.get("game") != TAG:
			continue
		var ip := socket.get_packet_ip()
		if info.get("ask", false):
			if _out != null:
				socket.set_dest_address(ip, socket.get_packet_port())
				socket.put_packet(_packet_of_beacon())
			continue
		info["seen"] = now
		info["ip"] = ip
		groups["%s:%d" % [ip, int(info.get("port", 0))]] = info


func _packet_of_beacon() -> PackedByteArray:
	var info: Dictionary = _beacon.call()
	info["game"] = TAG
	return JSON.stringify(info).to_utf8_buffer()


func _packet_of_ask() -> PackedByteArray:
	return JSON.stringify({"game": TAG, "ask": true}).to_utf8_buffer()
