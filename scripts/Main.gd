extends Node3D

const WORLD_SCRIPT := preload("res://scripts/World.gd")
const PLAYER_SCRIPT := preload("res://scripts/Player.gd")
const HUD_SCRIPT := preload("res://scripts/HUD.gd")
const RANGE_SHELL_SCENE := preload("res://scenes/RangeShell.tscn")

var world: Node3D
var player: CharacterBody3D
var hud: CanvasLayer


func _ready() -> void:
    randomize()
    _build_range_shell()
    _build_world()
    _build_player()
    _build_hud()


func _build_world() -> void:
    world = WORLD_SCRIPT.new()
    world.name = "World"
    add_child(world)
    world.build()


func _build_range_shell() -> void:
    var shell := RANGE_SHELL_SCENE.instantiate()
    shell.name = "RangeShell"
    add_child(shell)


func _build_player() -> void:
    player = PLAYER_SCRIPT.new()
    player.name = "Player"
    add_child(player)
    player.global_position = Vector3(2.0, 0.05, 0.5)
    player.world = world


func _build_hud() -> void:
    hud = HUD_SCRIPT.new()
    hud.name = "HUD"
    add_child(hud)
    hud.setup(player)
