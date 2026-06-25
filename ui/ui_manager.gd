# res://ui/ui_manager.gd
class_name UIManager
extends CanvasLayer

# Gère le démarrage et le re-jeu
signal match_started(tanks: int, cars: int, planes: int, hp: int, ap: int, game_mode: int, map_name: String, p2_tanks: int, p2_cars: int, p2_planes: int, budget: int)
signal play_again_requested
signal match_paused
signal match_resumed
signal game_exited

enum ScreenType {
	MAIN_MENU,
	GAME_SETUP,
	HUD,
	VICTORY
}

@onready var main_menu: UIScreen = $UIRoot/ScreensContainer/MainMenu
@onready var game_setup: UIScreen = $UIRoot/ScreensContainer/GameSetup
@onready var hud: UIScreen = $UIRoot/ScreensContainer/HUD
@onready var victory_screen: UIScreen = $UIRoot/ScreensContainer/VictoryScreen
@onready var transition_overlay: ColorRect = $UIRoot/TransitionOverlay

var _screens: Dictionary = {}
var _current_screen: UIScreen = null
var _last_match_settings: Dictionary = {"vehicles": 3, "hp": 50, "ap": 5}

func _ready() -> void:
	# Liaison des types d'écran à leurs scènes physiques
	_screens[ScreenType.MAIN_MENU] = main_menu
	_screens[ScreenType.GAME_SETUP] = game_setup
	_screens[ScreenType.HUD] = hud
	_screens[ScreenType.VICTORY] = victory_screen
	
	# Initialiser tous les écrans (les masquer et configurer leur taille)
	for screen: UIScreen in _screens.values():
		screen.hide()
		screen.set_anchors_preset(Control.PRESET_FULL_RECT)
		
	# Connecter les signaux internes des écrans
	_connect_screen_signals()
	
	# Transition initiale : Menu Principal sans fondu
	change_screen(ScreenType.MAIN_MENU, false)

func _connect_screen_signals() -> void:
	# Signaux du Menu Principal
	if main_menu:
		main_menu.connect("new_game_pressed", func() -> void: change_screen(ScreenType.GAME_SETUP))
		main_menu.connect("quit_pressed", func() -> void: game_exited.emit())
		
	# Signaux de Configuration de Partie
	if game_setup:
		game_setup.connect("back_pressed", func() -> void: change_screen(ScreenType.MAIN_MENU))
		game_setup.connect("start_match_pressed", _on_start_match_requested)
		
	# Signaux du HUD In-Game
	if hud:
		hud.connect("pause_pressed", _on_pause_requested)
		
	# Signaux de l'Écran de Victoire
	if victory_screen:
		victory_screen.connect("back_to_menu_pressed", func() -> void: change_screen(ScreenType.MAIN_MENU))
		victory_screen.connect("play_again_pressed", _on_play_again_requested)

## Gère le routage et le changement d'écran avec transition fondu (Tween)
func change_screen(new_screen_type: ScreenType, use_transition: bool = true) -> void:
	var target_screen: UIScreen = _screens.get(new_screen_type) as UIScreen
	if not target_screen:
		push_error("Type d'écran invalide ou non relié dans le UIManager.")
		return
		
	if _current_screen == target_screen:
		return
		
	# Désactiver le tactile durant la transition
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	
	if use_transition:
		# 1. Fondu au noir (transition_overlay)
		var fade_in: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		fade_in.tween_property(transition_overlay, "color:a", 1.0, 0.25)
		await fade_in.finished
		
		# 2. Fermer l'ancien écran, ouvrir le nouveau
		if _current_screen:
			_current_screen.hide()
			
		_current_screen = target_screen
		if target_screen.has_method("open_screen"):
			target_screen.open_screen()
		else:
			target_screen.show()
		
		# Petit temps d'arrêt pour la fluidité
		await get_tree().create_timer(0.05).timeout
		
		# 3. Fondu de sortie (réapparition)
		var fade_out: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		fade_out.tween_property(transition_overlay, "color:a", 0.0, 0.25)
		await fade_out.finished
	else:
		if _current_screen:
			_current_screen.hide()
		_current_screen = target_screen
		if target_screen.has_method("open_screen"):
			target_screen.open_screen()
		else:
			target_screen.show()
		transition_overlay.color.a = 0.0
		
	# Libérer les inputs tactiles à la fin de la transition
	transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

# --- Callbacks de navigation interne ---

func _on_start_match_requested(tanks: int, cars: int, planes: int, ap: int, hp: int, game_mode: int, map_name: String, p2_tanks: int, p2_cars: int, p2_planes: int, budget: int) -> void:
	# Enregistrer les paramètres pour le bouton "Play Again"
	_last_match_settings["tanks"] = tanks
	_last_match_settings["cars"] = cars
	_last_match_settings["planes"] = planes
	_last_match_settings["ap"] = ap
	_last_match_settings["hp"] = hp
	_last_match_settings["game_mode"] = game_mode
	_last_match_settings["map_name"] = map_name
	_last_match_settings["p2_tanks"] = p2_tanks
	_last_match_settings["p2_cars"] = p2_cars
	_last_match_settings["p2_planes"] = p2_planes
	_last_match_settings["budget"] = budget

	# Lancer le match (changement vers HUD)
	change_screen(ScreenType.HUD)

	# Mettre à jour l'affichage AP initial dans le HUD
	if hud and hud.has_method("update_ap_display"):
		hud.update_ap_display("P1", ap, ap, true)

	# Émettre le signal global pour que le gameplay instancie la grille et les tanks
	match_started.emit(tanks, cars, planes, hp, ap, game_mode, map_name, p2_tanks, p2_cars, p2_planes, budget)

func _on_play_again_requested() -> void:
	change_screen(ScreenType.HUD)
	play_again_requested.emit()
	
	var ap = _last_match_settings["ap"]
	if hud and hud.has_method("update_ap_display"):
		hud.update_ap_display("P1", ap, ap, true)
		
	# Lancer le match avec les mêmes configurations
	match_started.emit(
		_last_match_settings.get("tanks", 1),
		_last_match_settings.get("cars", 1),
		_last_match_settings.get("planes", 1),
		_last_match_settings["hp"],
		_last_match_settings["ap"],
		_last_match_settings.get("game_mode", 0),
		_last_match_settings.get("map_name", "classic"),
		_last_match_settings.get("p2_tanks", -1),
		_last_match_settings.get("p2_cars", -1),
		_last_match_settings.get("p2_planes", -1),
		_last_match_settings.get("budget", 150)
	)

func _on_pause_requested() -> void:
	# Retourner au menu principal pour la démo, mais on émet le signal
	match_paused.emit()
	change_screen(ScreenType.MAIN_MENU)

## Fonction publique permettant au Gameplay d'annoncer une victoire et d'afficher l'écran
func show_victory(winner_name: String, vehicles_left: int, turns: int, accuracy: int, is_red_win: bool = false) -> void:
	if victory_screen and victory_screen.has_method("set_results"):
		victory_screen.set_results(winner_name, vehicles_left, turns, accuracy, is_red_win)
	change_screen(ScreenType.VICTORY)
