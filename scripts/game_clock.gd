extends Node

## In-game date and time, registered as the `GameClock` autoload.
##
## One in-game day lasts REAL_SECONDS_PER_DAY real seconds (2 hours), so game time runs
## SPEED times faster than real time. Saved per user by the `SaveGame` autoload.

## A new in-game minute started (the taskbar clock and dates follow it).
signal minute_changed
## One real second passed; things that live in real time (the SkamCoin market) tick on it.
signal second_passed

const START := {"year": 2028, "month": 9, "day": 1, "hour": 8, "minute": 30, "second": 0}
const REAL_SECONDS_PER_DAY := 7200.0
const SPEED := 86400.0 / REAL_SECONDS_PER_DAY

## Game seconds since START.
var elapsed := 0.0
## Stops time, e.g. for tests that drive the clock by hand.
var running := true
var _real := 0.0

func _process(delta: float) -> void:
	if running:
		advance(delta)

## Moves time forward by [param real_seconds] of real time.
func advance(real_seconds: float) -> void:
	var minute_before := floori(elapsed / 60.0)
	elapsed += real_seconds * SPEED
	_real += real_seconds
	while _real >= 1.0:
		_real -= 1.0
		second_passed.emit()
	if floori(elapsed / 60.0) != minute_before:
		minute_changed.emit()

func reset_state() -> void:
	elapsed = 0.0
	_real = 0.0
	minute_changed.emit()

func save_state() -> Dictionary:
	return {"elapsed": elapsed}

func load_state(data: Dictionary) -> void:
	elapsed = maxf(float(data.get("elapsed", 0.0)), 0.0)
	minute_changed.emit()

static func start_unix() -> int:
	return Time.get_unix_time_from_datetime_dict(START)

## Current game moment as a Unix timestamp (seconds).
func unix() -> int:
	return start_unix() + floori(elapsed)

func datetime() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(unix())

## "01.09.2028"
func date_text() -> String:
	return format_date(unix())

## "08:00"
func time_text() -> String:
	return format_time(unix())

## "01.09.2028  08:00", as used in bank and casino histories.
func stamp() -> String:
	return date_text() + "  " + time_text()

static func format_date(unix_time: int) -> String:
	var moment := Time.get_datetime_dict_from_unix_time(unix_time)
	return "%02d.%02d.%04d" % [moment.day, moment.month, moment.year]

static func format_time(unix_time: int, with_seconds := false) -> String:
	var moment := Time.get_datetime_dict_from_unix_time(unix_time)
	if with_seconds:
		return "%02d:%02d:%02d" % [moment.hour, moment.minute, moment.second]
	return "%02d:%02d" % [moment.hour, moment.minute]
