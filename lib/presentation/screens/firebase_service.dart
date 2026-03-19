import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// ─────────────────────────────────────────────
// Firebase Service — Auth + Firestore sync
// ─────────────────────────────────────────────
class FirebaseService {
  static final _auth      = FirebaseAuth.instance;
  static final _firestore = FirebaseFirestore.instance;
  static final _google    = GoogleSignIn();

  // ── Usuario actual ────────────────────────
  static User? get currentUser => _auth.currentUser;
  static bool  get isLoggedIn  => currentUser != null;
  static String get uid        => currentUser?.uid ?? '';

  // ── Inicializar ───────────────────────────
  static Future<void> init() async {
    await Firebase.initializeApp();

    // Escuchar cambios de auth
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        // Sincronizar datos locales al iniciar sesión
        syncAllToCloud();
      }
    });
  }

  // ─────────────────────────────────────────────
  // AUTH — Email / Password
  // ─────────────────────────────────────────────
  static Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password,
      );
      await cred.user?.updateDisplayName(name);

      // Crear perfil en Firestore
      await _createUserProfile(cred.user!, name: name, email: email);

      // Guardar nombre localmente
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name',  name);
      await prefs.setString('user_email', email);

      return AuthResult.success;
    } on FirebaseAuthException catch (e) {
      return _authError(e.code);
    }
  }

  static Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      await _loadProfileFromCloud();
      return AuthResult.success;
    } on FirebaseAuthException catch (e) {
      return _authError(e.code);
    }
  }

  // ── Auth — Google ─────────────────────────
  static Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) return AuthResult.cancelled;

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);

      // Crear perfil si es nuevo usuario
      final isNew = cred.additionalUserInfo?.isNewUser ?? false;
      if (isNew) {
        await _createUserProfile(
          cred.user!,
          name:  googleUser.displayName ?? 'Usuario',
          email: googleUser.email,
        );
      } else {
        await _loadProfileFromCloud();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name',  googleUser.displayName ?? 'Usuario');
      await prefs.setString('user_email', googleUser.email);

      return AuthResult.success;
    } on FirebaseAuthException catch (e) {
      return _authError(e.code);
    } catch (_) {
      return AuthResult.error;
    }
  }

  // ── Auth — Recuperar contraseña ───────────
  static Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success;
    } on FirebaseAuthException catch (e) {
      return _authError(e.code);
    }
  }

  // ── Auth — Cerrar sesión ──────────────────
  static Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }

  // ─────────────────────────────────────────────
  // PERFIL DE USUARIO
  // ─────────────────────────────────────────────
  static Future<void> _createUserProfile(User user, {required String name, required String email}) async {
    await _firestore.collection('users').doc(user.uid).set({
      'uid':        user.uid,
      'name':       name,
      'email':      email,
      'createdAt':  FieldValue.serverTimestamp(),
      'streak':     0,
      'daysActive': 0,
      'wellness':   0.72,
      'lang':       'Español',
    }, SetOptions(merge: true));
  }

  static Future<void> _loadProfileFromCloud() async {
    if (!isLoggedIn) return;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return;
      final data  = doc.data()!;
      final prefs = await SharedPreferences.getInstance();
      if (data['name']  != null) await prefs.setString('user_name',  data['name']);
      if (data['email'] != null) await prefs.setString('user_email', data['email']);
      if (data['streak']     != null) await prefs.setInt('current_streak', data['streak']);
      if (data['daysActive'] != null) await prefs.setInt('days_active',    data['daysActive']);
      if (data['wellness']   != null) await prefs.setDouble('wellness_level', (data['wellness'] as num).toDouble());
    } catch (_) {}
  }

  static Future<void> updateProfile({String? name, String? lang}) async {
    if (!isLoggedIn) return;
    try {
      final updates = <String, dynamic>{};
      if (name != null) { updates['name'] = name; await currentUser?.updateDisplayName(name); }
      if (lang != null)   updates['lang'] = lang;
      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updates);
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // DIARIO EMOCIONAL
  // ─────────────────────────────────────────────
  static Future<void> syncDiaryToCloud() async {
    if (!isLoggedIn) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString('acom_diary_entries');
      if (raw == null) return;

      final entries = jsonDecode(raw) as List;
      final batch   = _firestore.batch();

      for (final entry in entries) {
        final ref = _firestore
            .collection('users').doc(uid)
            .collection('diary').doc(entry['id']);
        batch.set(ref, {
          ...entry,
          'syncedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (_) {}
  }

  static Future<void> loadDiaryFromCloud() async {
    if (!isLoggedIn) return;
    try {
      final snapshot = await _firestore
          .collection('users').doc(uid)
          .collection('diary')
          .orderBy('date', descending: true)
          .get();

      if (snapshot.docs.isEmpty) return;
      final entries = snapshot.docs.map((d) => d.data()).toList();
      final prefs   = await SharedPreferences.getInstance();
      await prefs.setString('acom_diary_entries', jsonEncode(entries));
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // CONVERSACIONES DEL CHAT
  // ─────────────────────────────────────────────
  static Future<void> saveConversationToCloud({
    required String conversationId,
    required List<Map<String, dynamic>> messages,
    required String title,
  }) async {
    if (!isLoggedIn) return;
    try {
      await _firestore
          .collection('users').doc(uid)
          .collection('conversations').doc(conversationId)
          .set({
        'id':        conversationId,
        'title':     title,
        'messages':  messages,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> loadConversationsFromCloud() async {
    if (!isLoggedIn) return [];
    try {
      final snapshot = await _firestore
          .collection('users').doc(uid)
          .collection('conversations')
          .orderBy('updatedAt', descending: true)
          .limit(20)
          .get();
      return snapshot.docs.map((d) => d.data()).toList();
    } catch (_) {
      return [];
    }
  }

  // ─────────────────────────────────────────────
  // RESULTADOS DE TESTS
  // ─────────────────────────────────────────────
  static Future<void> syncTestResultsToCloud() async {
    if (!isLoggedIn) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString('acom_assessments');
      if (raw == null) return;

      final results = jsonDecode(raw) as List;
      final batch   = _firestore.batch();

      for (final result in results) {
        final id  = '${result['testId']}_${result['date']}';
        final ref = _firestore
            .collection('users').doc(uid)
            .collection('assessments').doc(id);
        batch.set(ref, {
          ...result,
          'syncedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (_) {}
  }

  static Future<void> loadTestResultsFromCloud() async {
    if (!isLoggedIn) return;
    try {
      final snapshot = await _firestore
          .collection('users').doc(uid)
          .collection('assessments')
          .orderBy('date', descending: true)
          .get();

      if (snapshot.docs.isEmpty) return;
      final results = snapshot.docs.map((d) => d.data()).toList();
      final prefs   = await SharedPreferences.getInstance();
      await prefs.setString('acom_assessments', jsonEncode(results));
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // ESTADÍSTICAS Y RACHA
  // ─────────────────────────────────────────────
  static Future<void> syncStatsToCloud() async {
    if (!isLoggedIn) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await _firestore.collection('users').doc(uid).update({
        'streak':        prefs.getInt('current_streak')    ?? 0,
        'daysActive':    prefs.getInt('days_active')       ?? 0,
        'wellness':      prefs.getDouble('wellness_level') ?? 0.72,
        'diaryEntries':  prefs.getInt('diary_count')       ?? 0,
        'breathSessions':prefs.getInt('breath_sessions')   ?? 0,
        'chatMessages':  prefs.getInt('chat_messages')     ?? 0,
        'statsUpdatedAt':FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Future<void> loadStatsFromCloud() async {
    if (!isLoggedIn) return;
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return;
      final data  = doc.data()!;
      final prefs = await SharedPreferences.getInstance();
      if (data['streak']         != null) await prefs.setInt('current_streak',  data['streak']);
      if (data['daysActive']     != null) await prefs.setInt('days_active',      data['daysActive']);
      if (data['wellness']       != null) await prefs.setDouble('wellness_level',(data['wellness'] as num).toDouble());
      if (data['breathSessions'] != null) await prefs.setInt('breath_sessions',  data['breathSessions']);
      if (data['chatMessages']   != null) await prefs.setInt('chat_messages',    data['chatMessages']);
    } catch (_) {}
  }

  // ─────────────────────────────────────────────
  // SYNC COMPLETO
  // ─────────────────────────────────────────────
  static Future<void> syncAllToCloud() async {
    if (!isLoggedIn) return;
    await Future.wait([
      syncDiaryToCloud(),
      syncTestResultsToCloud(),
      syncStatsToCloud(),
    ]);
  }

  static Future<void> loadAllFromCloud() async {
    if (!isLoggedIn) return;
    await Future.wait([
      _loadProfileFromCloud(),
      loadDiaryFromCloud(),
      loadTestResultsFromCloud(),
      loadStatsFromCloud(),
    ]);
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────
  static AuthResult _authError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential': return AuthResult.invalidCredentials;
      case 'email-already-in-use': return AuthResult.emailInUse;
      case 'weak-password':        return AuthResult.weakPassword;
      case 'network-request-failed': return AuthResult.networkError;
      case 'too-many-requests':    return AuthResult.tooManyRequests;
      default: return AuthResult.error;
    }
  }
}

// ─────────────────────────────────────────────
// Resultado de autenticación
// ─────────────────────────────────────────────
enum AuthResult {
  success,
  cancelled,
  invalidCredentials,
  emailInUse,
  weakPassword,
  networkError,
  tooManyRequests,
  error;

  String get message {
    switch (this) {
      case AuthResult.success:            return '✅ Sesión iniciada correctamente';
      case AuthResult.cancelled:          return 'Inicio de sesión cancelado';
      case AuthResult.invalidCredentials: return '❌ Correo o contraseña incorrectos';
      case AuthResult.emailInUse:         return '❌ Este correo ya está registrado';
      case AuthResult.weakPassword:       return '❌ La contraseña debe tener al menos 6 caracteres';
      case AuthResult.networkError:       return '❌ Sin conexión. Verifica tu internet';
      case AuthResult.tooManyRequests:    return '❌ Demasiados intentos. Espera un momento';
      case AuthResult.error:              return '❌ Ocurrió un error. Intenta de nuevo';
    }
  }
}