# res://ui/ui_test_scene.gd
extends Node2D

const SimulatedVehicle = preload("res://ui/simulated_vehicle.gd")

@onready var ui_manager: UIManager = $UIManager

# Nœuds de simulation
var simulated_units: Array[Node2D] = []
var active_unit: Node2D = null

# États tactiles
var press_position: Vector2 = Vector2.ZERO
var current_mode: String = "none"
var turns: int = 1
var max_ap: int = 5
var current_ap: int = 5
var enemy_ap: int = 5
var is_enemy_turn: bool = false
var is_vs_ia: bool = true

# Drag & Swipe gesture tracking
var is_dragging: bool = false
var drag_current_position: Vector2 = Vector2.ZERO
var is_perfect_zone: bool = false
var perfect_timer: float = 0.0
var oscillation_time: float = 0.0

# Configuration de la Grille Agrandie 6x10
const GRID_COLUMNS = 6
const GRID_ROWS = 10
const CELL_WIDTH = 64
const OFFSET_X = 24
const OFFSET_Y = 100

const MAP_PRESETS = {
	"classic": [Vector2i(2, 4), Vector2i(3, 4), Vector2i(2, 5), Vector2i(3, 5)],
	"cross": [Vector2i(2, 4), Vector2i(3, 4), Vector2i(2, 5), Vector2i(3, 5), Vector2i(2, 3), Vector2i(3, 3), Vector2i(2, 6), Vector2i(3, 6), Vector2i(1, 4), Vector2i(1, 5), Vector2i(4, 4), Vector2i(4, 5)],
	"pillars": [Vector2i(1, 3), Vector2i(4, 3), Vector2i(1, 6), Vector2i(4, 6)],
	"corridor": [Vector2i(0, 4), Vector2i(1, 4), Vector2i(0, 5), Vector2i(1, 5), Vector2i(4, 4), Vector2i(5, 4), Vector2i(4, 5), Vector2i(5, 5)]
}
var current_map_name: String = "classic"
var obstacle_cells: Array[Vector2i] = [
	Vector2i(2, 4), Vector2i(3, 4), Vector2i(2, 5), Vector2i(3, 5)
]

# Gestion des projectiles physiques
var active_projectiles: Array[Dictionary] = []

# VFX
var laser_start: Vector2 = Vector2.ZERO
var laser_end: Vector2 = Vector2.ZERO
var laser_color: Color = Color("#00D2FF")
var show_laser: bool = false

func _ready() -> void:
	# Connecter les signaux du UIManager pour simuler la boucle de jeu
	ui_manager.match_started.connect(_on_match_started)
	ui_manager.play_again_requested.connect(_on_play_again_requested)
	ui_manager.match_paused.connect(_on_match_cleaned)
	
	print("Scène de démonstration UI prête. Lancement du flux complet !")

func _get_oscillation_pct() -> float:
	var speed = 1.6
	var cycle = fmod(oscillation_time * speed, 2.0)
	return cycle if cycle <= 1.0 else 2.0 - cycle

func _process(delta: float) -> void:
	# Mettre à jour l'affichage en continu pour animer les halos de sélection
	if is_dragging:
		oscillation_time += delta
		var pct = _get_oscillation_pct()
		is_perfect_zone = (pct >= 0.80 and pct <= 0.90)
		
		if is_perfect_zone:
			perfect_timer += delta * 15.0 # pulsation rapide haptique
		else:
			perfect_timer += delta * 2.0  # pulsation normale lente
	else:
		perfect_timer += delta * 2.0
		
	# Simuler la physique des projectiles de tir actifs
	var proj_to_remove = []
	for proj in active_projectiles:
		var prev_pos = proj.position
		var speed = 750.0 # Vitesse du projectile en px/s
		var next_pos = prev_pos + proj.velocity * speed * delta
		
		# Sweep check pas-à-pas (pas de 2px)
		var step_size = 2.0
		var direction = proj.velocity.normalized()
		var distance = prev_pos.distance_to(next_pos)
		var steps = int(distance / step_size)
		var hit_detected = false
		
		for step in range(1, steps + 1):
			var check_pos = prev_pos + direction * (step * step_size)
			
			# 1. Collision avec un véhicule
			var hit_unit = null
			for unit in simulated_units:
				if is_instance_valid(unit) and _get_hp(unit) > 0:
					if _get_is_enemy(unit) != proj.is_enemy:
						if unit.global_position.distance_to(check_pos) < 24.0:
							hit_unit = unit
							break
			if hit_unit:
				hit_detected = true
				
				# Appliquer les dégâts
				var dmg = proj.damage
				var new_hp = max(0, _get_hp(hit_unit) - dmg)
				hit_unit.set("hit_points", new_hp)
				
				# Secousse de l'unité
				var target_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				var target_orig_pos = hit_unit.global_position
				target_tween.tween_property(hit_unit, "global_position", target_orig_pos + Vector2(8, 0), 0.05)
				target_tween.tween_property(hit_unit, "global_position", target_orig_pos - Vector2(8, 0), 0.05)
				target_tween.tween_property(hit_unit, "global_position", target_orig_pos + Vector2(4, 0), 0.05)
				target_tween.tween_property(hit_unit, "global_position", target_orig_pos, 0.05)
				
				_update_unit_gauge(hit_unit)
				_spawn_floating_damage_text(hit_unit.global_position, "-%d HP" % dmg)
				_update_red_team_health_bar()
				
				if new_hp <= 0:
					if hit_unit == active_unit:
						active_unit = null
					get_tree().create_timer(0.2).timeout.connect(func():
						_explode_vehicle(hit_unit)
						_check_game_over()
					)
				break
				
			# 2. Collision avec un obstacle
			for cell in obstacle_cells:
				var x_min = OFFSET_X + cell.x * CELL_WIDTH
				var x_max = OFFSET_X + (cell.x + 1) * CELL_WIDTH
				var y_min = OFFSET_Y + cell.y * CELL_WIDTH
				var y_max = OFFSET_Y + (cell.y + 1) * CELL_WIDTH
				if check_pos.x >= x_min and check_pos.x <= x_max and check_pos.y >= y_min and check_pos.y <= y_max:
					if proj.bounces_left > 0:
						var normal = _get_obstacle_collision_normal(check_pos - direction * 2.0, cell)
						proj.velocity = proj.velocity.bounce(normal)
						proj.position = check_pos + normal * 4.0
						proj.bounces_left -= 1
						proj.damage += 15 # Bonus de dégâts ricochet !
						_spawn_floating_damage_text(check_pos, "Ricochet ! +15 Dmg")
						hit_detected = true
						break
					else:
						hit_detected = true
						break
			if hit_detected:
				break
				
			# 3. Collision avec une bordure de la grille
			var margin = 20.0
			if check_pos.x < (OFFSET_X + margin) or check_pos.x > (OFFSET_X + GRID_COLUMNS * CELL_WIDTH - margin) or check_pos.y < (OFFSET_Y + margin) or check_pos.y > (OFFSET_Y + GRID_ROWS * CELL_WIDTH - margin):
				hit_detected = true
				if proj.bounces_left > 0:
					var normal = _get_boundary_collision_normal(check_pos - direction * 2.0)
					proj.velocity = proj.velocity.bounce(normal)
					proj.position = check_pos + normal * 4.0
					proj.bounces_left -= 1
					proj.damage += 15 # Les rebonds sur les bords donnent aussi le bonus
					_spawn_floating_damage_text(check_pos, "Ricochet ! +15 Dmg")
					break
				else:
					break
					
		if hit_detected:
			if proj.bounces_left < 0:
				proj_to_remove.append(proj)
			elif proj.bounces_left >= 0 and proj.position != prev_pos:
				pass # Continue avec sa nouvelle trajectoire de rebond
			else:
				proj_to_remove.append(proj)
		else:
			proj.position = next_pos
			
		# Sécurité de sortie d'écran
		if proj.position.x < 0 or proj.position.x > 432 or proj.position.y < 0 or proj.position.y > 960:
			proj_to_remove.append(proj)
			
	for p in proj_to_remove:
		active_projectiles.erase(p)
		
	queue_redraw()

func _check_game_over() -> void:
	var p1_alive = 0
	var p2_alive = 0
	for unit in simulated_units:
		if is_instance_valid(unit) and _get_hp(unit) > 0:
			if _get_is_enemy(unit):
				p2_alive += 1
			else:
				p1_alive += 1
				
	if p1_alive == 0:
		get_tree().create_timer(0.6).timeout.connect(func():
			ui_manager.show_victory("Ennemi", p2_alive, turns, 75)
			_on_match_cleaned()
		)
	elif p2_alive == 0:
		get_tree().create_timer(0.6).timeout.connect(func():
			var accuracy = clamp(100 - (turns * 3), 50, 98)
			ui_manager.show_victory("Player 1", p1_alive, turns, accuracy)
			_on_match_cleaned()
		)

