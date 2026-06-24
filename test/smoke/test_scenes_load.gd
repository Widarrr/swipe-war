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
