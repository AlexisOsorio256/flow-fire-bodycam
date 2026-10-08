class_name Loadout
extends Node3D

signal fired

var player: Player
var weapons: Array = []
var current := 0


func build(owner_player: Player, cam: Camera3D) -> void:
	player = owner_player
	for spec: WeaponSpec in WeaponSpec.all():
		var weapon := Firearm.new()
		weapon.spec = spec
		weapon.name = spec.id.capitalize()
		weapon.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(weapon)
		weapon.setup(cam)
		weapon.shooter = owner_player
		weapon.shot_fired.connect(fired.emit)
		weapon.mag_seated.connect(owner_player.cam.kick_mag_seat)
		weapon.slide_batteried.connect(owner_player.cam.kick_battery)
		weapons.append(weapon)
	for i in weapons.size():
		_show(i, i == current)


func select(index: int) -> void:
	if index == current or index < 0 or index >= weapons.size() or not player.is_alive():
		return
	var old = weapons[current]
	old.release_trigger()
	old.set_aim(false)
	_show(current, false)
	current = index
	_show(current, true)
	weapons[current].equip()
	player.weapon = weapons[current]
	GameAudio.play_2d("cloth", -4.0, randf_range(0.95, 1.05))


func next() -> void:
	select((current + 1) % weapons.size())


func _show(index: int, shown: bool) -> void:
	weapons[index].visible = shown
	weapons[index].process_mode = Node.PROCESS_MODE_PAUSABLE if shown else Node.PROCESS_MODE_DISABLED


func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.is_alive() or player.paused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				select(0)
			KEY_2:
				select(1)
			KEY_3:
				select(2)
			KEY_Q:
				next()
	elif event is InputEventMouseButton and event.pressed and player.mouse_captured \
			and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		next()
