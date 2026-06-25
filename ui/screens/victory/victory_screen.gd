# res://ui/screens/victory/victory_screen.gd
extends UIScreen

signal back_to_menu_pressed
signal play_again_pressed

# Références aux nœuds
@onready var winner_label: Label = $VBoxContainer/WinnerContainer/WinnerLabel
@onready var vehicles_val: Label = $VBoxContainer/StatsHBox/VehiclesCard/Margin/VBox/ValueLabel
@onready var turns_val: Label = $VBoxContainer/StatsHBox/TurnsCard/Margin/VBox/ValueLabel
@onready var accuracy_val: Label = $VBoxContainer/StatsHBox/AccuracyCard/Margin/VBox/ValueLabel
@onready var particles_left: CPUParticles2D = $ParticlesLeft
@onready var particles_right: CPUParticles2D = $ParticlesRight
@onready var trophy_icon: Label = $VBoxContainer/TrophyContainer/TrophyIcon

var particles_top: CPUParticles2D

func _ready() -> void:
	super._ready()
	
	# Connecter les boutons
	$VBoxContainer/ButtonsContainer/BackToMenuButton.pressed.connect(func() -> void: back_to_menu_pressed.emit())
	$VBoxContainer/ButtonsContainer/PlayAgainButton.pressed.connect(func() -> void: play_again_pressed.emit())
	
	# Configurer les fontaines de confettis pour être continues et rotatives (Juiciness premium)
	for particles in [particles_left, particles_right]:
		if particles:
			particles.one_shot = false
			particles.amount = 50
			particles.lifetime = 3.5
			particles.angle_min = 0.0
			particles.angle_max = 360.0
			particles.angular_velocity_min = -150.0
			particles.angular_velocity_max = 150.0
			particles.scale_amount_min = 6.0
			particles.scale_amount_max = 14.0
			
	# Créer l'émetteur de pluie de confettis par le haut
	particles_top = CPUParticles2D.new()
	particles_top.name = "ParticlesTop"
	particles_top.position = Vector2(216, -10)
	particles_top.amount = 60
	particles_top.lifetime = 5.0
	particles_top.one_shot = false
	particles_top.explosiveness = 0.0
	particles_top.direction = Vector2.DOWN
	particles_top.spread = 70.0
	particles_top.gravity = Vector2(0, 120)
	particles_top.initial_velocity_min = 80.0
	particles_top.initial_velocity_max = 180.0
	particles_top.angle_min = 0.0
	particles_top.angle_max = 360.0
	particles_top.angular_velocity_min = -120.0
	particles_top.angular_velocity_max = 120.0
	particles_top.scale_amount_min = 5.0
	particles_top.scale_amount_max = 12.0
	
	# Partager le même dégradé de couleur néon
	if particles_left:
		particles_top.color_ramp = particles_left.color_ramp
		
	add_child(particles_top)

## Configure dynamiquement les résultats affichés sur l'écran
func set_results(winner_name: String, vehicles_left: int, turns: int, accuracy: int, is_red_win: bool = false) -> void:
	if winner_label:
		winner_label.text = winner_name + " Wins"
	if vehicles_val:
		vehicles_val.text = str(vehicles_left)
	if turns_val:
		turns_val.text = str(turns)
	if accuracy_val:
		accuracy_val.text = str(accuracy) + "%"

	# Couleurs du thème : Rouge pour l'équipe rouge, Cyan pour l'équipe bleue
	var theme_color = Color("#FF4B57") if is_red_win else Color("#00D2FF")
	var theme_pressed = Color("#C9303C") if is_red_win else Color("#00A6CC")
	
	if trophy_icon:
		trophy_icon.add_theme_color_override("font_color", theme_color)
		
	var victory_label = $VBoxContainer/WinnerContainer/VictoryLabel
	if victory_label:
		victory_label.add_theme_color_override("font_color", theme_color)
		
	if vehicles_val:
		vehicles_val.add_theme_color_override("font_color", theme_color)
		
	var back_button = $VBoxContainer/ButtonsContainer/BackToMenuButton
	if back_button:
		var style_normal = back_button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		if style_normal:
			style_normal.bg_color = theme_color
			style_normal.shadow_color = Color(theme_color.r, theme_color.g, theme_color.b, 0.2)
			back_button.add_theme_stylebox_override("normal", style_normal)

		var style_pressed = back_button.get_theme_stylebox("pressed").duplicate() as StyleBoxFlat
		if style_pressed:
			style_pressed.bg_color = theme_pressed
			back_button.add_theme_stylebox_override("pressed", style_pressed)
		
	# Dégradé des confettis
	var grad = Gradient.new()
	if is_red_win:
		grad.colors = PackedColorArray([
			Color("#FF4B57"),
			Color("#FF8A93"),
			Color("#991F26")
		])
		grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	else:
		grad.colors = PackedColorArray([
			Color(0, 0.823529, 1, 1),
			Color(1, 0.294118, 0.341176, 1),
			Color(1, 0.721569, 0, 1)
		])
		grad.offsets = PackedFloat32Array([0.0, 0.45, 0.9])
		
	for p in [particles_left, particles_right, particles_top]:
		if p:
			p.color_ramp = grad

## Surcharge de l'ouverture pour démarrer les confettis et l'animation
func open_screen() -> void:
	# Activer l'émission des particules
	if particles_left:
		particles_left.emitting = true
	if particles_right:
		particles_right.emitting = true
	if particles_top:
		particles_top.emitting = true
		
	await super.open_screen()
	
	# Animer le trophée pour un effet festif
	_animate_trophy()

func _animate_trophy() -> void:
	if not is_instance_valid(trophy_icon): return
	
	# Le trophée grossit avec un effet d'échelle rebondissante (pop)
	trophy_icon.pivot_offset = trophy_icon.size / 2.0
	trophy_icon.scale = Vector2.ZERO
	
	var tween: Tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(trophy_icon, "scale", Vector2.ONE, 0.8)
	
	# Petite oscillation continue
	var oscillate: Tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	oscillate.tween_property(trophy_icon, "rotation_degrees", 5.0, 1.5)
	oscillate.tween_property(trophy_icon, "rotation_degrees", -5.0, 1.5)
