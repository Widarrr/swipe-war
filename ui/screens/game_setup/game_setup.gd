# res://ui/screens/game_setup/game_setup.gd
extends UIScreen

signal back_pressed
signal start_match_pressed(tanks: int, cars: int, planes: int, action_points: int, hit_points: int, vs_ia: bool, map_name: String, p2_tanks: int, p2_cars: int, p2_planes: int, budget: int)

# Valeurs de configuration par défaut et limites pour la boutique
const BUDGET_MAX = 150 # budget par défaut
const BUDGET_LIMIT_MIN = 90
const BUDGET_LIMIT_MAX = 300
const BUDGET_LIMIT_STEP = 10
const COST_TANK = 50
const COST_PLANE = 40
const COST_CAR = 30

# Budget (points de composition d'équipe) réglable sur la page Règles
var team_budget: int = BUDGET_MAX

var num_tanks: int = 1
var num_planes: int = 1
var num_cars: int = 1

# Équipe du joueur 2 (configurée uniquement en mode J1 vs J2)
var p2_num_tanks: int = 1
var p2_num_planes: int = 1
var p2_num_cars: int = 1
# Joueur dont on édite l'équipe à l'étape boutique (1 = bleu, 2 = rouge)
var editing_player: int = 1

const AP_MIN = 3
const AP_MAX = 10
const HP_MIN = 10
const HP_MAX = 100
const HP_STEP = 5

var action_points: int = 5
var hit_points: int = 50
var vs_ia: bool = true
var selected_map_name: String = "classic"
var current_step: int = 1

# Références aux nœuds d'affichage
@onready var ap_label: Label = $VBoxContainer/CardsContainer/APCard/Margin/HBox/ControlArea/AdjusterHBox/ValueLabel
@onready var hp_label: Label = $VBoxContainer/CardsContainer/HPCard/Margin/HBox/ControlArea/AdjusterHBox/ValueLabel

# Références aux boutons tactiles
@onready var back_btn: TouchButton = $TopBar/BackButton
@onready var start_match_btn: TouchButton = $VBoxContainer/StartMatchButton

# Références de la boutique créées dynamiquement
var tank_val_label: Label
var plane_val_label: Label
var car_val_label: Label
var budget_label: Label
var shop_title_label: Label
# Carte "Points d'équipe" (budget) créée dynamiquement sur la page Règles
var budget_card: PanelContainer
var budget_value_label: Label
var budget_progress: ProgressBar

# Références des cartes et étapes
var mode_card_ia: Button
var mode_card_pvp: Button
var map_card_classic: Button
var map_card_cross: Button
var map_card_pillars: Button
var map_card_corridor: Button
var ap_progress: ProgressBar
var hp_progress: ProgressBar

var step_labels: Array[Label] = []
var step_dots: Array[Panel] = []
var step_indicator_container: HBoxContainer

func _ready() -> void:
	super._ready()
	
	# Connecter les boutons globaux
	back_btn.pressed.connect(_on_back_pressed)
	start_match_btn.pressed.connect(_on_next_pressed)
	
	# Configurer l'indicateur d'étape
	_setup_step_indicator()
	
	# Configurer le mode de jeu (vs IA ou vs J2) sous forme de 2 cartes premium
	_setup_game_mode_card()
	
	# Configurer la sélection de la carte
	_setup_map_card()
	
	# Ajouter la carte "Points d'équipe" (budget) AVANT les jauges,
	# pour que le clone de la carte AP ne récupère pas la barre de progression.
	_setup_budget_card()

	# Configurer les jauges de progression pour les stats (AP et HP)
	_setup_stat_gauges()
	
	# Configurer la boutique d'équipe dans VehiclesCard
	_setup_team_shop()
	
	# Connecter les boutons de contrôle individuels
	# Action Points
	$VBoxContainer/CardsContainer/APCard/Margin/HBox/ControlArea/AdjusterHBox/MinusButton.pressed.connect(_on_ap_minus)
	$VBoxContainer/CardsContainer/APCard/Margin/HBox/ControlArea/AdjusterHBox/PlusButton.pressed.connect(_on_ap_plus)
	
	# Hit Points
	$VBoxContainer/CardsContainer/HPCard/Margin/HBox/ControlArea/AdjusterHBox/MinusButton.pressed.connect(_on_hp_minus)
	$VBoxContainer/CardsContainer/HPCard/Margin/HBox/ControlArea/AdjusterHBox/PlusButton.pressed.connect(_on_hp_plus)
	
	# Affichage initial
	_update_ui()
	_update_step_view()

