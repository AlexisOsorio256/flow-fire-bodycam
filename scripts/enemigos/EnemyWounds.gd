class_name EnemyWounds
extends RefCounted

const HP := 100.0
const WOUNDED_BELOW := 60.0
const ZONES := {
	"Head": ["head", 200.0], "Neck": ["head", 200.0],
	"Chest.001": ["chest", 60.0], "Chest": ["chest", 60.0],
	"Spine": ["belly", 50.0], "Hips": ["hips", 50.0],
	"UpperArm_L": ["arm", 25.0], "UpperArm_R": ["arm", 25.0],
	"ForeArm_L": ["arm", 20.0], "ForeArm_R": ["arm", 20.0],
	"Hand_L": ["arm", 14.0], "Hand_R": ["arm", 14.0],
	"Thigh_L": ["leg", 34.0], "Thigh_R": ["leg", 34.0],
	"Shin_L": ["leg", 24.0], "Shin_R": ["leg", 24.0],
}
const KICK := {"head": 30.0, "chest": 22.0, "belly": 20.0, "hips": 16.0, "arm": 85.0, "leg": 40.0}
const REACTIONS := {"chest": "HitChest", "belly": "HitGut", "hips": "HitGut", "arm": "HitArm", "leg": "HitLeg"}
const POWER_REF := 2.77
const POWER_MAX := 1.5
const STAGGER := {"head": 0.0, "chest": 1.1, "belly": 1.0, "hips": 0.9, "arm": 0.6, "leg": 0.9}

var hp := HP
var region := ""
var stagger := 0.0
var limp := 0.0


static func power(impulse: float) -> float:
	return clampf(impulse / POWER_REF, 1.0, POWER_MAX)


func take(bone: String, impulse := 0.0) -> String:
	var zone: Array = ZONES.get(bone, ["chest", 40.0])
	region = zone[0]
	hp -= zone[1] * power(impulse)
	stagger = maxf(stagger, STAGGER[region])
	if region == "leg":
		limp = 1.0
	return region


func reaction(bone: String, from_behind: bool) -> String:
	var clip: String = REACTIONS.get(region, "HitChest")
	if region == "arm" or region == "leg":
		return clip + bone.right(1)
	return "HitBack" if from_behind else clip


func tick(delta: float) -> void:
	stagger = maxf(0.0, stagger - delta)


func dead() -> bool:
	return hp <= 0.0


func wounded() -> bool:
	return hp < WOUNDED_BELOW


func pace() -> float:
	return (0.5 if wounded() else 1.0) * (1.0 - 0.45 * limp)


func kick(impulse: float) -> float:
	return KICK.get(region, 20.0) * clampf(impulse / 2.6, 0.6, 1.4)
