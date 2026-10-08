class_name InteractionPrompt
extends CanvasLayer
## Texto "[E] Hablar con ..." centrado abajo. Se crea por código desde el Interactor.

var _label: Label


func _init() -> void:
	layer = 5
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.anchor_left = 0.0
	_label.anchor_right = 1.0
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = 0.0
	_label.offset_right = 0.0
	_label.offset_top = -120.0
	_label.offset_bottom = -80.0
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	_label.visible = false
	add_child(_label)


func show_prompt(text: String) -> void:
	_label.text = "[E] " + text
	_label.visible = true


func hide_prompt() -> void:
	_label.visible = false


func is_showing() -> bool:
	return _label.visible


func get_text() -> String:
	return _label.text