func _setup_step_indicator() -> void:
	step_indicator_container = HBoxContainer.new()
	step_indicator_container.name = "StepIndicator"
	step_indicator_container.alignment = BoxContainer.ALIGNMENT_CENTER
	step_indicator_container.add_theme_constant_override("separation", 10)
	
	$VBoxContainer.add_child(step_indicator_container)
	$VBoxContainer.move_child(step_indicator_container, 0)
	
	var steps_data = [
		{"icon": "🎮", "text": "MODE"},
		{"icon": "🗺️", "text": "CARTE"},
		{"icon": "⚙️", "text": "RÈGLES"},
		{"icon": "🛡️", "text": "ÉQUIPE"}
	]
	
	for i in range(steps_data.size()):
		var step_data = steps_data[i]
		
		# Créer un HBox pour ce jalon d'étape
		var step_hbox = HBoxContainer.new()
		step_hbox.add_theme_constant_override("separation", 4)
		step_indicator_container.add_child(step_hbox)
		
		# Petit point/cercle visuel
		var dot = Panel.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var dot_style = StyleBoxFlat.new()
		dot_style.bg_color = Color("#55555d")
		dot_style.corner_radius_top_left = 4
		dot_style.corner_radius_top_right = 4
		dot_style.corner_radius_bottom_left = 4
		dot_style.corner_radius_bottom_right = 4
		dot.add_theme_stylebox_override("panel", dot_style)
		step_hbox.add_child(dot)
		step_dots.append(dot)
		
		# Label de l'étape
		var label = Label.new()
		label.text = "%s %s" % [step_data["icon"], step_data["text"]]
		label.add_theme_font_size_override("font_size", 9)
		label.add_theme_color_override("font_color", Color("#55555d"))
		step_hbox.add_child(label)
		step_labels.append(label)
		
		# Si ce n'est pas la dernière étape, ajouter un séparateur
		if i < steps_data.size() - 1:
			var separator = Label.new()
			separator.text = "──"
			separator.add_theme_color_override("font_color", Color("#26262b"))
			separator.add_theme_font_size_override("font_size", 8)
			separator.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			step_indicator_container.add_child(separator)

func _update_step_indicator() -> void:
	for i in range(step_labels.size()):
		var label = step_labels[i]
		var dot = step_dots[i]
		
		if not is_instance_valid(label) or not is_instance_valid(dot):
			continue
			
		var dot_style = dot.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		
		if i + 1 == current_step:
			# Étape active : Neon Cyan
			label.add_theme_color_override("font_color", Color("#00D2FF"))
			label.add_theme_font_size_override("font_size", 10)
			
			dot_style.bg_color = Color("#00D2FF")
			dot_style.border_width_left = 1
			dot_style.border_width_top = 1
			dot_style.border_width_right = 1
			dot_style.border_width_bottom = 1
			dot_style.border_color = Color("#00D2FF", 0.5)
			dot_style.shadow_color = Color("#00D2FF", 0.3)
			dot_style.shadow_size = 4
			dot.add_theme_stylebox_override("panel", dot_style)
			
			# Micro-animation sur le label
			label.pivot_offset = label.size / 2.0
			var tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(label, "scale", Vector2(1.1, 1.1), 0.15)
		else:
			# Étape inactive : Gris foncé
			label.add_theme_color_override("font_color", Color("#55555d"))
			label.add_theme_font_size_override("font_size", 9)
			label.scale = Vector2.ONE
			
			dot_style.bg_color = Color("#26262b")
			dot_style.border_width_left = 0
			dot_style.border_width_top = 0
			dot_style.border_width_right = 0
			dot_style.border_width_bottom = 0
			dot_style.shadow_size = 0
			dot.add_theme_stylebox_override("panel", dot_style)

func _setup_game_mode_card() -> void:
	var cards_container = $VBoxContainer/CardsContainer
	if not cards_container: return
	
	# Créer un conteneur vertical pour les deux cartes de mode
	var mode_container = VBoxContainer.new()
	mode_container.name = "ModeCard"
	mode_container.add_theme_constant_override("separation", 16)
	mode_container.size_flags_horizontal = Control.SIZE_FILL
	mode_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_container.add_child(mode_container)
	cards_container.move_child(mode_container, 0)
	
	# Créer les styles pour les boutons-cartes
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color("#0F0F11")
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color("#1D1D21")
	style_normal.corner_radius_top_left = 16
	style_normal.corner_radius_top_right = 16
	style_normal.corner_radius_bottom_left = 16
	style_normal.corner_radius_bottom_right = 16
	
	# Carte JOUEUR VS IA
	mode_card_ia = Button.new()
	mode_card_ia.custom_minimum_size = Vector2(340, 110)
	mode_card_ia.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mode_card_ia.flat = false
	mode_card_ia.add_theme_stylebox_override("normal", style_normal)
	mode_card_ia.add_theme_stylebox_override("hover", style_normal)
	mode_card_ia.add_theme_stylebox_override("pressed", style_normal)
	mode_card_ia.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	mode_container.add_child(mode_card_ia)
	
	# Contenu de la carte IA
	_fill_mode_card(mode_card_ia, "🤖", "JOUEUR VS IA", "Affrontez l'intelligence artificielle.\nL'ordinateur contrôle l'équipe rouge.", Color("#00D2FF"))
	
	# Carte JOUEUR VS JOUEUR
	mode_card_pvp = Button.new()
	mode_card_pvp.custom_minimum_size = Vector2(340, 110)
	mode_card_pvp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mode_card_pvp.flat = false
	mode_card_pvp.add_theme_stylebox_override("normal", style_normal)
	mode_card_pvp.add_theme_stylebox_override("hover", style_normal)
	mode_card_pvp.add_theme_stylebox_override("pressed", style_normal)
	mode_card_pvp.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	mode_container.add_child(mode_card_pvp)
	
	_fill_mode_card(mode_card_pvp, "👥", "JOUEUR VS JOUEUR", "Duel local (Pass & Play).\nJouez à deux sur le même écran.", Color("#FF4B57"))
	
	# Connecter les clics
	mode_card_ia.pressed.connect(func():
		vs_ia = true
		_update_mode_cards_selection()
	)
	mode_card_pvp.pressed.connect(func():
		vs_ia = false
		_update_mode_cards_selection()
	)
	
	_update_mode_cards_selection()

