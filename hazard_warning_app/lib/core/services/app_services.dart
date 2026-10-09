import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:hazard_warning_app/core/repositories/data_repository.dart';
import 'package:hazard_warning_app/core/repositories/firebase_data_repository.dart';
import 'package:hazard_warning_app/core/repositories/local_data_repository.dart';
import 'package:hazard_warning_app/core/services/officer_auth_service.dart';
import 'package:hazard_warning_app/firebase_options.dart';

class AppServices {
  AppServices._({
    required this.repository,
    required this.usesFirebase,
    required this.connectivity,
    required this.auth,
  }) : _fixedOnline = null;

  /// Services with a fixed connectivity value, for widget and unit tests.
  @visibleForTesting
  AppServices.test({
    required this.repository,
    this.auth = const DemoOfficerAuthService(),
    bool online = true,
    this.usesFirebase = false,
  }) : connectivity = Connectivity(),
       _fixedOnline = online;

  final DataRepository repository;
  final bool usesFirebase;
  final Connectivity connectivity;
  final OfficerAuthService auth;
  final bool? _fixedOnline;

  static AppServices? _instance;

  static AppServices get instance {
    assert(_instance != null, 'Call AppServices.bootstrap() first');
    return _instance!;
  }

  static Future<AppServices> bootstrap() async {
    var usesFirebase = false;
    DataRepository repository = LocalDataRepository();
    OfficerAuthService auth = const DemoOfficerAuthService();

    if (DefaultFirebaseOptions.isConfigured) {
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        final firebaseAuth = FirebaseOfficerAuthService();
        // Sign citizens in anonymously first so report rules can check the
        // reporter's UID. Offline, carry on without it rather than fall back.
        await firebaseAuth.ensureCitizenSession().timeout(
          const Duration(seconds: 10),
          onTimeout: () {},
        );
        final firebaseRepo = FirebaseDataRepository(
          storage: FirebaseStorage.instance,
        );
        // Fail fast (and fall back to demo data) if Firestore is unreachable
        // or not created yet, rather than hanging on a blank screen.
        await firebaseRepo.initialize().timeout(const Duration(seconds: 15));
        repository = firebaseRepo;
        auth = firebaseAuth;
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
      auth: auth,
    );
    return _instance!;
  }

  Stream<bool> watchOnline() {
    if (_fixedOnline != null) return const Stream.empty();
    return connectivity.onConnectivityChanged.map((results) {
      return results.any((r) => r != ConnectivityResult.none);
    });
  }

  Future<bool> isOnline() async {
    if (_fixedOnline != null) return _fixedOnline;
    final results = await connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}
