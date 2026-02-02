"""DIALOGS - Theme dialogs (new, save, export, import, delete)"""
import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw
from pathlib import Path
from .applier import ThemeApplier

def show_new_dialog(window, pm, refresh_dropdown, refresh_ui):
    d = Adw.MessageDialog(transient_for=window, heading="Create New Profile", body="Enter name:")
    e = Gtk.Entry(); e.set_placeholder_text("My Custom Theme"); e.set_margin_start(24); e.set_margin_end(24)
    d.set_extra_child(e); d.add_response("cancel", "Cancel"); d.add_response("create", "Create")
    d.set_response_appearance("create", Adw.ResponseAppearance.SUGGESTED)
    def on_resp(d, r):
        if r == "create" and e.get_text().strip():
            tid = pm.create_custom_theme(e.get_text().strip(), pm.get_active_theme().get("id"))
            pm.set_active_theme(tid, False); refresh_dropdown(window, pm)
        d.destroy()
    d.connect("response", on_resp); d.present()

def show_save_dialog(window, pm, refresh_dropdown, refresh_ui):
    d = Adw.MessageDialog(transient_for=window, heading="Save As Custom", body="Enter name:")
    e = Gtk.Entry(); e.set_placeholder_text("My Custom Theme"); e.set_margin_start(24); e.set_margin_end(24)
    d.set_extra_child(e); d.add_response("cancel", "Cancel"); d.add_response("save", "Save")
    d.set_response_appearance("save", Adw.ResponseAppearance.SUGGESTED)
    def on_resp(d, r):
        if r == "save" and e.get_text().strip():
            tid = pm.create_custom_theme(e.get_text().strip())
            pm.update_custom_theme(tid, {"colors": window.current_theme_colors, "waybar": window.current_waybar_config,
                                         "rofi": window.current_rofi_config, "kitty": window.current_kitty_config})
            pm.set_active_theme(tid, False); refresh_dropdown(window, pm)
        d.destroy()
    d.connect("response", on_resp); d.present()

def show_export_dialog(window, pm):
    d = Gtk.FileChooserDialog(title="Export Theme", transient_for=window, action=Gtk.FileChooserAction.SAVE)
    d.add_button("Cancel", Gtk.ResponseType.CANCEL); d.add_button("Export", Gtk.ResponseType.ACCEPT)
    d.set_current_name(f"{pm.get_active_theme().get('id', 'theme')}.json")
    def on_resp(d, r):
        if r == Gtk.ResponseType.ACCEPT and d.get_file(): pm.export_theme(pm.get_active_theme().get("id"), Path(d.get_file().get_path()))
        d.destroy()
    d.connect("response", on_resp); d.present()

def show_import_dialog(window, pm, refresh_dropdown, refresh_ui):
    d = Gtk.FileChooserDialog(title="Import Theme", transient_for=window, action=Gtk.FileChooserAction.OPEN)
    d.add_button("Cancel", Gtk.ResponseType.CANCEL); d.add_button("Import", Gtk.ResponseType.ACCEPT)
    def on_resp(d, r):
        if r == Gtk.ResponseType.ACCEPT and d.get_file():
            tid = pm.import_theme(Path(d.get_file().get_path()))
            if tid: pm.set_active_theme(tid, False); refresh_dropdown(window, pm); refresh_ui(window, pm)
        d.destroy()
    d.connect("response", on_resp); d.present()

def show_delete_dialog(window, pm, refresh_dropdown, refresh_ui):
    theme = pm.get_active_theme()
    if theme.get("is_builtin", True): return
    d = Adw.MessageDialog(transient_for=window, heading="Delete Profile?", body=f"Delete '{theme.get('name')}'?")
    d.add_response("cancel", "Cancel"); d.add_response("delete", "Delete")
    d.set_response_appearance("delete", Adw.ResponseAppearance.DESTRUCTIVE)
    def on_resp(d, r):
        if r == "delete": pm.delete_custom_theme(theme.get("id")); refresh_dropdown(window, pm); refresh_ui(window, pm)
        d.destroy()
    d.connect("response", on_resp); d.present()
