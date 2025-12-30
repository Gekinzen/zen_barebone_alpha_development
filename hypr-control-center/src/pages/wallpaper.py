"""
Wallpaper Page - SWW integration with folder selection
Optimized grid layout with thumbnail previews
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GdkPixbuf, GLib
import subprocess
from pathlib import Path
from typing import List, Optional

from ..preferences import WallpaperPreferences

class WallpaperPage:
    """Wallpaper page with swww integration"""
    
    def __init__(self, window):
        self.window = window
        self.prefs = WallpaperPreferences()
        self.wallpapers = []
        
    def build(self) -> Gtk.Box:
        """Build wallpaper page"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        page.set_margin_top(24)
        page.set_margin_bottom(24)
        page.set_margin_start(32)
        page.set_margin_end(32)
        
        # Header
        header = self._build_header()
        page.append(header)
        
        # Folder selection
        folder_group = self._build_folder_group()
        page.append(folder_group)
        
        # Wallpaper grid
        grid_group = self._build_grid_group()
        page.append(grid_group)
        
        return page
    
    def _build_header(self) -> Gtk.Box:
        """Build page header"""
        header = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        header.set_margin_bottom(24)
        
        title = Gtk.Label(label="Wallpaper")
        title.add_css_class('page-title')
        title.set_xalign(0)
        header.append(title)
        
        subtitle = Gtk.Label(
            label="Wallpaper images, colors, and slideshow options"
        )
        subtitle.add_css_class('page-subtitle')
        subtitle.set_xalign(0)
        header.append(subtitle)
        
        return header
    
    def _build_folder_group(self) -> Adw.PreferencesGroup:
        """Build folder selection group"""
        group = Adw.PreferencesGroup()
        group.set_title("Wallpaper Folder")
        
        # Current folder row
        folder_row = Adw.ActionRow()
        folder_row.set_title("Folder Path")
        
        current_folder = self.prefs.get_wallpaper_folder()
        folder_row.set_subtitle(current_folder)
        
        # Browse button
        browse_btn = Gtk.Button(label="Browse")
        browse_btn.set_valign(Gtk.Align.CENTER)
        browse_btn.connect('clicked', lambda b: self._on_browse_folder())
        folder_row.add_suffix(browse_btn)
        
        group.add(folder_row)
        
        # Transition row
        transition_row = Adw.ActionRow()
        transition_row.set_title("Transition Effect")
        
        transitions = ["Fade", "Wipe", "Grow", "Outer", "Wave"]
        current_transition = self.prefs.get_transition_type()
        current_idx = 0
        
        transition_dropdown = Gtk.DropDown()
        transition_dropdown.set_model(Gtk.StringList.new(transitions))
        
        # Find current
        for i, t in enumerate(transitions):
            if t.lower() == current_transition:
                current_idx = i
                break
        
        transition_dropdown.set_selected(current_idx)
        transition_dropdown.set_valign(Gtk.Align.CENTER)
        transition_dropdown.connect('notify::selected',
                                   lambda d, _: self._on_transition_change(
                                       transitions[d.get_selected()].lower()
                                   ))
        transition_row.add_suffix(transition_dropdown)
        
        group.add(transition_row)
        
        return group
    
    def _build_grid_group(self) -> Adw.PreferencesGroup:
        """Build wallpaper grid"""
        group = Adw.PreferencesGroup()
        group.set_title("Select Wallpaper")
        
        # Scrolled window for grid
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_min_content_height(400)
        scrolled.set_max_content_height(600)
        
        # FlowBox for grid layout
        flowbox = Gtk.FlowBox()
        flowbox.set_max_children_per_line(6)  # Unlimited columns
        flowbox.set_min_children_per_line(2)
        flowbox.set_row_spacing(12)
        flowbox.set_column_spacing(12)
        flowbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        flowbox.set_homogeneous(True)
        flowbox.connect('child-activated', self._on_wallpaper_selected)
        
        # Load wallpapers asynchronously
        GLib.idle_add(lambda: self._load_wallpapers_async(flowbox))
        
        scrolled.set_child(flowbox)
        group.add(scrolled)
        
        return group
    
    def _load_wallpapers_async(self, flowbox):
        """Load wallpapers from folder"""
        folder = Path(self.prefs.get_wallpaper_folder()).expanduser()
        
        if not folder.exists():
            # Show message
            label = Gtk.Label(label="Folder not found. Please select a valid folder.")
            label.add_css_class('dim-label')
            flowbox.append(label)
            return False
        
        # Get image files
        extensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif']
        wallpapers = []
        
        for ext in extensions:
            wallpapers.extend(folder.glob(f'*{ext}'))
            wallpapers.extend(folder.glob(f'*{ext.upper()}'))
        
        if not wallpapers:
            label = Gtk.Label(label="No wallpapers found in folder")
            label.add_css_class('dim-label')
            flowbox.append(label)
            return False
        
        # Sort and limit
        wallpapers.sort()
        self.wallpapers = wallpapers[:100]  # Max 100 for performance
        
        # Create thumbnail widgets
        for wallpaper_path in self.wallpapers:
            thumbnail = self._create_thumbnail(wallpaper_path)
            flowbox.append(thumbnail)
        
        return False
    
    def _create_thumbnail(self, image_path: Path) -> Gtk.Box:
        """Create thumbnail widget"""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        box.wallpaper_path = str(image_path)
        
        try:
            # Load and scale image
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
                str(image_path),
                200,  # Width
                150,  # Height
                True  # Preserve aspect
            )
            
            # Create image widget
            image = Gtk.Image.new_from_pixbuf(pixbuf)
            image.set_size_request(200, 150)
            image.add_css_class('wallpaper-thumbnail')
            box.append(image)
            
        except Exception as e:
            # Fallback icon
            icon = Gtk.Image.new_from_icon_name('image-x-generic')
            icon.set_pixel_size(64)
            icon.set_size_request(200, 150)
            box.append(icon)
        
        # Filename label
        label = Gtk.Label(label=image_path.name)
        label.set_ellipsize(3)  # End ellipsize
        label.set_max_width_chars(20)
        label.add_css_class('wallpaper-label')
        box.append(label)
        
        return box
    
    def _on_browse_folder(self):
        """Open folder chooser dialog"""
        dialog = Gtk.FileDialog()
        dialog.set_title("Select Wallpaper Folder")
        
        # Set initial folder using Gio.File
        from gi.repository import Gio
        current = Path(self.prefs.get_wallpaper_folder()).expanduser()
        if current.exists():
            gfile = Gio.File.new_for_path(str(current))
            dialog.set_initial_folder(gfile)
        
        def on_response(dialog, result):
            try:
                folder = dialog.select_folder_finish(result)
                if folder:
                    folder_path = folder.get_path()
                    self.prefs.set_wallpaper_folder(folder_path)
                    self.window._show_toast(f"Folder: {folder_path}")
                    
                    # Reload page
                    # TODO: Implement page refresh
            except:
                pass
        
        dialog.select_folder(self.window, None, on_response)
    
    def _on_transition_change(self, transition: str):
        """Handle transition change"""
        self.prefs.set_transition_type(transition)
        self.window._show_toast(f"Transition: {transition.capitalize()}")
    
    def _on_wallpaper_selected(self, flowbox, child):
        """Handle wallpaper selection"""
        if not hasattr(child.get_first_child(), 'wallpaper_path'):
            return
        
        wallpaper_path = child.get_first_child().wallpaper_path
        
        # Apply wallpaper with swww
        self._apply_wallpaper(wallpaper_path)
    
    def _apply_wallpaper(self, wallpaper_path: str):
        """Apply wallpaper using swww"""
        try:
            # Get transition
            transition = self.prefs.get_transition_type()
            
            # Apply with swww
            subprocess.run([
                'swww', 'img',
                wallpaper_path,
                '--transition-type', transition
            ], timeout=5, check=True)
            
            # Save current wallpaper
            self.prefs.set_current_wallpaper(wallpaper_path)
            
            self.window._show_toast(f"Wallpaper applied!")
            
        except subprocess.CalledProcessError:
            self.window._show_toast("Error: swww command failed")
        except FileNotFoundError:
            self.window._show_toast("Error: swww not installed")
        except Exception as e:
            self.window._show_toast(f"Error: {str(e)}")


def build_wallpaper_page(window) -> Gtk.Box:
    """Build wallpaper page (factory function)"""
    page_builder = WallpaperPage(window)
    return page_builder.build()