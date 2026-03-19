---
name: weather
description: Check daily weather forecasts using the Open-Meteo API. Provides nuanced analysis across multiple weather dimensions — not just temperature, but comfort, UV, wind, precipitation patterns, and air quality.
---

## Context

This skill is for fetching and interpreting weather data from the free Open-Meteo API. Open-Meteo requires no API key and has generous rate limits for non-commercial use. The default location is the user's home area — ask them for coordinates if not already known, or use the Geocoding API to resolve a city name.

## Open-Meteo API Reference

Base URL: `https://api.open-meteo.com/v1/forecast`
Air Quality URL: `https://air-quality-api.open-meteo.com/v1/air-quality`
Geocoding URL: `https://geocoding-api.open-meteo.com/v1/search`

All endpoints return JSON. No authentication required.

### Geocoding (resolve city name to coordinates)

```
https://geocoding-api.open-meteo.com/v1/search?name=Warsaw&count=1&language=en
```

### Comprehensive daily forecast (7 days)

This is the primary call. Always request a wide set of variables — the goal is nuanced analysis, not just temperature.

```
https://api.open-meteo.com/v1/forecast?latitude=52.23&longitude=21.01&timezone=auto&daily=weather_code,temperature_2m_max,temperature_2m_min,apparent_temperature_max,apparent_temperature_min,sunrise,sunset,daylight_duration,sunshine_duration,uv_index_max,precipitation_sum,rain_sum,showers_sum,snowfall_sum,precipitation_hours,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant&forecast_days=7
```

### Current conditions snapshot

```
https://api.open-meteo.com/v1/forecast?latitude=52.23&longitude=21.01&timezone=auto&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,rain,showers,snowfall,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,wind_gusts_10m
```

### Hourly detail for today + tomorrow (useful for planning around specific hours)

```
https://api.open-meteo.com/v1/forecast?latitude=52.23&longitude=21.01&timezone=auto&hourly=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation_probability,precipitation,weather_code,cloud_cover,visibility,wind_speed_10m,wind_gusts_10m,uv_index,is_day&forecast_days=2
```

### Air quality forecast

```
https://air-quality-api.open-meteo.com/v1/air-quality?latitude=52.23&longitude=21.01&timezone=auto&hourly=pm10,pm2_5,carbon_monoxide,nitrogen_dioxide,ozone,uv_index,european_aqi&forecast_days=3
```

For European locations, you can add pollen data: `&hourly=...,alder_pollen,birch_pollen,grass_pollen`

## WMO Weather Codes

Use these to translate the `weather_code` field into human-readable descriptions:

| Code | Description |
|------|-------------|
| 0 | Clear sky |
| 1 | Mainly clear |
| 2 | Partly cloudy |
| 3 | Overcast |
| 45 | Fog |
| 48 | Depositing rime fog |
| 51 | Light drizzle |
| 53 | Moderate drizzle |
| 55 | Dense drizzle |
| 56 | Light freezing drizzle |
| 57 | Dense freezing drizzle |
| 61 | Slight rain |
| 63 | Moderate rain |
| 65 | Heavy rain |
| 66 | Light freezing rain |
| 67 | Heavy freezing rain |
| 71 | Slight snowfall |
| 73 | Moderate snowfall |
| 75 | Heavy snowfall |
| 77 | Snow grains |
| 80 | Slight rain showers |
| 81 | Moderate rain showers |
| 82 | Violent rain showers |
| 85 | Slight snow showers |
| 86 | Heavy snow showers |
| 95 | Thunderstorm |
| 96 | Thunderstorm with slight hail |
| 99 | Thunderstorm with heavy hail |

## How to Analyze Weather — Be Nuanced

Do NOT just report temperature and precipitation. The whole point of this skill is to think about weather the way a thoughtful person would — connecting metrics to real-world experience. Follow these principles:

### 1. Feels-like vs actual temperature

Always compare `temperature_2m` with `apparent_temperature`. A large gap tells a story:
- **Apparent much lower than actual** → wind chill is significant, it will feel colder than the number suggests. Flag this.
- **Apparent much higher than actual** → high humidity is trapping heat. Warn about discomfort.
- **Small gap** → calm, moderate humidity day. The number on the thermometer is what you'll feel.

