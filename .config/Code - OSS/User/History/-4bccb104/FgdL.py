from settings.services.hyprland import HyprlandService
from settings.utils.colors import rgba_to_hypr
from settings.utils.dialogs import confirm


class AppearanceController:
    def __init__(self):
        self.hypr = HyprlandService()

    # ===== OPACITY (SAFE) =====
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

    # ===== BORDER COLORS =====
    def set_active_border(self, rgba):
        self.hypr.set_active_border(rgba_to_hypr(rgba))

    def set_inactive_border(self, rgba):
        self.hypr.set_inactive_border(rgba_to_hypr(rgba))

    # ===== SHADOW =====
    def set_shadow_color(self, rgba):
        self.hypr.set_shadow_color(rgba_to_hypr(rgba))

    def set_shadow_enabled(self, enabled: bool):
        self.hypr.set_shadow_enabled(enabled)

    # ===== BLUR =====
    def set_blur_enabled(self, enabled: bool):
        self.hypr.set_blur_enabled(enabled)

    def set_vibrancy(self, value: float):
        self.hypr.set_vibrancy(value)
