class_name MapCatalog
extends RefCounted

const SCENES := [
	preload("res://scenes/Factory.tscn"),
	preload("res://scenes/Muelle.tscn"),
	preload("res://scenes/Nave.tscn"),
]
const NAMES := ["Fábrica", "Muelle", "Nave"]

static var choice := 0


static func scene() -> PackedScene:
	return SCENES[choice]


static func cycle() -> void:
	choice = (choice + 1) % SCENES.size()


static func name_of() -> String:
	return NAMES[choice]
