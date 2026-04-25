# res://ui/common/components/floating_gauge.gd
class_name FloatingGauge
extends Control

@onready var health_bar: ProgressBar = $PanelContainer/MarginContainer/VBoxContainer/HealthBar
@onready var ap_dots_container: HBoxContainer = $PanelContainer/MarginContainer/VBoxContainer/APDotsContainer

@export var target_unit: Node2D
@export var offset: Vector2 = Vector2(0, -35)

var _max_hp: int = 100
var _current_hp: int = 100
var _max_ap: int = 5
var _current_ap: int = 5

func _ready() -> void:
	# Ajuster le point de pivot en bas au centre
	pivot_offset = size / 2.0
	
	# Initialiser l'affichage
	update_gauge(_current_hp, _max_hp, _current_ap, _max_ap)

func _process(_delta: float) -> void:
	if not is_instance_valid(target_unit):
		# Détruire la jauge si l'unité ciblée n'existe plus
		queue_free()
		return
		
	# Projeter la position du monde 2D sur l'écran
	# Si le HUD est sur un CanvasLayer séparé avec des transformations,
	# get_global_transform_with_canvas() nous donne les coordonnées absolues à l'écran.
	var unit_screen_pos: Vector2 = target_unit.get_global_transform_with_canvas().origin
	global_position = unit_screen_pos + offset - (size / 2.0)

## Configure l'unité ciblée et s'abonne à ses signaux si disponibles
func setup(unit: Node2D) -> void:
	target_unit = unit
	
	# Si l'unité a des signaux de mise à jour, on s'y connecte de façon dynamique et sécurisée
	if target_unit.has_signal("hp_changed"):
		target_unit.connect("hp_changed", _on_unit_hp_changed)
	if target_unit.has_signal("ap_changed"):
		target_unit.connect("ap_changed", _on_unit_ap_changed)
		
	# Lecture initiale des données si elles existent
	var hp = target_unit.get("hit_points")
	var max_hp = target_unit.get("max_hit_points")
	var ap = target_unit.get("action_points")
	var max_ap = target_unit.get("max_action_points")
	
	_current_hp = hp if hp != null else 100
	_max_hp = max_hp if max_hp != null else 100
	_current_ap = ap if ap != null else 5
	_max_ap = max_ap if max_ap != null else 5
	
	update_gauge(_current_hp, _max_hp, _current_ap, _max_ap)

func _on_unit_hp_changed(new_hp: int, max_hp: int) -> void:
	_animate_health(new_hp, max_hp)

func _on_unit_ap_changed(new_ap: int, max_ap: int) -> void:
	_current_ap = new_ap
	_max_ap = max_ap
	_update_ap_dots()

## Met à jour manuellement toutes les valeurs de la jauge
func update_gauge(hp: int, max_hp: int, ap: int, max_ap: int) -> void:
	_current_hp = hp
	_max_hp = max_hp
	_current_ap = ap
	_max_ap = max_ap
	
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = hp
	
	_update_ap_dots()

func _animate_health(new_hp: int, max_hp: int) -> void:
	if not health_bar: return
	
	_max_hp = max_hp
	_current_hp = new_hp
	health_bar.max_value = max_hp
	
	# Transition douce pour la jauge de PV
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(health_bar, "value", new_hp, 0.2)
	
	# Petit effet d'échelle lors de la prise de dégâts (shake léger)
	var shake: Tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	shake.tween_property(self, "scale", Vector2(1.1, 1.1), 0.05)
	shake.tween_property(self, "scale", Vector2.ONE, 0.15)

func _update_ap_dots() -> void:
	if not ap_dots_container: return
	
	# Nettoyer l'affichage précédent
	for child in ap_dots_container.get_children():
		child.queue_free()
		
	# Créer de petits points (dots) représentant les points d'action
	for i in range(_max_ap):
		var dot = ColorRect.new()
		dot.custom_minimum_size = Vector2(3, 3)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		
		# Couleur du point : Cyan si actif, gris sombre si consommé
		if i < _current_ap:
			dot.color = Color("#00D2FF") # Cyan actif
		else:
			dot.color = Color("#3D3D43") # Consommé
			
		# Rendre le point rond via un stylebox (ici on crée un panneau stylisé pour la rondeur)
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(3, 3)
		
		var stylebox = StyleBoxFlat.new()
		stylebox.bg_color = dot.color
		stylebox.corner_radius_top_left = 2
		stylebox.corner_radius_top_right = 2
		stylebox.corner_radius_bottom_left = 2
		stylebox.corner_radius_bottom_right = 2
		
		panel.add_theme_stylebox_override("panel", stylebox)
		ap_dots_container.add_child(panel)
