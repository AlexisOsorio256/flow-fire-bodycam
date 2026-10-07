class_name Springs
extends RefCounted

const MAX_STEP := 0.02
const MAX_STEPS := 96


static func _max_step(k: float, c: float) -> float:
    var by_spring := 0.25 / sqrt(maxf(k, 0.0001))
    var by_damping := 0.25 / maxf(c, 0.0001)
    return minf(minf(by_spring, by_damping), MAX_STEP)


static func scalar(pos: float, vel: float, k: float, c: float, delta: float) -> Vector2:
    var h_max := _max_step(k, c)
    var span := minf(delta, h_max * MAX_STEPS)
    var steps := maxi(1, ceili(span / h_max))
    var h := span / float(steps)
    for _i in range(steps):
        vel += (-k * pos - c * vel) * h
        pos += vel * h
    return Vector2(pos, vel)


static func vector(pos: Vector3, vel: Vector3, k: float, c: float, delta: float) -> Array:
    var h_max := _max_step(k, c)
    var span := minf(delta, h_max * MAX_STEPS)
    var steps := maxi(1, ceili(span / h_max))
    var h := span / float(steps)
    var p := pos
    var v := vel
    for _i in range(steps):
        v += (-k * p - c * v) * h
        p += v * h
    return [p, v]
