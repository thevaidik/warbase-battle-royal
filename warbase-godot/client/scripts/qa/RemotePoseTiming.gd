extends RefCounted
## Fixed-bucket, allocation-free timing summary for explicit QA runs.

const BUCKET_LIMITS: Array[int] = [10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000, 25000, 50000]

var _counts := PackedInt64Array()
var _samples := 0
var _total_us := 0
var _max_us := 0
var _total_items := 0
var _max_items := 0

func _init() -> void:
	_counts.resize(BUCKET_LIMITS.size() + 1)
	_counts.fill(0)

func record(duration_us: int, item_count: int) -> void:
	var elapsed := maxi(0, duration_us)
	var items := maxi(0, item_count)
	_samples += 1
	_total_us += elapsed
	_max_us = maxi(_max_us, elapsed)
	_total_items += items
	_max_items = maxi(_max_items, items)
	for index in BUCKET_LIMITS.size():
		if elapsed <= BUCKET_LIMITS[index]:
			_counts[index] += 1
			return
	_counts[BUCKET_LIMITS.size()] += 1

func summary() -> Dictionary:
	return {
		"samples": _samples,
		"mean_us": float(_total_us) / maxi(_samples, 1),
		"max_us": _max_us,
		"p50_us_upper_bound": _percentile_upper_bound(0.50),
		"p95_us_upper_bound": _percentile_upper_bound(0.95),
		"p99_us_upper_bound": _percentile_upper_bound(0.99),
		"mean_items": float(_total_items) / maxi(_samples, 1),
		"max_items": _max_items,
		"bucket_limits_us": BUCKET_LIMITS,
	}

func _percentile_upper_bound(percentile: float) -> int:
	if _samples == 0: return 0
	var target := maxi(1, int(ceil(float(_samples) * clampf(percentile, 0.0, 1.0))))
	var cumulative := 0
	for index in _counts.size():
		cumulative += _counts[index]
		if cumulative >= target:
			return BUCKET_LIMITS[index] if index < BUCKET_LIMITS.size() else _max_us
	return _max_us