func _fill_mode_card(card: Button, icon: String, title_text: String, desc_text: String, accent_color: Color) -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(margin)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(hbox)
	
	# Icon Frame
	var icon_frame = Panel.new()
	icon_frame.custom_minimum_size = Vector2(48, 48)
	icon_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_frame.mouse_filter = Control.MOUSE_FILTER_PASS
	
	var icon_style = StyleBoxFlat.new()
	icon_style.bg_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.1)
	icon_style.border_width_left = 1
	icon_style.border_width_top = 1
	icon_style.border_width_right = 1
	icon_style.border_width_bottom = 1
	icon_style.border_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.25)
	icon_style.corner_radius_top_left = 12
	icon_style.corner_radius_top_right = 12
	icon_style.corner_radius_bottom_left = 12
	icon_style.corner_radius_bottom_right = 12
	icon_frame.add_theme_stylebox_override("panel", icon_style)
	hbox.add_child(icon_frame)
	
	var icon_label = Label.new()
	icon_label.text = icon
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon_label.add_theme_font_size_override("font_size", 22)
	icon_frame.add_child(icon_label)
	
	# Text area
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	hbox.add_child(vbox)
	
	var title = Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.name = "TitleLabel"
	vbox.add_child(title)
	
	var desc = Label.new()
	desc.text = desc_text
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color("#8e8e93"))
	desc.name = "DescLabel"
	vbox.add_child(desc)

func _update_mode_cards_selection() -> void:
	if not is_instance_valid(mode_card_ia) or not is_instance_valid(mode_card_pvp):
		return
		
	var accent_ia = Color("#00D2FF") # Cyan
	var accent_pvp = Color("#FF4B57") # Coral / Rouge
	
	# Pivot offset pour la mise à l'échelle (la moitié de custom_minimum_size)
	mode_card_ia.pivot_offset = Vector2(170, 55)
	mode_card_pvp.pivot_offset = Vector2(170, 55)
	
	var apply_style = func(card: Button, is_selected: bool, accent_color: Color):
		var style = StyleBoxFlat.new()
		style.bg_color = Color("#0F0F11") if not is_selected else Color("#131317")
		style.corner_radius_top_left = 16
		style.corner_radius_top_right = 16
		style.corner_radius_bottom_left = 16
		style.corner_radius_bottom_right = 16
		style.border_width_left = 2 if is_selected else 1
		style.border_width_top = 2 if is_selected else 1
		style.border_width_right = 2 if is_selected else 1
		style.border_width_bottom = 2 if is_selected else 1
		
		if is_selected:
			style.border_color = accent_color
			style.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.15)
			style.shadow_size = 8
			card.modulate = Color.WHITE
			card.scale = Vector2(1.02, 1.02)
		else:
			style.border_color = Color("#1D1D21")
			style.shadow_size = 0
			card.modulate = Color(1.0, 1.0, 1.0, 0.6)
			card.scale = Vector2.ONE
			
		card.add_theme_stylebox_override("normal", style)
		card.add_theme_stylebox_override("hover", style)
		card.add_theme_stylebox_override("pressed", style)
		
		# Ajuster la couleur du titre
		var title_node = card.find_child("TitleLabel", true, false)
		if title_node is Label:
			title_node.add_theme_color_override("font_color", accent_color if is_selected else Color.WHITE)
			
	apply_style.call(mode_card_ia, vs_ia, accent_ia)
	apply_style.call(mode_card_pvp, not vs_ia, accent_pvp)

