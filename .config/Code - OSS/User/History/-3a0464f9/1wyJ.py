import subprocess
import re


class HyprlandService:
    # ===============================
    # CORE
    # ===============================
    def _get(self, key: str) -> str:
        try:
            return subprocess.check_output(
                ["hyprctl", "getoption", key],
                text=True
            )
        except Exception:
            return ""

    def _set(self, key: str, value: str):
        subprocess.call(["hyprctl", "keyword", key, value])

    # ===============================
    # COLOR (HYPR → HEX)
    # ===============================
    def get_color(self, key: str, default="#ffffffff") -> str:
        """
        Extract rgba(RRGGBBAA) from hyprctl output
        and return #RRGGBBAA for GTK.
        """
        out = self._get(key)
        match = re.search(r"rgba\(([0-9a-fA-F]{8})\)", out)
        return f"#{match.group(1)}" if match else default

    def set_color(self, key: str, hex_color: str):
        """
        Accept #RRGGBBAA and send rgba(RRGGBBAA) to Hyprland
        """
        self._set(key, f"rgba({hex_color.lstrip('#')})")

    # ===============================
    # BORDERS
    # ===============================
    def get_active_border(self):
        return self.get_color("general:col.active_border")

    def get_inactive_border(self):
        return self.get_color("general:col.inactive_border")

    def set_active_border(self, color):
        self.set_color("general:col.active_border", color)

    def set_inactive_border(self, color):
        self.set_color("general:col.inactive_border", color)

    # ===============================
    # OPACITY
    # ===============================
    def _get_float(self, key, default):
        out = self._get(key)
        m = re.search(r"float:\s*([0-9.]+)", out)
        return float(m.group(1)) if m else default

    def get_active_opacity(self):
        return self._get_float("decoration:active_opacity", 1.0)

    def get_inactive_opacity(self):
        return self._get_float("decoration:inactive_opacity", 1.0)

    def set_opacity(self, active, inactive):
        self._set("decoration:active_opacity", f"{active:.2f}")
        self._set("decoration:inactive_opacity", f"{inactive:.2f}")

    # ===============================
    # SHADOW
    # ===============================
    def get_shadow_enabled(self):
        return "int: 1" in self._get("decoration:shadow:enabled")

    def set_shadow_enabled(self, enabled):
        self._set(
            "decoration:shadow:enabled",
            "true" if enabled else "false"
        )

    def get_shadow_color(self):
        return self.get_color("decoration:shadow:color")

    def set_shadow_color(self, color):
        self.set_color("decoration:shadow:color", color)

    # ===============================
    # BLUR
    # ===============================
    def get_blur_enabled(self):
        return "int: 1" in self._get("decoration:blur:enabled")

    def set_blur_enabled(self, enabled):
        self._set(
            "decoration:blur:enabled",
            "true" if enabled else "false"
        )

    def get_vibrancy(self):
        return self._get_float("decoration:blur:vibrancy", 0.0)

    def set_vibrancy(self, value):
        self._set("decoration:blur:vibrancy", f"{value:.3f}")