func _on_match_started(tanks: int, cars: int, planes: int, hp: int, ap: int, vs_ia: bool = true, map_name: String = "classic", p2_tanks: int = -1, p2_cars: int = -1, p2_planes: int = -1, budget: int = 150) -> void:
	max_ap = ap
	current_ap = ap
	enemy_ap = ap
	is_vs_ia = vs_ia
	turns = 1
	current_mode = "none"
	is_enemy_turn = false
	is_dragging = false
	active_projectiles.clear()
	current_map_name = map_name
	if MAP_PRESETS.has(map_name):
		obstacle_cells.assign(MAP_PRESETS[map_name])
	else:
		obstacle_cells.assign(MAP_PRESETS["classic"])
	
	print("Gameplay: Match démarré avec Tanks=%d, Cars=%d, Planes=%d, %d PV, %d PA max. VS IA=%s, Carte=%s" % [tanks, cars, planes, hp, ap, str(vs_ia), map_name])
	_spawn_simulated_match(tanks, cars, planes, hp, ap, p2_tanks, p2_cars, p2_planes, budget)
	
	# Connecter les boutons du HUD (APRES spawn pour éviter que _on_match_cleaned ne les déconnecte !)
	var hud_node = ui_manager.hud
	if not hud_node.move_mode_pressed.is_connected(_on_move_mode):
		hud_node.move_mode_pressed.connect(_on_move_mode)
	if not hud_node.shoot_mode_pressed.is_connected(_on_shoot_mode):
		hud_node.shoot_mode_pressed.connect(_on_shoot_mode)
	if not hud_node.end_turn_pressed.is_connected(_on_end_turn):
		hud_node.end_turn_pressed.connect(_on_end_turn)
		
	# Sélectionner l'unité active par défaut
	if not simulated_units.is_empty():
		active_unit = simulated_units[0]
	queue_redraw()

func _on_play_again_requested() -> void:
	print("Gameplay: Relance immédiate demandée !")
	_on_match_cleaned()

func _on_match_cleaned() -> void:
	# Déconnecter proprement pour éviter la duplication des signaux au re-match
	if is_instance_valid(ui_manager) and is_instance_valid(ui_manager.hud):
		var hud_node = ui_manager.hud
		if hud_node.move_mode_pressed.is_connected(_on_move_mode):
			hud_node.move_mode_pressed.disconnect(_on_move_mode)
		if hud_node.shoot_mode_pressed.is_connected(_on_shoot_mode):
			hud_node.shoot_mode_pressed.disconnect(_on_shoot_mode)
		if hud_node.end_turn_pressed.is_connected(_on_end_turn):
			hud_node.end_turn_pressed.disconnect(_on_end_turn)
			
	# Nettoyer les unités
	for unit in simulated_units:
		if is_instance_valid(unit):
			unit.queue_free()
	simulated_units.clear()
	active_unit = null
	current_mode = "none"
	show_laser = false
	is_enemy_turn = false
	is_dragging = false
	active_projectiles.clear()
	
	# Nettoyer d'éventuels boutons de démonstration résiduels
	var old_btn = ui_manager.hud.get_node_or_null("DemoWinButton")
	if old_btn:
		old_btn.queue_free()
	var old_map_btn = ui_manager.hud.get_node_or_null("DemoMapButton")
	if old_map_btn:
		old_map_btn.queue_free()
		
	queue_redraw()

func _generate_enemy_team(budget: int) -> Array[String]:
	var team: Array[String] = []
	var remaining = budget
	var options = [
		{"type": "tank", "cost": 50},
		{"type": "plane", "cost": 40},
		{"type": "car", "cost": 30}
	]
	# On achète des véhicules aléatoirement jusqu'à épuisement du budget ou max 5 véhicules
	while remaining >= 30 and team.size() < 5:
		var affordable = []
		for opt in options:
			if opt.cost <= remaining:
				affordable.append(opt)
		if affordable.is_empty():
			break
		var chosen = affordable.pick_random()
		team.append(chosen.type)
		remaining -= chosen.cost
	return team

func _spawn_simulated_match(tanks: int, cars: int, planes: int, hp_max: int, ap_max: int, p2_tanks: int = -1, p2_cars: int = -1, p2_planes: int = -1, budget: int = 150) -> void:
	_on_match_cleaned()
	queue_redraw()
	
	# Construire la composition de l'équipe du joueur
	var player_types: Array[String] = []
	for i in range(tanks): player_types.append("tank")
	for i in range(planes): player_types.append("plane")
	for i in range(cars): player_types.append("car")
	
	# Spawn des véhicules alliés (P1)
	for i in range(player_types.size()):
		var type = player_types[i]
		var unit = SimulatedVehicle.new()
		unit.name = "P1_Vehicle_%d" % i
		unit.is_enemy = false
		unit.facing_direction = Vector2.DOWN # Fait face à l'ennemi
		unit.vehicle_type = type
		
		# Ajuster les PV selon le type
		var unit_hp_max = hp_max
		if type == "car":
			unit_hp_max = int(hp_max * 0.8)
		elif type == "plane":
			unit_hp_max = int(hp_max * 0.6)
			
		# Placement sur la ligne index 1 de la grille 6x10
		var col = i
		var row = 1
		unit.global_position = Vector2(OFFSET_X + col * CELL_WIDTH + CELL_WIDTH / 2.0, OFFSET_Y + row * CELL_WIDTH + CELL_WIDTH / 2.0)
		add_child(unit)
		simulated_units.append(unit)
		
		unit.set("hit_points", unit_hp_max)
		unit.set("max_hit_points", unit_hp_max)
		unit.set("action_points", ap_max)
		unit.set("max_action_points", ap_max)
		
		var gauge = ui_manager.hud.create_floating_gauge(unit)
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = Color("#00D2FF")
		fill_style.corner_radius_top_left = 1
		fill_style.corner_radius_top_right = 1
		fill_style.corner_radius_bottom_left = 1
		fill_style.corner_radius_bottom_right = 1
		gauge.health_bar.add_theme_stylebox_override("fill", fill_style)
		
	# Équipe ennemie (rouge) : en J1 vs J2, on utilise la composition choisie
	# par le joueur 2 ; en mode IA (sentinelle -1), on la génère aléatoirement.
	var enemy_types: Array[String] = []
	if p2_tanks >= 0 or p2_cars >= 0 or p2_planes >= 0:
		for i in range(max(p2_tanks, 0)): enemy_types.append("tank")
		for i in range(max(p2_planes, 0)): enemy_types.append("plane")
		for i in range(max(p2_cars, 0)): enemy_types.append("car")
	if enemy_types.is_empty():
		enemy_types = _generate_enemy_team(budget)
	for i in range(enemy_types.size()):
		var type = enemy_types[i]
		var enemy = SimulatedVehicle.new()
		enemy.name = "P2_Vehicle_%d" % i
		enemy.is_enemy = true
		enemy.facing_direction = Vector2.UP # Fait face au joueur
		enemy.vehicle_type = type
		
		var enemy_hp_max = hp_max
		if type == "car":
			enemy_hp_max = int(hp_max * 0.8)
		elif type == "plane":
			enemy_hp_max = int(hp_max * 0.6)
			
		# Placement sur la ligne index 8 de la grille 6x10
		var col = i
		var row = 8
		enemy.global_position = Vector2(OFFSET_X + col * CELL_WIDTH + CELL_WIDTH / 2.0, OFFSET_Y + row * CELL_WIDTH + CELL_WIDTH / 2.0)
		add_child(enemy)
		simulated_units.append(enemy)
		
		enemy.set("hit_points", enemy_hp_max)
		enemy.set("max_hit_points", enemy_hp_max)
		enemy.set("action_points", 0) # Commence sans PA (tour P1)
		enemy.set("max_action_points", ap_max)
		
		var gauge = ui_manager.hud.create_floating_gauge(enemy)
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = Color("#FF4B57") # Rouge pour l'ennemi
		fill_style.corner_radius_top_left = 1
		fill_style.corner_radius_top_right = 1
		fill_style.corner_radius_bottom_left = 1
		fill_style.corner_radius_bottom_right = 1
		gauge.health_bar.add_theme_stylebox_override("fill", fill_style)
		
	_create_demo_win_button()
	_create_demo_map_button()
	_update_red_team_health_bar()

func _create_demo_win_button() -> void:
	var win_btn = TouchButton.new()
	win_btn.name = "DemoWinButton"
	win_btn.text = "🏆 SIMULER VICTOIRE"
	win_btn.custom_minimum_size = Vector2(190, 36)
	win_btn.position = Vector2(226, 750)
	
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color("#24B273")
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	win_btn.add_theme_stylebox_override("normal", normal_style)
	win_btn.add_theme_color_override("font_color", Color.WHITE)
	win_btn.add_theme_font_size_override("font_size", 11)
	
	ui_manager.hud.add_child(win_btn)
	win_btn.pressed.connect(func() -> void:
		ui_manager.show_victory("Player 1", simulated_units.size() - 1, turns, 85)
		win_btn.queue_free()
	)

func _create_demo_map_button() -> void:
	var map_btn = TouchButton.new()
	map_btn.name = "DemoMapButton"
	map_btn.text = "🗺️ CARTE : " + current_map_name.to_upper()
	map_btn.custom_minimum_size = Vector2(190, 36)
	map_btn.position = Vector2(16, 750)
	
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color("#1D1D21")
	normal_style.corner_radius_top_left = 8
	normal_style.corner_radius_top_right = 8
	normal_style.corner_radius_bottom_left = 8
	normal_style.corner_radius_bottom_right = 8
	map_btn.add_theme_stylebox_override("normal", normal_style)
	map_btn.add_theme_color_override("font_color", Color.WHITE)
	map_btn.add_theme_font_size_override("font_size", 11)
	
	ui_manager.hud.add_child(map_btn)
	map_btn.pressed.connect(func() -> void:
		var keys = MAP_PRESETS.keys()
		var idx = keys.find(current_map_name)
		var next_idx = (idx + 1) % keys.size()
		current_map_name = keys[next_idx]
		obstacle_cells.assign(MAP_PRESETS[current_map_name])
		map_btn.text = "🗺️ CARTE : " + current_map_name.to_upper()
		
		_spawn_floating_damage_text(Vector2(216, 320), "Carte : " + current_map_name.to_upper())
		queue_redraw()
	)

