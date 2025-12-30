from gi.repository import Gtk, Adw
from settings.services.look_and_feel import LookAndFeelService
from settings.utils.colors import hex_to_rgba


class AppearanceView(Adw.PreferencesPage):
    def __init__(self):
        super().__init__(title="Appearance")

        self.service = LookAndFeelService()
        state = self.service.read()

        # ===============================
        # GENERAL
        # ===============================
        general = Adw.PreferencesGroup(title="General")

        # ---- Active Border ----
        active_color = self._hypr_rgba_to_hex(state["active_border"])
        active_btn = Gtk.ColorButton()
        active_btn.set_rgba(hex_to_rgba(active_color))
        active_btn.set_tooltip_text(active_color)

        row = Adw.ActionRow(title="Active Border Color", subtitle=active_color)
        row.add_suffix(active_btn)
        general.add(row)

        # ---- Inactive Border ----
        inactive_color = self._hypr_rgba_to_hex(state["inactive_border"])
        inactive_btn = Gtk.ColorButton()
        inactive_btn.set_rgba(hex_to_rgba(inactive_color))
        inactive_btn.set_tooltip_text(inactive_color)

        row = Adw.ActionRow(title="Inactive Border Color", subtitle=inactive_color)
        row.add_suffix(inactive_btn)
        general.add(row)

        self.add(general)

        # ===============================
        # WINDOW DECORATION
        # ===============================
        deco = Adw.PreferencesGroup(title="Window Decoration")

        # ---- Active Opacity ----
        self._add_slider(
            deco,
            "Active Opacity",
            state["active_opacity"]
        )

        # ---- Inactive Opacity ----
        self._add_slider(
            deco,
            "Inactive Opacity",
            state["inactive_opacity"]
        )

        # ---- Shadow ----
        shadow_row = Adw.ActionRow(
            title="Window Shadow",
            subtitle="Enabled" if state["shadow_enabled"] else "Disabled"
        )
        shadow_switch = Gtk.Switch(active=state["shadow_enabled"])
        shadow_row.add_suffix(shadow_switch)
        deco.add(shadow_row)

        # ---- Shadow Color ----
        shadow_hex = self._hypr_rgba_to_hex(state["shadow_color"])
        shadow_btn = Gtk.ColorButton()
        shadow_btn.set_rgba(hex_to_rgba(shadow_hex))
        shadow_btn.set_tooltip_text(shadow_hex)

        row = Adw.ActionRow(title="Shadow Color", subtitle=shadow_hex)
        row.add_suffix(shadow_btn)
        deco.add(row)

        self.add(deco)

    # ===============================
    # HELPERS
    # ===============================
    def _hypr_rgba_to_hex(self, value: str) -> str:
        return "#" + value.replace("rgba(", "").replace(")", "")

    def _add_slider(self, group, title, value):
        label = Gtk.Label(label=f"{value:.2f}")
        label.add_css_class("dim-label")

        slider = Gtk.Scale.new_with_range(
            Gtk.Orientation.HORIZONTAL, 0.0, 1.0, 0.01
        )
        slider.set_hexpand(True)
        slider.set_value(value)

        slider.connect(
            "value-changed",
            lambda s: label.set_text(f"{s.get_value():.2f}")
        )

        row = Adw.ActionRow(title=title, subtitle=f"{value:.2f}")
        row.add_suffix(slider)
        row.add_suffix(label)
        group.add(row)
