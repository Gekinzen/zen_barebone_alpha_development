from settings.services.hyprland import HyprlandService
from settings.utils.colors import rgba_to_hex
from settings.utils.dialogs import confirm


class AppearanceController:
    def __init__(self):
        self.hypr = HyprlandService()

    def get_current_state(self):
        return {
            "active_opacity": self.hypr.get_active_opacity(),
            "inactive_opacity": self.hypr.get_inactive_opacity(),
            "shadow_enabled": self.hypr.get_shadow_enabled(),
            "blur_enabled": self.hypr.get_blur_enabled(),
            "vibrancy": self.hypr.get_vibrancy(),
            "active_border": self.hypr.get_active_border(),
            "inactive_border": self.hypr.get_inactive_border(),
            "shadow_color": self.hypr.get_shadow_color(),
        }

    def set_opacity(self, parent, active, inactive):
        if active < 0.3 or inactive < 0.3:
            if not confirm(
                parent,
                "Low Opacity Warning",
                "Very low opacity may make windows hard to see.\n\nContinue?"
            ):
                return
        self.hypr.set_opacity(active, inactive)

    def set_active_border(self, rgba):
        self.hypr.set_active_border(rgba_to_hex(rgba))

    def set_inactive_border(self, rgba):
        self.hypr.set_inactive_border(rgba_to_hex(rgba))

    def set_shadow_color(self, rgba):
        self.hypr.set_shadow_color(rgba_to_hex(rgba))

    def set_shadow_enabled(self, enabled):
        self.hypr.set_shadow_enabled(enabled)

    def set_blur_enabled(self, enabled):
        self.hypr.set_blur_enabled(enabled)

    def set_vibrancy(self, value):
        self.hypr.set_vibrancy(value)
