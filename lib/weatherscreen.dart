import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_icons/weather_icons.dart';

final weatherProvider =
    StateNotifierProvider<WeatherNotifier, WeatherState>((ref) {
  return WeatherNotifier();
});
final temperatureUnitProvider = StateProvider<bool>((ref) => true);

class WeatherNotifier extends StateNotifier<WeatherState> {
  WeatherNotifier() : super(WeatherState());

  String apiKey = '67fbd3c94cb53eafbfcd9a5a4681d342';

  Future<void> fetchWeatherByLocation() async {
    Position position = await _determinePosition();
    fetchWeatherDataByCoords(position.latitude, position.longitude);
  }

  Future<void> fetchWeatherDataByCoords(double lat, double lon) async {
    var connectivityResult = await Connectivity().checkConnectivity();
    bool isOffline = connectivityResult == ConnectivityResult.none;

    if (isOffline) {
      _loadCachedWeather();
      return;
    }

    String url =
        'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$apiKey&units=metric';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        int? sunriseTimestamp = data['sys']['sunrise'];
        int? sunsetTimestamp = data['sys']['sunset'];
        int? timezoneOffset = data['timezone'];

        String sunriseTime = "N/A";
        String sunsetTime = "N/A";

        if (sunriseTimestamp != null &&
            sunsetTimestamp != null &&
            timezoneOffset != null) {
          DateTime sunrise = DateTime.fromMillisecondsSinceEpoch(
              (sunriseTimestamp + timezoneOffset) * 1000);
          DateTime sunset = DateTime.fromMillisecondsSinceEpoch(
              (sunsetTimestamp + timezoneOffset) * 1000);

          sunriseTime = DateFormat('hh:mm a').format(sunrise);
          sunsetTime = DateFormat('hh:mm a').format(sunset);
        }
        state = WeatherState(
          city: data['name'],
          weather: data['weather'][0]['description'],
          temperature: data['main']['temp'],
          icon: data['weather'][0]['icon'],
          windspeed: data['wind']['speed'],
          humidity: data['main']['humidity'],
          sunrise: sunriseTime,
          sunset: sunsetTime,
          errorMessage: '',
        );
        await fetchForecast('', lat.toString(), lon.toString());
        _cacheWeatherData(data);
      } else if (response.statusCode == 404) {
        state =
            state.copyWith(errorMessage: "City not found. Try another one.");
      } else {
        state = state.copyWith(errorMessage: "Error fetching weather data.");
      }
    } catch (e) {
      state = state.copyWith(errorMessage: "Network error. Please try again.");
    }
  }

  Future<void> fetchWeatherAndForecast(String cityName) async {
    try {
      await fetchWeatherDataByCity(cityName);
      await Future.delayed(const Duration(seconds: 1));
      await fetchForecast(cityName, '', '');
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to fetch data.');
    }
  }

  Future<void> fetchWeatherDataByCity(String cityName) async {
    var connectivityResult = await Connectivity().checkConnectivity();
    bool isOffline = connectivityResult == ConnectivityResult.none;

    if (isOffline) {
      _loadCachedWeather();
      return;
    }

    String url =
        'https://api.openweathermap.org/data/2.5/weather?q=$cityName&appid=$apiKey&units=metric';
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        int? sunriseTimestamp = data['sys']['sunrise'];
        int? sunsetTimestamp = data['sys']['sunset'];
        int? timezoneOffset = data['timezone'];

        String sunriseTime = "N/A";
        String sunsetTime = "N/A";

        if (sunriseTimestamp != null &&
            sunsetTimestamp != null &&
            timezoneOffset != null) {
          DateTime sunrise = DateTime.fromMillisecondsSinceEpoch(
                  sunriseTimestamp * 1000,
                  isUtc: true)
              .add(Duration(seconds: timezoneOffset));

          DateTime sunset = DateTime.fromMillisecondsSinceEpoch(
                  sunsetTimestamp * 1000,
                  isUtc: true)
              .add(Duration(seconds: timezoneOffset));

          sunriseTime = DateFormat('hh:mm a').format(sunrise);
          sunsetTime = DateFormat('hh:mm a').format(sunset);
        }

        state = WeatherState(
          city: data['name'],
          weather: data['weather'][0]['description'],
          icon: data['weather'][0]['icon'],
          temperature: data['main']['temp'],
          humidity: data['main']['humidity'],
          windspeed: data['wind']['speed'],
          sunrise: sunriseTime,
          sunset: sunsetTime,
          errorMessage: '',
        );
        _cacheWeatherData(data);
      } else if (response.statusCode == 404) {
        state =
            state.copyWith(errorMessage: "City not found. Try another one.");
      } else {
        state = state.copyWith(errorMessage: "Error fetching weather data.");
      }
    } catch (e) {
      state = state.copyWith(errorMessage: "Network error. Please try again.");
    }
  }

  Future<void> fetchForecast(String cityName, String lat, String long) async {
    try {
      String url = '';

      if (cityName != '') {
        url =
            'https://api.openweathermap.org/data/2.5/forecast?q=$cityName&appid=$apiKey&units=metric';
      } else if (lat != '' && long != '') {
        url =
            'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$long&appid=$apiKey&units=metric';
      } else {
        throw ArgumentError("Either city or coordinates must be provided!");
      }
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        var forecastData = jsonDecode(response.body);
        List<ForecastDay> forecastDays = [];

        for (int i = 2; i < forecastData['list'].length; i += 8) {
          var item = forecastData['list'][i];
          String formattedDate =
              DateFormat('dd').format(DateTime.parse(item['dt_txt']));
          forecastDays.add(ForecastDay(
            date: formattedDate,
            temp: item['main']['temp'],
            weather: item['weather'][0]['description'],
            icon: item['weather'][0]['icon'],
          ));
        }

        state = state.copyWith(forecast: forecastDays, errorMessage: '');
      } else {
        state = state.copyWith(errorMessage: 'Failed to fetch forecast.');
      }
    } catch (e) {
      state = state.copyWith(
          errorMessage: 'Network error while fetching forecast.');
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied');
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _cacheWeatherData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('cached_city', data['name']);
    prefs.setString('cached_weather', data['weather'][0]['description']);
    prefs.setDouble('cached_temperature', data['main']['temp']);
    prefs.setDouble('cached_windspeed', data['wind']['speed']);
    prefs.setInt('cached_humidity', data['main']['humidity']);
    prefs.setInt('cached_sunrise', data['sys']['sunrise']);
    prefs.setInt('cached_sunset', data['sys']['sunset']);
  }

  Future<void> _loadCachedWeather() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedCity = prefs.getString('cached_city') ?? 'No Data';
    final cachedWeather = prefs.getString('cached_weather') ?? 'Unknown';
    final cachedTemperature = prefs.getDouble('cached_temperature') ?? 0.0;
    final cachedwindspeed = prefs.getDouble('cached_windspeed') ?? 0.0;
    final cachedhumidity = prefs.getInt('cached_humidity') ?? 0;
    int sunriseTimestamp = prefs.getInt('cached_sunrise') ?? 0;
    int sunsetTimestamp = prefs.getInt('cached_sunset') ?? 0;
    DateTime sunrise =
        DateTime.fromMillisecondsSinceEpoch(sunriseTimestamp * 1000);
    DateTime sunset =
        DateTime.fromMillisecondsSinceEpoch(sunsetTimestamp * 1000);
    String sunriseTime = DateFormat('hh:mm a').format(sunrise);
    String sunsetTime = DateFormat('hh:mm a').format(sunset);

    state = WeatherState(
      city: cachedCity,
      weather: cachedWeather,
      temperature: cachedTemperature,
      windspeed: cachedwindspeed,
      sunrise: sunriseTime,
      sunset: sunsetTime,
      humidity: cachedhumidity,
      errorMessage: '',
    );
  }
}

