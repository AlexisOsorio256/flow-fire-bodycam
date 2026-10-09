class_name LanDiscovery
extends Node

const PORT := 47821
const EVERY := 1.0
const FORGET := 3.5
const TAG := "flowfire"
const SWEEP := Vector2i(1, 254)

var groups := {}
var _out: PacketPeerUDP
var _in: PacketPeerUDP
var _beacon := Callable()
var _wait := 0.0


static func bases_and_own() -> Array[PackedStringArray]:
	var bases := PackedStringArray()
	var own := PackedStringArray()
	for address: String in IP.get_local_addresses():
		if not (address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172.")):
			continue
		var base := address.substr(0, address.rfind("."))
		if not bases.has(base):
			bases.append(base)
		own.append(address)
	return [bases, own]


static func targets() -> PackedStringArray:
	var out := PackedStringArray(["255.255.255.255"])
	for address: String in IP.get_local_addresses():
		if address.begins_with("192.168.") or address.begins_with("10.") or address.begins_with("172."):
			out.append(address.substr(0, address.rfind(".")) + ".255")
	return out


static func neighbors() -> PackedStringArray:
	var pair: Array[PackedStringArray] = bases_and_own()
	var out := PackedStringArray()
	for base: String in pair[0]:
		for n in range(SWEEP.x, SWEEP.y + 1):
			var ip := base + "." + str(n)
			if not pair[1].has(ip):
				out.append(ip)
	return out


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func announce(beacon: Callable) -> void:
	quiet()
	_beacon = beacon
	_out = PacketPeerUDP.new()
	_out.set_broadcast_enabled(true)
	_wait = 0.0


func listen() -> bool:
	quiet()
	_in = PacketPeerUDP.new()
	if _in.bind(PORT) != OK:
		_in = null
	return _in != null


func listening() -> bool:
	return _in != null


func quiet() -> void:
	if _in != null:
		_in.close()
	if _out != null:
		_out.close()
	_in = null
	_out = null
	_beacon = Callable()
	groups.clear()


func _process(delta: float) -> void:
	if _out != null:
		_wait -= delta
		if _wait <= 0.0:
			_wait = EVERY
			var info: Dictionary = _beacon.call()
			info["game"] = TAG
			var packet := JSON.stringify(info).to_utf8_buffer()
			for target in targets():
				_out.set_dest_address(target, PORT)
				_out.put_packet(packet)
			for target in neighbors():
				_out.set_dest_address(target, PORT)
				_out.put_packet(packet)
	if _in == null:
		return
	var now := Time.get_ticks_msec() * 0.001
	while _in.get_available_packet_count() > 0:
		var data := _in.get_packet().get_string_from_utf8()
		var info = JSON.parse_string(data)
		if info is Dictionary and info.get("game") == TAG:
			info["seen"] = now
			info["ip"] = _in.get_packet_ip()
			groups["%s:%d" % [info["ip"], int(info.get("port", 0))]] = info
	for key: String in groups.keys():
		if now - float(groups[key]["seen"]) > FORGET:
			groups.erase(key)