func _on_move_mode() -> void:
	# En J1 vs J2, le joueur 2 contrôle le rouge pendant le "tour ennemi".
	# On ne bloque les modes que lorsque c'est l'IA qui joue.
	if is_enemy_turn and is_vs_ia:
		return
	current_mode = "move"
	queue_redraw()

func _on_shoot_mode() -> void:
	if is_enemy_turn and is_vs_ia:
		return
	current_mode = "shoot"
	queue_redraw()

func _on_end_turn() -> void:
	if is_enemy_turn:
		if not is_vs_ia:
			_restore_player_turn()
		return
		
	# Passer au tour de l'ennemi (J2 / IA)
	is_enemy_turn = true
	enemy_ap = max_ap
	current_mode = "none"
	active_unit = null # Dé-sélectionner à la fin du tour
	
	var hud_node = ui_manager.hud
	hud_node.set_action_mode("none")
	_update_hud_ap()
	
	# Réinitialiser les AP des unités ennemies vivantes
	for unit in simulated_units:
		if not is_instance_valid(unit) or not _get_is_enemy(unit):
			continue
		if _get_hp(unit) > 0:
			unit.set("action_points", enemy_ap)
			_update_unit_gauge(unit)
			
	_spawn_floating_damage_text(Vector2(216, 320), "Tour Ennemi" if is_vs_ia else "Tour Joueur 2")
	queue_redraw()
	
	if is_vs_ia:
		# Attendre 1.0s pour la fluidité
		get_tree().create_timer(1.0).timeout.connect(_enemy_ai_action)

func _enemy_ai_action() -> void:
	if simulated_units.is_empty() or not is_instance_valid(self):
		return
		
	# Si l'IA n'a plus d'AP, on passe le tour
	if enemy_ap < 1:
		print("Gameplay: IA n'a plus d'AP (%d). Fin du tour." % enemy_ap)
		_restore_player_turn()
		return
		
	# Trouver les tanks P1 (cibles) vivants
	var targets: Array[Node2D] = []
	for unit in simulated_units:
		if is_instance_valid(unit) and not _get_is_enemy(unit) and _get_hp(unit) > 0:
			targets.append(unit)
			
	if targets.is_empty():
		_restore_player_turn()
		return
		
	# Cible prioritaire : celle avec le moins de PV restants (pour l'éliminer)
	var target = targets[0]
	var min_hp = _get_hp(target)
	for t in targets:
		var t_hp = _get_hp(t)
		if t_hp < min_hp:
			min_hp = t_hp
			target = t
			
	# Trouver les tanks ennemis (IA) vivants
	var enemies: Array[Node2D] = []
	for unit in simulated_units:
		if is_instance_valid(unit) and _get_is_enemy(unit) and _get_hp(unit) > 0:
			enemies.append(unit)
			
	if enemies.is_empty():
		_restore_player_turn()
		return
		
	# Choisir l'unité IA la plus proche de la cible prioritaire pour économiser les AP
	var ai_unit = enemies[0]
	var min_dist = ai_unit.global_position.distance_to(target.global_position)
	for e in enemies:
		var d = e.global_position.distance_to(target.global_position)
		if d < min_dist:
			min_dist = d
			ai_unit = e
			
	print("IA Tactique: Unité=%s (HP=%d) cible %s (HP=%d) avec AP restants=%d" % [ai_unit.name, _get_hp(ai_unit), target.name, _get_hp(target), enemy_ap])
	
	# Évaluer la ligne de visée (Line of Sight / LoS)
	var has_los = true
	var start_pos = ai_unit.global_position
	var end_pos = target.global_position
	var dir_to_target = (end_pos - start_pos).normalized()
	var dist_to_target = start_pos.distance_to(end_pos)
	var check_step = 8.0
	var check_steps = int(dist_to_target / check_step)
	
	for s in range(1, check_steps):
		var check_pos = start_pos + dir_to_target * (s * check_step)
		if _is_position_colliding_with_obstacles(check_pos, 16.0):
			has_los = false
			break
			
	# Décider de l'action
	var can_shoot = enemy_ap >= 2
	
	if can_shoot and has_los:
		# L'IA a les AP et a une ligne de visée claire : elle tire !
		_ai_perform_shoot(ai_unit, target)
	else:
		# L'IA n'a pas la visée ou pas assez d'AP pour tirer : elle se déplace
		# (ou tire quand même si elle ne peut pas bouger mais a des AP)
		_ai_perform_movement_or_fallback(ai_unit, target)

func _ai_perform_shoot(ai_unit: Node2D, target: Node2D) -> void:
	if not is_instance_valid(ai_unit) or not is_instance_valid(target):
		_restore_player_turn()
		return
		
	var is_perfect = randf() < 0.20 # 20% de chances de tir parfait (gratuit)
	var ap_cost = 0 if is_perfect else 2
	
	if not is_perfect:
		enemy_ap -= 2
		_update_hud_ap()
		_update_all_unit_gauges()
		
	var ai_shoot_dir = (target.global_position - ai_unit.global_position).normalized()
	ai_unit.set("facing_direction", ai_shoot_dir)
	
	# Recul physique
	var recoil_dist = 6.0
	var recoil_dir = -ai_shoot_dir
	var recoil_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var ai_orig_pos = ai_unit.global_position
	recoil_tween.tween_property(ai_unit, "global_position", ai_orig_pos + recoil_dir * recoil_dist, 0.05)
	recoil_tween.tween_property(ai_unit, "global_position", ai_orig_pos, 0.15)
	
	if is_perfect:
		_spawn_floating_damage_text(ai_unit.global_position, "Tir Parfait ! (Gratuit)")
		
	# Création du projectile
	var damage = _get_shoot_damage(ai_unit)
	var proj_color = Color("#FFD700") if is_perfect else Color("#FF4B57") # Doré si parfait, rouge sinon
	var proj = {
		"position": ai_unit.global_position,
		"velocity": ai_shoot_dir,
		"bounces_left": 3,
		"damage": damage,
		"is_enemy": true,
		"color": proj_color,
		"is_rainbow": is_perfect
	}
	active_projectiles.append(proj)
	queue_redraw()
	
	# Laisser le projectile voyager, puis enchaîner sur la prochaine action de l'IA
	get_tree().create_timer(1.2).timeout.connect(func():
		if is_instance_valid(self):
			_enemy_ai_action()
	)

func _ai_perform_movement_or_fallback(ai_unit: Node2D, target: Node2D) -> void:
	# Chercher une direction qui nous rapproche le plus de la cible
	var possible_dirs = [
		Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT,
		Vector2(1, 1).normalized(), Vector2(-1, 1).normalized(),
		Vector2(1, -1).normalized(), Vector2(-1, -1).normalized()
	]
	
	# Évaluer la glissade selon le poids
	var ai_pct = randf_range(0.5, 0.85)
	var weight = 1.0
	var v_type = ai_unit.get("vehicle_type")
	match v_type:
		"tank": weight = 1.8
		"car": weight = 1.0
		"plane": weight = 0.6
		
	var max_distance = 200.0
	var slide_distance = (max_distance * ai_pct) / weight
	
	var best_dir = Vector2.ZERO
	var best_pos = ai_unit.global_position
	var min_dist_to_target = ai_unit.global_position.distance_to(target.global_position)
	
	for dir in possible_dirs:
		var start_pos = ai_unit.global_position
		var target_pos = start_pos
		var step_size = 4.0
		var steps = int(slide_distance / step_size)
		var collides = false
		
		for step in range(1, steps + 1):
			var check_pos = start_pos + dir * (step * step_size)
			
			# 1. Bordures
			var margin = 20.0
			if check_pos.x < (OFFSET_X + margin) or check_pos.x > (OFFSET_X + GRID_COLUMNS * CELL_WIDTH - margin) or check_pos.y < (OFFSET_Y + margin) or check_pos.y > (OFFSET_Y + GRID_ROWS * CELL_WIDTH - margin):
				collides = true
				break
				
			# 2. Obstacles
			if _is_position_colliding_with_obstacles(check_pos, 15.0):
				collides = true
				break
				
			# 3. Véhicules
			var vehicle_at_pos = false
			for other in simulated_units:
				if is_instance_valid(other) and other != ai_unit and _get_hp(other) > 0:
					if other.global_position.distance_to(check_pos) < 32.0:
						vehicle_at_pos = true
						break
			if vehicle_at_pos:
				collides = true
				break
				
			target_pos = check_pos
			
		if not collides and target_pos != start_pos:
			var dist = target_pos.distance_to(target.global_position)
			if dist < min_dist_to_target:
				min_dist_to_target = dist
				best_dir = dir
				best_pos = target_pos
				
	# Si un mouvement valide est trouvé, on l'exécute
	if best_dir != Vector2.ZERO and enemy_ap >= 1:
		var is_perfect = randf() < 0.20 # 20% de chances de mouvement parfait
		if not is_perfect:
			enemy_ap -= 1
			_update_hud_ap()
			_update_all_unit_gauges()
			
		ai_unit.set("facing_direction", best_dir)
		_spawn_trail_particles(ai_unit, Color("#FFD700") if is_perfect else Color("#FF4B57"), 0.20)
		
		if is_perfect:
			_spawn_floating_damage_text(ai_unit.global_position, "Lancement Parfait ! (Gratuit)")
			
		# Déplacement Tween
		var move_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		move_tween.tween_property(ai_unit, "global_position", best_pos, 0.22)
		
		# Squash & Stretch
		var scale_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		ai_unit.scale = Vector2(1.25, 0.75) if best_dir.x != 0 else Vector2(0.75, 1.25)
		scale_tween.tween_property(ai_unit, "scale", Vector2.ONE, 0.35)
		
		await move_tween.finished
		_update_all_unit_gauges()
		queue_redraw()
		
		# Prochaine action IA après 0.4s
		get_tree().create_timer(0.4).timeout.connect(func():
			if is_instance_valid(self):
				_enemy_ai_action()
		)
	else:
		# Fallback : Si on est coincé ou plus assez d'AP pour bouger mais AP >= 2, on tente un tir désespéré
		if enemy_ap >= 2:
			print("IA Tactique: Bloqué ou éloigné, tir direct de secours.")
			_ai_perform_shoot(ai_unit, target)
		else:
			# Pas d'action possible, fin du tour
			print("IA Tactique: Pas d'action possible (coincé ou plus d'AP).")
			_restore_player_turn()

