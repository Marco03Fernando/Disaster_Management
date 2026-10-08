import 'package:flutter/material.dart';
import 'package:hazard_warning_app/app.dart';
import 'package:hazard_warning_app/core/services/app_services.dart';
import 'package:hazard_warning_app/core/state/app_state.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.bootstrap();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(services),
      child: HazardWarningApp(router: buildRouter()),
    ),
  );
}
