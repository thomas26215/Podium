import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<AppUser> signUp({required String email, required String password, required String displayName});
  Future<AppUser> signIn({required String email, required String password});
  Future<void> signOut();

  /// Sends a password-reset e-mail to `email`, if it belongs to an account.
  /// Firebase's own email-enumeration protection keeps this from revealing
  /// whether the address actually has an account (it resolves the same way
  /// either way) — see the equivalent flow in docs/reset.js.
  Future<void> sendPasswordResetEmail(String email);

  /// Re-proves the current password before a sensitive operation (account
  /// deletion) — Firebase requires a "recent login" for `User.delete()`.
  Future<void> reauthenticate(String password);

  /// Deletes the signed-in Firebase Auth user itself. Callers must delete
  /// the user's Firestore data (groups, users/{uid}, emailIndex) first —
  /// once this succeeds, `request.auth` no longer exists to authorize those
  /// writes.
  Future<void> deleteAccount();
}

String _friendlyAuthError(Object e) {
  if (e is fb.FirebaseAuthException) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Un compte existe déjà avec cet e-mail.';
      case 'invalid-email':
        return "Adresse e-mail invalide.";
      case 'weak-password':
        return 'Mot de passe trop court (6 caractères minimum).';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou mot de passe incorrect.';
      case 'requires-recent-login':
        return 'Veuillez vous reconnecter puis réessayer.';
      default:
        return e.message ?? 'Une erreur est survenue.';
    }
  }
  return e.toString();
}

class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _auth;
  final FirebaseFirestore _db;

  FirebaseAuthRepository({fb.FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  AppUser _fromFirebase(fb.User u, {String? displayNameOverride}) => AppUser(
        uid: u.uid,
        email: u.email ?? '',
        displayName: displayNameOverride ?? (u.displayName?.isNotEmpty == true ? u.displayName! : (u.email ?? 'Joueur')),
        color: colorForUid(u.uid),
      );

  @override
  AppUser? get currentUser {
    final u = _auth.currentUser;
    return u == null ? null : _fromFirebase(u);
  }

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((u) async {
      if (u == null) return null;
      final doc = await _db.collection('users').doc(u.uid).get();
      if (doc.exists) return AppUser.fromDoc(u.uid, doc.data()!);
      return _fromFirebase(u);
    });
  }

  @override
  Future<AppUser> signUp({required String email, required String password, required String displayName}) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      final user = cred.user!;
      await user.updateDisplayName(displayName.trim());
      final appUser = AppUser(
        uid: user.uid,
        email: email.trim().toLowerCase(),
        displayName: displayName.trim().isEmpty ? 'Joueur' : displayName.trim(),
        color: colorForUid(user.uid),
      );
      final batch = _db.batch();
      batch.set(_db.collection('users').doc(user.uid), appUser.toMap());
      batch.set(_db.collection('emailIndex').doc(appUser.email), {'uid': user.uid});
      await batch.commit();
      return appUser;
    } catch (e) {
      throw AuthException(_friendlyAuthError(e));
    }
  }

  @override
  Future<AppUser> signIn({required String email, required String password}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      final doc = await _db.collection('users').doc(cred.user!.uid).get();
      if (doc.exists) return AppUser.fromDoc(cred.user!.uid, doc.data()!);
      return _fromFirebase(cred.user!);
    } catch (e) {
      throw AuthException(_friendlyAuthError(e));
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw AuthException(_friendlyAuthError(e));
    }
  }

  @override
  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw AuthException('Aucun utilisateur connecté.');
    try {
      final cred = fb.EmailAuthProvider.credential(email: user.email!, password: password);
      await user.reauthenticateWithCredential(cred);
    } catch (e) {
      throw AuthException(_friendlyAuthError(e));
    }
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) throw AuthException('Aucun utilisateur connecté.');
    try {
      await user.delete();
    } catch (e) {
      throw AuthException(_friendlyAuthError(e));
    }
  }
}