func _restore_player_turn() -> void:
	is_enemy_turn = false
	active_unit = null # Dé-sélectionner
	turns += 1
	current_ap = max_ap
	current_mode = "none"
	
	var hud_node = ui_manager.hud
	hud_node.set_action_mode("none")
	_update_hud_ap()
	
	# Réinitialiser les PA de tous les tanks alliés vivants
	for unit in simulated_units:
		if not is_instance_valid(unit) or _get_is_enemy(unit):
			continue
		if _get_hp(unit) > 0:
			unit.set("action_points", current_ap)
			_update_unit_gauge(unit)
		
	_spawn_floating_damage_text(Vector2(216, 320), "Tour %d" % turns)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if simulated_units.is_empty() or (is_enemy_turn and is_vs_ia):
		return
		
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		var event_pressed = event.pressed if "pressed" in event else event.is_pressed()
		if event_pressed:
			var mouse_pos = get_global_mouse_position()
			# Ne pas traiter les clics dans la TopBar (Y < 75) ou le BottomPanel (Y > 800) du HUD
			if mouse_pos.y < 75 or mouse_pos.y > 800:
				return
				
			press_position = mouse_pos
			print("[Gameplay Input] Press down at: ", press_position, " | Mode: ", current_mode)
			
			# Vérifier si l'utilisateur a appuyé sur le tank déjà actif
			var clicked_on_active = false
			if active_unit and _get_is_enemy(active_unit) == is_enemy_turn and active_unit.global_position.distance_to(press_position) < 40.0:
				clicked_on_active = true
			
			# Sélectionner une unité vivante de son équipe lors du clic/toucher direct (rayon large de 40px)
			var selected_new_unit = false
			for unit in simulated_units:
				if not is_instance_valid(unit) or _get_hp(unit) <= 0:
					continue
				if _get_is_enemy(unit) != is_enemy_turn:
					continue
				if unit.global_position.distance_to(press_position) < 40.0:
					active_unit = unit
					selected_new_unit = true
					is_dragging = true
					oscillation_time = 0.0
					drag_current_position = press_position
					print("[Gameplay Input] Selected active unit: ", unit.name, " and started dragging.")
					_update_hud_ap()
					queue_redraw()
					break
					
			# Commencer à glisser si on clique sur le tank déjà actif
			if clicked_on_active and (current_mode == "move" or current_mode == "shoot"):
				is_dragging = true
				oscillation_time = 0.0
				drag_current_position = press_position
				print("[Gameplay Input] Clicked directly on active unit, started dragging.")
				queue_redraw()
			elif not selected_new_unit and active_unit and _get_is_enemy(active_unit) == is_enemy_turn and (current_mode == "move" or current_mode == "shoot"):
				# Permettre de glisser depuis N'IMPORTE OÙ sur la grille si un tank est déjà actif
				is_dragging = true
				oscillation_time = 0.0
				drag_current_position = press_position
				print("[Gameplay Input] Swipe started from empty space with active unit: ", active_unit.name)
				queue_redraw()
				
		else:
			# Relâchement du clic ou toucher
			if is_dragging and active_unit:
				is_dragging = false
				is_perfect_zone = false
				drag_current_position = get_global_mouse_position()
				var drag_vector = drag_current_position - press_position
				print("[Gameplay Input] Release at: ", drag_current_position, " | Drag Vector: ", drag_vector, " Length: ", drag_vector.length())
				
				# Seuil de swipe (15px)
				if drag_vector.length() > 15.0:
					var active_ap = enemy_ap if is_enemy_turn else current_ap
					if current_mode == "move":
						if active_ap < 1:
							print("[Gameplay Input] Swipe cancelled: 0 AP remaining.")
							_spawn_floating_damage_text(active_unit.global_position, "Pas de PA !")
						else:
							_handle_swipe(drag_vector)
					elif current_mode == "shoot":
						if active_ap < 2:
							print("[Gameplay Input] Shoot cancelled: 0 AP remaining.")
							_spawn_floating_damage_text(active_unit.global_position, "Pas de PA !")
						else:
							_handle_shoot_swipe(drag_vector)
				queue_redraw()

	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		# Mettre à jour la position du drag en temps réel pour le tracé visuel
		if is_dragging and active_unit:
			drag_current_position = get_global_mouse_position()
			queue_redraw()

func _handle_swipe(drag_vector: Vector2) -> void:
	var dir = drag_vector.normalized()
		
	# Dériver la puissance (pct) et calculer la glissade physique continue selon le poids
	var pct = _get_oscillation_pct()
	var weight = 1.0
	var v_type = active_unit.get("vehicle_type")
	match v_type:
		"tank": weight = 1.8
		"car": weight = 1.0
		"plane": weight = 0.6
		
	var max_distance = 200.0
	var slide_distance = (max_distance * pct) / weight
	
	var start_pos = active_unit.global_position
	var target_pos = start_pos
	var blocked_reason = "Hors Limites !"
	
	# Sweep check pas-à-pas (pas de 2 pixels)
	var step_size = 2.0
	var steps = int(slide_distance / step_size)
	for step in range(1, steps + 1):
		var check_pos = start_pos + dir * (step * step_size)
		
		# 1. Bordures de la grille 6x10
		var margin = 20.0
		if check_pos.x < (OFFSET_X + margin) or check_pos.x > (OFFSET_X + GRID_COLUMNS * CELL_WIDTH - margin) or check_pos.y < (OFFSET_Y + margin) or check_pos.y > (OFFSET_Y + GRID_ROWS * CELL_WIDTH - margin):
			blocked_reason = "Hors Limites !"
			break
			
		# 2. Obstacles de la carte courante
		if _is_position_colliding_with_obstacles(check_pos, 15.0):
			blocked_reason = "Obstacle !"
			break
			
		# 3. Autre véhicule vivant
		var vehicle_at_pos = false
		for other in simulated_units:
			if is_instance_valid(other) and other != active_unit and _get_hp(other) > 0:
				if other.global_position.distance_to(check_pos) < 32.0:
					vehicle_at_pos = true
					break
		if vehicle_at_pos:
			blocked_reason = "Bloqué !"
			break
			
		target_pos = check_pos
		
	if target_pos == start_pos:
		print("[Swipe Physics] Rejected: blocked immediately. Reason: ", blocked_reason)
		_spawn_floating_damage_text(start_pos, blocked_reason)
		return
		
	var is_perfect = (pct >= 0.80 and pct <= 0.90)
	
	if is_perfect:
		# Lancement Parfait ! Mouvement complètement gratuit
		_spawn_floating_damage_text(start_pos, "Lancement Parfait ! (Gratuit)")
	else:
		if is_enemy_turn:
			enemy_ap -= 1
		else:
			current_ap -= 1
		_update_hud_ap()
		_update_all_unit_gauges()
	
	# Faire tourner le tank vers sa direction de marche
	active_unit.set("facing_direction", dir)
	_update_unit_gauge(active_unit)
	
	print("[Swipe Physics] Executing %s move from %s to %s (Slide distance: %fpx, Weight: %f)" % [v_type, start_pos, target_pos, slide_distance, weight])
	
	# Activer VFX traînée de propulsion
	if is_perfect:
		_spawn_trail_particles(active_unit, Color("#FFD700"), 0.25, true)
	else:
		var trail_color = Color("#FF4B57") if is_enemy_turn else Color("#00D2FF")
		_spawn_trail_particles(active_unit, trail_color, 0.20, false)
	
	# Tween de déplacement fluide
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(active_unit, "global_position", target_pos, 0.20)
	
	# Tween d'écrasement/extension élastique (Squash & Stretch)
	var scale_tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	active_unit.scale = Vector2(1.25, 0.75)
	scale_tween.tween_property(active_unit, "scale", Vector2.ONE, 0.35)
	
	await tween.finished
	queue_redraw()

func _handle_shoot_swipe(drag_vector: Vector2) -> void:
	if not is_instance_valid(active_unit):
		return
		
	var dir = drag_vector.normalized()
	
	# Timing speedometer percentage (Perfect shot if in 80%-90%)
	var pct = _get_oscillation_pct()
	var is_perfect = (pct >= 0.80 and pct <= 0.90)
	
	if is_perfect:
		_spawn_floating_damage_text(active_unit.global_position, "Tir Parfait ! (Gratuit)")
	else:
		if is_enemy_turn:
			enemy_ap -= 2
		else:
			current_ap -= 2
		_update_hud_ap()
		_update_all_unit_gauges()
		
	# Tourner le tank vers sa direction de tir
	active_unit.set("facing_direction", dir)
	_update_unit_gauge(active_unit)
	
	# Recul physique sur l'attaquant
	var recoil_dist = 6.0
	var recoil_dir = -dir
	var recoil_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	var active_orig_pos = active_unit.global_position
	recoil_tween.tween_property(active_unit, "global_position", active_orig_pos + recoil_dir * recoil_dist, 0.05)
	recoil_tween.tween_property(active_unit, "global_position", active_orig_pos, 0.15)
	
	# Instancier le projectile
	var damage = _get_shoot_damage(active_unit)
	var default_proj_color = Color("#FF4B57") if is_enemy_turn else Color("#00D2FF")
	var proj = {
		"position": active_unit.global_position,
		"velocity": dir,
		"bounces_left": 3,
		"damage": damage,
		"is_enemy": is_enemy_turn,
		"color": default_proj_color if not is_perfect else Color("#FFD700") # Or brillant pour Perfect Shot
	}
	active_projectiles.append(proj)
	
	# Si Perfect Shot, on ajoute une traînée de propulsion arc-en-ciel néon
	if is_perfect:
		_spawn_trail_particles(active_unit, Color("#FFD700"), 0.3, true)
	else:
		_spawn_trail_particles(active_unit, default_proj_color, 0.2, false)
		
	queue_redraw()

