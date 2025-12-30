from gi.repository import Gtk, Adw
from settings.controllers.appearance import AppearanceController
from settings.utils.colors import hypr_to_rgba


class AppearanceView(Adw.PreferencesPage):
    def __init__(self):
        super().__init__(title="Appearance")

        self.ctrl = AppearanceController()
        state = self.ctrl.get_current_state()

        # ==================================================
        # GENERAL
        # ==================================================
        general = Adw.PreferencesGroup(title="General")

        active_border_btn = Gtk.ColorButton()
        active_border_btn.set_rgba(hypr_to_rgba(state["active_border"]))
        active_border_btn.connect(
            "color-set",
            lambda b: self.ctrl.set_active_border(b.get_rgba())
        )

        row = Adw.ActionRow(title="Active Border Color")
        row.add_suffix(active_border_btn)
        row.set_activatable_widget(active_border_btn)
        general.add(row)

        inactive_border_btn = Gtk.ColorButton()
        inactive_border_btn.set_rgba(hypr_to_rgba(state["inactive_border"]))
        inactive_border_btn.connect(
            "color-set",
            lambda b: self.ctrl.set_inactive_border(b.get_rgba())
        )

        row = Adw.ActionRow(title="Inactive Border Color")
        row.add_suffix(inactive_border_btn)
        row.set_activatable_widget(inactive_border_btn)
        general.add(row)

        self.add(general)

        # ==================================================
        # DECORATION
        # ==================================================
        deco = Adw.PreferencesGroup(title="Window Decoration")

        active_slider, active_value = self._slider(state["active_opacity"])
        inactive_slider, inactive_value = self._slider(state["inactive_opacity"])

        def apply_opacity():
            self.ctrl.set_opacity(
                self.get_root(),
                active_slider.get_value(),
                inactive_slider.get_value()
            )

        active_slider.connect(
            "value-changed",
            lambda s: (
                active_value.set_text(f"{s.get_value():.2f}"),
                apply_opacity()
            )
        )

        inactive_slider.connect(
            "value-changed",
            lambda s: (
                inactive_value.set_text(f"{s.get_value():.2f}"),
                apply_opacity()
            )
        )

        deco.add(self._row("Active Opacity", active_slider, active_value))
        deco.add(self._row("Inactive Opacity", inactive_slider, inactive_value))

        shadow_switch = Gtk.Switch(active=state["shadow_enabled"])
        shadow_switch.connect(
            "notify::active",
            lambda s, *_: self.ctrl.set_shadow_enabled(s.get_active())
        )

        row = Adw.ActionRow(title="Window Shadow")
        row.add_suffix(shadow_switch)
        row.set_activatable_widget(shadow_switch)
        deco.add(row)

        shadow_color_btn = Gtk.ColorButton()
        shadow_color_btn.set_rgba(hypr_to_rgba(state["shadow_color"]))
        shadow_color_btn.connect(
            "color-set",
            lambda b: self.ctrl.set_shadow_color(b.get_rgba())
        )

        row = Adw.ActionRow(title="Shadow Color")
        row.add_suffix(shadow_color_btn)
        row.set_activatable_widget(shadow_color_btn)
        deco.add(row)

        self.add(deco)

        # ==================================================
        # BLUR
        # ==================================================
        blur = Adw.PreferencesGroup(title="Blur")

        blur_switch = Gtk.Switch(active=state["blur_enabled"])
        blur_switch.connect(
            "notify::active",
            lambda s, *_: self.ctrl.set_blur_enabled(s.get_active())
        )

        row = Adw.ActionRow(title="Enable Blur")
        row.add_suffix(blur_switch)
        row.set_activatable_widget(blur_switch)
        blur.add(row)

        vibrancy_slider, vibrancy_value = self._slider(state["vibrancy"])
        vibrancy_slider.set_sensitive(state["blur_enabled"])

        blur_switch.connect(
            "notify::active",
            lambda s, *_: vibrancy_slider.set_sensitive(s.get_active())
        )

        vibrancy_slider.connect(
            "value-changed",
            lambda s: (
                vibrancy_value.set_text(f"{s.get_value():.2f}"),
                self.ctrl.set_vibrancy(s.get_value())
            )
        )

        blur.add(self._row("Blur Vibrancy", vibrancy_slider, vibrancy_value))

        self.add(blur)

    # ==================================================
    # HELPERS
    # ==================================================
    def _slider(self, value: float):
        slider = Gtk.Scale.new_with_range(
            Gtk.Orientation.HORIZONTAL, 0.0, 1.0, 0.01
        )
        slider.set_hexpand(True)
        slider.set_value(value)

        label = Gtk.Label(label=f"{value:.2f}")
        label.add_css_class("dim-label")

        return slider, label

    def _row(self, title, widget, value_label=None):
        row = Adw.ActionRow(title=title)
        row.add_suffix(widget)
        if value_label:
            row.add_suffix(value_label)
        row.set_activatable_widget(widget)
        return row
