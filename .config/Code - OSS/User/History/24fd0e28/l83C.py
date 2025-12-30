from gi.repository import Gtk, Adw
from settings.controllers.appearance import AppearanceController


class AppearanceView(Gtk.Box):
    def __init__(self):
        super().__init__(
            orientation=Gtk.Orientation.VERTICAL,
            spacing=24,
            margin_top=24,
            margin_bottom=24,
            margin_start=24,
            margin_end=24
        )

        self.ctrl = AppearanceController()

        # =====================
        # GENERAL
        # =====================
        self._section("General")

        self._color_row(
            "Active Border Color",
            self.ctrl.set_active_border
        )

        self._color_row(
            "Inactive Border Color",
            self.ctrl.set_inactive_border
        )

        # =====================
        # DECORATION
        # =====================
        self._section("Decoration")

        self._opacity_rows()

        shadow_switch = Gtk.Switch(active=True)
        shadow_switch.connect(
            "notify::active",
            lambda s, *_: self.ctrl.set_shadow_enabled(s.get_active())
        )

        shadow_row = Adw.ActionRow(title="Window Shadow")
        shadow_row.add_suffix(shadow_switch)
        shadow_row.set_activatable_widget(shadow_switch)
        self.append(shadow_row)

        self._color_row(
            "Shadow Color",
            self.ctrl.set_shadow_color
        )

        # =====================
        # BLUR
        # =====================
        self._section("Blur")

        blur_switch = Gtk.Switch(active=True)
        blur_switch.connect(
            "notify::active",
            lambda s, *_: self.ctrl.set_blur_enabled(s.get_active())
        )

        blur_row = Adw.ActionRow(title="Enable Blur")
        blur_row.add_suffix(blur_switch)
        blur_row.set_activatable_widget(blur_switch)
        self.append(blur_row)

        vibrancy_slider, vibrancy_value = self._slider(
            0.0, 1.0, 0.01, 0.17
        )

        vibrancy_slider.connect(
            "value-changed",
            lambda s: (
                vibrancy_value.set_text(f"{s.get_value():.2f}"),
                self.ctrl.set_vibrancy(s.get_value())
            )
        )

        self._row("Blur Vibrancy", vibrancy_slider, vibrancy_value)

    # =====================
    # HELPERS
    # =====================
    def _section(self, title):
        label = Gtk.Label(label=title)
        label.add_css_class("title-3")
        label.set_xalign(0)
        self.append(label)

    def _row(self, title, widget, value_label=None):
        row = Adw.ActionRow(title=title)
        row.add_suffix(widget)
        if value_label:
            row.add_suffix(value_label)
        row.set_activatable_widget(widget)
        self.append(row)

    def _color_row(self, title, callback):
        btn = Gtk.ColorButton()
        btn.connect("color-set", lambda b: callback(b.get_rgba()))
        self._row(title, btn)

    def _slider(self, min_v, max_v, step, default):
        slider = Gtk.Scale.new_with_range(
            Gtk.Orientation.HORIZONTAL,
            min_v, max_v, step
        )
        slider.set_hexpand(True)
        slider.set_value(default)

        value = Gtk.Label(label=f"{default:.2f}")
        value.add_css_class("dim-label")

        return slider, value

    def _opacity_rows(self):
        active_slider, active_val = self._slider(0.0, 1.0, 0.01, 1.0)
        inactive_slider, inactive_val = self._slider(0.0, 1.0, 0.01, 1.0)

        def apply():
            self.ctrl.set_opacity(
                self.get_root(),
                active_slider.get_value(),
                inactive_slider.get_value()
            )

        active_slider.connect(
            "value-changed",
            lambda s: (
                active_val.set_text(f"{s.get_value():.2f}"),
                apply()
            )
        )

        inactive_slider.connect(
            "value-changed",
            lambda s: (
                inactive_val.set_text(f"{s.get_value():.2f}"),
                apply()
            )
        )

        self._row("Active Opacity", active_slider, active_val)
        self._row("Inactive Opacity", inactive_slider, inactive_val)
