from gi.repository import Gtk
from settings.controllers.appearance import AppearanceController
class AppearanceView(Gtk.Box):
    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=18)
        self.set_margin_top(24)
        self.set_margin_start(24)
        self.set_margin_end(24)

        self.ctrl = AppearanceController()

        # ===== THEME =====
        self._section("Theme")
        dark = Gtk.Switch(active=self.ctrl.is_dark())
        dark.connect("notify::active", lambda s, _: self.ctrl.set_dark(s.get_active()))
        self._row("Dark Mode", dark)

        # ===== FONTS =====
        self._section("Fonts")
        font = Gtk.FontButton()
        font.connect("font-set", lambda b: self.ctrl.set_font(b.get_font()))
        self._row("System Font", font)

        mono = Gtk.FontButton()
        mono.connect("font-set", lambda b: self.ctrl.set_monospace_font(b.get_font()))
        self._row("Monospace Font", mono)

        # ===== WINDOW STYLE =====
        self._section("Window Style")

        rounding = Gtk.DropDown.new_from_strings(
            ["square", "slight", "medium", "round"]
        )
        rounding.connect(
            "notify::selected",
            lambda d, _: self.ctrl.set_rounding(
                d.get_model().get_string(d.get_selected())
            )
        )
        self._row("Corner Rounding", rounding)

        active = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0.5, 1.0, 0.05)
        inactive = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0.5, 1.0, 0.05)

        active.set_value(1.0)
        inactive.set_value(0.9)

        active.connect("value-changed", lambda s: self.ctrl.set_opacity(s.get_value(), inactive.get_value()))
        inactive.connect("value-changed", lambda s: self.ctrl.set_opacity(active.get_value(), s.get_value()))

        self._row("Active Window Opacity", active)
        self._row("Inactive Window Opacity", inactive)

    # ===== Helpers =====
    def _section(self, title):
        label = Gtk.Label(label=title, xalign=0)
        label.add_css_class("section-title")
        self.append(label)

    def _row(self, title, widget):
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        label = Gtk.Label(label=title, xalign=0)
        label.set_hexpand(True)
        row.append(label)
        row.append(widget)
        self.append(row)
