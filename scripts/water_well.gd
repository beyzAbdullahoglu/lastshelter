
extends TextureButton

@export var water_bar: ProgressBar

# Kuyu suyu
var well_water: int = 100
const MAX_WELL_WATER: int = 100
const WATER_PER_DRAW: int = 5

var popup_tail: Node2D

@onready var draw_popup: PanelContainer = $"../../../DrawWaterPopup"
@onready var draw_button: Button = $"../../../DrawWaterPopup/DrawWaterButton"


func _ready() -> void:
	draw_popup.hide()

	draw_button.pressed.connect(_on_draw_water_pressed)
	pressed.connect(_on_well_pressed)

	style_draw_button()
	style_draw_popup()

	# Kuyruk düğümünü popup ile aynı üst düğümün altına ekle
	popup_tail = PopupTail.new()
	draw_popup.add_child(popup_tail)
	popup_tail.position = Vector2(
		(draw_popup.size.x - 70) / 2,
		draw_popup.size.y - 2
	)
	popup_tail.z_index = 1
	popup_tail.hide()

	update_well_tooltip()


# Popup panelinin görünümü
func style_draw_popup() -> void:
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color.WHITE
	panel_style.border_color = Color.BLACK
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(18)

	draw_popup.add_theme_stylebox_override("panel", panel_style)


# Draw Water butonunun görünümü
func style_draw_button() -> void:
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color.WHITE
	normal.border_color = Color.BLACK
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

	draw_button.add_theme_color_override("font_color", Color.BLACK)
	draw_button.add_theme_color_override("font_hover_color", Color.BLACK)
	draw_button.add_theme_color_override("font_pressed_color", Color.BLACK)
	draw_button.add_theme_font_size_override("font_size", 16)


# Kuyuya tıklanınca popup açılır
func _on_well_pressed() -> void:
	if well_water <= 0:
		return

	var mouse_position = get_global_transform_with_canvas().origin
	draw_popup.global_position = mouse_position + Vector2(20, -70)
	draw_popup.show()

	popup_tail.position = Vector2(
		(draw_popup.size.x - 70) / 2,
		draw_popup.size.y - 2
	)
	popup_tail.show()
	popup_tail.queue_redraw()


# Popup ve kuyruğu beraber kapat
func close_popup() -> void:
	draw_popup.hide()
	popup_tail.hide()


# Su çekme butonu
func _on_draw_water_pressed() -> void:
	if well_water <= 0:
		close_popup()
		return

	if water_bar == null:
		print("HATA: WaterBar baglanmamis!")
		close_popup()
		return

	if water_bar.value >= water_bar.max_value:
		close_popup()
		return

	var available_space = water_bar.max_value - water_bar.value
	var amount = min(WATER_PER_DRAW, well_water, available_space)

	well_water -= amount
	water_bar.value -= amount

	update_well_tooltip()

	print("Kuyuda kalan su: ", well_water)
	print("Su deposundaki su: ", water_bar.value)

	close_popup()


# Kuyu suyu bilgisi
func update_well_tooltip() -> void:
	tooltip_text = "Well Water: %d / %d" % [
		well_water,
		MAX_WELL_WATER
	]


# Aşağı bakan beyaz konuşma balonu kuyruğu
class PopupTail extends Node2D:

	func _draw() -> void:
		# Beyaz üçgenin panelin arkasına giren üst kısmı
		var points = PackedVector2Array([
			Vector2(0, -3),
			Vector2(70, -3),
			Vector2(35, 40)
		])

		draw_colored_polygon(points, Color.WHITE)

		# Sadece üçgenin iki yan kenarını ve ucunu çiz
		draw_polyline(
			PackedVector2Array([
				Vector2(0, -3),
				Vector2(35, 40),
				Vector2(70, -3)
			]),
			Color.BLACK,
			3.0,
			true
		)
