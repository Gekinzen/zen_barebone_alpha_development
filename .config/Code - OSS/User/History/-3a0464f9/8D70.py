import subprocess
import re


class HyprlandService:
    """
    Handles reading & writing Hyprland runtime values
    via `hyprctl getoption` and `hyprctl keyword`.
    """

    # ===============================
    # INTERNAL HELPERS
    # ===============================
    def _get(self, key: str) -> str:
        """
        Raw getter from hyprctl.
        """
        try:
            out = subprocess.check_output(
                ["hyprctl", "getoption", key],
                text=True
            )
            return out
        except Exception:
            return ""

    def _set(self, key: str, value: str):
        """
        Raw setter to hyprctl.
        """
        subprocess.call(
            ["hyprctl", "keyword", key, value]
        )

    # ===============================
    # COLOR HELPERS (SAFE)
    # ===============================
    def get_color(self, key: str, default="rgba(ffffffff)") -> str:
        """
        Safely extract first rgba(...) from hyprctl output.
        Handles gradients like: rgba(xxxxxxxx) 45deg
        """
        out = self._get(key)

        match = re.search(r"rgba\([0-9a-fA-F]{8}\)", out)
        if match:
            return match.group(0)

        return default

    def set_color(self, key: str, rgba: str):
        """
        Sets color exactly as rgba(xxxxxxxx)
        """
        self._set(key, rgba)

    # ===============================
    # OPACITY
    # ===============================
    def get_active_opacity(self) -> float:
        out = self._get("decoration:active_opacity")
        return self._extract_float(out, 1.0)

    def get_inactive_opacity(self) -> float:
        out = self._get("decoration:inactive_opacity")
        return self._extract_float(out, 1.0)

    def set_opacity(self, active: float, inactive: float):
        self._set("decoration:active_opacity", f"{active:.2f}")
        self._set("decoration:inactive_opacity", f"{inactive:.2f}")

    # ===============================
    # BORDER COLORS
    # ===============================
    def get_active_border(self) -> str:
        return self.get_color("general:col.active_border")

    def get_inactive_border(self) -> str:
        return self.get_color("general:col.inactive_border")

    def set_active_border(self, rgba: str):
        self.set_color("general:col.active_border", rgba)

    def set_inactive_border(self, rgba: str):
        self.set_color("general:col.inactive_border", rgba)

    # ===============================
    # SHADOW
    # ===============================
    def get_shadow_enabled(self) -> bool:
        out = self._get("decoration:shadow:enabled")
        return self._extract_bool(out, True)

    def set_shadow_enabled(self, enabled: bool):
        self._set("decoration:shadow:enabled", "true" if enabled else "false")

    def get_shadow_color(self) -> str:
        return self.get_color("decoration:shadow:color")

    def set_shadow_color(self, rgba: str):
        self.set_color("decoration:shadow:color", rgba)

    # ===============================
    # BLUR
    # ===============================
    def get_blur_enabled(self) -> bool:
        out = self._get("decoration:blur:enabled")
        return self._extract_bool(out, True)

    def set_blur_enabled(self, enabled: bool):
        self._set("decoration:blur:enabled", "true" if enabled else "false")

    def get_vibrancy(self) -> float:
        out = self._get("decoration:blur:vibrancy")
        return self._extract_float(out, 0.0)

    def set_vibrancy(self, value: float):
        self._set("decoration:blur:vibrancy", f"{value:.3f}")

    # ===============================
    # PARSERS
    # ===============================
    def _extract_float(self, text: str, default: float) -> float:
        match = re.search(r"float:\s*([0-9.]+)", text)
        if match:
            try:
                return float(match.group(1))
            except ValueError:
                pass
        return default

    def _extract_bool(self, text: str, default: bool) -> bool:
        match = re.search(r"int:\s*([01])", text)
        if match:
            return match.group(1) == "1"
        return default
