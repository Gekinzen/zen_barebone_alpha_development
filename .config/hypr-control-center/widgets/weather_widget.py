#!/usr/bin/env python3
"""
Weather Widget - Configurable Location Version
Features:
- Auto-detect location OR manual override from config
- 7-day forecast from Open-Meteo
- Current weather from wttr.in
- Reads location from widgets.json
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib, Gdk
import json
import subprocess
import datetime
from pathlib import Path

try:
    gi.require_version('Gtk4LayerShell', '1.0')
    from gi.repository import Gtk4LayerShell
    HAS_LAYER_SHELL = True
except:
    HAS_LAYER_SHELL = False


CACHE_FILE = Path.home() / ".cache/hypr-widgets/weather_cache.json"
CACHE_MAX_AGE = 3600 * 6


class WeatherWidget(Gtk.Window):
    """Weather widget with configurable location"""
    
    def __init__(self, app):
        super().__init__(application=app)
        
        self.set_title("hypr-widget-weather")
        self.set_decorated(False)
        self.set_resizable(False)
        
        # Position tracking
        self.current_x = 100
        self.current_y = 400
        self.drag_origin_x = 0
        self.drag_origin_y = 0
        self.is_dragging = False
        
        # Config
        self.config_dir = Path.home() / ".config/hypr-control-center/preferences"
        self.config_path = self.config_dir / "widgets.json"
        self.config_dir.mkdir(parents=True, exist_ok=True)
        
        CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
        
        # Location settings
        self.location_mode = "auto"  # "auto" or "manual"
        self.location = "Manila"
        self.lat = None
        self.lon = None
        
        # Load config
        self._load_config()
        
        # Apply CSS
        self._apply_css()
        
        # Build UI
        self._build_ui()
        
        # Setup layer shell
        if HAS_LAYER_SHELL:
            self._setup_layer_shell()
        
        # Setup drag
        self._setup_drag()
        
        # Load cache first
        self._load_cache()
        
        # Initial update
        GLib.timeout_add(500, self._initial_update)
        GLib.timeout_add_seconds(1800, self.update_weather)
        
        # Watch config changes
        GLib.timeout_add_seconds(10, self._check_config_changes)
    
    def _load_config(self):
        """Load configuration"""
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r') as f:
                    config = json.load(f)
                
                widget_config = config.get('widgets', {}).get('weather', {})
                self.current_x = widget_config.get('x', self.current_x)
                self.current_y = widget_config.get('y', self.current_y)
                self.location_mode = widget_config.get('location', 'auto')
                
                if self.location_mode == "manual":
                    manual_loc = widget_config.get('location_name', '')
                    if manual_loc:
                        self.location = manual_loc
                    self.lat = widget_config.get('lat')
                    self.lon = widget_config.get('lon')
                
                # Also check detected location
                detected = config.get('detected_location', {})
                if self.location_mode == "auto" and detected.get('city'):
                    self.location = detected['city']
                    self.lat = detected.get('lat')
                    self.lon = detected.get('lon')
                    
            except Exception as e:
                print(f"[weather] Config load error: {e}")
        
        # Fallback: detect location if auto mode
        if self.location_mode == "auto" and not self.lat:
            self._detect_location()
    
    def _check_config_changes(self) -> bool:
        """Check for config changes"""
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r') as f:
                    config = json.load(f)
                
                widget_config = config.get('widgets', {}).get('weather', {})
                new_mode = widget_config.get('location', 'auto')
                new_loc = widget_config.get('location_name', '')
                
                # Check if location changed
                location_changed = False
                
                if new_mode != self.location_mode:
                    self.location_mode = new_mode
                    location_changed = True
                
                if new_mode == "manual" and new_loc and new_loc != self.location:
                    self.location = new_loc
                    self.lat = None  # Reset lat/lon for new location
                    self.lon = None
                    location_changed = True
                
                if new_mode == "auto":
                    detected = config.get('detected_location', {})
                    if detected.get('city') and detected['city'] != self.location:
                        self.location = detected['city']
                        self.lat = detected.get('lat')
                        self.lon = detected.get('lon')
                        location_changed = True
                
                if location_changed:
                    print(f"[weather] Location changed to: {self.location}")
                    self.update_weather()
                    
            except:
                pass
        
        return True
    
    def _save_config(self):
        """Save position to config"""
        config = {"widgets": {}}
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r') as f:
                    config = json.load(f)
            except:
                pass
        
        if 'widgets' not in config:
            config['widgets'] = {}
        
        if 'weather' not in config['widgets']:
            config['widgets']['weather'] = {}
        
        config['widgets']['weather'].update({
            'x': self.current_x,
            'y': self.current_y,
            'enabled': True
        })
        
        with open(self.config_path, 'w') as f:
            json.dump(config, f, indent=2)
    
    def _detect_location(self):
        """Auto-detect location via IP"""
        try:
            result = subprocess.run(
                ['curl', '-s', '--connect-timeout', '3', 'https://ipapi.co/json/'],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0 and result.stdout.strip():
                data = json.loads(result.stdout)
                city = data.get('city', '')
                if city:
                    self.location = city
                    self.lat = data.get('latitude')
                    self.lon = data.get('longitude')
                    print(f"[weather] Detected location: {city}")
                    return
        except:
            pass
        
        try:
            result = subprocess.run(
                ['curl', '-s', '--connect-timeout', '3', 'http://ip-api.com/json/'],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0 and result.stdout.strip():
                data = json.loads(result.stdout)
                city = data.get('city', '')
                if city:
                    self.location = city
                    self.lat = data.get('lat')
                    self.lon = data.get('lon')
                    return
        except:
            pass
    
    def _apply_css(self):
        """Apply CSS"""
        css = Gtk.CssProvider()
        css.load_from_string("""
            * {
                background: transparent;
                background-color: rgba(0,0,0,0);
            }
            
            .widget-container {
                background: rgba(20, 20, 22, 0.85);
                border-radius: 16px;
                border: 1px solid rgba(255, 255, 255, 0.08);
            }
            
            .weather-icon-compact {
                font-size: 48px;
            }
            
            .temp-compact {
                font-size: 42px;
                font-weight: 800;
                color: #ffffff;
            }
            
            .location-compact {
                font-size: 13px;
                color: rgba(255, 255, 255, 0.7);
            }
            
            .condition-compact {
                font-size: 14px;
                font-weight: 500;
                color: rgba(255, 255, 255, 0.85);
            }
            
            .stat-icon-tiny {
                font-size: 12px;
            }
            
            .stat-value-tiny {
                font-size: 12px;
                color: rgba(255, 255, 255, 0.7);
            }
            
            .dim-label {
                font-size: 10px;
                color: rgba(255, 255, 255, 0.4);
            }
            
            .weather-sep {
                background: rgba(255, 255, 255, 0.1);
                min-height: 1px;
            }
            
            .forecast-day-compact {
                padding: 6px 4px;
            }
            
            .forecast-day-name {
                font-size: 10px;
                font-weight: 600;
                color: rgba(255, 255, 255, 0.6);
            }
            
            .forecast-icon-compact {
                font-size: 18px;
            }
            
            .forecast-temp-compact {
                font-size: 10px;
                color: rgba(255, 255, 255, 0.8);
            }
        """)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css,
            Gtk.STYLE_PROVIDER_PRIORITY_USER
        )
    
    def _build_ui(self):
        """Build weather UI"""
        main = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        main.add_css_class("widget-container")
        main.set_size_request(380, 240)
        
        # Top section
        top = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=12)
        top.set_margin_start(18)
        top.set_margin_end(18)
        top.set_margin_top(15)
        
        # Left: Icon + Temp
        left_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        
        self.weather_icon = Gtk.Label()
        self.weather_icon.add_css_class("weather-icon-compact")
        left_box.append(self.weather_icon)
        
        temp_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        
        self.temp_label = Gtk.Label(label="--°C")
        self.temp_label.add_css_class("temp-compact")
        self.temp_label.set_halign(Gtk.Align.START)
        temp_box.append(self.temp_label)
        
        self.location_label = Gtk.Label(label=self.location)
        self.location_label.add_css_class("location-compact")
        self.location_label.set_halign(Gtk.Align.START)
        temp_box.append(self.location_label)
        
        left_box.append(temp_box)
        top.append(left_box)
        
        spacer = Gtk.Box()
        spacer.set_hexpand(True)
        top.append(spacer)
        
        # Right: Stats
        stats_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.feels_value = self._create_stat_row("🌡️", stats_box)
        self.humidity_value = self._create_stat_row("💧", stats_box)
        self.wind_value = self._create_stat_row("💨", stats_box)
        top.append(stats_box)
        main.append(top)
        
        # Condition
        self.condition_label = Gtk.Label(label="Loading...")
        self.condition_label.add_css_class("condition-compact")
        self.condition_label.set_margin_start(18)
        self.condition_label.set_margin_top(5)
        self.condition_label.set_halign(Gtk.Align.START)
        main.append(self.condition_label)
        
        # Updated time
        self.updated_label = Gtk.Label()
        self.updated_label.add_css_class("dim-label")
        self.updated_label.set_margin_start(18)
        self.updated_label.set_margin_top(2)
        self.updated_label.set_halign(Gtk.Align.START)
        main.append(self.updated_label)
        
        # Separator
        sep = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        sep.add_css_class("weather-sep")
        sep.set_margin_start(18)
        sep.set_margin_end(18)
        sep.set_margin_top(10)
        sep.set_margin_bottom(8)
        main.append(sep)
        
        # 7-day forecast
        forecast_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        forecast_box.set_margin_start(8)
        forecast_box.set_margin_end(8)
        forecast_box.set_margin_bottom(12)
        forecast_box.set_halign(Gtk.Align.CENTER)
        
        self.forecast_days = []
        for i in range(7):
            day_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            day_box.add_css_class("forecast-day-compact")
            day_box.set_size_request(48, -1)
            
            day_label = Gtk.Label(label="---")
            day_label.add_css_class("forecast-day-name")
            day_box.append(day_label)
            
            icon_label = Gtk.Label(label="🌡️")
            icon_label.add_css_class("forecast-icon-compact")
            day_box.append(icon_label)
            
            temp_label = Gtk.Label(label="--/--")
            temp_label.add_css_class("forecast-temp-compact")
            day_box.append(temp_label)
            
            forecast_box.append(day_box)
            self.forecast_days.append({
                'day': day_label,
                'icon': icon_label,
                'temp': temp_label
            })
        
        main.append(forecast_box)
        self.set_child(main)
    
    def _create_stat_row(self, icon_text: str, parent: Gtk.Box) -> Gtk.Label:
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        icon = Gtk.Label(label=icon_text)
        icon.add_css_class("stat-icon-tiny")
        row.append(icon)
        value = Gtk.Label(label="--")
        value.add_css_class("stat-value-tiny")
        row.append(value)
        parent.append(row)
        return value
    
    def _setup_layer_shell(self):
        """Setup layer shell"""
        Gtk4LayerShell.init_for_window(self)
        Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.BOTTOM)
        Gtk4LayerShell.set_namespace(self, "hypr-widget-weather")
        Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.ON_DEMAND)
        Gtk4LayerShell.set_exclusive_zone(self, -1)
        
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, False)
        Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, False)
        
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, self.current_y)
        Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, self.current_x)
    
    def _setup_drag(self):
        """Setup drag gesture"""
        drag = Gtk.GestureDrag.new()
        drag.set_button(1)
        drag.connect("drag-begin", self._on_drag_begin)
        drag.connect("drag-update", self._on_drag_update)
        drag.connect("drag-end", self._on_drag_end)
        self.add_controller(drag)
        
        motion = Gtk.EventControllerMotion.new()
        motion.connect("enter", lambda c,x,y: self.set_cursor(Gdk.Cursor.new_from_name("grab")))
        motion.connect("leave", lambda c: self.set_cursor(None) if not self.is_dragging else None)
        self.add_controller(motion)
    
    def _on_drag_begin(self, gesture, x, y):
        self.is_dragging = True
        self.drag_origin_x = self.current_x
        self.drag_origin_y = self.current_y
        self.set_cursor(Gdk.Cursor.new_from_name("grabbing"))
    
    def _on_drag_update(self, gesture, offset_x, offset_y):
        if not self.is_dragging:
            return
        
        new_x = max(0, int(self.drag_origin_x + offset_x))
        new_y = max(0, int(self.drag_origin_y + offset_y))
        
        self.current_x = new_x
        self.current_y = new_y
        
        if HAS_LAYER_SHELL:
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.TOP, new_y)
            Gtk4LayerShell.set_margin(self, Gtk4LayerShell.Edge.LEFT, new_x)
    
    def _on_drag_end(self, gesture, offset_x, offset_y):
        self.is_dragging = False
        self.set_cursor(Gdk.Cursor.new_from_name("grab"))
        
        self.current_x = max(0, int(self.drag_origin_x + offset_x))
        self.current_y = max(0, int(self.drag_origin_y + offset_y))
        
        self._save_config()
    
    def _initial_update(self):
        self.update_weather()
        return False
    
    def update_weather(self) -> bool:
        """Update weather data"""
        success = False
        
        try:
            current_data = self._fetch_wttr()
            forecast_data = self._fetch_open_meteo()
            
            if current_data or forecast_data:
                self._display_weather(current_data, forecast_data)
                self._save_cache(current_data, forecast_data)
                success = True
        except Exception as e:
            print(f"[Weather] Update error: {e}")
        
        if not success:
            self._load_cache()
        
        return True
    
    def _fetch_wttr(self) -> dict:
        try:
            url = f'wttr.in/{self.location}?format=j1'
            result = subprocess.run(
                ['curl', '-s', '--connect-timeout', '5', url],
                capture_output=True, text=True, timeout=10
            )
            
            if result.returncode == 0 and result.stdout.strip():
                data = json.loads(result.stdout)
                if not self.lat or not self.lon:
                    try:
                        self.lat = data['nearest_area'][0]['latitude']
                        self.lon = data['nearest_area'][0]['longitude']
                    except:
                        pass
                return data
        except Exception as e:
            print(f"[Weather] wttr.in error: {e}")
        return None
    
    def _fetch_open_meteo(self) -> dict:
        if not self.lat or not self.lon:
            self.lat = "14.5995"
            self.lon = "120.9842"
        
        try:
            url = (
                f"https://api.open-meteo.com/v1/forecast?"
                f"latitude={self.lat}&longitude={self.lon}"
                f"&current=temperature_2m,relative_humidity_2m,apparent_temperature,"
                f"weather_code,wind_speed_10m"
                f"&daily=weather_code,temperature_2m_max,temperature_2m_min"
                f"&timezone=auto&forecast_days=7"
            )
            
            result = subprocess.run(
                ['curl', '-s', '--connect-timeout', '5', url],
                capture_output=True, text=True, timeout=10
            )
            
            if result.returncode == 0 and result.stdout.strip():
                return json.loads(result.stdout)
        except Exception as e:
            print(f"[Weather] Open-Meteo error: {e}")
        return None
    
    def _get_day_name(self, index: int, date_str: str = None) -> str:
        days_short = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        
        if date_str:
            try:
                date_obj = datetime.datetime.strptime(date_str, '%Y-%m-%d')
                day_of_week = date_obj.weekday()
                day_name = days_short[day_of_week]
            except:
                today = datetime.datetime.now()
                day_of_week = (today.weekday() + index) % 7
                day_name = days_short[day_of_week]
        else:
            today = datetime.datetime.now()
            day_of_week = (today.weekday() + index) % 7
            day_name = days_short[day_of_week]
        
        if index == 0:
            return "Today"
        else:
            return day_name
    
    def _display_weather(self, wttr_data: dict, meteo_data: dict):
        try:
            # Current weather
            if wttr_data and 'current_condition' in wttr_data:
                current = wttr_data['current_condition'][0]
                
                self.temp_label.set_text(f"{current.get('temp_C', '--')}°C")
                self.condition_label.set_text(current.get('weatherDesc', [{}])[0].get('value', 'Unknown'))
                self.weather_icon.set_text(self._get_wttr_icon(current.get('weatherCode', '113')))
                
                self.feels_value.set_text(f"{current.get('FeelsLikeC', '--')}°")
                self.humidity_value.set_text(f"{current.get('humidity', '--')}%")
                self.wind_value.set_text(f"{current.get('windspeedKmph', '--')}km/h")
                
                try:
                    loc = wttr_data['nearest_area'][0]['areaName'][0]['value']
                    self.location_label.set_text(loc)
                except:
                    self.location_label.set_text(self.location)
            
            elif meteo_data and 'current' in meteo_data:
                current = meteo_data['current']
                
                temp = round(current.get('temperature_2m', 0))
                self.temp_label.set_text(f"{temp}°C")
                
                code = str(current.get('weather_code', 0))
                self.weather_icon.set_text(self._get_wmo_icon(code))
                self.condition_label.set_text(self._get_wmo_condition(code))
                
                self.feels_value.set_text(f"{round(current.get('apparent_temperature', 0))}°")
                self.humidity_value.set_text(f"{current.get('relative_humidity_2m', '--')}%")
                self.wind_value.set_text(f"{round(current.get('wind_speed_10m', 0))}km/h")
                
                self.location_label.set_text(self.location)
            
            # 7-day forecast
            if meteo_data and 'daily' in meteo_data:
                daily = meteo_data['daily']
                
                for i in range(min(7, len(daily.get('time', [])))):
                    if i >= len(self.forecast_days):
                        break
                    
                    forecast = self.forecast_days[i]
                    date_str = daily['time'][i]
                    
                    day_name = self._get_day_name(i, date_str)
                    forecast['day'].set_text(day_name)
                    
                    wmo_code = str(daily.get('weather_code', [0])[i])
                    forecast['icon'].set_text(self._get_wmo_icon(wmo_code))
                    
                    max_t = round(daily.get('temperature_2m_max', [0])[i])
                    min_t = round(daily.get('temperature_2m_min', [0])[i])
                    forecast['temp'].set_text(f"{max_t}°/{min_t}°")
            
            now = datetime.datetime.now().strftime("%H:%M")
            self.updated_label.set_text(f"Updated {now}")
            
        except Exception as e:
            print(f"[Weather] Display error: {e}")
    
    def _save_cache(self, wttr_data: dict, meteo_data: dict):
        try:
            cache = {
                'timestamp': datetime.datetime.now().isoformat(),
                'location': self.location,
                'lat': self.lat,
                'lon': self.lon,
                'wttr': wttr_data,
                'meteo': meteo_data
            }
            CACHE_FILE.write_text(json.dumps(cache, indent=2))
        except Exception as e:
            print(f"[Weather] Cache save error: {e}")
    
    def _load_cache(self) -> bool:
        try:
            if not CACHE_FILE.exists():
                return False
            
            cache = json.loads(CACHE_FILE.read_text())
            timestamp = datetime.datetime.fromisoformat(cache['timestamp'])
            age = (datetime.datetime.now() - timestamp).total_seconds()
            
            if age > CACHE_MAX_AGE:
                return False
            
            self._display_weather(cache.get('wttr'), cache.get('meteo'))
            cache_time = timestamp.strftime("%H:%M")
            self.updated_label.set_text(f"Cached from {cache_time}")
            return True
        except Exception as e:
            print(f"[Weather] Cache load error: {e}")
            return False
    
    def _get_wttr_icon(self, code) -> str:
        icons = {
            '113': '☀️', '116': '⛅', '119': '☁️', '122': '☁️',
            '143': '🌫️', '176': '🌦️', '179': '🌨️', '182': '🌨️',
            '185': '🌨️', '200': '⛈️', '227': '🌨️', '230': '❄️',
            '248': '🌫️', '260': '🌫️', '263': '🌧️', '266': '🌧️',
            '281': '🌧️', '284': '🌧️', '293': '🌧️', '296': '🌧️',
            '299': '🌧️', '302': '🌧️', '305': '🌧️', '308': '🌧️',
            '311': '🌧️', '314': '🌧️', '317': '🌨️', '320': '🌨️',
            '323': '🌨️', '326': '🌨️', '329': '❄️', '332': '❄️',
            '335': '❄️', '338': '❄️', '350': '🌨️', '353': '🌧️',
            '356': '🌧️', '359': '🌧️', '362': '🌨️', '365': '🌨️',
            '368': '🌨️', '371': '❄️', '374': '🌨️', '377': '🌨️',
            '386': '⛈️', '389': '⛈️', '392': '⛈️', '395': '❄️'
        }
        return icons.get(str(code), '🌡️')
    
    def _get_wmo_icon(self, code) -> str:
        icons = {
            '0': '☀️', '1': '🌤️', '2': '⛅', '3': '☁️',
            '45': '🌫️', '48': '🌫️',
            '51': '🌧️', '53': '🌧️', '55': '🌧️',
            '56': '🌧️', '57': '🌧️',
            '61': '🌧️', '63': '🌧️', '65': '🌧️',
            '66': '🌧️', '67': '🌧️',
            '71': '🌨️', '73': '🌨️', '75': '❄️', '77': '🌨️',
            '80': '🌦️', '81': '🌦️', '82': '🌧️',
            '85': '🌨️', '86': '❄️',
            '95': '⛈️', '96': '⛈️', '99': '⛈️'
        }
        return icons.get(str(code), '🌡️')
    
    def _get_wmo_condition(self, code) -> str:
        conditions = {
            '0': 'Clear sky', '1': 'Mainly clear', '2': 'Partly cloudy', '3': 'Overcast',
            '45': 'Fog', '48': 'Depositing fog',
            '51': 'Light drizzle', '53': 'Drizzle', '55': 'Heavy drizzle',
            '61': 'Light rain', '63': 'Rain', '65': 'Heavy rain',
            '71': 'Light snow', '73': 'Snow', '75': 'Heavy snow',
            '80': 'Light showers', '81': 'Showers', '82': 'Heavy showers',
            '95': 'Thunderstorm', '96': 'Thunderstorm with hail', '99': 'Heavy thunderstorm'
        }
        return conditions.get(str(code), 'Unknown')


def main():
    app = Gtk.Application(application_id="com.hypr.widget.weather")
    
    def on_activate(app):
        widget = WeatherWidget(app)
        widget.present()
    
    app.connect("activate", on_activate)
    app.run(None)


if __name__ == "__main__":
    main()