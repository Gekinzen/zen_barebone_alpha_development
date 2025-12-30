from gi.repository import Gtk, Adw
from settings.services.look_and_feel import LookAndFeelService
from settings.utils.colors import hex_to_rgba


class AppearanceView(Adw.PreferencesPage):
    def __init__(self):
        super().__init__(title="Appearance")

        self.service = LookAndFeelService()
        state = self.service.read()

        # ==================================================
        # GENERAL
        # ==================================================
        general = Adw.PreferencesGroup(
            title="General",
            description="Window borders and basic appearance"
        )

        # ---- Active Border Color ----
        active_border_btn = Gtk.ColorButton()
        active_border_btn.set_rgba(
            hex_to_rgba(self._hypr_rgba_to_hex(state["active_border"]))
        )

        row = Adw.ActionRow(title="Active Border Color")
        row.add_suffix(active_border_btn)
        row.set_activatable_widget(active_border_btn)
        general.add(row)

        # ---- Inactive Border Color ----
        inactive_border_btn = Gtk.ColorButton()
        inactive_border_btn.set_rgba(
            hex_to_rgba(self._hypr_rgba_to_hex(state["inactive_border"]))
        )

        row = Adw.ActionRow(title="Inactive Border Color")
        row.add_suffix(inactive_border_btn)
        row.set_activatable_widget(inactive_border_btn)
        general.add(row)

        self.add(general)

        # ==================================================
        # WINDOW DECORATION
        # ==================================================
        deco = Adw.PreferencesGroup(
            title="Window Decoration",
            description="Opacity, shadows and effects"
        )

        # ---- Active Opacity ----
        active_opacity_row = Adw.ActionRow(title="Active Opacity")

        active_opacity_label = Gtk.Label(
            label=f"{state['active_opacity']:.2f}",
            xalign=1
        )
        active_opacity_label.add_css_class("dim-label")

        active_opacity_slider = Gtk.Scale.new_with_range(
            Gtk.Orientation.HORIZONTAL, 0.0, 1.0, 0.01
        )
        active_opacity_slider.set_hexpand(True)
        active_opacity_slider.set_value(state["active_opacity"])

        active_opacity_slider.connect(
            "value-changed",
            lambda s: active_opacity_label.set_text(f"{s.get_value():.2f}")
        )

        active_opacity_row.add_suffix(active_opacity_slider)
        active_opacity_row.add_suffix(active_opacity_label)
        deco.add(active_opacity_row)

        # ---- Inactive Opacity ----
        inactive_opacity_row = Adw.ActionRow(title="Inactive Opacity")

        inactive_opacity_label = Gtk.Label(
            label=f"{state['inactive_opacity']:.2f}",
            xalign=1
        )
        inactive_opacity_label.add_css_class("dim-label")

        inactive_opacity_slider = Gtk.Scale.new_with_range(
            Gtk.Orientation.HORIZONTAL, 0.0, 1.0, 0.01
        )
        inactive_opacity_slider.set_hexpand(True)
        inactive_opacity_slider.set_value(state["inactive_opacity"])

        inactive_opacity_slider.connect(
            "value-changed",
            lambda s: inactive_opacity_label.set_text(f"{s.get_value():.2f}")
        )

        inactive_opacity_row.add_suffix(inactive_opacity_slider)
        inactive_opacity_row.add_suffix(inactive_opacity_label)
        deco.add(inactive_opacity_row)

        # ---- Shadow Toggle ----
        shadow_switch = Gtk.Switch(active=state["shadow_enabled"])

        shadow_row = Adw.ActionRow(title="Window Shadow")
        shadow_row.add_suffix(shadow_switch)
        shadow_row.set_activatable_widget(shadow_switch)
        deco.add(shadow_row)

        # ---- Shadow Color ----
        shadow_color_btn = Gtk.ColorButton()
        shadow_color_btn.set_rgba(
            hex_to_rgba(self._hypr_rgba_to_hex(state["shadow_color"]))
        )

        shadow_color_row = Adw.ActionRow(title="Shadow Color")
        shadow_color_row.add_suffix(shadow_color_btn)
        shadow_color_row.set_activatable_widget(shadow_color_btn)
        deco.add(shadow_color_row)

        self.add(deco)

    # ==================================================
    # HELPERS
    # ==================================================
    def _hypr_rgba_to_hex(self, value: str) -> str:
        """
        Convert 'rgba(83a598aa)' → '#83a598aa'
        """
        return "#" + value.replace("rgba(", "").replace(")", "")