func _update_unit_gauge(unit: Node2D) -> void:
	var hud_node = ui_manager.hud
	for child in hud_node.floating_container.get_children():
		if child is FloatingGauge and child.target_unit == unit:
			var ap_val = current_ap if not _get_is_enemy(unit) else enemy_ap
			child.update_gauge(_get_hp(unit), _get_max_hp(unit), ap_val, max_ap)

func _update_all_unit_gauges() -> void:
	for unit in simulated_units:
		if is_instance_valid(unit):
			_update_unit_gauge(unit)

func _update_red_team_health_bar() -> void:
	var total_hp = 0
	var total_max = 0
	for unit in simulated_units:
		if is_instance_valid(unit) and _get_is_enemy(unit):
			total_hp += _get_hp(unit)
			total_max += _get_max_hp(unit)
	if is_instance_valid(ui_manager) and is_instance_valid(ui_manager.hud):
		ui_manager.hud.update_red_team_health(total_hp, total_max)

func _spawn_floating_damage_text(pos: Vector2, msg: String) -> void:
	var label = Label.new()
	label.text = msg
	label.position = pos + Vector2(-50, -40)
	label.custom_minimum_size = Vector2(100, 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Styliser le texte (gros, gras, ombré et coloré)
	label.add_theme_font_size_override("font_size", 20)
	if msg.contains("HP"):
		label.add_theme_color_override("font_color", Color("#FF4B57")) # Rouge dégâts
	elif msg.contains("Tour"):
		label.add_theme_color_override("font_color", Color("#FFB800")) # Jaune tour
	elif msg.contains("Pas de PA") or msg.contains("Obstacle"):
		label.add_theme_color_override("font_color", Color("#FFB800")) # Orange alerte
	else:
		label.add_theme_color_override("font_color", Color("#00D2FF")) # Cyan
		
	# Ombre portée premium
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	
	add_child(label)
	
	# Tween d'ascension et disparition progressive (fade out)
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position", pos + Vector2(-50, -90), 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	
	await tween.finished
	label.queue_free()

# Rendu 2D de la grille et des tanks
func _draw() -> void:
	# Dessiner le fond uni sombre sur tout l'écran
	draw_rect(Rect2(0, 0, 432, 960), Color("#0C0C0D"))
	
	if simulated_units.is_empty():
		return
		
	var grid_color = Color("#1D1D21", 0.5)
	var line_width = 2.0
	
	# Dessiner le fond de la grille
	draw_rect(Rect2(OFFSET_X, OFFSET_Y, GRID_COLUMNS * CELL_WIDTH, GRID_ROWS * CELL_WIDTH), Color("#0F0F11", 0.8))
	
	# Dessiner les lignes de la grille (6 colonnes, 10 lignes)
	for i in range(GRID_ROWS + 1):
		var start_y = OFFSET_Y + (i * CELL_WIDTH)
		draw_line(Vector2(OFFSET_X, start_y), Vector2(OFFSET_X + (GRID_COLUMNS * CELL_WIDTH), start_y), grid_color, line_width)
	for i in range(GRID_COLUMNS + 1):
		var start_x = OFFSET_X + (i * CELL_WIDTH)
		draw_line(Vector2(start_x, OFFSET_Y), Vector2(start_x, OFFSET_Y + (GRID_ROWS * CELL_WIDTH)), grid_color, line_width)
		
	# Dessiner les obstacles de la carte courante
	var obstacle_color = Color("#18181A", 0.9)
	for cell in obstacle_cells:
		var cell_rect = Rect2(OFFSET_X + cell.x * CELL_WIDTH, OFFSET_Y + cell.y * CELL_WIDTH, CELL_WIDTH, CELL_WIDTH)
		draw_rect(cell_rect, obstacle_color)
		var inner_rect = Rect2(cell_rect.position + Vector2(2, 2), cell_rect.size - Vector2(4, 4))
		draw_rect(inner_rect, Color("#00D2FF", 0.15))

	# Dessiner les projectiles de tir actifs
	for proj in active_projectiles:
		var col = proj.color
		draw_circle(proj.position, 6.0, Color(col, 0.35))
		draw_circle(proj.position, 3.5, col)
		draw_circle(proj.position, 1.5, Color.WHITE)
	
	# Dessiner le VFX Laser s'il est actif
	if show_laser:
		draw_line(laser_start, laser_end, laser_color, 4.0)
		draw_line(laser_start, laser_end, Color.WHITE, 1.5)
		
	# Dessiner la prévisualisation du trajet en drag
	if is_dragging and active_unit:
		var drag_vector = drag_current_position - press_position
		if drag_vector.length() > 15.0:
			var drag_dir = drag_vector.normalized()
			var pct = _get_oscillation_pct()
			var is_perfect = (pct >= 0.80 and pct <= 0.90)
			
			var start_pos = active_unit.global_position
			
			if current_mode == "move":
				var weight = 1.0
				var v_type = active_unit.get("vehicle_type")
				match v_type:
					"tank": weight = 1.8
					"car": weight = 1.0
					"plane": weight = 0.6
					
				var max_distance = 200.0
				var slide_distance = (max_distance * pct) / weight
				var target_pos = start_pos
				var is_blocked = false
				
				# Sweep check pas-à-pas (pas de 2 pixels)
				var step_size = 2.0
				var steps = int(slide_distance / step_size)
				for i in range(1, steps + 1):
					var check_pos = start_pos + drag_dir * (i * step_size)
					
					# 1. Bordures de la grille 6x10
					var margin = 20.0
					if check_pos.x < (OFFSET_X + margin) or check_pos.x > (OFFSET_X + GRID_COLUMNS * CELL_WIDTH - margin) or check_pos.y < (OFFSET_Y + margin) or check_pos.y > (OFFSET_Y + GRID_ROWS * CELL_WIDTH - margin):
						is_blocked = true
						break
						
					# 2. Obstacles de la carte courante
					if _is_position_colliding_with_obstacles(check_pos, 15.0):
						is_blocked = true
						break
						
					# 3. Autre véhicule vivant
					var hit_vehicle = false
					for other in simulated_units:
						if is_instance_valid(other) and other != active_unit and _get_hp(other) > 0:
							if other.global_position.distance_to(check_pos) < 32.0:
								hit_vehicle = true
								break
					if hit_vehicle:
						is_blocked = true
						break
						
					target_pos = check_pos
					
				# Si bloqué dès le début, on montre le contact à 16px en rouge
				if target_pos == start_pos:
					is_blocked = true
					target_pos = start_pos + (drag_dir * 16.0)
					
				# DESSIN DU CÔNE DIRECTIONNEL HOLOGRAPHIQUE
				var cone_dir = (target_pos - start_pos).normalized()
				if cone_dir == Vector2.ZERO:
					cone_dir = drag_dir
					
				var cone_perp = cone_dir.rotated(PI/2)
				var base_width = 12.0
				var tip_width = 24.0
				
				var pts = PackedVector2Array([
					start_pos + cone_perp * base_width,
					target_pos + cone_perp * tip_width,
					target_pos - cone_perp * tip_width,
					start_pos - cone_perp * base_width
				])
				
				var active_ap = enemy_ap if is_enemy_turn else current_ap
				var default_color = Color("#FF4B57") if is_enemy_turn else Color("#00D2FF")
				
				var cone_color = default_color
				if is_blocked:
					cone_color = Color("#FF4B57") # Rouge bloqué
				elif active_ap < 1:
					cone_color = Color("#FFB800") # Orange pas de PA
				elif is_perfect:
					var pulse = 0.6 + 0.4 * sin(perfect_timer * 1.5)
					cone_color = Color("#FFD700").lerp(Color.WHITE, pulse * 0.3)
					
				var clrs = PackedColorArray([
					Color(cone_color, 0.22),
					Color(cone_color, 0.0),
					Color(cone_color, 0.0),
					Color(cone_color, 0.22)
				])
				
				draw_polygon(pts, clrs)
				draw_line(pts[0], pts[1], Color(cone_color, 0.4), 1.5)
				draw_line(pts[3], pts[2], Color(cone_color, 0.4), 1.5)
				
				var preview_color = default_color
				preview_color.a = 0.75
				if is_blocked:
					preview_color = Color("#FF4B57", 0.75)
				elif active_ap < 1:
					preview_color = Color("#FFB800", 0.75)
				elif is_perfect:
					var pulse = 0.6 + 0.4 * sin(perfect_timer * 1.5)
					preview_color = Color("#FFD700").lerp(Color.WHITE, pulse * 0.3)
					
				# Tracé de la ligne pointillée de ciblage
				var line_dist = start_pos.distance_to(target_pos)
				var points = int(line_dist / 8.0)
				points = max(points, 2)
				for i in range(points):
					if i % 2 == 0:
						var p1 = start_pos.lerp(target_pos, float(i) / points)
						var p2 = start_pos.lerp(target_pos, float(i + 1) / points)
						draw_line(p1, p2, preview_color, 2.5)
						
				# Rond de ciblage final
				if is_perfect:
					var pulse_size = 1.0 + 0.15 * sin(perfect_timer * 1.0)
					draw_circle(target_pos, 10.0 * pulse_size, Color("#FFD700", 0.35))
					draw_arc(target_pos, 10.0 * pulse_size, 0, TAU, 24, Color("#FFD700", 0.7), 1.0)
					
				draw_circle(target_pos, 6.0, preview_color)
				draw_circle(target_pos, 3.0, Color.WHITE)
				
				# Jauge de force (cadran)
				_draw_speedometer(start_pos, pct, is_perfect, drag_vector.length())
				
			elif current_mode == "shoot":
				var current_pos = start_pos
				var current_dir = drag_dir
				var bounces = 3
				var hit_unit = null
				var max_range = 600.0
				var distance_traveled = 0.0
				
				var traj_points = [start_pos]
				
				var step = 4.0
				while distance_traveled < max_range and bounces >= 0:
					var next_pos = current_pos + current_dir * step
					distance_traveled += step
					
					# Collision avec les bordures 6x10
					var margin = 20.0
					if next_pos.x < (OFFSET_X + margin) or next_pos.x > (OFFSET_X + GRID_COLUMNS * CELL_WIDTH - margin) or next_pos.y < (OFFSET_Y + margin) or next_pos.y > (OFFSET_Y + GRID_ROWS * CELL_WIDTH - margin):
						var normal = _get_boundary_collision_normal(current_pos)
						current_dir = current_dir.bounce(normal)
						traj_points.append(current_pos)
						bounces -= 1
						current_pos = current_pos + current_dir * 4.0
						continue
						
					# Collision avec les obstacles
					var hit_obs = false
					for cell in obstacle_cells:
						var x_min = OFFSET_X + cell.x * CELL_WIDTH
						var x_max = OFFSET_X + (cell.x + 1) * CELL_WIDTH
						var y_min = OFFSET_Y + cell.y * CELL_WIDTH
						var y_max = OFFSET_Y + (cell.y + 1) * CELL_WIDTH
						if next_pos.x >= x_min and next_pos.x <= x_max and next_pos.y >= y_min and next_pos.y <= y_max:
							var normal = _get_obstacle_collision_normal(current_pos, cell)
							current_dir = current_dir.bounce(normal)
							traj_points.append(current_pos)
							bounces -= 1
							current_pos = current_pos + current_dir * 4.0
							hit_obs = true
							break
					if hit_obs:
						continue
						
					# Collision avec un véhicule
					var hit_veh = false
					for other in simulated_units:
						if is_instance_valid(other) and other != active_unit and _get_hp(other) > 0:
							if other.global_position.distance_to(next_pos) < 24.0:
								hit_unit = other
								traj_points.append(next_pos)
								hit_veh = true
								break
					if hit_veh:
						break
						
					current_pos = next_pos
					
				if not hit_unit:
					traj_points.append(current_pos)
					
				# Dessiner la trajectoire de visée néon
				var active_ap = enemy_ap if is_enemy_turn else current_ap
				var default_color = Color("#FF4B57") if is_enemy_turn else Color("#00D2FF")
				var preview_color = default_color if not is_perfect else Color("#FFD700")
				if active_ap < 2:
					preview_color = Color("#FFB800")
					
				for i in range(traj_points.size() - 1):
					var p1 = traj_points[i]
					var p2 = traj_points[i+1]
					draw_line(p1, p2, Color(preview_color, 0.25), 4.5)
					draw_line(p1, p2, preview_color, 1.5)
					
				for i in range(1, traj_points.size() - 1):
					draw_circle(traj_points[i], 4.0, preview_color)
					draw_circle(traj_points[i], 2.0, Color.WHITE)
					
				var final_pt = traj_points.back()
				if hit_unit:
					var pulse = 1.0 + 0.15 * sin(perfect_timer * 1.5)
					draw_circle(final_pt, 12.0 * pulse, Color("#FF4B57", 0.25))
					draw_arc(final_pt, 12.0 * pulse, 0, TAU, 24, Color("#FF4B57", 0.7), 1.5)
					draw_circle(final_pt, 4.0, Color("#FF4B57"))
				else:
					draw_circle(final_pt, 4.0, preview_color)
					draw_circle(final_pt, 2.0, Color.WHITE)
					
				# Jauge de force (cadran)
				_draw_speedometer(start_pos, pct, is_perfect, drag_vector.length())
				
	# Dessiner les véhicules (corps géométriques tactiles et polis)
	for unit in simulated_units:
		if not is_instance_valid(unit) or _get_hp(unit) <= 0:
			continue
			
		var is_enemy = _get_is_enemy(unit)
		var color = Color("#FF4B57") if is_enemy else Color("#00D2FF")
		
		# Rendu du véhicule vectoriel stylisé en 2D selon son type.
		# Halo de sélection : sur l'unité active, sauf quand c'est l'IA qui joue
		# (en J1 vs J2, le joueur 2 doit voir son unité rouge sélectionnée).
		var is_active = unit == active_unit and not (is_enemy_turn and is_vs_ia)
		_draw_vector_vehicle(unit, color, is_active)

# Jauge de force vectorielle en forme de cadran / compteur de vitesse
func _draw_speedometer(start_pos: Vector2, pct: float, is_perfect: bool, drag_len: float) -> void:
	var center = start_pos + Vector2(0, -64.0)
	var radius = 32.0
	var min_angle = -deg_to_rad(170.0)
	var max_angle = -deg_to_rad(10.0)
	var current_angle = lerp(min_angle, max_angle, pct)
	
	var angle_0 = min_angle
	var angle_33 = lerp(min_angle, max_angle, 0.33)
	var angle_66 = lerp(min_angle, max_angle, 0.66)
	var angle_80 = lerp(min_angle, max_angle, 0.80)
	var angle_90 = lerp(min_angle, max_angle, 0.90)
	var angle_100 = max_angle
	
	var col_green = Color("#24B273")
	var col_light_green = Color("#8BE31B")
	var col_orange = Color("#FFB800")
	var col_red = Color("#FF4B57")
	var col_perfect = Color("#FFD700")
	
	draw_arc(center, radius, min_angle, max_angle, 32, Color("#0C0C0D", 0.95), 8.0)
	draw_arc(center, radius + 4.0, min_angle, max_angle, 32, Color("#1D1D21", 0.5), 1.0)
	
	draw_arc(center, radius, angle_0, angle_33, 16, Color(col_green, 0.25), 6.0)
	draw_arc(center, radius, angle_33, angle_66, 16, Color(col_light_green, 0.25), 6.0)
	draw_arc(center, radius, angle_66, angle_80, 10, Color(col_orange, 0.25), 6.0)
	draw_arc(center, radius, angle_80, angle_90, 10, Color(col_perfect, 0.25), 6.0)
	draw_arc(center, radius, angle_90, angle_100, 10, Color(col_red, 0.25), 6.0)
	
	if drag_len >= 15.0:
		var fill_angle = current_angle
		if fill_angle > angle_0:
			draw_arc(center, radius, angle_0, min(fill_angle, angle_33), 16, col_green, 6.0)
		if fill_angle > angle_33:
			draw_arc(center, radius, angle_33, min(fill_angle, angle_66), 16, col_light_green, 6.0)
		if fill_angle > angle_66:
			draw_arc(center, radius, angle_66, min(fill_angle, angle_80), 10, col_orange, 6.0)
		if fill_angle > angle_80:
			var perf_col = col_perfect
			if is_perfect:
				var pulse = 0.5 + 0.5 * sin(perfect_timer * 1.5)
				perf_col = col_perfect.lerp(Color.WHITE, pulse * 0.4)
			draw_arc(center, radius, angle_80, min(fill_angle, angle_90), 10, perf_col, 6.0)
		if fill_angle > angle_90:
			draw_arc(center, radius, angle_90, min(fill_angle, angle_100), 10, col_red, 6.0)
			
	var ticks = [angle_33, angle_66, angle_80, angle_90]
	for tick_ang in ticks:
		var dir_vec = Vector2.from_angle(tick_ang)
		draw_line(center + dir_vec * (radius - 4.0), center + dir_vec * (radius + 4.0), Color("#0C0C0D"), 1.5)
		
	var needle_len = radius + 4.0
	var needle_ang = current_angle
	var jitter = Vector2.ZERO
	var needle_color = Color.WHITE
	if is_perfect:
		var time_ms = Time.get_ticks_msec()
		jitter = Vector2(sin(time_ms * 0.1), cos(time_ms * 0.12)) * 0.8
		var pulse = 0.5 + 0.5 * sin(perfect_timer * 1.5)
		needle_color = col_perfect.lerp(Color.WHITE, pulse)
		
	var needle_vec = (Vector2.from_angle(needle_ang) * needle_len) + jitter
	draw_line(center + Vector2(0, 1.5), center + needle_vec + Vector2(0, 1.5), Color(0, 0, 0, 0.45), 2.5)
	draw_line(center, center + needle_vec, needle_color, 1.5)
	
	draw_circle(center, 4.0, Color("#0C0C0D"))
	draw_circle(center, 2.5, needle_color)
	draw_circle(center, 1.0, Color.BLACK if not is_perfect else col_perfect)

# Dispatcher de dessin selon le type de véhicule
func _draw_vector_vehicle(unit: Node2D, color: Color, is_active: bool) -> void:
	var v_type = unit.get("vehicle_type")
	if v_type == null:
		v_type = "tank"
		
	match v_type.to_lower():
		"car":
			_draw_vector_car(unit, color, is_active)
		"plane":
			_draw_vector_plane(unit, color, is_active)
		_:
			_draw_vector_tank(unit, color, is_active)

func _draw_vector_tank(unit: Node2D, color: Color, is_active: bool) -> void:
	var is_enemy = color.r > 0.5
	var pos = unit.global_position
	var facing = unit.get("facing_direction")
	if facing == null: facing = Vector2.DOWN
	
	if is_active:
		var pulse = 1.0 + 0.1 * sin(Time.get_ticks_msec() * 0.008)
		var ring_color = Color(color, 0.35 if current_mode == "move" else 0.18)
		draw_circle(pos, 22.0 * pulse, ring_color)
		draw_arc(pos, 22.0 * pulse, 0, TAU, 32, ring_color.lightened(0.15), 1.5)

	draw_circle(pos + Vector2(0, 3), 15.0, Color(0, 0, 0, 0.4))
	
	var xform = Transform2D(facing.angle(), unit.scale, 0.0, pos)
	draw_set_transform_matrix(xform)
	
	var track_color = Color("#1E2026")
	var track_border = Color("#3B3F4A")
	var wheel_color = Color("#2F333E")
	var tread_line_color = Color("#2D313B")
	
	draw_rect(Rect2(-13, -14, 26, 5), track_color)
	draw_rect(Rect2(-13, -14, 26, 5), track_border, false, 1.0)
	draw_rect(Rect2(-13, 9, 26, 5), track_color)
	draw_rect(Rect2(-13, 9, 26, 5), track_border, false, 1.0)
	
	for x_offset in range(-11, 12, 4):
		draw_line(Vector2(x_offset, -14), Vector2(x_offset, -9), tread_line_color, 1.0)
		draw_line(Vector2(x_offset, 9), Vector2(x_offset, 14), tread_line_color, 1.0)
		
	for x_offset in range(-9, 10, 4.5):
		draw_circle(Vector2(x_offset, -11.5), 1.5, wheel_color)
		draw_circle(Vector2(x_offset, 11.5), 1.5, wheel_color)
		
	var chassis_bg = Color("#16233B") if not is_enemy else Color("#3B161B")
	var chassis_border = color.lightened(0.1)
	
	var chassis_poly = PackedVector2Array([
		Vector2(-11, -9),
		Vector2(9, -9),
		Vector2(14, -5),
		Vector2(14, 5),
		Vector2(9, 9),
		Vector2(-11, 9),
	])
	draw_colored_polygon(chassis_poly, chassis_bg)
	draw_polyline(chassis_poly, chassis_border, 1.5)
	
	draw_rect(Rect2(-6, -8, 12, 2), color)
	draw_rect(Rect2(-6, 6, 12, 2), color)
	
	var flame_color = color
	flame_color.a = 0.7
	var flame_poly = PackedVector2Array([
		Vector2(-11, -3),
		Vector2(-18, 0),
		Vector2(-11, 3)
	])
	draw_colored_polygon(flame_poly, flame_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-11, -1.5),
		Vector2(-14, 0),
		Vector2(-11, 1.5)
	]), Color.WHITE)
	
	draw_rect(Rect2(0, -2.5, 17, 5), Color("#2E323D"))
	draw_rect(Rect2(0, -2.5, 17, 5), color, false, 1.0)
	
	draw_line(Vector2(5, -2.5), Vector2(5, 2.5), color, 1.5)
	draw_line(Vector2(9, -2.5), Vector2(9, 2.5), color, 1.5)
	draw_line(Vector2(13, -2.5), Vector2(13, 2.5), color, 1.5)
	
	draw_circle(Vector2(17, 0), 3.5, color)
	draw_circle(Vector2(17, 0), 1.5, Color.WHITE)
	draw_arc(Vector2(17, 0), 6.0, 0, TAU, 16, Color(color, 0.4), 1.0)
	
	var turret_bg = Color("#111A2C") if not is_enemy else Color("#2C1115")
	draw_circle(Vector2.ZERO, 8.0, turret_bg)
	draw_circle(Vector2.ZERO, 8.0, color, false, 1.5)
	
	draw_circle(Vector2.ZERO, 4.5, color)
	draw_circle(Vector2.ZERO, 2.0, Color.WHITE)
	
	draw_line(Vector2(-6, 0), Vector2(-2, 0), Color.WHITE, 1.0)
	draw_line(Vector2(2, 0), Vector2(6, 0), Color.WHITE, 1.0)
	draw_line(Vector2(0, -6), Vector2(0, -2), Color.WHITE, 1.0)
	draw_line(Vector2(0, 2), Vector2(0, 6), Color.WHITE, 1.0)
	
	draw_set_transform_matrix(Transform2D())

