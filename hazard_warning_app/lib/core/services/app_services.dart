import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:hazard_warning_app/core/repositories/data_repository.dart';
import 'package:hazard_warning_app/core/repositories/firebase_data_repository.dart';
import 'package:hazard_warning_app/core/repositories/local_data_repository.dart';
import 'package:hazard_warning_app/firebase_options.dart';

class AppServices {
  AppServices._({
    required this.repository,
    required this.usesFirebase,
    required this.connectivity,
  });

  final DataRepository repository;
  final bool usesFirebase;
  final Connectivity connectivity;

  static AppServices? _instance;

  static AppServices get instance {
    assert(_instance != null, 'Call AppServices.bootstrap() first');
    return _instance!;
  }

  static Future<AppServices> bootstrap() async {
    var usesFirebase = false;
    DataRepository repository = LocalDataRepository();

    if (DefaultFirebaseOptions.isConfigured) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        final firebaseRepo = FirebaseDataRepository();
        // Fail fast (and fall back to demo data) if Firestore is unreachable
        // or not created yet, rather than hanging on a blank screen.
        await firebaseRepo.initialize().timeout(const Duration(seconds: 15));
        repository = firebaseRepo;
        usesFirebase = true;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Firebase init failed, using local data: $e');
        }
      }
    }

    _instance = AppServices._(
      repository: repository,
      usesFirebase: usesFirebase,
      connectivity: Connectivity(),
    );
    return _instance!;
  }

  Stream<bool> watchOnline() {
    return connectivity.onConnectivityChanged.map((results) {
      return results.any((r) => r != ConnectivityResult.none);
    });
  }

  Future<bool> isOnline() async {
    final results = await connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}
