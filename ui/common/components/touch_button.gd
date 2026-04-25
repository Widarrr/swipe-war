# res://ui/common/components/touch_button.gd
class_name TouchButton
extends Button

@export var press_scale: Vector2 = Vector2(0.92, 0.92)
@export var transition_duration: float = 0.08

var _original_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	# Configurer le pivot au centre pour que le scale s'applique correctement
	_original_scale = scale
	pivot_offset = size / 2.0
	
	# Connecter les signaux tactiles natifs
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	
	# Réinitialiser la taille pour recalculer le pivot si le bouton change de dimension
	resized.connect(func() -> void: pivot_offset = size / 2.0)

func _on_button_down() -> void:
	# Micro-animation d'écrasement (squeeze)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", press_scale, transition_duration)

func _on_button_up() -> void:
	# Effet de ressort (spring) de retour à la taille normale
	var tween: Tween = create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", _original_scale, transition_duration * 2.0)
