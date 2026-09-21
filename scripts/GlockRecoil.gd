class_name GlockRecoil
extends RefCounted

## RETROCESO Y PESO DEL ARMA. Dos capas separadas, nunca sumadas a lo loco:
##
##   1. EL ARMA dentro del agarre -> `pos` + `rot` sobre WeaponSocket.
##      Rapida y corta: la pistola cabecea y se hunde unos milimetros.
##   2. EL CONJUNTO cede despues -> `give_pos` + `give_rot` sobre BodyGive.
##      Mas lenta y mas blanda: el cuerpo absorbe el empuje. No es un segundo
##      latigazo, es la masa del conjunto.
##
## La camara NO se toca aqui: eso es Player.gd.
##
## PARA QUE EL ARMA PESE MAS, se toca la seccion de abajo y nada mas. Las tres
## palancas que de verdad cambian la sensacion de masa:
##   RECOIL_KICK     cuanto golpea al disparar (impulso)
##   WEAPON_K        cuanto tarda en volver (rigidez; mas bajo = mas pesada)
##   GIVE            cuanto cede el conjunto (mas alto = absorbe mas)
## El resto son limites de seguridad.

# --- 1. arma ---------------------------------------------------------------
# Unidades VERDADERAS: velocidades iniciales del resorte (rad/s y m/s).
# El golpe rapido no se infla: la masa se percibe porque tarda un poco mas en
# asentarse y porque el conjunto acompana despues. Empujar solo el angulo pico
# hacia arriba convertiria la Glock en una camara que salta, no en ~600-700 g de
# arma sostenida a dos manos.
const RECOIL_PITCH_VEL := 5.10   # rad/s de cabeceo por disparo
const RECOIL_YAW_VEL := 0.14     # rad/s dispersion lateral, simetrica
const WEAPON_K := 450.0          # algo menos rigido: mismo golpe, mas lectura de masa
const WEAPON_C := 24.0           # amortiguado: vuelve limpio sin rebote elastico
const RECOIL_BACK_VEL := 0.105   # m/s hacia el tirador
const RECOIL_RISE_VEL := 0.020   # m/s subida

# --- 2. conjunto -----------------------------------------------------------
const GIVE := 0.72               # mas del impulso llega a manos/brazos
const GIVE_K := 60.0             # mas blando y tardio que el arma
const GIVE_C := 12.0

# --- limites ---------------------------------------------------------------
const POS_LIMIT := Vector3(0.012, 0.018, 0.020)
const ROT_LIMIT := Vector3(0.22, 0.055, 0.065)
const GIVE_POS_LIMIT := Vector3(0.008, 0.008, 0.010)
const GIVE_ROT_LIMIT := Vector3(0.035, 0.0, 0.018)

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var rot := Vector3.ZERO
var rot_vel := Vector3.ZERO
var give_pos := Vector3.ZERO
var give_vel := Vector3.ZERO
var give_rot := Vector3.ZERO
var give_rot_vel := Vector3.ZERO
## Punto de giro del cabeceo, en espacio del WeaponSocket. Lo coloca el
## viewmodel sobre la empuñadura (Grip MEDIDO del GLB via grip_pivot()).
var pivot := Vector3(0.0, -0.055, 0.025)


## El disparo tiene dos tiempos: primero el arma gira y se hunde en el agarre;
## despues el conjunto cede una fraccion.
func kick_shot() -> void:
	rot_vel += Vector3(
		RECOIL_PITCH_VEL + randf() * 0.30,
		(randf() - 0.5) * RECOIL_YAW_VEL,
		(randf() - 0.5) * 0.18)
	vel += Vector3((randf() - 0.5) * 0.012, RECOIL_RISE_VEL, RECOIL_BACK_VEL + randf() * 0.015)
	give_vel += Vector3((randf() - 0.5) * 0.010, 0.016, RECOIL_BACK_VEL * GIVE)
	# ~1,3 grados de cesion lenta del conjunto, despues de ~6-7 grados del arma.
	# Es suficiente para leer hombros/manos absorbiendo energia sin duplicar el
	# recoil rapido del WeaponSocket.
	give_rot_vel += Vector3(0.42 + randf() * 0.05, 0.0, (randf() - 0.5) * 0.065)


## Asentar un cargador transmite masa al agarre, pero no parece otro disparo.
## El golpe viene de abajo: empuja el arma hacia arriba y atras contra el cuerpo.
func kick_mag_seat() -> void:
	rot_vel.x += 0.32
	vel.z += 0.012
	give_vel += Vector3(0.0, 0.022, 0.018)
	give_rot_vel.x -= 0.08


## La corredera choca contra el armazon/bloque de cierre al entrar en bateria:
## golpe seco hacia adelante y leve cabeceo hacia abajo.
func kick_slide_battery() -> void:
	rot_vel.x -= 0.16
	vel.z -= 0.012
	give_vel += Vector3(0.0, -0.005, -0.010)
	give_rot_vel.x -= 0.04


func set_pivot(point: Vector3) -> void:
	pivot = point


func update(delta: float) -> void:
	var rp := Springs.vector(pos, vel, WEAPON_K, WEAPON_C, delta)
	pos = rp[0]
	vel = rp[1]
	var rr := Springs.vector(rot, rot_vel, WEAPON_K, WEAPON_C, delta)
	rot = rr[0]
	rot_vel = rr[1]
	pos = Vector3(clampf(pos.x, -POS_LIMIT.x, POS_LIMIT.x), clampf(pos.y, -POS_LIMIT.y, POS_LIMIT.y), clampf(pos.z, -POS_LIMIT.z, POS_LIMIT.z))
	rot = Vector3(clampf(rot.x, -ROT_LIMIT.x, ROT_LIMIT.x), clampf(rot.y, -ROT_LIMIT.y, ROT_LIMIT.y), clampf(rot.z, -ROT_LIMIT.z, ROT_LIMIT.z))

	var gp := Springs.vector(give_pos, give_vel, GIVE_K, GIVE_C, delta)
	give_pos = gp[0]
	give_vel = gp[1]
	var gr := Springs.vector(give_rot, give_rot_vel, GIVE_K, GIVE_C, delta)
	give_rot = gr[0]
	give_rot_vel = gr[1]
	give_pos = Vector3(clampf(give_pos.x, -GIVE_POS_LIMIT.x, GIVE_POS_LIMIT.x), clampf(give_pos.y, -GIVE_POS_LIMIT.y, GIVE_POS_LIMIT.y), clampf(give_pos.z, -GIVE_POS_LIMIT.z, GIVE_POS_LIMIT.z))
	give_rot = Vector3(clampf(give_rot.x, -GIVE_ROT_LIMIT.x, GIVE_ROT_LIMIT.x), 0.0, clampf(give_rot.z, -GIVE_ROT_LIMIT.z, GIVE_ROT_LIMIT.z))


## Escribe las dos capas. `give` recibe la cesion del conjunto; `socket`
## recibe el cabeceo del arma. Cada nodo tiene UN dueno y solo este metodo
## escribe en ellos.
func apply(give: Node3D, socket: Node3D) -> void:
	give.position = give_pos
	give.rotation = give_rot
	var r := Basis.from_euler(rot)
	socket.position = pivot + (r * -pivot) + pos
	socket.basis = r
