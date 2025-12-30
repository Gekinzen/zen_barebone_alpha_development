from gi.repository import Gtk


def confirm(parent, title, message):
    dialog = Gtk.MessageDialog(
        transient_for=parent,
        modal=True,
        buttons=Gtk.ButtonsType.OK_CANCEL,
        text=title
    )
    dialog.format_secondary_text(message)
    response = dialog.run()
    dialog.destroy()
    return response == Gtk.ResponseType.OK
