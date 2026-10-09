class_name MapCatalog
extends RefCounted

const PATHS := ["res://scenes/Patio.tscn", "res://scenes/Callejones.tscn"]
const NAMES := ["Patio", "Callejones"]
const PREVIEWS := ["res://assets/maps/preview_patio.png", "res://assets/maps/preview_callejones.png"]
const LOBBY_ROUTE := [Vector2(-34.5, 22.0), Vector2(2.5, 20.0)]

static var choice := 0


static func scene() -> PackedScene:
	return load(PATHS[choice])


static func pick() -> int:
	choice = (choice + 1 + randi() % (PATHS.size() - 1)) % PATHS.size()
	return choice
