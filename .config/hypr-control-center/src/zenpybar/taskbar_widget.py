import gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk

class TaskbarWidget(Gtk.Box):
    def __init__(self, app):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)

        self.app = app
        self.add_css_class("panel-container")

        self.append(Gtk.Label(label="󰆍 Taskbar OK (pure widget)"))