double convertTemperature(bool isCelsius, double temp) {
  return isCelsius ? temp : (temp * 9 / 5) + 32;
}

String getFormattedDate() {
  return DateFormat('EEEE, MMM d, yyyy').format(DateTime.now());
}

class WeatherState {
  final String city;
  final String weather;
  final double temperature;
  final String icon;
  final double windspeed;
  final int humidity;
  final String sunrise;
  final String sunset;
  final String errorMessage;
  final List<ForecastDay> forecast;

  WeatherState({
    this.city = 'Enter City',
    this.weather = '',
    this.temperature = 0.0,
    this.icon = '',
    this.windspeed = 0.0,
    this.humidity = 0,
    this.errorMessage = '',
    this.sunrise = '',
    this.sunset = '',
    this.forecast = const [],
  });
  WeatherState copyWith({
    String? city,
    String? weather,
    double? temperature,
    String? icon,
    double? windspeed,
    String? sunrise,
    String? sunset,
    int? humidity,
    String? errorMessage,
    List<ForecastDay>? forecast,
  }) {
    return WeatherState(
      city: city ?? this.city,
      weather: weather ?? this.weather,
      temperature: temperature ?? this.temperature,
      icon: icon ?? this.icon,
      windspeed: windspeed ?? this.windspeed,
      humidity: humidity ?? this.humidity,
      sunrise: sunrise ?? this.sunrise,
      sunset: sunset ?? this.sunset,
      errorMessage: errorMessage ?? this.errorMessage,
      forecast: forecast ?? this.forecast,
    );
  }
}

class ForecastDay {
  final String date;
  final double temp;
  final String weather;
  final String icon;

  ForecastDay(
      {required this.date,
      required this.temp,
      required this.weather,
      required this.icon});
}

