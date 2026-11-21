extends RefCounted
## Rates measured from values sampled once per physics tick (Story 1.16 code review). A helper, not
## a test (no test_/smoke_ prefix): `const Rate := preload("res://tests/rate.gd")`.
## A count over a short window rounds a rate down (2.1 Hz counts as 2.0 over 2 s), so these measure
## the span between the first and the last event instead.


## The indices where `values` turns: its local maxima and minima, in order. A flat top or bottom
## counts once.
static func turns(values: Array) -> Array[int]:
	var out: Array[int] = []
	for i in range(1, values.size() - 1):
		var top: bool = values[i - 1] < values[i] and values[i] >= values[i + 1]
		var bottom: bool = values[i - 1] > values[i] and values[i] <= values[i + 1]
		if top or bottom:
			out.append(i)
	return out


## The lowest (x) and highest (y) rate in Hz that could have produced `events`, the tick indices of
## one repeating event (per_cycle = 1), or of the turns above (per_cycle = 2: a peak and a trough per
## cycle). A sample lands up to half a tick from the true moment, so the span may be one tick off
## either way: a cap is checked against x, an exact rate against both. Vector2.ZERO with fewer than
## two events.
static func hz_band(events: Array[int], ticks_per_second: float, per_cycle := 1) -> Vector2:
	if events.size() < 2:
		return Vector2.ZERO
	var cycles := float(events.size() - 1) / per_cycle
	var span := events[-1] - events[0]
	return Vector2(ticks_per_second * cycles / (span + 1), ticks_per_second * cycles / maxi(span - 1, 1))
