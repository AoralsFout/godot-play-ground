## 集中提供界面配色、字体和控件样式。
## 主菜单、聊天、暂停菜单共享同一主题，中文字体使用系统字体回退。

class_name UIStyle
extends RefCounted

const INK := Color("183247")
const PANEL := Color("23445d")
const ACCENT := Color("f2c879")
const TEXT := Color("edf4fa")
const MUTED := Color("a8c2d3")


static func theme() -> Theme:
	var result := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "PingFang SC", "sans-serif"])
	result.default_font = font
	result.default_font_size = 18
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", TEXT)
	result.set_color("font_focus_color", "Button", ACCENT)
	result.set_color("font_disabled_color", "Button", MUTED.darkened(0.25))
	result.set_stylebox("normal", "Button", box(PANEL, 8, 14))
	result.set_stylebox("hover", "Button", box(Color("315b78"), 8, 14))
	result.set_stylebox("pressed", "Button", box(Color("102d43"), 8, 14))
	result.set_stylebox("disabled", "Button", box(INK.lightened(0.04), 8, 14))
	var focus := box(Color.TRANSPARENT, 8, 14)
	focus.set_border_width_all(2)
	focus.border_color = ACCENT
	result.set_stylebox("focus", "Button", focus)
	result.set_stylebox("normal", "LineEdit", box(Color("122b3e"), 6, 12))
	result.set_stylebox("focus", "LineEdit", focus)
	result.set_color("font_color", "LineEdit", TEXT)
	result.set_color("font_placeholder_color", "LineEdit", MUTED)
	result.set_color("caret_color", "LineEdit", ACCENT)
	result.set_stylebox("panel", "PanelContainer", box(INK, 12, 26))
	result.set_constant("separation", "VBoxContainer", 12)
	result.set_constant("separation", "HBoxContainer", 12)
	return result


static func box(color: Color, radius: int = 8, margin: int = 12) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_corner_radius_all(radius)
	result.content_margin_left = margin
	result.content_margin_right = margin
	result.content_margin_top = margin
	result.content_margin_bottom = margin
	return result


static func label(text: String, size: int = 18, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	return result


static func button(text: String, action: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size.y = 48
	result.pressed.connect(action)
	return result


static func fill(control: Control) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
