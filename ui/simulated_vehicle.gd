# res://ui/simulated_vehicle.gd
extends Node2D

var hit_points: int = 100
var max_hit_points: int = 100
var action_points: int = 5
var max_action_points: int = 5
var is_enemy: bool = false
var facing_direction: Vector2 = Vector2.DOWN
var vehicle_type: String = "tank" # "tank", "car", "plane"
