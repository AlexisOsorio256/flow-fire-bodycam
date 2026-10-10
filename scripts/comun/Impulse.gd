class_name Impulse
extends RefCounted

const LETHAL := 8.0


static func scale(impulse: float, ref: float, lo: float, hi: float) -> float:
	return clampf(impulse / ref, lo, hi)


static func push(impulse: float, factor: float, lo: float, hi: float) -> float:
	return clampf(impulse * factor, lo, hi)


static func lethal(impulse: float) -> bool:
	return impulse >= LETHAL
