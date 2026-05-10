extends Node

# In-memory session state. Resets when the browser reloads.

enum Difficulty { EASY, MEDIUM, HARD, ADAPTIVE, CUSTOM }

var current_difficulty: int = Difficulty.EASY

var stats: Dictionary = {
	Difficulty.EASY: {"high_score": 0, "last_score": 0, "total_rounds": 0, "total_points": 0},
	Difficulty.MEDIUM: {"high_score": 0, "last_score": 0, "total_rounds": 0, "total_points": 0},
	Difficulty.HARD: {"high_score": 0, "last_score": 0, "total_rounds": 0, "total_points": 0},
	Difficulty.ADAPTIVE: {"high_score": 0, "last_score": 0, "total_rounds": 0, "total_points": 0},
	Difficulty.CUSTOM: {"high_score": 0, "last_score": 0, "total_rounds": 0, "total_points": 0},
}

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


func record_round(final_score: int) -> void:
	var s: Dictionary = stats[current_difficulty]
	s["last_score"] = final_score
	s["total_rounds"] += 1
	s["total_points"] += final_score
	if final_score > s["high_score"]:
		s["high_score"] = final_score


func get_high_score(difficulty: int) -> int:
	return stats[difficulty]["high_score"]


func get_last_score(difficulty: int) -> int:
	return stats[difficulty]["last_score"]


func get_average_score(difficulty: int) -> float:
	var s: Dictionary = stats[difficulty]
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
