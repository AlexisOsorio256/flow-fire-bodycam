class_name MapCatalog
extends RefCounted

const PATHS := ["res://scenes/Factory.tscn", "res://scenes/Muelle.tscn", "res://scenes/Nave.tscn"]
const NAMES := ["Fábrica", "Muelle", "Nave"]
const PREVIEWS := ["res://assets/maps/preview_factory.png", "res://assets/maps/preview_muelle.png", "res://assets/maps/preview_nave.png"]

static var choice := 0


static func scene() -> PackedScene:
	return load(PATHS[choice])


static func pick() -> int:
	choice = (choice + 1 + randi() % (PATHS.size() - 1)) % PATHS.size()
	return choice
