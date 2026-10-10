class_name EnemyWounds
extends RefCounted

const HP := 100.0
const WOUNDED_BELOW := 60.0
const HEAD_DAMAGE := 200.0
const BODY_DAMAGE := 50.0
const ZONES := {
	"Head": "head", "Neck": "head",
	"Chest.001": "chest", "Chest": "chest",
	"Spine": "belly", "Hips": "hips",
	"UpperArm_L": "arm", "UpperArm_R": "arm",
	"ForeArm_L": "arm", "ForeArm_R": "arm",
	"Hand_L": "arm", "Hand_R": "arm",
	"Thigh_L": "leg", "Thigh_R": "leg",
	"Shin_L": "leg", "Shin_R": "leg",
}
const KICK := {"head": 30.0, "chest": 22.0, "belly": 20.0, "hips": 16.0, "arm": 85.0, "leg": 40.0}
const REACTIONS := {"chest": "HitChest", "belly": "HitGut", "hips": "HitGut", "arm": "HitArm", "leg": "HitLeg"}
const POWER_REF := 2.77
const KICK_REF := 2.6
const POWER_MAX := 1.5
const BLEED := 2.0
const STAGGER := {"head": 0.0, "chest": 1.1, "belly": 1.0, "hips": 0.9, "arm": 0.6, "leg": 0.9}

var hp := HP
var region := ""
var stagger := 0.0
var limp := 0.0
var bleed := 0.0


static func power(impulse: float) -> float:
	return Impulse.scale(impulse, POWER_REF, 1.0, POWER_MAX)


func take(bone: String, impulse := 0.0) -> String:
	region = ZONES.get(bone, "chest")
	hp -= (HEAD_DAMAGE if region == "head" else BODY_DAMAGE) * power(impulse)
	if Impulse.lethal(impulse):
		hp = 0.0
	stagger = maxf(stagger, STAGGER[region])
	if region == "leg":
		limp = 1.0
	if hp > 0.0 and wounded():
		bleed = BLEED
	return region


func reaction(bone: String, from_behind: bool) -> String:
	var clip: String = REACTIONS.get(region, "HitChest")
	if region == "arm" or region == "leg":
		return clip + bone.right(1)
	return "HitBack" if from_behind else clip


func tick(delta: float) -> void:
	stagger = maxf(0.0, stagger - delta)
	hp -= bleed * delta


func dead() -> bool:
	return hp <= 0.0


func wounded() -> bool:
	return hp < WOUNDED_BELOW


func pace() -> float:
	return (0.5 if wounded() else 1.0) * (1.0 - 0.45 * limp)


static func kick_for(region: String, impulse: float) -> float:
	return KICK.get(region, 20.0) * Impulse.scale(impulse, KICK_REF, 0.6, 1.4)