func _draw_vector_car(unit: Node2D, color: Color, is_active: bool) -> void:
	var is_enemy = color.r > 0.5
	var pos = unit.global_position
	var facing = unit.get("facing_direction")
	if facing == null: facing = Vector2.DOWN
	
	if is_active:
		var pulse = 1.0 + 0.1 * sin(Time.get_ticks_msec() * 0.008)
		var ring_color = Color(color, 0.35 if current_mode == "move" else 0.18)
		draw_circle(pos, 22.0 * pulse, ring_color)
		draw_arc(pos, 22.0 * pulse, 0, TAU, 32, ring_color.lightened(0.15), 1.5)

	draw_circle(pos + Vector2(0, 3), 14.0, Color(0, 0, 0, 0.4))
	
	var xform = Transform2D(facing.angle(), unit.scale, 0.0, pos)
	draw_set_transform_matrix(xform)
	
	var tire_color = Color("#18191D")
	var rim_color = Color("#4E5361")
	var neon_glow = color
	neon_glow.a = 0.8
	
	draw_rect(Rect2(5, -13, 9, 3.5), tire_color)
	draw_rect(Rect2(5, -13, 9, 3.5), rim_color, false, 1.0)
	draw_line(Vector2(9.5, -13), Vector2(9.5, -9.5), neon_glow, 1.5)
	
	draw_rect(Rect2(5, 9.5, 9, 3.5), tire_color)
	draw_rect(Rect2(5, 9.5, 9, 3.5), rim_color, false, 1.0)
	draw_line(Vector2(9.5, 9.5), Vector2(9.5, 13), neon_glow, 1.5)
	
	draw_rect(Rect2(-12, -13, 9, 3.5), tire_color)
	draw_rect(Rect2(-12, -13, 9, 3.5), rim_color, false, 1.0)
	draw_line(Vector2(-7.5, -13), Vector2(-7.5, -9.5), neon_glow, 1.5)
	
	draw_rect(Rect2(-12, 9.5, 9, 3.5), tire_color)
	draw_rect(Rect2(-12, 9.5, 9, 3.5), rim_color, false, 1.0)
	draw_line(Vector2(-7.5, 9.5), Vector2(-7.5, 13), neon_glow, 1.5)
	
	var chassis_bg = Color("#131D30") if not is_enemy else Color("#301317")
	var chassis_border = color.lightened(0.1)
	
	var car_poly = PackedVector2Array([
		Vector2(-13, -8),
		Vector2(11, -6),
		Vector2(15, 0),
		Vector2(11, 6),
		Vector2(-13, 8),
		Vector2(-15, 3),
		Vector2(-15, -3),
	])
	draw_colored_polygon(car_poly, chassis_bg)
	draw_polyline(car_poly, chassis_border, 1.5)
	
	draw_line(Vector2(-8, -5), Vector2(6, -4), color, 1.0)
	draw_line(Vector2(-8, 5), Vector2(6, 4), color, 1.0)
	
	var flame_color = color
	flame_color.a = 0.65
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15, -4), Vector2(-20, -3), Vector2(-15, -2)
	]), flame_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15, 2), Vector2(-20, 3), Vector2(-15, 4)
	]), flame_color)
	
	draw_rect(Rect2(-2, -7.5, 14, 2.5), Color("#272930"))
	draw_rect(Rect2(-2, -7.5, 14, 2.5), color, false, 0.8)
	draw_circle(Vector2(12, -6.25), 2.0, Color.WHITE)
	
	draw_rect(Rect2(-2, 5, 14, 2.5), Color("#272930"))
	draw_rect(Rect2(-2, 5, 14, 2.5), color, false, 0.8)
	draw_circle(Vector2(12, 6.25), 2.0, Color.WHITE)
	
	var canopy_color = Color("#1D2D49") if not is_enemy else Color("#491D22")
	draw_circle(Vector2(-2, 0), 5.5, canopy_color)
	draw_circle(Vector2(-2, 0), 5.5, color, false, 1.0)
	
	draw_line(Vector2(-4.5, -2.5), Vector2(0.5, 2.5), Color.WHITE, 1.0)
	
	draw_set_transform_matrix(Transform2D())

