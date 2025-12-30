"""
Wallpaper Page - SWWW integration with folder selection
COMPLETE VERSION with bigger thumbnails (240x240) and slideshow
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GdkPixbuf, GLib, Gio
import subprocess
from pathlib import Path
from typing import List, Optional
import random

from ..preferences import WallpaperPreferences


class WallpaperPage:
    """Wallpaper page with swww integration"""
    
    def __init__(self, window):
        self.window = window
        self.prefs = WallpaperPreferences()
        self.wallpapers = []
        self.slideshow_timer = None
        self.slideshow_enabled = False
        
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
        
        # Slideshow controls
        slideshow_group = self._build_slideshow_group()
        page.append(slideshow_group)
        
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
    
    def _build_slideshow_group(self) -> Adw.PreferencesGroup:
        """Build slideshow controls"""
        group = Adw.PreferencesGroup()
        group.set_title("Slideshow")
        group.set_description("Automatically change wallpaper at intervals")
        
        # Enable slideshow
        enable_row = Adw.ActionRow()
        enable_row.set_title("Auto Change Wallpaper")
        enable_row.set_subtitle("Randomly select wallpapers")
        
        enable_switch = Gtk.Switch()
        enable_switch.set_valign(Gtk.Align.CENTER)
        enable_switch.connect('notify::active', self._on_slideshow_toggle)
        enable_row.add_suffix(enable_switch)
        
        group.add(enable_row)
        
        # Interval selection
        interval_row = Adw.ActionRow()
        interval_row.set_title("Change Interval")
        
        intervals = ["10 seconds", "1 minute", "30 minutes", "1 hour"]
        interval_values = [10, 60, 1800, 3600]
        
        interval_dropdown = Gtk.DropDown()
        interval_dropdown.set_model(Gtk.StringList.new(intervals))
        interval_dropdown.set_selected(1)  # Default 1 minute
        interval_dropdown.set_valign(Gtk.Align.CENTER)
        
        def on_interval_selected(dropdown, _):
            interval = interval_values[dropdown.get_selected()]
            self.prefs.set('slideshow_interval', interval)
            if self.slideshow_enabled:
                self._restart_slideshow()
        
        interval_dropdown.connect('notify::selected', on_interval_selected)
        interval_row.add_suffix(interval_dropdown)
        
        group.add(interval_row)
        
        # Random transition toggle
        random_row = Adw.ActionRow()
        random_row.set_title("Random Transition")
        random_row.set_subtitle("Use different effect each time")
        
        random_switch = Gtk.Switch()
        random_switch.set_valign(Gtk.Align.CENTER)
        random_switch.connect('notify::active', self._on_random_toggle)
        random_row.add_suffix(random_switch)
        
        group.add(random_row)
        
        return group
    
    def _build_grid_group(self) -> Adw.PreferencesGroup:
        """Build wallpaper grid with bigger thumbnails"""
        group = Adw.PreferencesGroup()
        group.set_title("Select Wallpaper")
        
        # Scrolled window for grid
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_min_content_height(400)
        scrolled.set_max_content_height(600)
        
        # FlowBox for grid layout - 4 columns for 240px thumbnails
        flowbox = Gtk.FlowBox()
        flowbox.set_max_children_per_line(4)
        flowbox.set_min_children_per_line(2)
        flowbox.set_row_spacing(20)
        flowbox.set_column_spacing(20)
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
        """Create bigger square thumbnail (240x240)"""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        box.wallpaper_path = str(image_path)
        
        # Create fixed size frame for consistent layout
        frame = Gtk.Frame()
        frame.set_size_request(240, 240)  # BIGGER! 240x240
        frame.add_css_class('wallpaper-frame')
        
        try:
            # Load image to get dimensions
            pixbuf_full = GdkPixbuf.Pixbuf.new_from_file(str(image_path))
            orig_width = pixbuf_full.get_width()
            orig_height = pixbuf_full.get_height()
            
            # Calculate scaling to fill square while maintaining aspect
            target_size = 240
            scale = max(target_size / orig_width, target_size / orig_height)
            new_width = int(orig_width * scale)
            new_height = int(orig_height * scale)
            
            # Scale image
            pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_scale(
                str(image_path),
                new_width,
                new_height,
                True
            )
            
            # Create image widget
            image = Gtk.Image.new_from_pixbuf(pixbuf)
            image.add_css_class('wallpaper-thumbnail')
            frame.set_child(image)
            
        except Exception as e:
            # Fallback icon
            icon = Gtk.Image.new_from_icon_name('image-x-generic')
            icon.set_pixel_size(64)
            frame.set_child(icon)
        
        box.append(frame)
        
        # Filename label
        label = Gtk.Label(label=image_path.name)
        label.set_ellipsize(3)  # End ellipsize
        label.set_max_width_chars(25)
        label.add_css_class('wallpaper-label')
        box.append(label)
        
        return box
    
    def _on_browse_folder(self):
        """Open folder chooser dialog"""
        dialog = Gtk.FileDialog()
        dialog.set_title("Select Wallpaper Folder")
        
        # Set initial folder using Gio.File
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
            except:
                pass
        
        dialog.select_folder(self.window, None, on_response)
    
    def _on_transition_change(self, transition: str):
        """Handle transition change"""
        self.prefs.set_transition_type(transition)
        self.window._show_toast(f"Transition: {transition.capitalize()}")
    
    def _on_slideshow_toggle(self, switch, _):
        """Handle slideshow toggle"""
        self.slideshow_enabled = switch.get_active()
        if self.slideshow_enabled:
            self._start_slideshow()
            self.window._show_toast("Slideshow started")
        else:
            self._stop_slideshow()
            self.window._show_toast("Slideshow stopped")
    
    def _on_random_toggle(self, switch, _):
        """Handle random transition toggle"""
        enabled = switch.get_active()
        self.prefs.set('random_transition', enabled)
        self.window._show_toast("Random transitions: " + ("On" if enabled else "Off"))
    
    def _start_slideshow(self):
        """Start automatic wallpaper changes"""
        interval = self.prefs.get('slideshow_interval', 60)
        interval_ms = interval * 1000
        
        def change_wallpaper():
            if self.wallpapers and self.slideshow_enabled:
                # Pick random wallpaper
                wallpaper = random.choice(self.wallpapers)
                
                # Get transition
                if self.prefs.get('random_transition', False):
                    transitions = ['fade', 'wipe', 'grow', 'outer', 'wave']
                    transition = random.choice(transitions)
                else:
                    transition = self.prefs.get_transition_type()
                
                # Apply
                self._apply_wallpaper(str(wallpaper), transition)
                
                return True  # Continue timer
            return False
        
        self.slideshow_timer = GLib.timeout_add(interval_ms, change_wallpaper)
    
    def _stop_slideshow(self):
        """Stop automatic wallpaper changes"""
        if self.slideshow_timer:
            GLib.source_remove(self.slideshow_timer)
            self.slideshow_timer = None
    
    def _restart_slideshow(self):
        """Restart slideshow with new interval"""
        self._stop_slideshow()
        if self.slideshow_enabled:
            self._start_slideshow()
    
    def _on_wallpaper_selected(self, flowbox, child):
        """Handle wallpaper selection"""
        if not hasattr(child.get_first_child(), 'wallpaper_path'):
            return
        
        wallpaper_path = child.get_first_child().wallpaper_path
        
        # Get current transition
        transition = self.prefs.get_transition_type()
        
        # Apply wallpaper
        self._apply_wallpaper(wallpaper_path, transition)
    
    def _apply_wallpaper(self, wallpaper_path: str, transition: str = 'fade'):
        """Apply wallpaper using swww"""
        try:
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