import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")
gi.require_version("Gdk", "4.0")

from gi.repository import Gtk, Adw, Gdk
from pathlib import Path

from settings.window import ZenSettingsWindow


class ZenSettingsApp(Adw.Application):
    def __init__(self):
        super().__init__(application_id="zen.settings")

    def do_activate(self):
        # =========================
        # LOAD ZEN CSS (GTK4 SAFE)
        # =========================
        css_path = Path(__file__).parent / "style.css"

        css_provider = Gtk.CssProvider()
        css_provider.load_from_path(str(css_path))

        display = Gdk.Display.get_default()
        Gtk.StyleContext.add_provider_for_display(
            display,
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        # =========================
        # CREATE WINDOW
        # =========================
        win = ZenSettingsWindow(self)
        win.present()


def main():
    app = ZenSettingsApp()
    app.run()


if __name__ == "__main__":
    main()
