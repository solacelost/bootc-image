#!/usr/bin/env python

import json
import requests
from datetime import datetime

WEATHER_CODES = {
    "113": "☀️",  # Clear, Sunny
    "116": "⛅️",  # Partly cloudy
    "119": "☁️",  # Cloudy
    "122": "☁️",  # Overcast
    "143": "🌫",  # Mist
    "176": "🌦",  # Patchy rain possible
    "179": "🌧",  # Patchy snow possible
    "182": "🌧",  # Patchy sleet possible
    "185": "🌧",  # Patchy freezing drizzle possible
    "200": "⛈",  # Thundery outbreaks possible
    "227": "🌨",  # Blowing snow
    "230": "❄️",  # Blizzard
    "248": "🌫",  # Fog
    "260": "🌫",  # Freezing fog
    "263": "🌦",  # Patchy light drizzle
    "266": "🌦",  # Light drizzle
    "281": "🌧",  # Freezing drizzle
    "284": "🌧",  # Heavy freezing drizzle
    "293": "🌦",  # Patchy light rain
    "296": "🌦",  # Light rain
    "299": "🌧",  # Light freezing rain
    "302": "🌧",  # Moderate rain
    "305": "🌧",  # Heavy rain at times
    "308": "🌧",  # Heavy rain
    "311": "🌧",  # Light freezing rain
    "314": "🌧",  # Moderate or heavy freezing rain
    "317": "🌧",  # Light sleet
    "320": "🌨️",  # Moderate or heavy sleet
    "323": "🌨",  # Patchy light snow
    "326": "🌨",  # Light snow
    "329": "❄️",  # Patchy moderate snow
    "332": "❄️",  # Moderate snow
    "335": "❄️",  # Patchy heavy snow
    "338": "❄️",  # Heavy snow
    "350": "🌧",  # Ice pellets
    "353": "🌦",  # Light rain shower
    "356": "🌧",  # Moderate or heavy rain shower
    "359": "🌧",  # Torrential rain shower
    "362": "🌧",  # Light sleet showers
    "365": "🌧",  # Moderate or heavy sleet showers
    "368": "🌨",  # Light snow showers
    "371": "❄️",  # Moderate or heavy snow showers
    "374": "🌧",  # Light sleet showers
    "377": "🌧",  # Light sleet
    "386": "⛈",  # Patchy light rain with thunder
    "389": "🌩",  # Moderate or heavy rain with thunder
    "392": "⛈",  # Patchy light snow with thunder
    "395": "❄️",  # Moderate or heavy snow with thunder
}

data = {}


weather = requests.get("https://wttr.in/?format=j1&F").json()


def format_time(time):
    return time.replace("00", "").zfill(2)


def format_temp(temp):
    return (hour["FeelsLikeF"] + "°").ljust(3)


def format_chances(hour):
    chances = {
        "chanceoffog": "Fog",
        "chanceoffrost": "Frost",
        "chanceofovercast": "Overcast",
        "chanceofrain": "Rain",
        "chanceofsnow": "Snow",
        "chanceofsunshine": "Sunshine",
        "chanceofthunder": "Thunder",
        "chanceofwindy": "Wind",
    }

    conditions = []
    for event in chances.keys():
        if int(hour[event]) > 0:
            conditions.append(chances[event] + " " + hour[event] + "%")
    return ", ".join(conditions)


data["text"] = (
    WEATHER_CODES[weather["current_condition"][0]["weatherCode"]]
    + " "
    + weather["current_condition"][0]["FeelsLikeF"]
    + "°"
)

data["tooltip"] = (
    f"<b>{weather['current_condition'][0]['weatherDesc'][0]['value']} {weather['current_condition'][0]['temp_F']}°</b>\n"
)
data["tooltip"] += f"Feels like: {weather['current_condition'][0]['FeelsLikeF']}°\n"
data["tooltip"] += f"Wind: {weather['current_condition'][0]['windspeedMiles']}Km/h\n"
data["tooltip"] += f"Humidity: {weather['current_condition'][0]['humidity']}%\n"
for i, day in enumerate(weather["weather"]):
    data["tooltip"] += "\n<b>"
    if i == 0:
        data["tooltip"] += "Today, "
    if i == 1:
        data["tooltip"] += "Tomorrow, "
    data["tooltip"] += f"{day['date']}</b>\n"
    data["tooltip"] += f"⬆️ {day['maxtempF']}° ⬇️ {day['mintempF']}° "
    data["tooltip"] += (
        f"🌅 {day['astronomy'][0]['sunrise']} 🌇 {day['astronomy'][0]['sunset']}\n"
    )
    for hour in day["hourly"]:
        if i == 0:
            if int(format_time(hour["time"])) < datetime.now().hour - 2:
                continue
        data["tooltip"] += (
            f"{format_time(hour['time'])} {WEATHER_CODES[hour['weatherCode']]} {format_temp(hour['FeelsLikeF'])} {hour['weatherDesc'][0]['value']}, {format_chances(hour)}\n"
        )


print(json.dumps(data))
