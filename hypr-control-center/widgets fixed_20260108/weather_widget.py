#!/usr/bin/env python3
# ~/.config/hypr-control-center/widgets/weather_widget.py
"""
Weather Widget - Auto-detect location, no API key needed
Uses wttr.in (free, no registration)
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib
import json
import subprocess
from base_widget import BaseWidget
from pathlib import Path

class WeatherWidget(BaseWidget):
    def __init__(self):
        super().__init__("weather")
        
        # Auto-detect location
        self.location = self.detect_location()
        print(f"[weather] 📍 Detected location: {self.location}")
        
        # Create main container
        main_container = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        main_container.add_css_class("widget-container")
        main_container.add_css_class("weather-widget")
        
        # Current Weather Section
        current_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        current_box.add_css_class("weather-current")
        
        # Header
        header_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=15)
        header_box.set_halign(Gtk.Align.CENTER)
        
        self.weather_icon = Gtk.Label()
        self.weather_icon.add_css_class("weather-icon-main")
        header_box.append(self.weather_icon)
        
        temp_location_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        
        self.temp_label = Gtk.Label()
        self.temp_label.add_css_class("temp-label-main")
        self.temp_label.set_halign(Gtk.Align.START)
        temp_location_box.append(self.temp_label)
        
        self.location_label = Gtk.Label()
        self.location_label.add_css_class("location-label")
        self.location_label.set_halign(Gtk.Align.START)
        temp_location_box.append(self.location_label)
        
        header_box.append(temp_location_box)
        current_box.append(header_box)
        
        self.condition_label = Gtk.Label()
        self.condition_label.add_css_class("condition-label")
        self.condition_label.set_halign(Gtk.Align.CENTER)
        current_box.append(self.condition_label)
        
        # Details grid
        details_grid = Gtk.Grid()
        details_grid.set_column_spacing(20)
        details_grid.set_row_spacing(5)
        details_grid.set_halign(Gtk.Align.CENTER)
        details_grid.add_css_class("weather-details-grid")
        
        # Feels Like
        feels_icon = Gtk.Label(label="🌡️")
        feels_icon.add_css_class("detail-icon")
        details_grid.attach(feels_icon, 0, 0, 1, 1)
        
        feels_label = Gtk.Label(label="Feels Like")
        feels_label.add_css_class("detail-title")
        details_grid.attach(feels_label, 0, 1, 1, 1)
        
        self.feels_value = Gtk.Label()
        self.feels_value.add_css_class("detail-value")
        details_grid.attach(self.feels_value, 0, 2, 1, 1)
        
        # Humidity
        humidity_icon = Gtk.Label(label="💧")
        humidity_icon.add_css_class("detail-icon")
        details_grid.attach(humidity_icon, 1, 0, 1, 1)
        
        humidity_label = Gtk.Label(label="Humidity")
        humidity_label.add_css_class("detail-title")
        details_grid.attach(humidity_label, 1, 1, 1, 1)
        
        self.humidity_value = Gtk.Label()
        self.humidity_value.add_css_class("detail-value")
        details_grid.attach(self.humidity_value, 1, 2, 1, 1)
        
        # Wind
        wind_icon = Gtk.Label(label="💨")
        wind_icon.add_css_class("detail-icon")
        details_grid.attach(wind_icon, 2, 0, 1, 1)
        
        wind_label = Gtk.Label(label="Wind")
        wind_label.add_css_class("detail-title")
        details_grid.attach(wind_label, 2, 1, 1, 1)
        
        self.wind_value = Gtk.Label()
        self.wind_value.add_css_class("detail-value")
        details_grid.attach(self.wind_value, 2, 2, 1, 1)
        
        current_box.append(details_grid)
        main_container.append(current_box)
        
        # Separator
        separator = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        separator.add_css_class("weather-separator")
        main_container.append(separator)
        
        # Forecast title
        forecast_title = Gtk.Label(label="7-Day Forecast")
        forecast_title.add_css_class("forecast-title")
        forecast_title.set_halign(Gtk.Align.START)
        forecast_title.set_margin_top(15)
        forecast_title.set_margin_bottom(10)
        main_container.append(forecast_title)
        
        # Forecast grid
        self.forecast_grid = Gtk.Grid()
        self.forecast_grid.set_column_spacing(8)
        self.forecast_grid.add_css_class("forecast-grid")
        main_container.append(self.forecast_grid)
        
        # Create forecast day boxes
        self.forecast_days = []
        for i in range(7):
            day_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
            day_box.add_css_class("forecast-day")
            
            day_label = Gtk.Label()
            day_label.add_css_class("forecast-day-label")
            day_box.append(day_label)
            
            icon_label = Gtk.Label()
            icon_label.add_css_class("forecast-icon")
            day_box.append(icon_label)
            
            temp_label = Gtk.Label()
            temp_label.add_css_class("forecast-temp")
            day_box.append(temp_label)
            
            self.forecast_grid.attach(day_box, i, 0, 1, 1)
            self.forecast_days.append({
                'day': day_label,
                'icon': icon_label,
                'temp': temp_label
            })
        
        self.set_child(main_container)
        
        # Update weather immediately, then hourly
        self.update_weather()
        GLib.timeout_add_seconds(3600, self.update_weather)  # Every hour
        
    def detect_location(self):
        """Auto-detect location from IP"""
        try:
            # Try to get location from IP
            result = subprocess.run(
                ['curl', '-s', 'https://ipapi.co/city/'],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0 and result.stdout.strip():
                city = result.stdout.strip()
                if city and len(city) < 50:  # Sanity check
                    return city
        except:
            pass
        
        # Fallback: try timezone-based detection
        try:
            import subprocess
            result = subprocess.run(
                ['timedatectl', 'show', '--property=Timezone', '--value'],
                capture_output=True,
                text=True,
                timeout=2
            )
            if result.returncode == 0:
                timezone = result.stdout.strip()
                # Extract city from timezone (e.g., "Asia/Manila" -> "Manila")
                if '/' in timezone:
                    return timezone.split('/')[-1]
        except:
            pass
            
        # Ultimate fallback
        return "Manila"
        
    def update_weather(self):
        """Fetch weather from wttr.in (no API key needed)"""
        try:
            # Use wttr.in with JSON format
            url = f"wttr.in/{self.location}?format=j1"
            
            result = subprocess.run(
                ['curl', '-s', url],
                capture_output=True,
                text=True,
                timeout=10
            )
            
            if result.returncode == 0 and result.stdout.strip():
                data = json.loads(result.stdout)
                self.display_weather(data)
                print(f"[weather] ✅ Updated for {self.location}")
            else:
                self.show_error("Connection error")
                
        except Exception as e:
            print(f"[weather] ❌ Error: {e}")
            self.show_error("Update failed")
            
        return True
        
    def display_weather(self, data):
        """Display weather data"""
        try:
            current = data['current_condition'][0]
            
            # Location - use nearest area or detected location
            try:
                location = data['nearest_area'][0]['areaName'][0]['value']
            except:
                location = self.location
            self.location_label.set_text(location)
            
            # Temperature
            temp = current['temp_C']
            self.temp_label.set_text(f"{temp}°C")
            
            # Feels like
            feels_like = current['FeelsLikeC']
            self.feels_value.set_text(f"{feels_like}°C")
            
            # Condition
            condition = current['weatherDesc'][0]['value']
            self.condition_label.set_text(condition)
            
            # Weather icon
            weather_code = current['weatherCode']
            self.weather_icon.set_text(self.get_weather_icon(weather_code))
            
            # Humidity
            humidity = current['humidity']
            self.humidity_value.set_text(f"{humidity}%")
            
            # Wind
            wind_kmh = current['windspeedKmph']
            self.wind_value.set_text(f"{wind_kmh} km/h")
            
            # 7-day forecast
            weather_data = data.get('weather', [])
            days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
            
            import datetime
            today = datetime.datetime.now()
            
            for i, day_data in enumerate(weather_data[:7]):
                if i < len(self.forecast_days):
                    forecast = self.forecast_days[i]
                    
                    # Day name
                    day_num = (today.weekday() + i + 1) % 7
                    forecast['day'].set_text(days[day_num])
                    
                    # Weather icon (use midday forecast)
                    try:
                        hourly = day_data['hourly'][4]  # Around noon
                        code = hourly['weatherCode']
                    except:
                        code = day_data['hourly'][0]['weatherCode']
                    forecast['icon'].set_text(self.get_weather_icon(code))
                    
                    # Temperature range
                    max_temp = day_data['maxtempC']
                    min_temp = day_data['mintempC']
                    forecast['temp'].set_text(f"{max_temp}°/{min_temp}°")
            
        except Exception as e:
            print(f"[weather] ❌ Display error: {e}")
            self.show_error("Display error")
        
    def get_weather_icon(self, code):
        """Get weather emoji based on code"""
        icons = {
            '113': '☀️',  '116': '⛅',  '119': '☁️',  '122': '☁️',
            '143': '🌫️',  '176': '🌦️',  '179': '🌨️',  '182': '🌨️',
            '185': '🌨️',  '200': '⛈️',  '227': '🌨️',  '230': '🌨️',
            '248': '🌫️',  '260': '🌫️',  '263': '🌧️',  '266': '🌧️',
            '281': '🌧️',  '284': '🌧️',  '293': '🌧️',  '296': '🌧️',
            '299': '🌧️',  '302': '🌧️',  '305': '🌧️',  '308': '🌧️',
            '311': '🌧️',  '314': '🌧️',  '317': '🌨️',  '320': '🌨️',
            '323': '🌨️',  '326': '🌨️',  '329': '🌨️',  '332': '🌨️',
            '335': '🌨️',  '338': '🌨️',  '350': '🌧️',  '353': '🌧️',
            '356': '🌧️',  '359': '🌧️',  '362': '🌨️',  '365': '🌨️',
            '368': '🌨️',  '371': '🌨️',  '374': '🌨️',  '377': '🌨️',
            '386': '⛈️',  '389': '⛈️',  '392': '⛈️',  '395': '⛈️'
        }
        return icons.get(code, '🌡️')
        
    def show_error(self, msg):
        """Show error state"""
        self.location_label.set_text("Weather Error")
        self.weather_icon.set_text("❌")
        self.temp_label.set_text("--°C")
        self.condition_label.set_text(msg)
        self.feels_value.set_text("--°C")
        self.humidity_value.set_text("--%")
        self.wind_value.set_text("--")

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