class WeatherHomeScreen extends ConsumerStatefulWidget {
  const WeatherHomeScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends ConsumerState<WeatherHomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(weatherProvider.notifier).fetchWeatherByLocation();
    });
  }

  final TextEditingController _cityController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final weatherState = ref.watch(weatherProvider);
    final weatherNotifier = ref.read(weatherProvider.notifier);
    final isCelsius = ref.watch(temperatureUnitProvider);
    return Scaffold(
        body: SingleChildScrollView(
            child: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.blue.shade300,
            Colors.blue.shade700,
          ],
        ),
      ),
      child: weatherState.errorMessage.isNotEmpty
          ? Text(weatherState.errorMessage,
              style: const TextStyle(color: Colors.red))
          : weatherState.temperature == 0.0
              ? const CircularProgressIndicator()
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 40, bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          SizedBox(
                              width: MediaQuery.of(context).size.width,
                              child: Row(
                                children: [
                                  const SizedBox(width: 20),
                                  const Icon(Icons.location_on,
                                      color: Colors.black, size: 20),
                                  const SizedBox(width: 5),
                                  Text(
                                    weatherState.city,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  const Text("°C"),
                                  Switch(
                                    value: isCelsius,
                                    onChanged: (value) => ref
                                        .read(temperatureUnitProvider.notifier)
                                        .state = value,
                                  ),
                                  const Text("°F"),
                                  const SizedBox(
                                    width: 20,
                                  )
                                ],
                              )),
                        ],
                      ),
                    ),
                    Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20.0,
                        ),
                        child: TextField(
                          controller: _cityController,
                          decoration: InputDecoration(
                            hintText: 'Enter city name',
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(
                                vertical: 10.0, horizontal: 15.0),
                            fillColor: Colors.white.withOpacity(0.2),
                            border: OutlineInputBorder(
                              borderSide: const BorderSide(
                                width: 0,
                                style: BorderStyle.none,
                              ),
                              borderRadius: BorderRadius.circular(
                                20.0,
                              ),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search),
                              onPressed: () {
                                weatherNotifier.fetchWeatherAndForecast(
                                    _cityController.text);
                              },
                            ),
                          ),
                          onSubmitted: (value) {
                            weatherNotifier.fetchWeatherAndForecast(value);
                          },
                        )),
                    const SizedBox(height: 20),
                    if ((weatherState.errorMessage ?? '').isNotEmpty) ...[
                      Text(
                        weatherState.errorMessage ?? '',
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Container(
                        transform: Matrix4.translationValues(0, -30, 0),
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.network(
                                'https://openweathermap.org/img/wn/${weatherState.icon}@4x.png',
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.error,
                                      color: Colors.red);
                                },
                              ),
                              Container(
                                transform: Matrix4.translationValues(0, -30, 0),
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 20),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Today ${getFormattedDate()}',
                                      style: const TextStyle(
                                          color: Colors.white70, fontSize: 16),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '${convertTemperature(isCelsius, weatherState.temperature).toStringAsFixed(1)} ${isCelsius ? "°C" : "°F"}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 70,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      weatherState.weather,
                                      style: const TextStyle(
                                          color: Colors.white, fontSize: 24),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(WeatherIcons.wind,
                                                color: Colors.white),
                                            const SizedBox(width: 5),
                                            Text(
                                              "${weatherState.windspeed} km/h",
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            const Icon(WeatherIcons.raindrop,
                                                color: Colors.white),
                                            const SizedBox(width: 5),
                                            Text(
                                              "Hum ${weatherState.humidity}%",
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                      height: 5,
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        Row(
                                          children: [
                                            const Icon(WeatherIcons.sunrise,
                                                color: Colors.white),
                                            const SizedBox(width: 10),
                                            Text(
                                              weatherState.sunrise,
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          children: [
                                            const Icon(WeatherIcons.sunset,
                                                color: Colors.white),
                                            const SizedBox(width: 10),
                                            Text(
                                              weatherState.sunset,
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (weatherState.forecast.isNotEmpty) ...[
                                const SizedBox(
                                  height: 10,
                                ),
                                const Text(
                                  'What’s Coming? 5-Day Weather Trend',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  height: 120,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children:
                                          weatherState.forecast.map((day) {
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 5.0),
                                          child: Card(
                                            color: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15)),
                                            elevation: 0,
                                            child: Container(
                                              width: 100,
                                              decoration: BoxDecoration(
                                                color: Colors.blue
                                                    .withOpacity(0.5),
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                              ),
                                              padding: const EdgeInsets.all(10),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(day.date,
                                                      style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight
                                                              .normal)),
                                                  const SizedBox(height: 5),
                                                  Image.network(
                                                      'https://openweathermap.org/img/wn/${day.icon}@2x.png',
                                                      width: 50),
                                                  Text(
                                                      '${convertTemperature(isCelsius, day.temp).toStringAsFixed(1)} ${isCelsius ? "°C" : "°F"}',
                                                      style: const TextStyle(
                                                          fontSize: 12)),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                              ],
                            ]))
                  ],
                ),
    )));
  }
}
