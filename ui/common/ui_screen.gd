# res://ui/common/ui_screen.gd
class_name UIScreen
extends Control

## Émis lorsque l'écran a terminé sa transition d'ouverture.
signal opened
## Émis lorsque l'écran a terminé sa transition de fermeture.
signal closed

@export var is_modal: bool = false

func _ready() -> void:
	# Par défaut, on masque l'écran au lancement pour éviter les superpositions accidentelles.
	hide()

## Affiche l'écran de manière fluide avec un effet de fondu et de zoom (Juice tactile).
func open_screen() -> void:
	show()
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# Initialisation de l'animation
	modulate.a = 0.0
	scale = Vector2(0.95, 0.95)
	
	# Centrage du pivot pour que l'effet de zoom se fasse depuis le centre de l'écran
	pivot_offset = size / 2.0
	
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.25)
	tween.tween_property(self, "scale", Vector2.ONE, 0.25)
	
	await tween.finished
	opened.emit()

## Masque l'écran de manière fluide avec une transition de fondu et de rétrécissement.
func close_screen() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Centrage du pivot
	pivot_offset = size / 2.0
	
	var tween: Tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate:a", 0.0, 0.20)
	tween.tween_property(self, "scale", Vector2(0.95, 0.95), 0.20)
	
	await tween.finished
	hide()
	closed.emit()