func _setup_map_card() -> void:
	var cards_container = $VBoxContainer/CardsContainer
	if not cards_container: return
	
	# Créer un GridContainer pour les 4 cartes de map
	var map_grid = GridContainer.new()
	map_grid.name = "MapCard"
	map_grid.columns = 2
	map_grid.add_theme_constant_override("h_separation", 16)
	map_grid.add_theme_constant_override("v_separation", 16)
	map_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	map_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_container.add_child(map_grid)
	cards_container.move_child(map_grid, 1) # Mettre après ModeCard
	
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color("#0F0F11")
	style_normal.border_width_left = 1
	style_normal.border_width_top = 1
	style_normal.border_width_right = 1
	style_normal.border_width_bottom = 1
	style_normal.border_color = Color("#1D1D21")
	style_normal.corner_radius_top_left = 16
	style_normal.corner_radius_top_right = 16
	style_normal.corner_radius_bottom_left = 16
	style_normal.corner_radius_bottom_right = 16
	
	# Bouton Classique
	map_card_classic = Button.new()
	map_card_classic.custom_minimum_size = Vector2(162, 105)
	map_card_classic.flat = false
	map_card_classic.add_theme_stylebox_override("normal", style_normal)
	map_card_classic.add_theme_stylebox_override("hover", style_normal)
	map_card_classic.add_theme_stylebox_override("pressed", style_normal)
	map_card_classic.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	map_grid.add_child(map_card_classic)
	_fill_map_card(map_card_classic, "🟪", "Classique", "4 obstacles\nau centre", Color("#00D2FF"))
	
	# Bouton Croix
	map_card_cross = Button.new()
	map_card_cross.custom_minimum_size = Vector2(162, 105)
	map_card_cross.flat = false
	map_card_cross.add_theme_stylebox_override("normal", style_normal)
	map_card_cross.add_theme_stylebox_override("hover", style_normal)
	map_card_cross.add_theme_stylebox_override("pressed", style_normal)
	map_card_cross.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	map_grid.add_child(map_card_cross)
	_fill_map_card(map_card_cross, "❌", "Croix", "Grande croix\ncentrale", Color("#FFB800"))
	
	# Bouton Piliers
	map_card_pillars = Button.new()
	map_card_pillars.custom_minimum_size = Vector2(162, 105)
	map_card_pillars.flat = false
	map_card_pillars.add_theme_stylebox_override("normal", style_normal)
	map_card_pillars.add_theme_stylebox_override("hover", style_normal)
	map_card_pillars.add_theme_stylebox_override("pressed", style_normal)
	map_card_pillars.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	map_grid.add_child(map_card_pillars)
	_fill_map_card(map_card_pillars, "🏛️", "Piliers", "4 colonnes\nprotectrices", Color("#8BE31B"))
	
	# Bouton Couloir
	map_card_corridor = Button.new()
	map_card_corridor.custom_minimum_size = Vector2(162, 105)
	map_card_corridor.flat = false
	map_card_corridor.add_theme_stylebox_override("normal", style_normal)
	map_card_corridor.add_theme_stylebox_override("hover", style_normal)
	map_card_corridor.add_theme_stylebox_override("pressed", style_normal)
	map_card_corridor.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	map_grid.add_child(map_card_corridor)
	_fill_map_card(map_card_corridor, "🚪", "Couloir", "Murs épais\nsur les côtés", Color("#FF4B57"))
	
	# Connecter les clics
	map_card_classic.pressed.connect(func(): selected_map_name = "classic"; _update_map_selection())
	map_card_cross.pressed.connect(func(): selected_map_name = "cross"; _update_map_selection())
	map_card_pillars.pressed.connect(func(): selected_map_name = "pillars"; _update_map_selection())
	map_card_corridor.pressed.connect(func(): selected_map_name = "corridor"; _update_map_selection())
	
	_update_map_selection()

func _fill_map_card(card: Button, icon: String, title_text: String, desc_text: String, accent_color: Color) -> void:
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	margin.add_child(vbox)
	
	# Icon Label
	var icon_label = Label.new()
	icon_label.text = icon
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(icon_label)
	
	# Title
	var title = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.name = "TitleLabel"
	vbox.add_child(title)
	
	# Description
	var desc = Label.new()
	desc.text = desc_text
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 9)
	desc.add_theme_color_override("font_color", Color("#8e8e93"))
	desc.name = "DescLabel"
	vbox.add_child(desc)

func _update_map_selection() -> void:
	if not is_instance_valid(map_card_classic) or not is_instance_valid(map_card_cross) or not is_instance_valid(map_card_pillars) or not is_instance_valid(map_card_corridor):
		return
		
	var apply_style = func(card: Button, is_selected: bool, accent_color: Color):
		card.pivot_offset = Vector2(81, 52) # la moitié de custom_minimum_size (162, 105)
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color("#0F0F11") if not is_selected else Color("#131317")
		style.corner_radius_top_left = 16
		style.corner_radius_top_right = 16
		style.corner_radius_bottom_left = 16
		style.corner_radius_bottom_right = 16
		style.border_width_left = 2 if is_selected else 1
		style.border_width_top = 2 if is_selected else 1
		style.border_width_right = 2 if is_selected else 1
		style.border_width_bottom = 2 if is_selected else 1
		
		if is_selected:
			style.border_color = accent_color
			style.shadow_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.15)
			style.shadow_size = 6
			card.modulate = Color.WHITE
			card.scale = Vector2(1.02, 1.02)
		else:
			style.border_color = Color("#1D1D21")
			style.shadow_size = 0
			card.modulate = Color(1.0, 1.0, 1.0, 0.6)
			card.scale = Vector2.ONE
			
		card.add_theme_stylebox_override("normal", style)
		card.add_theme_stylebox_override("hover", style)
		card.add_theme_stylebox_override("pressed", style)
		
		var title_node = card.find_child("TitleLabel", true, false)
		if title_node is Label:
			title_node.add_theme_color_override("font_color", accent_color if is_selected else Color.WHITE)
			
	apply_style.call(map_card_classic, selected_map_name == "classic", Color("#00D2FF"))
	apply_style.call(map_card_cross, selected_map_name == "cross", Color("#FFB800"))
	apply_style.call(map_card_pillars, selected_map_name == "pillars", Color("#8BE31B"))
	apply_style.call(map_card_corridor, selected_map_name == "corridor", Color("#FF4B57"))

