from pathlib import Path
import re

CONF_PATH = Path.home() / ".config/hypr/modules/look_and_feel.conf"


class LookAndFeelService:
    def read(self):
        text = CONF_PATH.read_text()

        def find(pattern, default):
            m = re.search(pattern, text)
            return m.group(1) if m else default

        return {
            "active_opacity": float(find(r"active_opacity\s*=\s*([0-9.]+)", "1.0")),
            "inactive_opacity": float(find(r"inactive_opacity\s*=\s*([0-9.]+)", "1.0")),
            "shadow_color": find(r"color\s*=\s*(rgba\([^)]+\))", "rgba(000000ff)"),
            "shadow_enabled": find(r"shadow\s*{[^}]*enabled\s*=\s*(\w+)", "true") == "true",
            "active_border": find(r"col.active_border\s*=\s*(rgba\([^)]+\))", "rgba(ffffffff)"),
            "inactive_border": find(r"col.inactive_border\s*=\s*(rgba\([^)]+\))", "rgba(ffffffff)"),
        }
