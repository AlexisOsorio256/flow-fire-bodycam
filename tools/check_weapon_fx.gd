extends Node

## Regresion de presentacion barata pero critica:
## - un disparo debe dibujar al menos un frame de fogonazo incluso a 16 FPS;
## - el humo de boca/eyeccion debe reutilizar sus recursos de dibujo y nacer.
##
## Se ejecuta como escena del proyecto para que los autoloads GameAudio e
## ImpactFX existan igual que en runtime:
##   godot4 --headless --path . tools/check_weapon_fx.tscn


func _ready() -> void:
    var fx := WeaponFX.new()
    add_child(fx)
    fx.build()
    fx.pop_flash()

    # 62,5 ms > FLASH_TIME (50 ms). Antes update() restaba este delta en el
    # mismo frame del fire y apagaba todo antes de que el renderer lo viera.
    fx.update(1.0 / 16.0)
    var first_visible := fx.flash_mesh != null and fx.flash_mesh.visible
    var first_timer := fx.timer
    var first_world := fx.world_flash.light_energy if fx.world_flash != null else -1.0
    _check(first_visible, "fogonazo visible durante el primer frame a 16 FPS")
    _check(first_timer > 0.0, "el primer update no consume la vida completa del flash")
    _check(fx.muzzle_light.visible, "la luz del viewmodel esta visible durante el fogonazo")
    _check(fx.world_flash.visible, "la luz de mundo esta visible durante el fogonazo")
    _check(first_world > 0.0, "la luz de mundo participa en el primer frame")

    fx.update(1.0 / 16.0)
    _check(not fx.flash_mesh.visible, "el fogonazo no queda pegado despues del frame garantizado")
    _check(not fx.muzzle_light.visible and fx.muzzle_light.light_energy == 0.0,
        "la luz del viewmodel se apaga al terminar el fogonazo")
    _check(not fx.world_flash.visible and fx.world_flash.light_energy == 0.0,
        "la luz de mundo se apaga al terminar el fogonazo")

    _check(ImpactFX.get("_muzzle_smoke_quad") != null, "humo de boca comparte QuadMesh")
    _check(ImpactFX.get("_muzzle_smoke_scale") != null, "humo de boca comparte curva de escala")
    _check(ImpactFX.get("_muzzle_smoke_fade") != null, "humo de boca comparte fade")
    _check(ImpactFX.get("_ejection_smoke_quad") != null, "humo de eyeccion comparte QuadMesh")

    ImpactFX.spawn_muzzle_smoke(Vector3.ZERO, Vector3.FORWARD)
    ImpactFX.spawn_ejection_smoke(Vector3.ZERO, Vector3.RIGHT)
    await get_tree().process_frame
    var particle_nodes := ImpactFX.find_children("*", "GPUParticles3D", true, false).size()
    _check(particle_nodes >= 2, "nacen humo de boca y humo de eyeccion")

    if _failures == 0:
        print("CHECK weapon_fx: OK (flash 16 FPS + humo compartido)")
        get_tree().quit(0)
    else:
        get_tree().quit(1)


var _failures := 0


func _check(ok: bool, label: String) -> void:
    if ok:
        return
    _failures += 1
    push_error("CHECK weapon_fx FALLO: " + label)