# Crée la carte "Points d'équipe" en clonant la carte AP (même style premium).
func _setup_budget_card() -> void:
	var ap_card = $VBoxContainer/CardsContainer/APCard
	if not ap_card: return

	budget_card = ap_card.duplicate() as PanelContainer
	budget_card.name = "BudgetCard"
	ap_card.get_parent().add_child(budget_card)
	# Placer la carte budget juste avant la carte AP.
	ap_card.get_parent().move_child(budget_card, ap_card.get_index())

	var icon = budget_card.get_node_or_null("Margin/HBox/IconFrame/IconLabel")
	var title = budget_card.get_node_or_null("Margin/HBox/ControlArea/Title")
	var range_label = budget_card.get_node_or_null("Margin/HBox/ControlArea/RangeLabel")
	budget_value_label = budget_card.get_node_or_null("Margin/HBox/ControlArea/AdjusterHBox/ValueLabel")
	var minus_btn = budget_card.get_node_or_null("Margin/HBox/ControlArea/AdjusterHBox/MinusButton")
	var plus_btn = budget_card.get_node_or_null("Margin/HBox/ControlArea/AdjusterHBox/PlusButton")

	if icon: icon.text = "💰"
	if title: title.text = "Points d'équipe"
	if range_label: range_label.text = "%d - %d pts (pas de %d)" % [BUDGET_LIMIT_MIN, BUDGET_LIMIT_MAX, BUDGET_LIMIT_STEP]
	if budget_value_label: budget_value_label.text = str(team_budget)

	# Barre de progression (cohérente avec AP/HP)
	var ctrl_area = budget_card.get_node_or_null("Margin/HBox/ControlArea")
	if ctrl_area:
		var track_style = StyleBoxFlat.new()
		track_style.bg_color = Color("#18181C")
		track_style.corner_radius_top_left = 4
		track_style.corner_radius_top_right = 4
		track_style.corner_radius_bottom_left = 4
		track_style.corner_radius_bottom_right = 4
		budget_progress = ProgressBar.new()
		budget_progress.show_percentage = false
		budget_progress.custom_minimum_size = Vector2(0, 6)
		budget_progress.min_value = BUDGET_LIMIT_MIN
		budget_progress.max_value = BUDGET_LIMIT_MAX
		budget_progress.value = team_budget
		budget_progress.add_theme_stylebox_override("background", track_style)
		var fill = StyleBoxFlat.new()
		fill.bg_color = Color("#8BE31B") # Vert (budget)
		fill.corner_radius_top_left = 4
		fill.corner_radius_top_right = 4
		fill.corner_radius_bottom_left = 4
		fill.corner_radius_bottom_right = 4
		budget_progress.add_theme_stylebox_override("fill", fill)
		ctrl_area.add_child(budget_progress)

	# Le clone ne copie pas les connexions faites par code : on (re)branche les boutons.
	if minus_btn: minus_btn.pressed.connect(_on_budget_minus)
	if plus_btn: plus_btn.pressed.connect(_on_budget_plus)

	budget_card.hide()

func _on_budget_minus() -> void:
	team_budget = max(BUDGET_LIMIT_MIN, team_budget - BUDGET_LIMIT_STEP)
	_update_budget_ui()

func _on_budget_plus() -> void:
	team_budget = min(BUDGET_LIMIT_MAX, team_budget + BUDGET_LIMIT_STEP)
	_update_budget_ui()

func _update_budget_ui() -> void:
	if budget_value_label: budget_value_label.text = str(team_budget)
	if budget_progress: budget_progress.value = team_budget

