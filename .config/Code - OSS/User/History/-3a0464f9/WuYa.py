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
    # COLOR PARSING (FIXED)
    # ===============================
    def get_color(self, key: str, default="#ffffff") -> str:
        """
        Returns GTK-compatible #RRGGBBAA
        """
        out = self._get(key)

        # Extract FIRST rgba(xxxxxxxx)
        match = re.search(r"rgba\(([0-9a-fA-F]{8})\)", out)
        if not match:
            return default

        hex8 = match.group(1)
        return f"#{hex8}"

    def set_color(self, key: str, hex_color: str):
        """
        Accepts #RRGGBBAA and converts to hypr format
        """
        hex_color = hex_color.lstrip("#")
        self._set(key, f"rgba({hex_color})")

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
        out = self._get("decoration:shadow:enabled")
        return "int: 1" in out

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
        out = self._get("decoration:blur:enabled")
        return "int: 1" in out

    def set_blur_enabled(self, enabled):
        self._set(
            "decoration:blur:enabled",
            "true" if enabled else "false"
        )

    def get_vibrancy(self):
        return self._get_float("decoration:blur:vibrancy", 0.0)

    def set_vibrancy(self, value):
        self._set("decoration:blur:vibrancy", f"{value:.3f}")
