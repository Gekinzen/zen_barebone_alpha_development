import subprocess
import re


class HyprlandService:
    # ==================================================
    # INTERNAL HELPERS
    # ==================================================
    def _run(self, args):
        try:
            subprocess.run(args, check=False)
        except Exception:
            pass

    def _get(self, key: str) -> str:
        try:
            return subprocess.check_output(
                ["hyprctl", "getoption", key],
                text=True
            )
        except Exception:
            return ""

    # ==================================================
    # GENERIC WRITE
    # ==================================================
    def keyword(self, key: str, value):
        self._run(["hyprctl", "keyword", key, str(value)])

    # ==================================================
    # GENERIC READ
    # ==================================================
    def get_float(self, key: str, default=0.0) -> float:
        out = self._get(key)
        match = re.search(r"float:\s*([0-9.]+)", out)
        return float(match.group(1)) if match else default

    def get_int(self, key: str, default=0) -> int:
        out = self._get(key)
        match = re.search(r"int:\s*([0-9]+)", out)
        return int(match.group(1)) if match else default

    def get_bool(self, key: str, default=True) -> bool:
        out = self._get(key)
        match = re.search(r"int:\s*([01])", out)
        return bool(int(match.group(1))) if match else default

    def get_color(self, key: str, default="rgba(ffffffff)") -> str:
        out = self._get(key)
        match = re.search(r"rgba\([0-9a-fA-F]{8}\)", out)
        return match.group(0) if match else default

    # ==================================================
    # GENERAL
    # ==================================================
    def set_active_border(self, value: str):
        self.keyword("general:col.active_border", value)

    def set_inactive_border(self, value: str):
        self.keyword("general:col.inactive_border", value)

    def get_active_border(self) -> str:
        return self.get_color("general:col.active_border")

    def get_inactive_border(self) -> str:
        return self.get_color("general:col.inactive_border")

    # ==================================================
    # DECORATION
    # ==================================================
    def set_rounding(self, value: int):
        self.keyword("decoration:rounding", value)

    def get_rounding(self) -> int:
        return self.get_int("decoration:rounding", 14)

    def set_opacity(self, active: float, inactive: float):
        self.keyword("decoration:active_opacity", round(active, 2))
        self.keyword("decoration:inactive_opacity", round(inactive, 2))

    def get_active_opacity(self) -> float:
        return self.get_float("decoration:active_opacity", 1.0)

    def get_inactive_opacity(self) -> float:
        return self.get_float("decoration:inactive_opacity", 1.0)

    # ==================================================
    # SHADOW
    # ==================================================
    def set_shadow_enabled(self, enabled: bool):
        self.keyword(
            "decoration:shadow:enabled",
            "true" if enabled else "false"
        )

    def get_shadow_enabled(self) -> bool:
        return self.get_bool("decoration:shadow:enabled", True)

    def set_shadow_color(self, value: str):
        self.keyword("decoration:shadow:color", value)

    def get_shadow_color(self) -> str:
        return self.get_color("decoration:shadow:color")

    # ==================================================
    # BLUR
    # ==================================================
    def set_blur_enabled(self, enabled: bool):
        self.keyword(
            "decoration:blur:enabled",
            "true" if enabled else "false"
        )

    def get_blur_enabled(self) -> bool:
        return self.get_bool("decoration:blur:enabled", True)

    def set_vibrancy(self, value: float):
        self.keyword("decoration:blur:vibrancy", round(value, 3))

    def get_vibrancy(self) -> float:
        return self.get_float("decoration:blur:vibrancy", 0.17)
