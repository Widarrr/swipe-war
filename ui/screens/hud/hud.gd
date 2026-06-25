# res://ui/screens/hud/hud.gd
extends UIScreen

signal pause_pressed
signal move_mode_pressed
signal shoot_mode_pressed
signal end_turn_pressed

# Références aux nœuds
@onready var p1_label: Label = $TopBar/PlayerContainer/PlayerLabel
@onready var ap_label: Label = $TopBar/APLabel
@onready var move_btn: TouchButton = $BottomPanel/Margin/VBox/ActionsHBox/MoveButton
@onready var shoot_btn: TouchButton = $BottomPanel/Margin/VBox/ActionsHBox/ShootButton
@onready var end_turn_btn: TouchButton = $BottomPanel/Margin/VBox/EndTurnButton
@onready var floating_container: Control = $FloatingUIContainer

# Préchargement de la jauge flottante pour l'instancier dynamiquement
const FLOATING_GAUGE_SCENE = preload("res://ui/common/components/floating_gauge.tscn")

# Thèmes StyleBox pour les modes d'action (Move et Shoot actifs/inactifs)
var style_active_move: StyleBoxFlat
var style_active_shoot: StyleBoxFlat
var style_inactive: StyleBoxFlat

var red_team_health_bar: ProgressBar
var red_team_health_label: Label
var blue_team_health_bar: ProgressBar
var blue_team_health_label: Label

func _ready() -> void:
	super._ready()
	
	# Connecter les boutons
	$TopBar/PauseButton.pressed.connect(func() -> void: pause_pressed.emit())
	move_btn.pressed.connect(_on_move_pressed)
	shoot_btn.pressed.connect(_on_shoot_pressed)
	end_turn_btn.pressed.connect(func() -> void: end_turn_pressed.emit())
	
	# Initialiser les StyleBoxes personnalisés à partir de ceux du Figma
	_setup_styles()
	
	# Initialiser les barres de vie globales
	setup_health_bars()
	
	# Par défaut, mode neutre
	set_action_mode("none")

func _setup_styles() -> void:
	# Inactif (Bouton sombre transparent)
	style_inactive = StyleBoxFlat.new()
	style_inactive.bg_color = Color("#17171A")
	style_inactive.border_width_left = 1
	style_inactive.border_width_top = 1
	style_inactive.border_width_right = 1
	style_inactive.border_width_bottom = 1
	style_inactive.border_color = Color("#26262A")
	style_inactive.corner_radius_top_left = 14
	style_inactive.corner_radius_top_right = 14
	style_inactive.corner_radius_bottom_left = 14
	style_inactive.corner_radius_bottom_right = 14
	
	# Move Actif (Cyan)
	style_active_move = StyleBoxFlat.new()
	style_active_move.bg_color = Color("#00D2FF")
	style_active_move.corner_radius_top_left = 14
	style_active_move.corner_radius_top_right = 14
	style_active_move.corner_radius_bottom_left = 14
	style_active_move.corner_radius_bottom_right = 14
	
	# Shoot Actif (Corail/Rouge)
	style_active_shoot = StyleBoxFlat.new()
	style_active_shoot.bg_color = Color("#FF4B57")
	style_active_shoot.corner_radius_top_left = 14
	style_active_shoot.corner_radius_top_right = 14
	style_active_shoot.corner_radius_bottom_left = 14
	style_active_shoot.corner_radius_bottom_right = 14

## Met à jour les informations du joueur actif et de ses points d'action (ex: "AP: 3/5")
func update_ap_display(player_name: String, current_ap: int, max_ap: int, is_p1: bool = true) -> void:
	if p1_label:
		p1_label.text = player_name
		p1_label.add_theme_color_override("font_color", Color("#00D2FF") if is_p1 else Color("#FF4B57"))
	
	if ap_label:
		ap_label.text = "AP: %d/%d" % [current_ap, max_ap]
		if current_ap == 0:
			ap_label.add_theme_color_override("font_color", Color("#FF4B57"))
		elif current_ap == max_ap:
			ap_label.add_theme_color_override("font_color", Color("#FFB800"))
		else:
			ap_label.add_theme_color_override("font_color", Color.WHITE)

