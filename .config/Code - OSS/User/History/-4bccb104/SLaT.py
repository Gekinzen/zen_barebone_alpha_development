from settings.utils.state import State
from settings.services.gtk import GtkService
from settings.services.hyprland import HyprlandService
from settings.services.waybar import WaybarService

ROUNDING_MAP = {
    "square": 0,
    "slight": 6,
    "medium": 12,
    "round": 18
}

class AppearanceController:
    def __init__(self):
        self.state = State("appearance.json")
        self.gtk = GtkService()
        self.hypr = HyprlandService()
        self.waybar = WaybarService()

    # ===== Theme =====
    def is_dark(self):
        return self.state.get("mode", "dark") == "dark"

    def set_dark(self, enabled: bool):
        self.state.set("mode", "dark" if enabled else "light")
        self.gtk.set_dark_mode(enabled)

    # ===== Fonts =====
    def set_font(self, font: str):
        self.state.set("font", font)
        self.gtk.set_font(font)

    def set_monospace_font(self, font: str):
        self.state.set("monospace_font", font)
        self.gtk.set_monospace_font(font)

    # ===== Window Style =====
    def set_rounding(self, level: str):
        self.state.set("rounding", level)
        self.hypr.set_rounding(ROUNDING_MAP[level])

    def set_opacity(self, active: float, inactive: float):
        self.state.set("active_opacity", active)
        self.state.set("inactive_opacity", inactive)
        self.hypr.set_opacity(active, inactive)
