class_name MapCatalog
extends RefCounted

const MAPS := [
	{"path": "res://scenes/Patio.tscn", "name": "Patio", "preview": "res://assets/maps/preview_patio.png",
		"route": Vector2(-34.5, 22.0)},
	{"path": "res://scenes/Callejones.tscn", "name": "Callejones", "preview": "res://assets/maps/preview_callejones.png",
		"route": Vector2(2.5, 20.0)},
]

static var choice := 0


static func scene() -> PackedScene:
	return load(MAPS[choice]["path"])


static func pick() -> int:
	choice = (choice + 1 + randi() % (MAPS.size() - 1)) % MAPS.size()
	return choice
