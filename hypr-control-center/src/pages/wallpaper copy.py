"""
Wallpaper Page - SWWW integration with folder selection
COMPLETE FIXED VERSION with bigger thumbnails (240x240) and slideshow + PAGINATION
Matching Appearance page design
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('Gdk', '4.0')
from gi.repository import Gtk, Adw, GdkPixbuf, GLib, Gio, Gdk
import subprocess
from pathlib import Path
from typing import List, Optional
import random

from ..preferences import WallpaperPreferences
from ..widgets import SettingsGroup

# Pagination settings
WALLPAPERS_PER_PAGE = 10  # 5 columns x 2 rows
COLUMNS = 5


class WallpaperPage:
    """Wallpaper page with swww integration"""
    
    def __init__(self, window):
        self.window = window
        self.prefs = WallpaperPreferences()
        self.wallpapers = []
        self.slideshow_timer = None
        
        # Pagination state
        self.current_page = 0
        self.total_pages = 0
        self.flowbox = None
        self.prev_btn = None
        self.next_btn = None
        self.page_label = None
        
        # Load saved slideshow state
        wallpaper_data = self.prefs.load()
        self.slideshow_enabled = wallpaper_data.get('slideshow_enabled', False)
        
        # Start slideshow if it was enabled
        if self.slideshow_enabled:
            GLib.idle_add(self._start_slideshow)
        
    def build(self) -> Gtk.Box:
        """Build wallpaper page - MATCH APPEARANCE DESIGN"""
        page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        page.add_css_class('content-area')
        
        # Main content with consistent padding
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=16)
        content.set_margin_start(32)
        content.set_margin_end(32)
        content.set_margin_top(16)
        content.set_margin_bottom(16)
        
        # Header
        header = self.window._create_page_header(
            "Wallpaper",
            "Wallpaper images, colors, and slideshow options"
        )
        content.append(header)
        
        # Folder selection
        folder_group = self._build_folder_group()
        content.append(folder_group)
        
        # Slideshow controls
        slideshow_group = self._build_slideshow_group()
        content.append(slideshow_group)
        
        # Wallpaper grid with pagination
        grid_group = self._build_grid_group()
        content.append(grid_group)
        
        page.append(content)
        return page
    
    def _build_folder_group(self) -> Gtk.Box:
        """Build folder selection group - SettingsGroup style"""
        group = SettingsGroup("Wallpaper Folder")
        
        # Current folder row
        folder_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        folder_box.set_margin_top(8)
        folder_box.set_margin_bottom(8)
        
        # Label
        folder_label = Gtk.Label(label="Folder Path")
        folder_label.add_css_class('setting-label')
        folder_label.set_halign(Gtk.Align.START)
        folder_label.set_hexpand(True)
        folder_box.append(folder_label)
        
        # Current path entry
        current_folder = self.prefs.get_wallpaper_folder()
        folder_entry = Gtk.Entry()
        folder_entry.set_text(current_folder)
        folder_entry.set_editable(False)
        folder_entry.set_hexpand(True)
        folder_box.append(folder_entry)
        
        # Browse button
        browse_btn = Gtk.Button(label="Browse")
        browse_btn.add_css_class('suggested-action')
        browse_btn.connect('clicked', lambda b: self._on_browse_folder(folder_entry))
        folder_box.append(browse_btn)
        
        group.append(folder_box)
        
        # Stats label
        stats_label = Gtk.Label()
        stats_label.add_css_class('setting-description')
        stats_label.set_halign(Gtk.Align.START)
        stats_label.set_margin_bottom(8)
        group.append(stats_label)
        self.stats_label = stats_label
        
        # Transition row
        transition_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        transition_box.set_margin_top(8)
        transition_box.set_margin_bottom(8)
        
        transition_label = Gtk.Label(label="Transition Effect")
        transition_label.add_css_class('setting-label')
        transition_label.set_halign(Gtk.Align.START)
        transition_label.set_hexpand(True)
        transition_box.append(transition_label)
        
        transitions = ["Random", "Fade", "Wipe", "Grow", "Outer", "Wave"]
        current_transition = self.prefs.get_transition_type()
        current_idx = 1  # Default to Fade
        
        transition_dropdown = Gtk.DropDown()
        transition_dropdown.set_model(Gtk.StringList.new(transitions))
        
        # Find current
        for i, t in enumerate(transitions):
            if t.lower() == current_transition:
                current_idx = i
                break
        
        transition_dropdown.set_selected(current_idx)
        transition_dropdown.set_valign(Gtk.Align.CENTER)
        transition_dropdown.add_css_class('setting-dropdown')
        transition_dropdown.connect('notify::selected',
                                   lambda d, _: self._on_transition_change(
                                       transitions[d.get_selected()].lower()
                                   ))
        transition_box.append(transition_dropdown)
        
        group.append(transition_box)
        
        return group
    
    def _build_slideshow_group(self) -> Gtk.Box:
        """Build slideshow controls - SettingsGroup style"""
        from ..widgets import ToggleRow
        
        group = SettingsGroup("Slideshow")
        
        wallpaper_data = self.prefs.load()
        
        # Enable slideshow toggle
        enable_row = ToggleRow(
            "Auto Change Wallpaper",
            wallpaper_data.get('slideshow_enabled', False),
            self._on_slideshow_toggle,
            "Randomly select wallpapers at intervals"
        )
        group.append(enable_row)
        
        # Interval selection
        interval_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        interval_box.set_margin_top(8)
        interval_box.set_margin_bottom(8)
        
        interval_label = Gtk.Label(label="Change Interval")
        interval_label.add_css_class('setting-label')
        interval_label.set_halign(Gtk.Align.START)
        interval_label.set_hexpand(True)
        interval_box.append(interval_label)
        
        current_interval = wallpaper_data.get('slideshow_interval', 60)
        intervals = ["10 seconds", "1 minute", "30 minutes", "1 hour"]
        interval_values = [10, 60, 1800, 3600]

        interval_dropdown = Gtk.DropDown()
        interval_dropdown.set_model(Gtk.StringList.new(intervals))
        interval_dropdown.add_css_class('setting-dropdown')

        # Find matching index
        selected_idx = 1
        for i, val in enumerate(interval_values):
            if val == current_interval:
                selected_idx = i
                break

        interval_dropdown.set_selected(selected_idx)
        interval_dropdown.set_valign(Gtk.Align.CENTER)
        
        def on_interval_selected(dropdown, _):
            interval = interval_values[dropdown.get_selected()]
            self.prefs.update({'slideshow_interval': interval})
            if self.slideshow_enabled:
                self._restart_slideshow()
        
        interval_dropdown.connect('notify::selected', on_interval_selected)
        interval_box.append(interval_dropdown)
        
        group.append(interval_box)
        
        # Random transition toggle
        random_row = ToggleRow(
            "Random Transition",
            wallpaper_data.get('random_transition', False),
            self._on_random_toggle,
            "Use different effect each time"
        )
        group.append(random_row)
        
        return group
    
    def _build_grid_group(self) -> Gtk.Box:
        """Build wallpaper grid with pagination - 5 columns, SettingsGroup style"""
        group = SettingsGroup("Select Wallpaper")
        
        # Info
        info = Gtk.Label(label="Click on a wallpaper to set it as your desktop background")
        info.add_css_class('setting-description')
        info.set_wrap(True)
        info.set_halign(Gtk.Align.START)
        info.set_margin_bottom(12)
        group.append(info)
        
        # Scrolled window - REDUCED height
        scrolled = Gtk.ScrolledWindow()
        scrolled.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        scrolled.set_min_content_height(400)
        scrolled.set_max_content_height(600)
        scrolled.set_vexpand(True)
        
        # FlowBox for grid layout - 5 columns
        self.flowbox = Gtk.FlowBox()
        self.flowbox.set_max_children_per_line(COLUMNS)
        self.flowbox.set_min_children_per_line(2)
        self.flowbox.set_row_spacing(16)
        self.flowbox.set_column_spacing(16)
        self.flowbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.flowbox.set_homogeneous(True)
        self.flowbox.connect('child-activated', self._on_wallpaper_selected)
        
        # Load wallpapers asynchronously
        GLib.idle_add(lambda: self._load_wallpapers_async())
        
        scrolled.set_child(self.flowbox)
        group.append(scrolled)
        
        # Pagination controls
        pagination = self._build_pagination_controls()
        group.append(pagination)
        
        return group
    
    def _build_pagination_controls(self) -> Gtk.Box:
        """Build pagination buttons - match appearance style"""
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        box.set_halign(Gtk.Align.CENTER)
        box.set_margin_top(12)
        
        # Previous button
        self.prev_btn = Gtk.Button(label="← Previous")
        self.prev_btn.add_css_class('action-button')
        self.prev_btn.connect('clicked', lambda b: self._on_previous_page())
        self.prev_btn.set_sensitive(False)
        box.append(self.prev_btn)
        
        # Page label
        self.page_label = Gtk.Label(label="Page 1 of 1")
        self.page_label.add_css_class('setting-label')
        self.page_label.set_margin_start(12)
        self.page_label.set_margin_end(12)
        box.append(self.page_label)
        
        # Next button
        self.next_btn = Gtk.Button(label="Next →")
        self.next_btn.add_css_class('action-button')
        self.next_btn.connect('clicked', lambda b: self._on_next_page())
        self.next_btn.set_sensitive(False)
        box.append(self.next_btn)
        
        return box
    
    def _load_wallpapers_async(self):
        """Load wallpapers from folder"""
        folder = Path(self.prefs.get_wallpaper_folder()).expanduser()
        
        if not folder.exists():
            label = Gtk.Label(label="Folder not found. Please select a valid folder.")
            label.add_css_class('setting-description')
            self.flowbox.append(label)
            if hasattr(self, 'stats_label'):
                self.stats_label.set_text("No wallpapers found")
            return False
        
        # Get image files
        extensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif']
        wallpapers = []
        
        for ext in extensions:
            wallpapers.extend(folder.glob(f'*{ext}'))
            wallpapers.extend(folder.glob(f'*{ext.upper()}'))
        
        if not wallpapers:
            label = Gtk.Label(label="No wallpapers found in folder")
            label.add_css_class('setting-description')
            self.flowbox.append(label)
            if hasattr(self, 'stats_label'):
                self.stats_label.set_text("No wallpapers found")
            return False
        
        # Sort
        wallpapers.sort()
        self.wallpapers = wallpapers
        
        # Update stats
        total = len(self.wallpapers)
        if hasattr(self, 'stats_label'):
            self.stats_label.set_text(f"Found {total} wallpaper{'s' if total != 1 else ''} in this directory")
        
        # Calculate total pages
        self.total_pages = (len(self.wallpapers) + WALLPAPERS_PER_PAGE - 1) // WALLPAPERS_PER_PAGE
        self.current_page = 0
        
        # Render first page
        self._render_page()
        
        return False
    
    def _render_page(self):
        """Render current page of wallpapers"""
        # Clear flowbox
        while True:
            child = self.flowbox.get_first_child()
            if child is None:
                break
            self.flowbox.remove(child)
        
        # Calculate range
        start_idx = self.current_page * WALLPAPERS_PER_PAGE
        end_idx = min(start_idx + WALLPAPERS_PER_PAGE, len(self.wallpapers))
        
        # Add thumbnails for current page
        for wallpaper_path in self.wallpapers[start_idx:end_idx]:
            thumbnail = self._create_thumbnail(wallpaper_path)
            self.flowbox.append(thumbnail)
        
        # Update pagination controls
        self.page_label.set_text(f"Page {self.current_page + 1} of {max(1, self.total_pages)}")
        self.prev_btn.set_sensitive(self.current_page > 0)
        self.next_btn.set_sensitive(self.current_page < self.total_pages - 1)
    
    def _on_previous_page(self):
        """Go to previous page"""
        if self.current_page > 0:
            self.current_page -= 1
            self._render_page()
    
    def _on_next_page(self):
        """Go to next page"""
        if self.current_page < self.total_pages - 1:
            self.current_page += 1
            self._render_page()
    
    def _create_thumbnail(self, image_path: Path) -> Gtk.Box:
        """Create thumbnail - image MUST fill 240x240"""
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        box.wallpaper_path = str(image_path)
        box.set_size_request(240, 260)
        box.set_hexpand(False)
        box.set_vexpand(False)

        aspect = Gtk.AspectFrame()
        aspect.set_ratio(1.0)
        aspect.set_obey_child(True)
        aspect.set_size_request(240, 240)
        aspect.set_hexpand(False)
        aspect.set_vexpand(False)

        frame = Gtk.Frame()
        frame.set_size_request(240, 240)
        frame.set_hexpand(False)
        frame.set_vexpand(False)
        frame.add_css_class('wallpaper-frame')

        try:
            picture = Gtk.Picture.new_for_filename(str(image_path))
            picture.set_content_fit(Gtk.ContentFit.COVER)
            picture.set_can_shrink(True)
            frame.set_child(picture)
        except Exception as e:
            icon = Gtk.Image.new_from_icon_name('image-x-generic')
            icon.set_pixel_size(80)
            frame.set_child(icon)

        aspect.set_child(frame)
        box.append(aspect)

        label = Gtk.Label(label=image_path.name)
        label.set_ellipsize(3)
        label.set_max_width_chars(20)
        label.add_css_class('wallpaper-label')
        box.append(label)

        return box
    
    def _on_browse_folder(self, folder_entry):
        """Open folder chooser dialog with auto-refresh"""
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
                    
                    # Update UI
                    folder_entry.set_text(folder_path)
                    
                    # AUTO-REFRESH: Reload wallpapers!
                    self.current_page = 0
                    self._load_wallpapers_async()
                    
                    self.window._show_toast(f"Loaded wallpapers from {Path(folder_path).name}")
            except:
                pass
        
        dialog.select_folder(self.window, None, on_response)
    
    def _on_transition_change(self, transition: str):
        """Handle transition change"""
        self.prefs.set_transition_type(transition)
        self.window._show_toast(f"Transition: {transition.capitalize()}")
    
    def _on_slideshow_toggle(self, switch, _):
        """Handle slideshow toggle - SAVE STATE"""
        self.slideshow_enabled = switch.get_active()
        self.prefs.update({'slideshow_enabled': self.slideshow_enabled})
        
        if self.slideshow_enabled:
            self._start_slideshow()
            self.window._show_toast("Slideshow started")
        else:
            self._stop_slideshow()
            self.window._show_toast("Slideshow stopped")
    
    def _on_random_toggle(self, switch, _):
        """Handle random transition toggle"""
        enabled = switch.get_active()
        self.prefs.update({'random_transition': enabled})
        self.window._show_toast("Random transitions: " + ("On" if enabled else "Off"))
    
    def _start_slideshow(self):
        """Start automatic wallpaper changes"""
        wallpaper_data = self.prefs.load()
        interval = wallpaper_data.get('slideshow_interval', 60)
        interval_ms = interval * 1000
        
        def change_wallpaper():
            if self.wallpapers and self.slideshow_enabled:
                wallpaper = random.choice(self.wallpapers)
                
                wallpaper_data = self.prefs.load()
                transition_type = self.prefs.get_transition_type()
                
                if transition_type == 'random' or wallpaper_data.get('random_transition', False):
                    transitions = ['fade', 'wipe', 'grow', 'outer', 'wave']
                    transition = random.choice(transitions)
                else:
                    transition = transition_type if transition_type != 'random' else 'fade'
                
                self._apply_wallpaper(str(wallpaper), transition)
                
                return True
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
        transition = self.prefs.get_transition_type()
        self._apply_wallpaper(wallpaper_path, transition)
    
    def _apply_wallpaper(self, wallpaper_path: str, transition: str = 'fade'):
        """Apply wallpaper using swww"""
        try:
            subprocess.run([
                'swww', 'img',
                wallpaper_path,
                '--transition-type', transition
            ], timeout=5, check=True)
            
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