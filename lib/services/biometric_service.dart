import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Verifica si el dispositivo soporta biométricos
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck && isSupported;
    } on PlatformException {
      return false;
    }
  }

  /// Retorna los tipos disponibles: huella, face ID, etc.
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Autentica al usuario
  static Future<BiometricResult> authenticate() async {
    try {
      final available = await isAvailable();
      if (!available) {
        return BiometricResult.notAvailable;
      }

      final authenticated = await _auth.authenticate(
        localizedReason: 'Usa tu huella o Face ID para entrar a ACOM',
        options: const AuthenticationOptions(
          stickyAuth: true,       // No cancela si el usuario sale de la app
          biometricOnly: false,   // Permite PIN como fallback
          sensitiveTransaction: false,
        ),
      );

      return authenticated
          ? BiometricResult.success
          : BiometricResult.failed;

    } on PlatformException catch (e) {
      if (e.code == 'NotEnrolled') return BiometricResult.notEnrolled;
      if (e.code == 'LockedOut')   return BiometricResult.lockedOut;
      return BiometricResult.error;
    }
  }
}

enum BiometricResult {
  success,
  failed,
  notAvailable,
  notEnrolled,
  lockedOut,
  error,
}