from gi.repository import Gtk, Adw
from settings.controllers.appearance import AppearanceController
from settings.utils.colors import hex_to_rgba


class AppearanceView(Adw.PreferencesPage):
    def __init__(self):
        super().__init__(title="Appearance")

        self.ctrl = AppearanceController()
        state = self.ctrl.get_current_state()

        # ===============================
        # GENERAL
        # ===============================
        general = Adw.PreferencesGroup(title="General")

        active_btn = Gtk.ColorButton()
        active_btn.set_rgba(hex_to_rgba(state["active_border"]))
        active_btn.connect(
            "color-set",
            lambda b: self.ctrl.set_active_border(b.get_rgba())
        )

        row = Adw.ActionRow(title="Active Border Color")
        row.add_suffix(active_btn)
        row.set_activatable_widget(active_btn)
        general.add(row)

        inactive_btn = Gtk.ColorButton()
        inactive_btn.set_rgba(hex_to_rgba(state["inactive_border"]))
        inactive_btn.connect(
            "color-set",
            lambda b: self.ctrl.set_inactive_border(b.get_rgba())
        )

        row = Adw.ActionRow(title="Inactive Border Color")
        row.add_suffix(inactive_btn)
        row.set_activatable_widget(inactive_btn)
        general.add(row)

        self.add(general)

        # ===============================
        # WINDOW DECORATION
        # ===============================
        deco = Adw.PreferencesGroup(title="Window Decoration")

        active = Gtk.Scale.new_with_range(
            Gtk.Orientation.HORIZONTAL, 0.0, 1.0, 0.01
        )
        inactive = Gtk.Scale.new_with_range(
            Gtk.Orientation.HORIZONTAL, 0.0, 1.0, 0.01
        )

        # 🔥 IMPORTANT: make sliders long
        active.set_hexpand(True)
        inactive.set_hexpand(True)

        active.set_value(state["active_opacity"])
        inactive.set_value(state["inactive_opacity"])

        def apply_opacity():
            self.ctrl.set_opacity(
                self.get_root(),
                active.get_value(),
                inactive.get_value()
            )

        active.connect("value-changed", lambda *_: apply_opacity())
        inactive.connect("value-changed", lambda *_: apply_opacity())

        row = Adw.ActionRow(title="Active Opacity")
        row.add_suffix(active)
        row.set_activatable_widget(active)
        deco.add(row)

        row = Adw.ActionRow(title="Inactive Opacity")
        row.add_suffix(inactive)
        row.set_activatable_widget(inactive)
        deco.add(row)

        shadow_switch = Gtk.Switch(active=state["shadow_enabled"])
        shadow_switch.connect(
            "notify::active",
            lambda s, *_: self.ctrl.set_shadow_enabled(s.get_active())
        )

        row = Adw.ActionRow(title="Window Shadow")
        row.add_suffix(shadow_switch)
        row.set_activatable_widget(shadow_switch)
        deco.add(row)

        shadow_btn = Gtk.ColorButton()
        shadow_btn.set_rgba(hex_to_rgba(state["shadow_color"]))
        shadow_btn.connect(
            "color-set",
            lambda b: self.ctrl.set_shadow_color(b.get_rgba())
        )

        row = Adw.ActionRow(title="Shadow Color")
        row.add_suffix(shadow_btn)
        row.set_activatable_widget(shadow_btn)
        deco.add(row)

        self.add(deco)
