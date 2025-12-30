from pathlib import Path
import re

CONF_PATH = Path.home() / ".config/hypr/modules/look_and_feel.conf"


class LookAndFeelService:
    def read(self):
        text = CONF_PATH.read_text()

        def find(pattern, default):
            m = re.search(pattern, text, re.S)
            return m.group(1).strip() if m else default

        def first_rgba(value):
            m = re.search(r"rgba\([0-9a-fA-F]{8}\)", value)
            return m.group(0) if m else "rgba(ffffffff)"

        return {
            # ---------- GENERAL ----------
            "active_border": first_rgba(
                find(
                    r"general\s*{[^}]*col\.active_border\s*=\s*([^\n]+)",
                    "rgba(ffffffff)"
                )
            ),
            "inactive_border": first_rgba(
                find(
                    r"general\s*{[^}]*col\.inactive_border\s*=\s*([^\n]+)",
                    "rgba(ffffffff)"
                )
            ),

            # ---------- DECORATION ----------
            "active_opacity": float(
                find(r"active_opacity\s*=\s*([0-9.]+)", "1.0")
            ),
            "inactive_opacity": float(
                find(r"inactive_opacity\s*=\s*([0-9.]+)", "1.0")
            ),

            "shadow_enabled":
                find(r"shadow\s*{[^}]*enabled\s*=\s*(\w+)", "true") == "true",

            "shadow_color": first_rgba(
                find(
                    r"shadow\s*{[^}]*color\s*=\s*([^\n]+)",
                    "rgba(000000ff)"
                )
            ),
        }
