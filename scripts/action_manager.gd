extends Node
@export var water_bar: ProgressBar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	style_draw_button()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func style_draw_button() -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color("#FFFFFF")
	normal.border_color = Color("#000000")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8

	var hover = normal.duplicate()
	hover.bg_color = Color("#EEEEEE")

	var pressed_style = normal.duplicate()
	pressed_style.bg_color = Color("#D6D6D6")

	draw_button.add_theme_stylebox_override("normal", normal)
	draw_button.add_theme_stylebox_override("hover", hover)
	draw_button.add_theme_stylebox_override("pressed", pressed_style)

	draw_button.add_theme_color_override("font_color", Color("#000000"))
	draw_button.add_theme_color_override("font_hover_color", Color("#000000"))
	draw_button.add_theme_color_override("font_pressed_color", Color("#000000"))
	draw_button.add_theme_color_override("font_focus_color", Color("#000000"))

	draw_button.add_theme_font_size_override("font_size", 16)