func _draw_vector_plane(unit: Node2D, color: Color, is_active: bool) -> void:
	var is_enemy = color.r > 0.5
	var pos = unit.global_position
	var facing = unit.get("facing_direction")
	if facing == null: facing = Vector2.DOWN
	
	if is_active:
		var pulse = 1.0 + 0.1 * sin(Time.get_ticks_msec() * 0.008)
		var ring_color = Color(color, 0.35 if current_mode == "move" else 0.18)
		draw_circle(pos, 22.0 * pulse, ring_color)
		draw_arc(pos, 22.0 * pulse, 0, TAU, 32, ring_color.lightened(0.15), 1.5)

	draw_circle(pos + Vector2(0, 6), 12.0, Color(0, 0, 0, 0.25))
	
	var xform = Transform2D(facing.angle(), unit.scale, 0.0, pos)
	draw_set_transform_matrix(xform)
	
	var wing_bg = Color("#0D253F") if not is_enemy else Color("#3F0D15")
	var wing_border = color.lightened(0.2)
	
	var plane_poly = PackedVector2Array([
		Vector2(16, 0),
		Vector2(-5, -14),
		Vector2(-8, -6),
		Vector2(-14, 0),
		Vector2(-8, 6),
		Vector2(-5, 14),
	])
	draw_colored_polygon(plane_poly, wing_bg)
	draw_polyline(plane_poly, wing_border, 1.5)
	
	draw_circle(Vector2(-5, -14), 2.0, color)
	draw_circle(Vector2(-5, -14), 0.8, Color.WHITE)
	draw_circle(Vector2(-5, 14), 2.0, color)
	draw_circle(Vector2(-5, 14), 0.8, Color.WHITE)
	
	draw_line(Vector2(6, 0), Vector2(-8, -5), color, 0.8)
	draw_line(Vector2(6, 0), Vector2(-8, 5), color, 0.8)
	
	var jet_color = color
	jet_color.a = 0.75
	var jet_poly = PackedVector2Array([
		Vector2(-14, -2.5),
		Vector2(-24, 0),
		Vector2(-14, 2.5)
	])
	draw_colored_polygon(jet_poly, jet_color)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-14, -1.2),
		Vector2(-18, 0),
		Vector2(-14, 1.2)
	]), Color.WHITE)
	
	draw_line(Vector2(9, 0), Vector2(21, 0), Color("#2E323D"), 2.0)
	draw_line(Vector2(14, 0), Vector2(21, 0), color, 1.0)
	draw_circle(Vector2(21, 0), 2.5, color)
	draw_circle(Vector2(21, 0), 1.0, Color.WHITE)
	
	var cockpit_poly = PackedVector2Array([
		Vector2(5, 0),
		Vector2(-1, -3),
		Vector2(-5, 0),
		Vector2(-1, 3)
	])
	var canopy_color = Color("#16325C") if not is_enemy else Color("#5C161E")
	draw_colored_polygon(cockpit_poly, canopy_color)
	draw_polyline(cockpit_poly, color, 1.0)
	
	# Reflet
	draw_line(Vector2(1, -1.5), Vector2(-3, 1.5), Color.WHITE, 1.0)
	
	draw_set_transform_matrix(Transform2D())

# --- Fonctions d'accès sécurisées (anti-crash de typage dynamic GDScript) ---

func _is_position_colliding_with_obstacles(check_pos: Vector2, obs_margin: float = 15.0) -> bool:
	for cell in obstacle_cells:
		var x_min = OFFSET_X + cell.x * CELL_WIDTH
		var x_max = OFFSET_X + (cell.x + 1) * CELL_WIDTH
		var y_min = OFFSET_Y + cell.y * CELL_WIDTH
		var y_max = OFFSET_Y + (cell.y + 1) * CELL_WIDTH
		if check_pos.x >= (x_min - obs_margin) and check_pos.x <= (x_max + obs_margin) and check_pos.y >= (y_min - obs_margin) and check_pos.y <= (y_max + obs_margin):
			return true
	return false

func _get_obstacle_collision_normal(prev_pos: Vector2, cell: Vector2i) -> Vector2:
	var x_min = OFFSET_X + cell.x * CELL_WIDTH
	var x_max = OFFSET_X + (cell.x + 1) * CELL_WIDTH
	var y_min = OFFSET_Y + cell.y * CELL_WIDTH
	var y_max = OFFSET_Y + (cell.y + 1) * CELL_WIDTH
	
	if prev_pos.x < x_min:
		return Vector2.LEFT
	elif prev_pos.x > x_max:
		return Vector2.RIGHT
	elif prev_pos.y < y_min:
		return Vector2.UP
	elif prev_pos.y > y_max:
		return Vector2.DOWN
	return Vector2.UP

func _get_boundary_collision_normal(prev_pos: Vector2) -> Vector2:
	var margin = 20.0
	var left = OFFSET_X + margin
	var right = OFFSET_X + GRID_COLUMNS * CELL_WIDTH - margin
	var top = OFFSET_Y + margin
	var bottom = OFFSET_Y + GRID_ROWS * CELL_WIDTH - margin
	
	if prev_pos.x < left:
		return Vector2.RIGHT
	elif prev_pos.x > right:
		return Vector2.LEFT
	elif prev_pos.y < top:
		return Vector2.DOWN
	elif prev_pos.y > bottom:
		return Vector2.UP
	return Vector2.UP

func _get_hp(unit: Node2D) -> int:
	if not is_instance_valid(unit):
		return 0
	var hp = unit.get("hit_points")
	return hp if hp != null else 0

func _get_max_hp(unit: Node2D) -> int:
	if not is_instance_valid(unit):
		return 100
	var max_hp = unit.get("max_hit_points")
	return max_hp if max_hp != null else 100

func _get_ap(unit: Node2D) -> int:
	if not is_instance_valid(unit):
		return 0
	var ap = unit.get("action_points")
	return ap if ap != null else 0

func _get_is_enemy(unit: Node2D) -> bool:
	if not is_instance_valid(unit):
		return false
	var val = unit.get("is_enemy")
	return val if val != null else unit.name.begins_with("P2")

func _get_shoot_damage(unit: Node2D) -> int:
	if not is_instance_valid(unit):
		return 15
	var v_type = unit.get("vehicle_type")
	if v_type == null:
		return 15
	match v_type.to_lower():
		"tank": return 30
		"car": return 20
		"plane": return 15
		_: return 15

func _update_hud_ap() -> void:
	var hud_node = ui_manager.hud
	if not is_instance_valid(hud_node):
		return
	if is_enemy_turn:
		if is_vs_ia:
			hud_node.update_ap_display("P2 (Ennemi)", 0, max_ap, false)
		else:
			if active_unit and _get_is_enemy(active_unit):
				var v_type = active_unit.get("vehicle_type")
				if v_type == null: v_type = "tank"
				hud_node.update_ap_display("P2 - " + v_type.to_upper(), enemy_ap, max_ap, false)
			else:
				hud_node.update_ap_display("P2 (Joueur 2)", enemy_ap, max_ap, false)
	elif active_unit and not _get_is_enemy(active_unit):
		var v_type = active_unit.get("vehicle_type")
		if v_type == null:
			v_type = "tank"
		hud_node.update_ap_display("P1 - " + v_type.to_upper(), current_ap, max_ap, true)
	else:
		hud_node.update_ap_display("P1 (Joueur 1)", current_ap, max_ap, true)

func _spawn_trail_particles(unit: Node2D, color: Color, duration: float, is_rainbow: bool = false) -> void:
	if not is_instance_valid(unit):
		return
	var particles = CPUParticles2D.new()
	particles.amount = 35 if is_rainbow else 15
	particles.lifetime = 0.5 if is_rainbow else 0.4
	particles.spread = 55.0 if is_rainbow else 45.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 30.0 if is_rainbow else 20.0
	particles.initial_velocity_max = 60.0 if is_rainbow else 50.0
	particles.scale_amount_min = 3.0 if is_rainbow else 2.0
	particles.scale_amount_max = 7.0 if is_rainbow else 5.0
	
	var facing = unit.get("facing_direction")
	if facing != null:
		particles.direction = -facing
	else:
		particles.direction = Vector2.UP
		
	var grad = Gradient.new()
	if is_rainbow:
		grad.offsets = [0.0, 0.33, 0.66, 1.0]
		grad.colors = [
			Color("#00D2FF", 0.9), # Cyan
			Color("#FF4B57", 0.9), # Magenta/Pink
			Color("#FFB800", 0.9), # Yellow/Gold
			Color("#8BE31B", 0.0)  # Green transparent
		]
	else:
		grad.set_color(0, Color(color, 0.8))
		grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	particles.color_ramp = grad
	
	unit.add_child(particles)
	particles.emitting = true
	
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		particles.emitting = false
		get_tree().create_timer(0.5).timeout.connect(particles.queue_free)
	)

func _spawn_death_particles(pos: Vector2, color: Color) -> void:
	var particles = CPUParticles2D.new()
	particles.global_position = pos
	particles.amount = 35
	particles.lifetime = 1.2
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.spread = 180.0
	particles.gravity = Vector2.ZERO
	particles.initial_velocity_min = 90.0
	particles.initial_velocity_max = 200.0
	particles.scale_amount_min = 5.0
	particles.scale_amount_max = 10.0
	
	var grad = Gradient.new()
	grad.set_color(0, Color.WHITE)
	grad.set_color(1, Color(color.r, color.g, color.b, 0.0))
	particles.color_ramp = grad
	
	add_child(particles)
	particles.emitting = true
	
	get_tree().create_timer(1.4).timeout.connect(particles.queue_free)

func _explode_vehicle(unit: Node2D) -> void:
	if not is_instance_valid(unit):
		return
	var pos = unit.global_position
	var is_enemy = _get_is_enemy(unit)
	var color = Color("#FF4B57") if is_enemy else Color("#00D2FF")
	
	var hud_node = ui_manager.hud
	if is_instance_valid(hud_node) and is_instance_valid(hud_node.floating_container):
		for child in hud_node.floating_container.get_children():
			if child is FloatingGauge and child.target_unit == unit:
				child.queue_free()
				
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(unit, "modulate", Color.WHITE, 0.15)
	tween.tween_property(unit, "scale", Vector2.ZERO, 0.25)
	
	_spawn_death_particles(pos, color)
	
	await tween.finished
	unit.queue_free()
	
	var idx = simulated_units.find(unit)
	if idx != -1:
		simulated_units.remove_at(idx)
	queue_redraw()