## Gère le style visuel des boutons en fonction du mode choisi ("move", "shoot", "none")
func set_action_mode(mode: String) -> void:
	if not move_btn or not shoot_btn: return
	
	match mode.to_lower():
		"move":
			# Activer Move, Désactiver Shoot
			move_btn.add_theme_stylebox_override("normal", style_active_move)
			move_btn.add_theme_stylebox_override("pressed", style_active_move)
			move_btn.add_theme_stylebox_override("hover", style_active_move)
			move_btn.add_theme_color_override("font_color", Color("#070708"))
			
			shoot_btn.add_theme_stylebox_override("normal", style_inactive)
			shoot_btn.add_theme_stylebox_override("pressed", style_inactive)
			shoot_btn.add_theme_stylebox_override("hover", style_inactive)
			shoot_btn.add_theme_color_override("font_color", Color("#9E9EAF"))
			
		"shoot":
			# Activer Shoot, Désactiver Move
			move_btn.add_theme_stylebox_override("normal", style_inactive)
			move_btn.add_theme_stylebox_override("pressed", style_inactive)
			move_btn.add_theme_stylebox_override("hover", style_inactive)
			move_btn.add_theme_color_override("font_color", Color("#9E9EAF"))
			
			shoot_btn.add_theme_stylebox_override("normal", style_active_shoot)
			shoot_btn.add_theme_stylebox_override("pressed", style_active_shoot)
			shoot_btn.add_theme_stylebox_override("hover", style_active_shoot)
			shoot_btn.add_theme_color_override("font_color", Color("#070708"))
			
		_:
			# Tout inactif
			move_btn.add_theme_stylebox_override("normal", style_inactive)
			move_btn.add_theme_stylebox_override("pressed", style_inactive)
			move_btn.add_theme_stylebox_override("hover", style_inactive)
			move_btn.add_theme_color_override("font_color", Color("#9E9EAF"))
			
			shoot_btn.add_theme_stylebox_override("normal", style_inactive)
			shoot_btn.add_theme_stylebox_override("pressed", style_inactive)
			shoot_btn.add_theme_stylebox_override("hover", style_inactive)
			shoot_btn.add_theme_color_override("font_color", Color("#9E9EAF"))

## Spécifique tactile : instancier et attacher une jauge flottante à une unité du monde
func create_floating_gauge(unit: Node2D) -> FloatingGauge:
	var gauge = FLOATING_GAUGE_SCENE.instantiate() as FloatingGauge
	floating_container.add_child(gauge)
	gauge.setup(unit)
	return gauge

# --- Clics internes ---

func _on_move_pressed() -> void:
	set_action_mode("move")
	move_mode_pressed.emit()

func _on_shoot_pressed() -> void:
	set_action_mode("shoot")
	shoot_mode_pressed.emit()

