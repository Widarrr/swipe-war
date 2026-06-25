extends GutTest

# Tests "smoke" : chaque scène doit s'instancier sans erreur.
# Attrape les scènes/scripts cassés à chaque commit.

const SCENES = [
	"res://ui/ui_test_scene.tscn",
	"res://ui/ui_manager.tscn",
	"res://ui/screens/main_menu/main_menu.tscn",
	"res://ui/screens/game_setup/game_setup.tscn",
	"res://ui/screens/hud/hud.tscn",
	"res://ui/screens/victory/victory_screen.tscn",
	"res://ui/common/components/floating_gauge.tscn",
]

func test_all_scenes_can_be_loaded() -> void:
	for path in SCENES:
		var packed = load(path)
		assert_not_null(packed, "La scène se charge: %s" % path)

func test_all_scenes_instantiate_in_tree() -> void:
	for path in SCENES:
		var packed = load(path)
		if packed == null:
			continue
		var instance = packed.instantiate()
		assert_not_null(instance, "Instanciation OK: %s" % path)
		# add_child déclenche _ready ; autofree libère après le test.
		add_child_autofree(instance)
		assert_true(instance.is_inside_tree(), "Présente dans l'arbre: %s" % path)

func test_victory_screen_set_results() -> void:
	var packed = load("res://ui/screens/victory/victory_screen.tscn")
	var instance = packed.instantiate()
	add_child_autofree(instance)
	
	# Tester set_results pour P1 (is_red_win = false)
	instance.set_results("Player 1", 3, 10, 85, false)
	assert_eq(instance.winner_label.text, "Player 1 Wins")
	assert_eq(instance.vehicles_val.text, "3")
	assert_eq(instance.turns_val.text, "10")
	assert_eq(instance.accuracy_val.text, "85%")
	
	# Vérifier les couleurs (modulées ou thémées)
	var p1_color = instance.trophy_icon.get_theme_color("font_color")
	assert_eq(p1_color, Color("#00D2FF"))
	
	# Tester set_results pour J2/Rouge (is_red_win = true)
	instance.set_results("Joueur 2", 2, 12, 75, true)
	assert_eq(instance.winner_label.text, "Joueur 2 Wins")
	var p2_color = instance.trophy_icon.get_theme_color("font_color")
	assert_eq(p2_color, Color("#FF4B57"))

func test_hud_health_bars() -> void:
	var packed = load("res://ui/screens/hud/hud.tscn")
	var instance = packed.instantiate()
	add_child_autofree(instance)
	
	assert_not_null(instance.blue_team_health_bar, "Blue health bar should exist")
	assert_not_null(instance.red_team_health_bar, "Red health bar should exist")
	
	instance.update_blue_team_health(80, 120)
	assert_eq(instance.blue_team_health_bar.value, 80.0)
	assert_eq(instance.blue_team_health_bar.max_value, 120.0)
	assert_eq(instance.blue_team_health_label.text, "Équipe Bleue : 80/120 HP")
	
	instance.update_red_team_health(50, 100)
	assert_eq(instance.red_team_health_bar.value, 50.0)
	assert_eq(instance.red_team_health_bar.max_value, 100.0)
	assert_eq(instance.red_team_health_label.text, "Équipe Rouge : 50/100 HP")
