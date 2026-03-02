# res://ui/screens/main_menu/main_menu.gd
extends UIScreen

signal new_game_pressed
signal quit_pressed

@onready var new_game_btn: TouchButton = $VBoxContainer/ButtonsContainer/NewGameButton
@onready var quit_btn: TouchButton = $VBoxContainer/ButtonsContainer/QuitButton
@onready var logo_container: Control = $VBoxContainer/LogoContainer

var time_accum: float = 0.0

func _ready() -> void:
	super._ready()
	$Background.visible = false
	
	# Connecter les signaux des boutons tactiles
	new_game_btn.pressed.connect(_on_new_game_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func _process(delta: float) -> void:
	time_accum += delta
	queue_redraw()

func _draw() -> void:
	# 1. Dessiner le fond uni très sombre
	draw_rect(Rect2(Vector2.ZERO, size), Color("#0C0C0D"))
	
	# 2. Dessiner les orbes lumineuses floues animées (Vignette néon)
	var center_cyan = Vector2(80.0 + 40.0 * sin(time_accum * 0.7), size.y - 120.0 + 30.0 * cos(time_accum * 0.9))
	var center_red = Vector2(size.x - 80.0 + 35.0 * cos(time_accum * 0.8), 180.0 + 40.0 * sin(time_accum * 0.6))
	
	_draw_glow_orb(center_cyan, 240.0, Color("#00D2FF")) # Cyan
	_draw_glow_orb(center_red, 240.0, Color("#FF4B57"))  # Rouge
	
	# 3. Dessiner la grille de points subtile (Tactique)
	var dot_spacing = 32
	var grid_color = Color("#1D1D21", 0.18 + 0.05 * sin(time_accum * 1.2)) # Légère pulsation
	for x in range(16, int(size.x), dot_spacing):
		for y in range(16, int(size.y), dot_spacing):
			draw_circle(Vector2(x, y), 1.0, grid_color)

func _draw_glow_orb(pos: Vector2, radius: float, color: Color) -> void:
	var steps = 14
	for i in range(steps):
		var t = float(i) / steps
		var r = radius * (1.0 - t)
		var alpha = 0.038 * t * t # Courbe quadratique pour un dégradé très doux
		draw_circle(pos, r, Color(color.r, color.g, color.b, alpha))

## Surcharge de l'ouverture pour ajouter une animation spécifique au logo et aux boutons
func open_screen() -> void:
	var title_node = $VBoxContainer/TitleContainer
	
	if new_game_btn:
		new_game_btn.scale = Vector2.ZERO
	if quit_btn:
		quit_btn.scale = Vector2.ZERO
	if title_node:
		title_node.modulate.a = 0.0
		
	# Appeler l'ouverture de base (fondu + zoom léger de l'écran entier)
	super.open_screen()
	
	# Animer le titre (fondu seulement pour préserver le layout responsive)
	if title_node:
		var title_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		title_tween.tween_property(title_node, "modulate:a", 1.0, 0.4)
		
	# Animer les boutons avec un effet d'échelle élastique
	if new_game_btn:
		var btn_tween1 = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		btn_tween1.tween_property(new_game_btn, "scale", Vector2.ONE, 0.6)
		
	if quit_btn:
		await get_tree().create_timer(0.08).timeout # petit délai décalé
		if is_instance_valid(quit_btn):
			var btn_tween2 = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			btn_tween2.tween_property(quit_btn, "scale", Vector2.ONE, 0.6)
		
	# Ajouter un petit effet de respiration (idle animation) sur le Logo
	_animate_logo_idle()

func _animate_logo_idle() -> void:
	if not is_instance_valid(logo_container): return
	
	# Faire pulser les tuiles de manière asynchrone
	var t2 = $VBoxContainer/LogoContainer/LogoGrid/Tile2
	var t3 = $VBoxContainer/LogoContainer/LogoGrid/Tile3
	
	if t2:
		t2.pivot_offset = t2.size / 2.0
		var tween_t2 = create_tween().set_loops().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween_t2.tween_property(t2, "scale", Vector2(1.15, 1.15), 1.0)
		tween_t2.tween_property(t2, "modulate", Color(1.3, 1.3, 1.3), 1.0)
		tween_t2.chain()
		tween_t2.tween_property(t2, "scale", Vector2.ONE, 1.0)
		tween_t2.tween_property(t2, "modulate", Color.WHITE, 1.0)
		
	if t3:
		t3.pivot_offset = t3.size / 2.0
		# Décalage de phase pour un effet de balayage alterné
		await get_tree().create_timer(0.5).timeout
		if is_instance_valid(t3):
			var tween_t3 = create_tween().set_loops().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
			tween_t3.tween_property(t3, "scale", Vector2(1.15, 1.15), 1.0)
			tween_t3.tween_property(t3, "modulate", Color(1.3, 1.3, 1.3), 1.0)
			tween_t3.chain()
			tween_t3.tween_property(t3, "scale", Vector2.ONE, 1.0)
			tween_t3.tween_property(t3, "modulate", Color.WHITE, 1.0)

func _on_new_game_pressed() -> void:
	new_game_pressed.emit()

func _on_quit_pressed() -> void:
	quit_pressed.emit()
	# Si on est sur une plateforme qui supporte la fermeture
	if OS.has_feature("pc"):
		get_tree().quit()
