#!/usr/bin/env python3
"""
Weather Widget - Compact 360x220 Design
Clean, minimal, inspired by mobile weather apps
Fixed: Proper 7-day forecast display
"""

import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib
import json
import subprocess
import datetime
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
        """Fetch weather - Use Open-Meteo for 7-day forecast"""
        try:
            # First get coordinates from wttr.in
            result = subprocess.run(
                ['curl', '-s', f'wttr.in/{self.location}?format=j1'],
                capture_output=True, text=True, timeout=10
            )
            
            if result.returncode == 0 and result.stdout.strip():
                wttr_data = json.loads(result.stdout)
                
                # Get coordinates for Open-Meteo
                try:
                    lat = wttr_data['nearest_area'][0]['latitude']
                    lon = wttr_data['nearest_area'][0]['longitude']
                except:
                    lat, lon = "14.5995", "120.9842"  # Manila fallback
                
                # Fetch 7-day forecast from Open-Meteo (free, no API key needed)
                meteo_url = (
                    f"https://api.open-meteo.com/v1/forecast?"
                    f"latitude={lat}&longitude={lon}"
                    f"&daily=weather_code,temperature_2m_max,temperature_2m_min"
                    f"&timezone=auto&forecast_days=7"
                )
                
                meteo_result = subprocess.run(
                    ['curl', '-s', meteo_url],
                    capture_output=True, text=True, timeout=10
                )
                
                forecast_data = None
                if meteo_result.returncode == 0 and meteo_result.stdout.strip():
                    try:
                        forecast_data = json.loads(meteo_result.stdout)
                    except:
                        pass
                
                self.display_weather(wttr_data, forecast_data)
        except Exception as e:
            print(f"Weather update error: {e}")
        return True
    
    def display_weather(self, wttr_data, forecast_data=None):
        """Display weather with proper 7-day forecast"""
        try:
            current = wttr_data['current_condition'][0]
            
            # Temp
            self.temp_label.set_text(f"{current['temp_C']}°C")
            
            # Location
            try:
                location = wttr_data['nearest_area'][0]['areaName'][0]['value']
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
            
            # 7-day forecast from Open-Meteo
            days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
            today = datetime.datetime.now()
            
            if forecast_data and 'daily' in forecast_data:
                daily = forecast_data['daily']
                for i in range(min(7, len(daily.get('time', [])))):
                    if i < len(self.forecast_days):
                        forecast = self.forecast_days[i]
                        
                        # Parse date to get day name
                        try:
                            date_str = daily['time'][i]
                            date_obj = datetime.datetime.strptime(date_str, '%Y-%m-%d')
                            day_name = days[date_obj.weekday()]
                            
                            # Mark today
                            if i == 0:
                                day_name = "Today"
                        except:
                            day_name = days[(today.weekday() + i) % 7]
                        
                        forecast['day'].set_text(day_name)
                        
                        # Weather code from Open-Meteo
                        wmo_code = str(daily.get('weather_code', [0])[i])
                        forecast['icon'].set_text(self.get_wmo_icon(wmo_code))
                        
                        # Temps
                        max_temp = round(daily.get('temperature_2m_max', [0])[i])
                        min_temp = round(daily.get('temperature_2m_min', [0])[i])
                        forecast['temp'].set_text(f"{max_temp}°/{min_temp}°")
            else:
                # Fallback to wttr.in data (only 3 days) + placeholders
                wttr_weather = wttr_data.get('weather', [])
                
                for i in range(7):
                    if i < len(self.forecast_days):
                        forecast = self.forecast_days[i]
                        day_num = (today.weekday() + i) % 7
                        
                        if i == 0:
                            forecast['day'].set_text("Today")
                        else:
                            forecast['day'].set_text(days[day_num])
                        
                        if i < len(wttr_weather):
                            day_data = wttr_weather[i]
                            try:
                                code = day_data['hourly'][4]['weatherCode']
                            except:
                                code = day_data['hourly'][0]['weatherCode']
                            forecast['icon'].set_text(self.get_weather_icon(code))
                            forecast['temp'].set_text(f"{day_data['maxtempC']}°/{day_data['mintempC']}°")
                        else:
                            # No data available for this day
                            forecast['icon'].set_text("❓")
                            forecast['temp'].set_text("--/--")
        except Exception as e:
            print(f"Display error: {e}")
    
    def get_weather_icon(self, code):
        """Weather emoji for wttr.in codes"""
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
    
    def get_wmo_icon(self, code):
        """Weather emoji for WMO codes (Open-Meteo)"""
        wmo_icons = {
            '0': '☀️',   # Clear sky
            '1': '🌤️',   # Mainly clear
            '2': '⛅',   # Partly cloudy
            '3': '☁️',   # Overcast
            '45': '🌫️',  # Fog
            '48': '🌫️',  # Depositing rime fog
            '51': '🌧️',  # Light drizzle
            '53': '🌧️',  # Moderate drizzle
            '55': '🌧️',  # Dense drizzle
            '56': '🌧️',  # Light freezing drizzle
            '57': '🌧️',  # Dense freezing drizzle
            '61': '🌧️',  # Slight rain
            '63': '🌧️',  # Moderate rain
            '65': '🌧️',  # Heavy rain
            '66': '🌧️',  # Light freezing rain
            '67': '🌧️',  # Heavy freezing rain
            '71': '🌨️',  # Slight snow
            '73': '🌨️',  # Moderate snow
            '75': '❄️',  # Heavy snow
            '77': '🌨️',  # Snow grains
            '80': '🌦️',  # Slight rain showers
            '81': '🌦️',  # Moderate rain showers
            '82': '🌧️',  # Violent rain showers
            '85': '🌨️',  # Slight snow showers
            '86': '❄️',  # Heavy snow showers
            '95': '⛈️',  # Thunderstorm
            '96': '⛈️',  # Thunderstorm with slight hail
            '99': '⛈️',  # Thunderstorm with heavy hail
        }
        return wmo_icons.get(str(code), '🌡️')


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