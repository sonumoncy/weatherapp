import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:weatherapp/main.dart' as app;
import 'package:weatherapp/weatherscreen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('weatherscreen Integration Test', (tester) async {
    // Launch the app
    app.main();
    await tester.pumpAndSettle();

    // Expect the screen widget to be found
    expect(find.byType(WeatherHomeScreen), findsOneWidget);

    // Add more test steps like interaction, navigation, etc.
  });
}