### 2. The sunshine vs daylight ratio

Compare `sunshine_duration` to `daylight_duration`. A day might have 14 hours of daylight but only 3 hours of sunshine — that's a grey, overcast day even if it doesn't rain. Conversely, a short winter day with nearly 100% sunshine ratio feels much more pleasant than the raw hours suggest. Report this ratio and what it means.

### 3. Wind context

Raw wind speed numbers don't mean much without context:
- Below 15 km/h: calm, barely noticeable
- 15-30 km/h: breezy, you'll feel it
- 30-50 km/h: windy, affects outdoor activities and cycling
- 50-70 km/h: very windy, unsecured objects move
- Above 70 km/h: dangerous, stay alert

Also compare sustained wind vs gusts. A day with 20 km/h sustained but 55 km/h gusts is deceptive — it feels calm most of the time then hits you hard. Flag large gust-to-sustained ratios.

Mention dominant wind direction in terms the user can relate to (e.g. "from the northwest" not "315 degrees").

### 4. Precipitation patterns, not just totals

- Compare `precipitation_hours` to the total daylight hours. 2mm of rain spread across 10 hours (persistent drizzle) is a very different day from 2mm in 1 hour (a brief shower you can wait out).
- Distinguish between `rain_sum`, `showers_sum`, and `snowfall_sum` — showers are convective (hit-or-miss, often afternoon), rain is frontal (widespread, longer-lasting).
- Use `precipitation_probability_max` to gauge confidence. 30% probability with 5mm potential is a "maybe carry an umbrella" day. 90% with 5mm is a "you will get wet" day.

### 5. UV awareness

- UV Index 1-2: Low, no protection needed
- UV Index 3-5: Moderate, sunscreen recommended for extended time outside
- UV Index 6-7: High, sunscreen and hat needed, avoid midday sun
- UV Index 8-10: Very high, minimize midday outdoor time
- UV Index 11+: Extreme, avoid outdoor exposure

Mention UV even on partly cloudy days — clouds don't block all UV radiation.

### 6. Look for multi-day patterns and transitions

Don't analyze each day in isolation. Look for:
- **Temperature trends**: warming or cooling pattern across the week
- **Frontal passages**: a sharp temperature drop + wind shift + precipitation often means a cold front. Mention it.
- **Dry spells vs wet periods**: group consecutive dry or wet days
- **Weekend vs weekday**: if the user asks for a weekly forecast, highlight whether the weekend looks better or worse than workdays

### 7. Air quality connections

When air quality data is fetched, connect it to weather:
- High pressure + low wind + warm temps = potential for trapped pollutants (poor AQI)
- Rain tends to wash particulate matter out of the air (improving AQI)
- High ozone often correlates with hot sunny days
- Mention pollen data during spring/summer if available for European locations

### 8. Practical framing

End with actionable observations. Think about what a person planning their day or week actually cares about:
- Is it a good day to be outdoors? Run errands? Exercise outside?
- Should they dress in layers? Carry rain gear? Wear sunscreen?
- Any dramatic weather changes to plan around?
- Best day of the week for outdoor activities if they have flexibility?

## Fetching Data

**Important:** `curl` is NOT available in the Claude Code container. Use the **WebFetch tool** (with `format: text`) to call the Open-Meteo API endpoints directly by URL. This returns the raw JSON response which you can then analyze. Make all four API calls (current, daily, hourly, air quality) in parallel using parallel WebFetch tool calls.

Example — instead of:
```sh
# DOES NOT WORK — curl is not installed
curl -s "https://api.open-meteo.com/v1/forecast?latitude=52.23&longitude=21.01&..."
```

Use WebFetch with the full URL and `format: text` to get the JSON response directly.

## Notes

- Open-Meteo uses WGS84 coordinates (standard lat/lon). Positive latitude = north, negative = south. Positive longitude = east, negative = west.
- All timestamps are returned in the timezone specified by `&timezone=`. Always use `auto` to get local time for the location.
- The `best_match` model (default) automatically picks the highest-resolution model available for a given location. No need to manually select models unless the user asks.
- Open-Meteo is free for non-commercial use. No API key needed.
- Wind direction is in degrees (0° = north, 90° = east, 180° = south, 270° = west). Convert to compass directions for readability.
