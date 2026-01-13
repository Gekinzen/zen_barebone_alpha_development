#!/usr/bin/env python3
"""
Weather Widget - Compact 360x220 Design
Clean, minimal, inspired by mobile weather apps
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib
import json
import subprocess
from base_widget import BaseWidget


class WeatherWidget(BaseWidget):
    def __init__(self):
        super().__init__("weather")
        
        # Auto-detect location
        self.location = self.detect_location()
        
        # Main container - COMPACT
        main = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        main.add_css_class("widget-container")
        main.add_css_class("weather-compact")
        main.set_size_request(360, 220)
        
        # Top section: Temp + Location
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
        
        self.temp_label = Gtk.Label()
        self.temp_label.add_css_class("temp-compact")
        self.temp_label.set_halign(Gtk.Align.START)
        temp_box.append(self.temp_label)
        
        self.location_label = Gtk.Label()
        self.location_label.add_css_class("location-compact")
        self.location_label.set_halign(Gtk.Align.START)
        temp_box.append(self.location_label)
        
        left_box.append(temp_box)
        top.append(left_box)
        
        # Spacer
        spacer = Gtk.Box()
        spacer.set_hexpand(True)
        top.append(spacer)
        
        # Right: Vertical stats (Feels, Humidity, Wind)
        stats_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        
        # Feels Like
        feels_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        feels_icon = Gtk.Label(label="🌡️")
        feels_icon.add_css_class("stat-icon-tiny")
        feels_row.append(feels_icon)
        self.feels_value = Gtk.Label()
        self.feels_value.add_css_class("stat-value-tiny")
        feels_row.append(self.feels_value)
        stats_box.append(feels_row)
        
        # Humidity
        humid_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        humid_icon = Gtk.Label(label="💧")
        humid_icon.add_css_class("stat-icon-tiny")
        humid_row.append(humid_icon)
        self.humidity_value = Gtk.Label()
        self.humidity_value.add_css_class("stat-value-tiny")
        humid_row.append(self.humidity_value)
        stats_box.append(humid_row)
        
        # Wind
        wind_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=6)
        wind_icon = Gtk.Label(label="💨")
        wind_icon.add_css_class("stat-icon-tiny")
        wind_row.append(wind_icon)
        self.wind_value = Gtk.Label()
        self.wind_value.add_css_class("stat-value-tiny")
        wind_row.append(self.wind_value)
        stats_box.append(wind_row)
        
        top.append(stats_box)
        main.append(top)
        
        # Condition
        self.condition_label = Gtk.Label()
        self.condition_label.add_css_class("condition-compact")
        self.condition_label.set_margin_start(18)
        self.condition_label.set_margin_top(5)
        self.condition_label.set_halign(Gtk.Align.START)
        main.append(self.condition_label)
        
        # Separator
        sep = Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL)
        sep.add_css_class("weather-sep")
        sep.set_margin_start(18)
        sep.set_margin_end(18)
        sep.set_margin_top(12)
        sep.set_margin_bottom(8)
        main.append(sep)
        
        # 7-day forecast (horizontal, compact)
        forecast_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=4)
        forecast_box.set_margin_start(12)
        forecast_box.set_margin_end(12)
        forecast_box.set_margin_bottom(12)
        forecast_box.set_halign(Gtk.Align.CENTER)
        
        self.forecast_days = []
        for i in range(7):
            day_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            day_box.add_css_class("forecast-day-compact")
            
            day_label = Gtk.Label()
            day_label.add_css_class("forecast-day-name")
            day_box.append(day_label)
            
            icon_label = Gtk.Label()
            icon_label.add_css_class("forecast-icon-compact")
            day_box.append(icon_label)
            
            temp_label = Gtk.Label()
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
        
        # Update
        self.update_weather()
        GLib.timeout_add_seconds(3600, self.update_weather)
    
    def detect_location(self):
        """Auto-detect location"""
        try:
            result = subprocess.run(
                ['curl', '-s', 'https://ipapi.co/city/'],
                capture_output=True, text=True, timeout=5
            )
            if result.returncode == 0 and result.stdout.strip():
                return result.stdout.strip()
        except:
            pass
        return "Manila"
    
    def update_weather(self):
        """Fetch weather"""
        try:
            result = subprocess.run(
                ['curl', '-s', f'wttr.in/{self.location}?format=j1'],
                capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0 and result.stdout.strip():
                data = json.loads(result.stdout)
                self.display_weather(data)
        except:
            pass
        return True
    
    def display_weather(self, data):
        """Display weather"""
        try:
            current = data['current_condition'][0]
            
            # Temp
            self.temp_label.set_text(f"{current['temp_C']}°C")
            
            # Location
            try:
                location = data['nearest_area'][0]['areaName'][0]['value']
            except:
                location = self.location
            self.location_label.set_text(location)
            
            # Condition
            self.condition_label.set_text(current['weatherDesc'][0]['value'])
            
            # Icon
            self.weather_icon.set_text(self.get_weather_icon(current['weatherCode']))
            
            # Stats
            self.feels_value.set_text(f"{current['FeelsLikeC']}°")
            self.humidity_value.set_text(f"{current['humidity']}%")
            self.wind_value.set_text(f"{current['windspeedKmph']}km/h")
            
            # 7-day forecast
            import datetime
            today = datetime.datetime.now()
            days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
            
            for i, day_data in enumerate(data.get('weather', [])[:7]):
                if i < len(self.forecast_days):
                    forecast = self.forecast_days[i]
                    day_num = (today.weekday() + i + 1) % 7
                    forecast['day'].set_text(days[day_num])
                    
                    try:
                        code = day_data['hourly'][4]['weatherCode']
                    except:
                        code = day_data['hourly'][0]['weatherCode']
                    forecast['icon'].set_text(self.get_weather_icon(code))
                    forecast['temp'].set_text(f"{day_data['maxtempC']}°/{day_data['mintempC']}°")
        except:
            pass
    
    def get_weather_icon(self, code):
        """Weather emoji"""
        icons = {
            '113': '☀️', '116': '⛅', '119': '☁️', '122': '☁️',
            '143': '🌫️', '176': '🌦️', '179': '🌨️', '182': '🌨️',
            '200': '⛈️', '263': '🌧️', '296': '🌧️', '302': '🌧️'
        }
        return icons.get(code, '🌡️')


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