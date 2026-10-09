
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:hazard_warning_app/core/services/app_services.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:hazard_warning_app/features/officer/screens/shelters_list_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const connectivityChannel = MethodChannel(
    'dev.fluttercommunity.plus/connectivity',
  );

  late AppServices services;
  late AppState state;

  setUpAll(() async {
    services = await AppServices.bootstrap();
  });

  setUp(() {
    connectivityChannel.setMockMethodCallHandler((call) async {
      if (call.method == 'check') {
        return <String>['wifi'];
      }
      return null;
    });

    state = AppState(services);
  });

  tearDown(() {
    state.dispose();
    connectivityChannel.setMockMethodCallHandler(null);
  });

  Future<void> openScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(
          home: SheltersListScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  group('Shelters list screen', () {
    testWidgets('opens the screen without throwing an exception', (
      tester,
    ) async {
      await openScreen(tester);

      expect(find.byType(SheltersListScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('displays the Shelters heading', (tester) async {
      await openScreen(tester);

      // The navigation scaffold may also display "Shelters".
      expect(find.text('Shelters'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the register shelter button', (tester) async {
      await openScreen(tester);

      expect(find.text('Register Shelter'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens the shelter registration form', (tester) async {
      await openScreen(tester);

      final registerButton = find.text('Register Shelter').first;
      await tester.tap(registerButton);
      await tester.pumpAndSettle();

      expect(find.text('Shelter name'), findsOneWidget);
      expect(find.text('District'), findsOneWidget);
      expect(find.text('Location / address'), findsOneWidget);
      expect(find.text('Capacity'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}