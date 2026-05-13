extends Node

# In-memory session state. Resets when the browser reloads.

enum Mode { SINGLE, VERSUS_AI, MULTIPLAYER }
enum Difficulty { EASY, MEDIUM, HARD, ADAPTIVE, CUSTOM }

var current_mode: int = Mode.SINGLE
var current_difficulty: int = Difficulty.EASY

# Stats stored as stats[mode][difficulty] = {high_score, last_score, total_rounds, total_points}
# Multiplayer mode never writes here (per spec: no high score saved).
var stats: Dictionary = {}

# Custom mode configuration — defaults match Medium difficulty.
# Persists in-session so the config screen remembers prior values.
var custom_config: Dictionary = {
	"player_speed": 2000.0,
	"hazard_speed": 150.0,
	"red_count": 10,
	"increase_reds": false,
	"red_increment_interval": 2,
	"red_cap": 15,
	"use_purples": false,
	"purple_start_score": 20,
	"purple_increment_interval": 5,
	"purple_cap": 5,
	"speed_scaling": false,
}


func _ready() -> void:
	_init_stats()


func _init_stats() -> void:
	stats.clear()
	for mode in [Mode.SINGLE, Mode.VERSUS_AI, Mode.MULTIPLAYER]:
		stats[mode] = {}
		for diff in [
			Difficulty.EASY,
			Difficulty.MEDIUM,
			Difficulty.HARD,
			Difficulty.ADAPTIVE,
			Difficulty.CUSTOM,
		]:
			stats[mode][diff] = {
				"high_score": 0,
				"last_score": 0,
				"total_rounds": 0,
				"total_points": 0,
			}


func record_round(final_score: int) -> void:
	# Multiplayer is excluded per spec — no stats saved.
	if current_mode == Mode.MULTIPLAYER:
		return
	var s: Dictionary = stats[current_mode][current_difficulty]
	s["last_score"] = final_score
	s["total_rounds"] += 1
	s["total_points"] += final_score
	if final_score > s["high_score"]:
		s["high_score"] = final_score


func record_high_score(value: int) -> void:
	# Versus AI uses this — only the high score is tracked (no last/avg).
	if current_mode == Mode.MULTIPLAYER:
		return
	var s: Dictionary = stats[current_mode][current_difficulty]
	if value > s["high_score"]:
		s["high_score"] = value


func get_high_score(difficulty: int) -> int:
	return stats[current_mode][difficulty]["high_score"]


func get_last_score(difficulty: int) -> int:
	return stats[current_mode][difficulty]["last_score"]


func get_average_score(difficulty: int) -> float:
	var s: Dictionary = stats[current_mode][difficulty]
	if s["total_rounds"] <= 0:
		return 0.0
	return float(s["total_points"]) / float(s["total_rounds"])


func difficulty_name(difficulty: int) -> String:
	match difficulty:
		Difficulty.EASY:
			return "Easy"
		Difficulty.MEDIUM:
			return "Medium"
		Difficulty.HARD:
			return "Hard"
		Difficulty.ADAPTIVE:
			return "Adaptive"
		Difficulty.CUSTOM:
			return "Custom"
		_:
			return "Unknown"


func mode_name(mode: int) -> String:
	match mode:
		Mode.SINGLE:
			return "Single Player"
		Mode.VERSUS_AI:
			return "Versus AI"
		Mode.MULTIPLAYER:
			return "Multiplayer"
		_:
			return "Unknown"
