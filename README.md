Weather App

A simple Flutter application that fetches and displays weather information using the OpenWeatherMap API.

📌 Features

Get current weather details (temperature, humidity, wind speed, etc.)

Search Functionality allow users to search for weather information by entering a city name.

5-day weather forecast

Cache the last retrieved weather data for offline access with Sharedpreferences.

Riverpod state management

unit conversion (Celsius ↔ Fahrenheit).


🛠 Prerequisites

Ensure you have the following installed on your system:

Flutter SDK (latest stable version)

Dart SDK (included with Flutter)

Android Studio / VS Code (for running the app)

Emulator or physical device for testing

🚀 Getting Started

1️⃣ Clone the Repository

git clone https://github.com/sonumoncy/weatherapp.git

cd weather_app

2️⃣ Install Dependencies

flutter pub get

3️⃣ Set Up OpenWeatherMap API

Create an OpenWeatherMap Account:

Sign up at OpenWeather.

Go to API Keys and copy your API key.

Add API Key to the Project:

Open lib/weatherscreen.dart 

Assign the API key to the variable 'apiKey' 

4️⃣ Run the App

For Android/iOS:

flutter run

For Web:

flutter run -d chrome

🌟 Contributions

Feel free to open issues and submit pull requests for improvements.