func _setup_stat_gauges() -> void:
	var ap_ctrl_area = $VBoxContainer/CardsContainer/APCard/Margin/HBox/ControlArea
	var hp_ctrl_area = $VBoxContainer/CardsContainer/HPCard/Margin/HBox/ControlArea
	
	if not ap_ctrl_area or not hp_ctrl_area: return
	
	# Style pour le fond de la barre (track)
	var track_style = StyleBoxFlat.new()
	track_style.bg_color = Color("#18181C")
	track_style.corner_radius_top_left = 4
	track_style.corner_radius_top_right = 4
	track_style.corner_radius_bottom_left = 4
	track_style.corner_radius_bottom_right = 4
	track_style.content_margin_top = 4
	track_style.content_margin_bottom = 4
	
	# Progress bar pour AP
	ap_progress = ProgressBar.new()
	ap_progress.show_percentage = false
	ap_progress.custom_minimum_size = Vector2(0, 6)
	ap_progress.min_value = AP_MIN
	ap_progress.max_value = AP_MAX
	ap_progress.add_theme_stylebox_override("background", track_style)
	
	var ap_fill = StyleBoxFlat.new()
	ap_fill.bg_color = Color("#FFB800") # Gold/Yellow
	ap_fill.corner_radius_top_left = 4
	ap_fill.corner_radius_top_right = 4
	ap_fill.corner_radius_bottom_left = 4
	ap_fill.corner_radius_bottom_right = 4
	ap_progress.add_theme_stylebox_override("fill", ap_fill)
	
	ap_ctrl_area.add_child(ap_progress)
	
	# Progress bar pour HP
	hp_progress = ProgressBar.new()
	hp_progress.show_percentage = false
	hp_progress.custom_minimum_size = Vector2(0, 6)
	hp_progress.min_value = HP_MIN
	hp_progress.max_value = HP_MAX
	hp_progress.add_theme_stylebox_override("background", track_style)
	
	var hp_fill = StyleBoxFlat.new()
	hp_fill.bg_color = Color("#FF4B57") # Rouge/Coral
	hp_fill.corner_radius_top_left = 4
	hp_fill.corner_radius_top_right = 4
	hp_fill.corner_radius_bottom_left = 4
	hp_fill.corner_radius_bottom_right = 4
	hp_progress.add_theme_stylebox_override("fill", hp_fill)
	
	hp_ctrl_area.add_child(hp_progress)

func _setup_team_shop() -> void:
	var vehicles_card = $VBoxContainer/CardsContainer/VehiclesCard
	if not vehicles_card: return
	
	# Enlever l'ancienne structure de la carte
	for child in vehicles_card.get_children():
		child.queue_free()
	
	# Augmenter légèrement la taille de la carte pour accueillir les 3 types de véhicules
	vehicles_card.custom_minimum_size = Vector2(340, 210)
	
	# Créer la marge interne
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_top", 12)
	margin_container.add_theme_constant_override("margin_bottom", 12)
	margin_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	vehicles_card.add_child(margin_container)
	
	# VBox principal pour la boutique
	var shop_vbox = VBoxContainer.new()
	shop_vbox.add_theme_constant_override("separation", 8)
	shop_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin_container.add_child(shop_vbox)
	
	# Titre de la carte boutique (mis à jour selon le joueur édité)
	var title = Label.new()
	title.text = "Créer son Équipe (Max 5 véhicules)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color("#00D2FF"))
	title.add_theme_font_size_override("font_size", 13)
	shop_vbox.add_child(title)
	shop_title_label = title
	
	# Récupérer les styles existants des autres boutons pour préserver l'esthétique premium
	var ref_minus = $VBoxContainer/CardsContainer/APCard/Margin/HBox/ControlArea/AdjusterHBox/MinusButton
	var normal_style = ref_minus.get_theme_stylebox("normal") if ref_minus else null
	var pressed_style = ref_minus.get_theme_stylebox("pressed") if ref_minus else null
	
	# Ligne Tank
	var tank_hbox = _create_shop_row("🛡️ Tank (50 pts)\nLourd - Résistant - Masse 1.8x", num_tanks, func(val: int): _set_vehicle_count("tank", val), normal_style, pressed_style)
	tank_val_label = tank_hbox.get_node("Value")
	shop_vbox.add_child(tank_hbox)

	# Ligne Avion
	var plane_hbox = _create_shop_row("✈️ Avion (40 pts)\nLéger - Rapide - Masse 0.6x", num_planes, func(val: int): _set_vehicle_count("plane", val), normal_style, pressed_style)
	plane_val_label = plane_hbox.get_node("Value")
	shop_vbox.add_child(plane_hbox)

	# Ligne Voiture
	var car_hbox = _create_shop_row("🚗 Voiture (30 pts)\nMoyen - Équilibré - Masse 1.0x", num_cars, func(val: int): _set_vehicle_count("car", val), normal_style, pressed_style)
	car_val_label = car_hbox.get_node("Value")
	shop_vbox.add_child(car_hbox)
	
	# Label du budget restant
	budget_label = Label.new()
	budget_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	budget_label.add_theme_font_size_override("font_size", 11)
	shop_vbox.add_child(budget_label)
	
	_update_shop_ui()

func _create_shop_row(label_text: String, initial_val: int, on_change: Callable, normal_style: StyleBox, pressed_style: StyleBox) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var value_label = Label.new()
	value_label.name = "Value"
	value_label.text = str(initial_val)
	value_label.custom_minimum_size = Vector2(24, 0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 14)
	
	var name_label = Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", Color("#cccccc"))
	hbox.add_child(name_label)
	
	var minus_btn = Button.new()
	minus_btn.text = "-"
	minus_btn.custom_minimum_size = Vector2(32, 32)
	if normal_style: minus_btn.add_theme_stylebox_override("normal", normal_style)
	if pressed_style: minus_btn.add_theme_stylebox_override("pressed", pressed_style)
	if normal_style: minus_btn.add_theme_stylebox_override("hover", normal_style)
	minus_btn.pressed.connect(func():
		var val = int(value_label.text)
		if val > 0:
			on_change.call(val - 1)
	)
	hbox.add_child(minus_btn)
	hbox.add_child(value_label)
	
	var plus_btn = Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(32, 32)
	if normal_style: plus_btn.add_theme_stylebox_override("normal", normal_style)
	if pressed_style: plus_btn.add_theme_stylebox_override("pressed", pressed_style)
	if normal_style: plus_btn.add_theme_stylebox_override("hover", normal_style)
	plus_btn.pressed.connect(func():
		var val = int(value_label.text)
		on_change.call(val + 1)
	)
	hbox.add_child(plus_btn)
	
	return hbox

