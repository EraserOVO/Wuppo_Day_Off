extends CanvasLayer

signal confirmed
signal dismissed

var is_open := false
var heading: Label
var message: Label
var confirm_button: Button
var panel: PanelContainer
var center: CenterContainer

func _ready() -> void:
	layer = 100
	var screen := Control.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.10, 0.15, 0.16, 0.64)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(shade)
	center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 280)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("fff8e9")
	card_style.set_corner_radius_all(22)
	card_style.set_border_width_all(3)
	card_style.border_color = Color("b78a4d")
	card_style.shadow_color = Color(0.17, 0.11, 0.07, 0.34)
	card_style.shadow_size = 20
	card_style.content_margin_left = 30
	card_style.content_margin_right = 30
	card_style.content_margin_top = 26
	card_style.content_margin_bottom = 28
	panel.add_theme_stylebox_override("panel", card_style)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 20)
	panel.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	heading = Label.new()
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color("36534a"))
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.text = GameSettings.text("退出对局")
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(heading)
	var close := Button.new()
	close.text = "×"
	close.tooltip_text = GameSettings.text("关闭窗口")
	close.custom_minimum_size = Vector2(44, 44)
	close.add_theme_font_size_override("font_size", 28)
	_style_button(close, Color("eee2ca"), Color("e4d1ad"), Color("d7c198"), Color("57483c"))
	close.pressed.connect(close_dialog)
	header.add_child(close)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.size_flags_vertical = Control.SIZE_EXPAND_FILL
	message.add_theme_font_size_override("font_size", 21)
	message.add_theme_color_override("font_color", Color("5f6254"))
	column.add_child(message)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 14)
	column.add_child(buttons)
	var cancel := Button.new()
	cancel.text = GameSettings.text("继续游戏")
	cancel.custom_minimum_size = Vector2(168, 54)
	cancel.add_theme_font_size_override("font_size", 20)
	_style_button(cancel, Color("e9deca"), Color("ddd0b9"), Color("cfc0a5"), Color("514a3d"))
	cancel.pressed.connect(close_dialog)
	buttons.add_child(cancel)
	confirm_button = Button.new()
	confirm_button.text = GameSettings.text("确认退出")
	confirm_button.custom_minimum_size = Vector2(168, 54)
	confirm_button.add_theme_font_size_override("font_size", 20)
	_style_button(confirm_button, Color("527866"), Color("416955"), Color("345744"), Color("ffffff"))
	confirm_button.pressed.connect(func():
		is_open = false
		visible = false
		confirmed.emit()
	)
	buttons.add_child(confirm_button)
	visible = false
	get_viewport().size_changed.connect(_resize)
	_resize()

func show_dialog(title: String, detail: String, action := "确认退出") -> void:
	heading.text = GameSettings.text(title)
	message.text = GameSettings.text(detail)
	confirm_button.text = GameSettings.text(action)
	is_open = true
	visible = true

func close_dialog() -> void:
	if not is_open: return
	is_open = false
	visible = false
	dismissed.emit()

func _resize() -> void:
	if not is_instance_valid(panel): return
	var view := get_viewport().get_visible_rect().size
	panel.custom_minimum_size = Vector2(clampf(view.x * 0.40, 460.0, 560.0), clampf(view.y * 0.28, 250.0, 280.0))

func _style_button(button: Button, normal: Color, hover: Color, pressed: Color, text_color: Color) -> void:
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
	for variant in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = normal if variant == "normal" else pressed if variant == "pressed" else hover
		style.set_corner_radius_all(14)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 10
		style.content_margin_bottom = 10
		button.add_theme_stylebox_override(variant, style)

func _input(event: InputEvent) -> void:
	if is_open and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		close_dialog()
		get_viewport().set_input_as_handled()
