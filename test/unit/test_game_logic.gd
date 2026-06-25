extends GutTest

# Tests unitaires de la logique pure du jeu (sans dépendance à la scène).

const GameplayScript = preload("res://ui/ui_test_scene.gd")
const SetupScript = preload("res://ui/screens/game_setup/game_setup.gd")

var _gp

func before_each() -> void:
	# On instancie le script SANS l'ajouter à l'arbre : on accède juste
	# aux constantes et aux fonctions pures (pas de _ready, pas de scène).
	_gp = GameplayScript.new()

func after_each() -> void:
	if is_instance_valid(_gp):
		_gp.free()

# --- Grille & cartes -------------------------------------------------------

func test_grid_dimensions() -> void:
	assert_eq(_gp.GRID_COLUMNS, 64, "La grille fait 64 colonnes")
	assert_eq(_gp.GRID_ROWS, 64, "La grille fait 64 lignes")

func test_map_presets_exist() -> void:
	for name in ["classic", "cross", "pillars", "corridor"]:
		assert_true(_gp.MAP_PRESETS.has(name), "Le preset '%s' existe" % name)

func test_map_presets_cells_in_bounds() -> void:
	# Chaque obstacle doit rester dans les limites de la grille.
	for name in _gp.MAP_PRESETS.keys():
		for cell in _gp.MAP_PRESETS[name]:
			assert_between(cell.x, 0, _gp.GRID_COLUMNS - 1, "%s: x dans la grille" % name)
			assert_between(cell.y, 0, _gp.GRID_ROWS - 1, "%s: y dans la grille" % name)

# --- Jauge de puissance (oscillation) --------------------------------------

func test_oscillation_pct_always_normalized() -> void:
	# Le pourcentage de puissance doit toujours rester entre 0 et 1.
	for t in [0.0, 0.3, 0.625, 1.0, 1.7, 3.14, 10.0]:
		_gp.oscillation_time = t
		var pct = _gp._get_oscillation_pct()
		assert_between(pct, 0.0, 1.0, "pct normalisé pour t=%s" % t)

# --- Génération d'équipe ennemie -------------------------------------------

func _team_cost(team: Array) -> int:
	var costs = {"tank": 50, "plane": 40, "car": 30}
	var total = 0
	for t in team:
		total += costs.get(t, 0)
	return total

func test_enemy_team_respects_budget_and_limits() -> void:
	var team = _gp._generate_enemy_team(150)
	assert_lt(team.size(), 6, "Au maximum 5 véhicules")
	assert_lte(_team_cost(team), 150, "Le coût ne dépasse pas le budget")
	for t in team:
		assert_true(t in ["tank", "plane", "car"], "Type de véhicule valide: %s" % t)

func test_enemy_team_empty_when_budget_too_low() -> void:
	# Le moins cher coûte 30 ; en dessous, aucune unité possible.
	assert_eq(_gp._generate_enemy_team(20).size(), 0, "Budget < 30 => équipe vide")

# --- Constantes de la boutique (game_setup) --------------------------------

func test_shop_costs_are_coherent() -> void:
	var s = SetupScript.new()
	assert_eq(s.BUDGET_MAX, 150, "Budget max attendu")
	assert_true(s.COST_TANK > s.COST_PLANE, "Le tank coûte plus cher que l'avion")
	assert_true(s.COST_PLANE > s.COST_CAR, "L'avion coûte plus cher que la voiture")
	assert_true(s.HP_MIN < s.HP_MAX, "PV: min < max")
	assert_true(s.AP_MIN < s.AP_MAX, "PA: min < max")
	s.free()

# --- Caméra, Portée et Spawns ----------------------------------------------

func test_camera_zoom_min() -> void:
	assert_eq(_gp.CAM_ZOOM_MIN, 0.08, "Le dézoom minimum doit être de 0.08")

func test_spawn_rows_clear_of_obstacles() -> void:
	# Les équipes J1 et J2 spawnent respectivement aux lignes 52 et 12 (centre +/- 20)
	for preset_name in _gp.MAP_PRESETS.keys():
		for cell in _gp.MAP_PRESETS[preset_name]:
			assert_ne(cell.y, 52, "Pas d'obstacle sur la ligne de spawn J1 (ligne 52) - preset %s" % preset_name)
			assert_ne(cell.y, 12, "Pas d'obstacle sur la ligne de spawn J2 (ligne 12) - preset %s" % preset_name)
