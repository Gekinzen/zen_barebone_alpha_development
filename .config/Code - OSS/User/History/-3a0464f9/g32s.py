import subprocess


class HyprlandService:
    def keyword(self, key: str, value):
        subprocess.run(
            ["hyprctl", "keyword", key, str(value)],
            check=False
        )

    # ===== GENERAL =====
    def set_active_border(self, value: str):
        self.keyword("general:col.active_border", value)

    def set_inactive_border(self, value: str):
        self.keyword("general:col.inactive_border", value)

    # ===== DECORATION =====
    def set_opacity(self, active: float, inactive: float):
        self.keyword("decoration:active_opacity", round(active, 2))
        self.keyword("decoration:inactive_opacity", round(inactive, 2))

    def set_shadow_color(self, value: str):
        self.keyword("decoration:shadow:color", value)

    def set_shadow_enabled(self, enabled: bool):
        self.keyword(
            "decoration:shadow:enabled",
            "true" if enabled else "false"
        )

    # ===== BLUR =====
    def set_blur_enabled(self, enabled: bool):
        self.keyword(
            "decoration:blur:enabled",
            "true" if enabled else "false"
        )

    def set_vibrancy(self, value: float):
        self.keyword("decoration:blur:vibrancy", round(value, 3))
