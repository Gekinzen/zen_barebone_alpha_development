#!/usr/bin/env python3

import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Adw", "1")

from gi.repository import Adw, Gtk
from settings.window import ZenSettingsWindow

class ZenSettingsApp(Adw.Application):
    def __init__(self):
        super().__init__(
            application_id="zen.settings",
            flags=Adw.ApplicationFlags.FLAGS_NONE
        )

    def do_activate(self):
        win = ZenSettingsWindow(self)
        win.present()

if __name__ == "__main__":
    app = ZenSettingsApp()
    app.run()
