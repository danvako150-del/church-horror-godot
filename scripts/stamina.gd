class_name ChurchStamina
extends RefCounted

var power: float = 100.0
var exhausted: bool = false

func step(delta: float, running: bool) -> void:
	if delta <= 0.0:
		return
	if running and not exhausted:
		power -= 20.0 * delta
		if power <= 0.0001:
			power = 0.0
			exhausted = true
	else:
		power += 20.0 * delta
		if power >= 99.9999:
			power = 100.0
			exhausted = false
	power = clampf(power, 0.0, 100.0)