func setup_health_bars() -> void:
	# 1. Barre de vie de l'Équipe Bleue (tout en bas, dans le BottomPanel)
	var vbox = $BottomPanel/Margin/VBox
	if vbox:
		var blue_hbox = HBoxContainer.new()
		blue_hbox.name = "BlueTeamHealthHBox"
		blue_hbox.add_theme_constant_override("separation", 8)
		blue_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		blue_team_health_label = Label.new()
		blue_team_health_label.text = "Équipe Bleue : 100/100 HP"
		blue_team_health_label.add_theme_color_override("font_color", Color("#00D2FF")) # Bleu/Cyan
		blue_team_health_label.add_theme_font_size_override("font_size", 12)
		
		blue_team_health_bar = ProgressBar.new()
		blue_team_health_bar.custom_minimum_size = Vector2(0, 12)
		blue_team_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		blue_team_health_bar.show_percentage = true
		blue_team_health_bar.add_theme_font_size_override("font_size", 10)
		
		var bg_style_blue = StyleBoxFlat.new()
		bg_style_blue.bg_color = Color("#17171A")
		bg_style_blue.corner_radius_top_left = 6
		bg_style_blue.corner_radius_top_right = 6
		bg_style_blue.corner_radius_bottom_left = 6
		bg_style_blue.corner_radius_bottom_right = 6
		blue_team_health_bar.add_theme_stylebox_override("background", bg_style_blue)
		
		var fill_style_blue = StyleBoxFlat.new()
		fill_style_blue.bg_color = Color("#00D2FF") # Bleu/Cyan
		fill_style_blue.corner_radius_top_left = 6
		fill_style_blue.corner_radius_top_right = 6
		fill_style_blue.corner_radius_bottom_left = 6
		fill_style_blue.corner_radius_bottom_right = 6
		blue_team_health_bar.add_theme_stylebox_override("fill", fill_style_blue)
		
		blue_hbox.add_child(blue_team_health_label)
		blue_hbox.add_child(blue_team_health_bar)
		
		vbox.add_child(blue_hbox)
		vbox.move_child(blue_hbox, 0)
		
	# 2. Barre de vie de l'Équipe Rouge (en haut, dans le TopBar)
	var topbar = $TopBar
	if topbar:
		# Agrandir le TopBar pour faire de la place
		topbar.custom_minimum_size.y = 80
		
		# Ajuster la position des contrôles existants dans le TopBar vers le haut
		var player_container = topbar.get_node_or_null("PlayerContainer")
		if player_container:
			player_container.offset_top = -30
			player_container.offset_bottom = 2
		var ap_label_node = topbar.get_node_or_null("APLabel")
		if ap_label_node:
			ap_label_node.offset_top = -30
			ap_label_node.offset_bottom = 2
		var pause_btn = topbar.get_node_or_null("PauseButton")
		if pause_btn:
			pause_btn.offset_top = -34
			pause_btn.offset_bottom = 14
			
		var red_hbox = HBoxContainer.new()
		red_hbox.name = "RedTeamHealthHBox"
		red_hbox.add_theme_constant_override("separation", 8)
		red_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		
		# Ancrer en bas du TopBar
		red_hbox.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		red_hbox.offset_left = 16
		red_hbox.offset_right = -16
		red_hbox.offset_top = -28
		red_hbox.offset_bottom = -8
		
		red_team_health_label = Label.new()
		red_team_health_label.text = "Équipe Rouge : 100/100 HP"
		red_team_health_label.add_theme_color_override("font_color", Color("#FF4B57")) # Rouge
		red_team_health_label.add_theme_font_size_override("font_size", 12)
		
		red_team_health_bar = ProgressBar.new()
		red_team_health_bar.custom_minimum_size = Vector2(0, 12)
		red_team_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		red_team_health_bar.show_percentage = true
		red_team_health_bar.add_theme_font_size_override("font_size", 10)
		
		var bg_style_red = StyleBoxFlat.new()
		bg_style_red.bg_color = Color("#17171A")
		bg_style_red.corner_radius_top_left = 6
		bg_style_red.corner_radius_top_right = 6
		bg_style_red.corner_radius_bottom_left = 6
		bg_style_red.corner_radius_bottom_right = 6
		red_team_health_bar.add_theme_stylebox_override("background", bg_style_red)
		
		var fill_style_red = StyleBoxFlat.new()
		fill_style_red.bg_color = Color("#FF4B57") # Rouge
		fill_style_red.corner_radius_top_left = 6
		fill_style_red.corner_radius_top_right = 6
		fill_style_red.corner_radius_bottom_left = 6
		fill_style_red.corner_radius_bottom_right = 6
		red_team_health_bar.add_theme_stylebox_override("fill", fill_style_red)
		
		red_hbox.add_child(red_team_health_label)
		red_hbox.add_child(red_team_health_bar)
		
		topbar.add_child(red_hbox)

func update_red_team_health(current: int, max_val: int) -> void:
	if is_instance_valid(red_team_health_bar) and is_instance_valid(red_team_health_label):
		red_team_health_bar.max_value = max_val
		red_team_health_bar.value = current
		red_team_health_label.text = "Équipe Rouge : %d/%d HP" % [current, max_val]

func update_blue_team_health(current: int, max_val: int) -> void:
	if is_instance_valid(blue_team_health_bar) and is_instance_valid(blue_team_health_label):
		blue_team_health_bar.max_value = max_val
		blue_team_health_bar.value = current
		blue_team_health_label.text = "Équipe Bleue : %d/%d HP" % [current, max_val]
