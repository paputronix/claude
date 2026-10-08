extends CanvasLayer
## Móvil del personaje: toast de aviso (cola), sonido generado por código y
## panel con la lista de mensajes (acción `phone`, Tab). La UI se construye aquí.

signal notified(title: String, body: String)

const TOAST_IN := 0.3
const TOAST_OUT := 0.3
const TOAST_WIDTH := 320.0
const PANEL_SIZE := Vector2(320, 560)
const COLOR_TITLE := Color(1.0, 0.82, 0.4)

## Historial: [{title, body, time: "HH:MM"}], más reciente al final.
var messages: Array[Dictionary] = []
## Segundos que el toast permanece visible.
var toast_duration := 4.0

var _unread := 0
var _queue: Array[Dictionary] = []
var _showing := false
var _toast_tween: Tween

var _root: Control
var _toast: PanelContainer
var _toast_title: Label
var _toast_body: Label
var _panel: PanelContainer
var _time_label: Label
var _money_label: Label
var _list: VBoxContainer
var _badge: Label
var _player: AudioStreamPlayer


func _ready() -> void:
	_build_ui()
	_player = AudioStreamPlayer.new()
	_player.stream = _make_ding()
	_player.volume_db = -8.0
	add_child(_player)
	GameClock.minute_changed.connect(func(_m: int) -> void: _update_time())
	Wallet.money_changed.connect(func(_v: int, _d: int, _r: String) -> void: _update_money())
	_update_time()
	_update_money()
	_refresh_badge()


func notify(title: String, body: String) -> void:
	messages.append({"title": title, "body": body, "time": GameClock.format_time()})
	if is_open():
		_rebuild_list()
	else:
		_unread += 1
		_refresh_badge()
	_queue.append({"title": title, "body": body})
	if not _showing:
		_show_next_toast()
	notified.emit(title, body)


func open() -> void:
	_panel.visible = true
	_unread = 0
	_refresh_badge()
	_update_time()
	_rebuild_list()


func close() -> void:
	_panel.visible = false


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func is_open() -> bool:
	return _panel != null and _panel.visible


func unread_count() -> int:
	return _unread


## Avisos esperando turno (sin contar el que se está mostrando).
func pending_toasts() -> int:
	return _queue.size()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("phone") and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()


func _show_next_toast() -> void:
	if _queue.is_empty():
		_showing = false
		return
	_showing = true
	var data: Dictionary = _queue.pop_front()
	_toast_title.text = data["title"]
	_toast_body.text = data["body"]
	_toast.modulate.a = 0.0
	_toast.visible = true
	_player.play()
	var width := _root.size.x if _root.size.x > 0.0 else 1280.0
	var shown_x := width - TOAST_WIDTH - 20.0
	_toast.position.x = width
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast, "position:x", shown_x, TOAST_IN).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, TOAST_IN)
	_toast_tween.chain().tween_interval(toast_duration)
	_toast_tween.chain().tween_property(_toast, "modulate:a", 0.0, TOAST_OUT)
	_toast_tween.parallel().tween_property(_toast, "position:x", width, TOAST_OUT)
	_toast_tween.chain().tween_callback(_on_toast_done)


func _on_toast_done() -> void:
	_toast.visible = false
	_show_next_toast()


func _update_time() -> void:
	if _time_label:
		_time_label.text = GameClock.format_time()


func _update_money() -> void:
	if _money_label:
		_money_label.text = "%d €" % Wallet.money


func _refresh_badge() -> void:
	if _badge:
		_badge.visible = _unread > 0 and not is_open()
		_badge.text = " %d " % _unread


func _rebuild_list() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if messages.is_empty():
		var empty := Label.new()
		empty.text = "Sin mensajes"
		empty.modulate = Color(1, 1, 1, 0.5)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list.add_child(empty)
		return
	for i in range(messages.size() - 1, -1, -1):
		_list.add_child(_make_entry(messages[i]))


func _make_entry(msg: Dictionary) -> Control:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.17, 0.18, 0.24)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(8)
	box.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(col)
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	var title := Label.new()
	title.name = "Title"
	title.text = msg["title"]
	title.add_theme_color_override("font_color", COLOR_TITLE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(title)
	var time := Label.new()
	time.text = msg["time"]
	time.modulate = Color(1, 1, 1, 0.55)
	time.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(time)
	var body := Label.new()
	body.name = "Body"
	body.text = msg["body"]
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(body)
	return box


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# Toast (esquina inferior derecha; la X la anima el Tween)
	_toast = PanelContainer.new()
	_toast.name = "Toast"
	_toast.visible = false
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.custom_minimum_size = Vector2(TOAST_WIDTH, 0)
	_toast.anchor_top = 1.0
	_toast.anchor_bottom = 1.0
	_toast.offset_top = -110.0
	_toast.offset_bottom = -20.0
	_toast.offset_right = TOAST_WIDTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.16, 0.95)
	style.border_color = COLOR_TITLE
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	_toast.add_theme_stylebox_override("panel", style)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_child(col)
	_toast_title = Label.new()
	_toast_title.add_theme_color_override("font_color", COLOR_TITLE)
	_toast_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_toast_title)
	_toast_body = Label.new()
	_toast_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_toast_body)
	_root.add_child(_toast)

	# Panel del móvil (derecha)
	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.5
	_panel.anchor_bottom = 0.5
	_panel.offset_left = -PANEL_SIZE.x - 24.0
	_panel.offset_right = -24.0
	_panel.offset_top = -PANEL_SIZE.y / 2.0
	_panel.offset_bottom = PANEL_SIZE.y / 2.0
	var pstyle := StyleBoxFlat.new()
	pstyle.bg_color = Color(0.06, 0.07, 0.1, 0.96)
	pstyle.border_color = Color(0.3, 0.32, 0.4)
	pstyle.set_border_width_all(4)
	pstyle.set_corner_radius_all(28)
	pstyle.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", pstyle)
	_root.add_child(_panel)
	var pcol := VBoxContainer.new()
	pcol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(pcol)
	var bar := HBoxContainer.new()
	bar.name = "StatusBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pcol.add_child(bar)
	_time_label = Label.new()
	_time_label.name = "TimeLabel"
	_time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_time_label)
	_money_label = Label.new()
	_money_label.name = "MoneyLabel"
	_money_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	_money_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(_money_label)
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pcol.add_child(sep)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pcol.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(_list)

	# Badge de no leídos (visible con el móvil cerrado)
	_badge = Label.new()
	_badge.name = "Badge"
	_badge.visible = false
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.anchor_left = 1.0
	_badge.anchor_right = 1.0
	_badge.offset_left = -64.0
	_badge.offset_right = -16.0
	_badge.offset_top = 56.0
	_badge.offset_bottom = 84.0
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = Color(0.85, 0.2, 0.25)
	bstyle.set_corner_radius_all(14)
	_badge.add_theme_stylebox_override("normal", bstyle)
	_root.add_child(_badge)


## Ding corto de dos tonos, 16 bits mono, generado en memoria.
func _make_ding() -> AudioStreamWAV:
	var rate := 22050
	var count := int(rate * 0.35)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / rate
		var freq := 880.0 if t < 0.12 else 1320.0
		var env := exp(-t * 9.0) * minf(1.0, t * 400.0)
		data.encode_s16(i * 2, int(sin(TAU * freq * t) * env * 0.6 * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav
