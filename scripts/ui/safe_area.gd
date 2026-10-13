class_name SafeArea
extends RefCounted
## The screen edges covered by the notch and the home indicator, in canvas units, so HUD controls
## can stay clear of them. Zero on screens without a safe area.


## Canvas units covered at the top (x) and bottom (y) of `viewport`.
static func insets(viewport: Viewport) -> Vector2:
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.y <= 0:
		return Vector2.ZERO
	var window_size := DisplayServer.window_get_size()
	var to_canvas := viewport.get_visible_rect().size.y / maxf(1.0, window_size.y)
	var top := maxf(0.0, float(safe.position.y))
	var bottom := maxf(0.0, float(window_size.y - safe.end.y))
	return Vector2(top, bottom) * to_canvas
