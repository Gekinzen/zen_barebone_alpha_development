#!/usr/bin/env python3
"""
Weather Widget - Compact 380x240 Design
Data Sources: wttr.in (current) + Open-Meteo (7-day forecast)
Features:
  - Auto-detect location via IP
  - 7-day forecast: Today, [Tomorrow's Day], then 5 more days
  - Local JSON cache for offline fallback
  - Updates every 30 minutes
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib
import json
import subprocess
import datetime
from pathlib import Path
from base_widget import BaseWidget


CACHE_FILE = Path.home() / ".cache/hypr-widgets/weather_cache.json"
CACHE_MAX_AGE = 3600 * 6  # 6 hours


class WeatherWidget(BaseWidget):
    def __init__(self):
        super().__init__("weather")
        
        CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
        
        self.location = self.detect_location()
        self.lat = None
        self.lon = None
        
        self._build_ui()
        self._load_cache()
        
        GLib.timeout_add(500, self._initial_update)
        GLib.timeout_add_seconds(1800, self.update_weather)
    
    def _build_ui(self):
        main = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        main.add_css_class("widget-container")
        main.add_css_class("weather-compact")
        main.set_size_request(380, 240)
        
        # Top section: Temp + Location + Stats
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
    
    def detect_location(self) -> str:
        try:
            result = subprocess.run(
                ['curl', '-s', '--connect-timeout', '3', 'https://ipapi.co/json/'],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0 and result.stdout.strip():
                data = json.loads(result.stdout)
                city = data.get('city', '')
                if city:
                    self.lat = data.get('latitude')
                    self.lon = data.get('longitude')
                    return city
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
                    self.lat = data.get('lat')
                    self.lon = data.get('lon')
                    return city
        except:
            pass
        
        return "Manila"
    
    def _initial_update(self):
        self.update_weather()
        return False
    
    def update_weather(self) -> bool:
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
        """
        Get proper day name:
        - Index 0: "Today"
        - Index 1+: Actual day name (Sat, Sun, Mon, etc.)
        
        No "Tomorrow" label - just show the actual day so it's clear!
        """
        days_short = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        
        if date_str:
            try:
                date_obj = datetime.datetime.strptime(date_str, '%Y-%m-%d')
                day_of_week = date_obj.weekday()  # 0=Monday, 6=Sunday
                day_name = days_short[day_of_week]
            except:
                today = datetime.datetime.now()
                day_of_week = (today.weekday() + index) % 7
                day_name = days_short[day_of_week]
        else:
            today = datetime.datetime.now()
            day_of_week = (today.weekday() + index) % 7
            day_name = days_short[day_of_week]
        
        # Only "Today" for index 0, rest show actual day name
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
            
            # 7-day forecast from Open-Meteo
            if meteo_data and 'daily' in meteo_data:
                daily = meteo_data['daily']
                
                for i in range(min(7, len(daily.get('time', [])))):
                    if i >= len(self.forecast_days):
                        break
                    
                    forecast = self.forecast_days[i]
                    date_str = daily['time'][i]
                    
                    # Get proper day name
                    day_name = self._get_day_name(i, date_str)
                    forecast['day'].set_text(day_name)
                    
                    # Weather icon
                    wmo_code = str(daily.get('weather_code', [0])[i])
                    forecast['icon'].set_text(self._get_wmo_icon(wmo_code))
                    
                    # Temps
                    max_t = round(daily.get('temperature_2m_max', [0])[i])
                    min_t = round(daily.get('temperature_2m_min', [0])[i])
                    forecast['temp'].set_text(f"{max_t}°/{min_t}°")
            
            elif wttr_data and 'weather' in wttr_data:
                # Fallback to wttr.in (only 3 days available)
                for i in range(7):
                    if i >= len(self.forecast_days):
                        break
                    
                    forecast = self.forecast_days[i]
                    
                    if i < len(wttr_data['weather']):
                        day_data = wttr_data['weather'][i]
                        date_str = day_data.get('date', '')
                        
                        day_name = self._get_day_name(i, date_str)
                        forecast['day'].set_text(day_name)
                        
                        try:
                            code = day_data['hourly'][4]['weatherCode']
                        except:
                            code = day_data.get('hourly', [{}])[0].get('weatherCode', '113')
                        
                        forecast['icon'].set_text(self._get_wttr_icon(code))
                        forecast['temp'].set_text(f"{day_data['maxtempC']}°/{day_data['mintempC']}°")
                    else:
                        # No data for this day
                        day_name = self._get_day_name(i)
                        forecast['day'].set_text(day_name)
                        forecast['icon'].set_text("❓")
                        forecast['temp'].set_text("--/--")
            
            # Update timestamp
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
        widget = WeatherWidget()
        widget.set_application(app)
        widget.present()
    
    app.connect("activate", on_activate)
    app.run(None)


if __name__ == "__main__":
    main()