# Écrit la quantité d'un véhicule dans l'équipe du joueur en cours d'édition.
func _set_vehicle_count(type: String, val: int) -> void:
	if editing_player == 1:
		match type:
			"tank": num_tanks = val
			"plane": num_planes = val
			"car": num_cars = val
	else:
		match type:
			"tank": p2_num_tanks = val
			"plane": p2_num_planes = val
			"car": p2_num_cars = val
	_update_shop_ui()

# Quantités de l'équipe en cours d'édition (P1 ou P2).
func _active_counts() -> Array:
	if editing_player == 1:
		return [num_tanks, num_planes, num_cars]
	return [p2_num_tanks, p2_num_planes, p2_num_cars]

# Réinitialise la boutique pour le joueur courant (titre, couleur, valeurs).
func _refresh_shop_for_player() -> void:
	if shop_title_label:
		if editing_player == 2:
			shop_title_label.text = "Équipe Joueur 2 — Rouge (Max 5)"
			shop_title_label.add_theme_color_override("font_color", Color("#FF4B57"))
		else:
			shop_title_label.text = "Créer son Équipe (Max 5 véhicules)"
			shop_title_label.add_theme_color_override("font_color", Color("#00D2FF"))
	_update_shop_ui()

func _update_shop_ui() -> void:
	var counts = _active_counts()
	var n_tanks = counts[0]
	var n_planes = counts[1]
	var n_cars = counts[2]
	var total_cost = (n_tanks * COST_TANK) + (n_planes * COST_PLANE) + (n_cars * COST_CAR)
	var remaining = team_budget - total_cost
	var total_vehicles = n_tanks + n_planes + n_cars

	if tank_val_label:
		tank_val_label.text = str(n_tanks)
	if plane_val_label:
		plane_val_label.text = str(n_planes)
	if car_val_label:
		car_val_label.text = str(n_cars)
		
	if budget_label:
		if remaining < 0:
			budget_label.text = "Budget dépassé ! (%d pts)" % total_cost
			budget_label.add_theme_color_override("font_color", Color("#FF4B57"))
			start_match_btn.disabled = true
			start_match_btn.modulate = Color(1, 1, 1, 0.4)
		elif total_vehicles > 5:
			budget_label.text = "Max 5 véhicules ! (Actuel: %d)" % total_vehicles
			budget_label.add_theme_color_override("font_color", Color("#FF4B57"))
			start_match_btn.disabled = true
			start_match_btn.modulate = Color(1, 1, 1, 0.4)
		elif total_vehicles < 1:
			budget_label.text = "Achetez au moins 1 véhicule !"
			budget_label.add_theme_color_override("font_color", Color("#FFB800"))
			start_match_btn.disabled = true
			start_match_btn.modulate = Color(1, 1, 1, 0.4)
		else:
			budget_label.text = "Budget : %d / %d pts (Équipe : %d/5)" % [remaining, team_budget, total_vehicles]
			budget_label.add_theme_color_override("font_color", Color("#8BE31B"))
			start_match_btn.disabled = false
			start_match_btn.modulate = Color.WHITE

func _update_ui() -> void:
	if ap_label:
		ap_label.text = str(action_points)
	if hp_label:
		hp_label.text = str(hit_points)
		
	if ap_progress:
		ap_progress.value = action_points
	if hp_progress:
		hp_progress.value = hit_points

func _on_ap_minus() -> void:
	if action_points > AP_MIN:
		action_points -= 1
		_update_ui()
		_play_feedback_animation(ap_label)

func _on_ap_plus() -> void:
	if action_points < AP_MAX:
		action_points += 1
		_update_ui()
		_play_feedback_animation(ap_label)

func _on_hp_minus() -> void:
	if hit_points > HP_MIN:
		hit_points -= HP_STEP
		_update_ui()
		_play_feedback_animation(hp_label)

func _on_hp_plus() -> void:
	if hit_points < HP_MAX:
		hit_points += HP_STEP
		_update_ui()
		_play_feedback_animation(hp_label)

func open_screen() -> void:
	current_step = 1
	editing_player = 1
	_update_step_view()
	super.open_screen()

