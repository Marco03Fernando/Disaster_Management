// Run `dart pub global activate flutterfire_cli` then `flutterfire configure`
// to replace this file with your project credentials.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static const String placeholderProjectId = 'REPLACE_WITH_YOUR_PROJECT_ID';

  static bool get isConfigured =>
      firebaseProjectId != placeholderProjectId && firebaseProjectId.isNotEmpty;

  /// Matches the project in the platform options below.
  static const String firebaseProjectId = 'dmc-hazard-warning';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError('Linux Firebase is not configured.');
      default:
        throw UnsupportedError('Unsupported platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDf8zSpiEEGI_RoOqrFTYXwTxq5bctmG0Q',
    appId: '1:549451773588:web:cd3aef04aeca293f212681',
    messagingSenderId: '549451773588',
    projectId: 'dmc-hazard-warning',
    authDomain: 'dmc-hazard-warning.firebaseapp.com',
    storageBucket: 'dmc-hazard-warning.firebasestorage.app',
    measurementId: 'G-H67LYCQQPC',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCMFyUEd1gEVTKjfqHdWxuEhBO21r3iTvc',
    appId: '1:549451773588:android:1a5041f4e0950157212681',
    messagingSenderId: '549451773588',
    projectId: 'dmc-hazard-warning',
    storageBucket: 'dmc-hazard-warning.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAcr0LirvEY559bnGy3vnQosMI0vNZ3aZo',
    appId: '1:549451773588:ios:d12e173e31ae1aa1212681',
    messagingSenderId: '549451773588',
    projectId: 'dmc-hazard-warning',
    storageBucket: 'dmc-hazard-warning.firebasestorage.app',
    iosBundleId: 'lk.sliit.dmc.hazardWarningApp',
  );
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAcr0LirvEY559bnGy3vnQosMI0vNZ3aZo',
    appId: '1:549451773588:ios:d12e173e31ae1aa1212681',
    messagingSenderId: '549451773588',
    projectId: 'dmc-hazard-warning',
    storageBucket: 'dmc-hazard-warning.firebasestorage.app',
    iosBundleId: 'lk.sliit.dmc.hazardWarningApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDf8zSpiEEGI_RoOqrFTYXwTxq5bctmG0Q',
    appId: '1:549451773588:web:e6b8bac90fab1c93212681',
    messagingSenderId: '549451773588',
    projectId: 'dmc-hazard-warning',
    authDomain: 'dmc-hazard-warning.firebaseapp.com',
    storageBucket: 'dmc-hazard-warning.firebasestorage.app',
    measurementId: 'G-RHLXNL3S1Y',
  );
}
