class_name Springs
extends RefCounted

const MAX_STEP := 0.02
const MAX_STEPS := 96


static func _max_step(k: float, c: float) -> float:
    var by_spring := 0.25 / sqrt(maxf(k, 0.0001))
    var by_damping := 0.25 / maxf(c, 0.0001)
    return minf(minf(by_spring, by_damping), MAX_STEP)


static func step(pos: float, vel: float, goal: float, k: float, c: float, h: float) -> Vector2:
    var next := vel + ((goal - pos) * k - c * vel) * h
    return Vector2(pos + next * h, next)


static func scalar(pos: float, vel: float, k: float, c: float, delta: float) -> Vector2:
    var h_max := _max_step(k, c)
    var span := minf(delta, h_max * MAX_STEPS)
    var steps := maxi(1, ceili(span / h_max))
    var h := span / float(steps)
    for _i in range(steps):
        var s := step(pos, vel, 0.0, k, c, h)
        pos = s.x
        vel = s.y
    return Vector2(pos, vel)


static func vector(pos: Vector3, vel: Vector3, k: float, c: float, delta: float) -> Array:
    var out := [Vector3.ZERO, Vector3.ZERO]
    vector_into(pos, vel, k, c, delta, out)
    return out


static func vector_into(pos: Vector3, vel: Vector3, k: float, c: float, delta: float, out: Array) -> void:
    var h_max := _max_step(k, c)
    var span := minf(delta, h_max * MAX_STEPS)
    var steps := maxi(1, ceili(span / h_max))
    var h := span / float(steps)
    var p := pos
    var v := vel
    for _i in range(steps):
        v += (-k * p - c * v) * h
        p += v * h
    out[0] = p
    out[1] = v