func _update_step_view() -> void:
	var cards_container = $VBoxContainer/CardsContainer
	if not cards_container: return
	
	var mode_card = cards_container.get_node_or_null("ModeCard")
	var map_card = cards_container.get_node_or_null("MapCard")
	var vehicles_card = cards_container.get_node_or_null("VehiclesCard")
	var ap_card = cards_container.get_node_or_null("APCard")
	var hp_card = cards_container.get_node_or_null("HPCard")
	var title_label = $TopBar/TitleLabel
	
	_update_step_indicator()
	
	if current_step == 1:
		if mode_card: mode_card.show()
		if map_card: map_card.hide()
		if vehicles_card: vehicles_card.hide()
		if ap_card: ap_card.hide()
		if hp_card: hp_card.hide()
		if budget_card: budget_card.hide()

		if title_label: title_label.text = "1. Choisir le Mode"
		if start_match_btn:
			start_match_btn.text = "Suivant >"
			start_match_btn.disabled = false
			start_match_btn.modulate = Color.WHITE
	elif current_step == 2:
		if mode_card: mode_card.hide()
		if map_card: map_card.show()
		if vehicles_card: vehicles_card.hide()
		if ap_card: ap_card.hide()
		if hp_card: hp_card.hide()
		if budget_card: budget_card.hide()

		if title_label: title_label.text = "2. Sélectionner la Carte"
		if start_match_btn:
			start_match_btn.text = "Suivant >"
			start_match_btn.disabled = false
			start_match_btn.modulate = Color.WHITE
	elif current_step == 3:
		if mode_card: mode_card.hide()
		if map_card: map_card.hide()
		if vehicles_card: vehicles_card.hide()
		if ap_card: ap_card.show()
		if hp_card: hp_card.show()
		if budget_card: budget_card.show()

		if title_label: title_label.text = "3. Paramètres de Match"
		if start_match_btn:
			start_match_btn.text = "Suivant >"
			start_match_btn.disabled = false
			start_match_btn.modulate = Color.WHITE
	else:
		if mode_card: mode_card.hide()
		if map_card: map_card.hide()
		if vehicles_card: vehicles_card.show()
		if ap_card: ap_card.hide()
		if hp_card: hp_card.hide()
		if budget_card: budget_card.hide()

		# En J1 vs J2 : étape équipe en deux temps (J1 puis J2).
		if not vs_ia and editing_player == 1:
			if title_label: title_label.text = "4. Équipe Joueur 1"
			if start_match_btn:
				start_match_btn.text = "Suivant >"
		elif not vs_ia and editing_player == 2:
			if title_label: title_label.text = "4. Équipe Joueur 2"
			if start_match_btn:
				start_match_btn.text = "Lancer le Match"
		else:
			if title_label: title_label.text = "4. Composer l'Équipe"
			if start_match_btn:
				start_match_btn.text = "Lancer le Match"
		_update_shop_ui()

func _on_back_pressed() -> void:
	if current_step == 4:
		# En J1 vs J2, l'étape équipe se fait en deux temps (J1 puis J2).
		if editing_player == 2:
			editing_player = 1
			_refresh_shop_for_player()
			_update_step_view()
			_animate_cards_transition()
			return
		current_step = 3
		_update_step_view()
		_animate_cards_transition()
	elif current_step == 3:
		current_step = 2
		_update_step_view()
		_animate_cards_transition()
	elif current_step == 2:
		current_step = 1
		_update_step_view()
		_animate_cards_transition()
	else:
		back_pressed.emit()

func _on_next_pressed() -> void:
	if current_step == 1:
		current_step = 2
		_update_step_view()
		_animate_cards_transition()
	elif current_step == 2:
		current_step = 3
		_update_step_view()
		_animate_cards_transition()
	elif current_step == 3:
		current_step = 4
		editing_player = 1
		_refresh_shop_for_player()
		_update_step_view()
		_animate_cards_transition()
	else:
		# Étape équipe. En J1 vs J2, on enchaîne J1 -> J2 avant de lancer.
		if not vs_ia and editing_player == 1:
			editing_player = 2
			_refresh_shop_for_player()
			_update_step_view()
			_animate_cards_transition()
		else:
			_on_start_match_pressed()

func _animate_cards_transition() -> void:
	var cards_container = $VBoxContainer/CardsContainer
	if not cards_container: return
	
	cards_container.pivot_offset = cards_container.size / 2.0
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(cards_container, "modulate:a", 1.0, 0.2).from(0.0)
	tween.tween_property(cards_container, "scale", Vector2.ONE, 0.2).from(Vector2(0.96, 0.96))

func _on_start_match_pressed() -> void:
	# En J1 vs J2, on transmet l'équipe configurée par le joueur 2.
	# En mode IA, on envoie -1 (sentinelle) pour que l'équipe rouge soit générée.
	var p2_t := p2_num_tanks if not vs_ia else -1
	var p2_c := p2_num_cars if not vs_ia else -1
	var p2_p := p2_num_planes if not vs_ia else -1
	start_match_pressed.emit(num_tanks, num_cars, num_planes, action_points, hit_points, vs_ia, selected_map_name, p2_t, p2_c, p2_p, team_budget)

# Rétrocompatibilité et feedback visuel de transition sur le texte quand la valeur change
func _play_feedback_animation(target_label: Label) -> void:
	if not is_instance_valid(target_label): return
	
	target_label.pivot_offset = target_label.size / 2.0
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(target_label, "scale", Vector2(1.2, 1.2), 0.05)
	tween.tween_property(target_label, "scale", Vector2.ONE, 0.1)
