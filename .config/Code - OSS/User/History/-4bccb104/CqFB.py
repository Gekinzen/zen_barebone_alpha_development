from settings.services.hyprland import HyprlandService
from settings.utils.colors import rgba_to_hex
from settings.utils.dialogs import confirm


class AppearanceController:
    def __init__(self):
        self.hypr = HyprlandService()

    # ===============================
    # READ CURRENT STATE
    # ===============================
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

    # ===============================
    # OPACITY
    # ===============================
    def set_opacity(self, parent, active: float, inactive: float):
        if active < 0.3 or inactive < 0.3:
            ok = confirm(
                parent,
                "Low Opacity Warning",
                "Very low opacity may make windows hard to see.\n\nContinue?"
            )
            if not ok:
                return

        self.hypr.set_opacity(active, inactive)

    # ===============================
    # COLORS
    # ===============================
    def set_active_border(self, rgba):
        self.hypr.set_active_border(rgba_to_hex(rgba))

    def set_inactive_border(self, rgba):
        self.hypr.set_inactive_border(rgba_to_hex(rgba))

    def set_shadow_color(self, rgba):
        self.hypr.set_shadow_color(rgba_to_hex(rgba))

    # ===============================
    # TOGGLES
    # ===============================
    def set_shadow_enabled(self, enabled: bool):
        self.hypr.set_shadow_enabled(enabled)

    def set_blur_enabled(self, enabled: bool):
        self.hypr.set_blur_enabled(enabled)

    # ===============================
    # BLUR
    # ===============================
    def set_vibrancy(self, value: float):
        self.hypr.set_vibrancy(value)
