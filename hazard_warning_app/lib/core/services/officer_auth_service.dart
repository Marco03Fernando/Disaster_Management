import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

enum OfficerAccessStatus {
  checking,
  signedOut,
  authorized,
  unauthorized,
  error,
}

/// Who is using the duty officer console, and whether they may verify reports.
class OfficerSession {
  const OfficerSession({
    required this.status,
    this.uid,
    this.displayName,
    this.email,
    this.message,
  });

  static const checking = OfficerSession(status: OfficerAccessStatus.checking);
  static const signedOut = OfficerSession(
    status: OfficerAccessStatus.signedOut,
  );

  final OfficerAccessStatus status;
  final String? uid;
  final String? displayName;
  final String? email;

  /// Explanation shown for [OfficerAccessStatus.unauthorized] / error.
  final String? message;

  bool get isAuthorized => status == OfficerAccessStatus.authorized;
}

/// Firebase Auth for duty officers, plus the anonymous session citizens use so
/// their reports carry a reporter UID that security rules can check.
abstract class OfficerAuthService {
  /// False in demo mode, where there is no backend to protect.
  bool get enforcesAccess;

  /// UID stamped on reports submitted from this device, or null in demo mode.
  String? get currentUid;

  Stream<OfficerSession> watchSession();

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();

  /// Re-checks officer access for the signed-in account.
  Future<void> refresh();
}

/// Officers are Firebase Auth email/password users who also have an
/// `officers/{uid}` document with `active: true`. That document can only be
/// created from the Firebase Console (rules deny client writes), so nobody can
/// grant themselves officer access from the app.
class FirebaseOfficerAuthService implements OfficerAuthService {
  FirebaseOfficerAuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  @override
  bool get enforcesAccess => true;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  /// Gives citizens an anonymous identity. Fails quietly if Anonymous sign-in
  /// is not enabled yet; report submission then surfaces the rules error.
  Future<void> ensureCitizenSession() async {
    if (_auth.currentUser != null) return;
    try {
      await _auth.signInAnonymously();
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) debugPrint('Anonymous sign-in failed: ${e.code}');
    }
  }

  final _refreshes = StreamController<void>.broadcast();

  /// Emits `checking` then the resolved session on every auth change or
  /// [refresh]; a stale lookup never overwrites a newer one.
  @override
  Stream<OfficerSession> watchSession() {
    late final StreamController<OfficerSession> ctrl;
    StreamSubscription<User?>? authSub;
    StreamSubscription<void>? refreshSub;
    var generation = 0;

    Future<void> emit(User? user) async {
      final current = ++generation;
      ctrl.add(OfficerSession.checking);
      final session = await _resolve(user);
      if (current == generation && !ctrl.isClosed) ctrl.add(session);
    }

    ctrl = StreamController<OfficerSession>(
      onListen: () {
        authSub = _auth.authStateChanges().listen(emit);
        refreshSub = _refreshes.stream.listen((_) => emit(_auth.currentUser));
      },
      onCancel: () async {
        await authSub?.cancel();
        await refreshSub?.cancel();
      },
    );
    return ctrl.stream;
  }

  @override
  Future<void> refresh() async => _refreshes.add(null);

  Future<OfficerSession> _resolve(User? user) async {
    if (user == null || user.isAnonymous) return OfficerSession.signedOut;
    final name = user.displayName?.isNotEmpty == true
        ? user.displayName!
        : (user.email ?? 'Duty officer');
    try {
      final doc = await _db.collection('officers').doc(user.uid).get();
      final data = doc.data();
      if (data == null || data['active'] != true) {
        return OfficerSession(
          status: OfficerAccessStatus.unauthorized,
          uid: user.uid,
          email: user.email,
          displayName: name,
          message:
              'This account is not registered as an active duty officer. '
              'Ask a DMC administrator to grant access.',
        );
      }
      return OfficerSession(
        status: OfficerAccessStatus.authorized,
        uid: user.uid,
        email: user.email,
        displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
            ? data['displayName'] as String
            : name,
      );
    } on FirebaseException catch (e) {
      return OfficerSession(
        status: e.code == 'permission-denied'
            ? OfficerAccessStatus.unauthorized
            : OfficerAccessStatus.error,
        uid: user.uid,
        email: user.email,
        displayName: name,
        message: e.code == 'permission-denied'
            ? 'Officer access could not be confirmed for this account.'
            : 'Could not check officer access. Check your connection and try again.',
      );
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Returns the device to an anonymous citizen session.
  @override
  Future<void> signOut() async {
    await _auth.signOut();
    await ensureCitizenSession();
  }
}

/// Demo mode (no Firebase): on-device data only, so the console is open and
/// decisions are attributed to a demo officer.
class DemoOfficerAuthService implements OfficerAuthService {
  const DemoOfficerAuthService();

  static const demoSession = OfficerSession(
    status: OfficerAccessStatus.authorized,
    uid: 'demo-officer',
    displayName: 'Demo duty officer',
  );

  @override
  bool get enforcesAccess => false;

  @override
  String? get currentUid => null;

  @override
  Stream<OfficerSession> watchSession() => Stream.value(demoSession);

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> refresh() async {}
}

/// Turns Firebase Auth error codes into messages for the sign-in form.
String describeAuthError(Object error) {
  if (error is FirebaseAuthException) {
    return switch (error.code) {
      'invalid-email' => 'Enter a valid email address.',
      'user-disabled' => 'This account has been disabled.',
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => 'Incorrect email or password.',
      'too-many-requests' =>
        'Too many attempts. Wait a moment, then try again.',
      'network-request-failed' =>
        "You're offline. Connect to the internet to sign in.",
      'operation-not-allowed' =>
        'Email/password sign-in is not enabled for this project.',
      _ => 'Sign-in failed (${error.code}).',
    };
  }
  return 'Sign-in failed. Please try again.';
}
