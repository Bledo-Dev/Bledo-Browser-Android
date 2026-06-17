import 'dart:io';
import 'package:flutter/services.dart';
import 'browser_model.dart';

enum SecurityLevel { safe, warning, critical }

class SecurityGuard {
  static const _channel = MethodChannel('com.bledo.browser/security');

  /// Runs all security checks. Returns the security level.
  static Future<SecurityLevel> performIntegrityCheck(BrowserModel model) async {
    bool isWarning = false;
    bool isCritical = false;

    // 1. Root Detection
    bool isRooted = await _checkRoot();
    if (isRooted) {
      print("Security Alert: Root access detected.");
      isWarning = true; // For now, treat root as a warning to keep it usable
    }

    // 2. Debugger Detection
    bool isBeingDebugged = await _checkDebugger();
    if (isBeingDebugged) {
      print("Security Alert: Debugger detected.");
      isWarning = true;
    }

    // 3. Signature Verification
    bool isSignatureValid = await _checkSignature();
    if (!isSignatureValid) {
      print("Security Alert: Unauthorized APK signature.");
      isCritical = true; // Signature mismatch is CRITICAL
    }

    // 4. Emulator Detection
    bool isEmulator = await _checkEmulator();
    if (isEmulator) {
      print("Security Alert: Emulator environment detected.");
    }

    // 5. Virtual Environment Detection
    bool isVirtual = await _checkVirtual();
    if (isVirtual) {
      print("Security Alert: Virtual/Cloned environment detected.");
      isWarning = true;
    }

    // LOGGING FOR DEBUGGING:
    print("DEBUG_INTEGRITY_SUMMARY: isRooted=$isRooted, isDebugged=$isBeingDebugged, isSignatureValid=$isSignatureValid, isVirtual=$isVirtual");

    if (isCritical) {
      await _triggerSelfProtect(model);
      return SecurityLevel.critical;
    }

    if (isWarning) {
      return SecurityLevel.warning;
    }

    return SecurityLevel.safe;
  }

  static Future<bool> _checkRoot() async {
    try {
      return await _channel.invokeMethod('isRooted') ?? false;
    } catch (e) {
      return true; // Assume rooted if check fails
    }
  }

  static Future<bool> _checkDebugger() async {
    try {
      return await _channel.invokeMethod('isDebugged') ?? false;
    } catch (e) {
      return true;
    }
  }

  static Future<bool> _checkEmulator() async {
    try {
      return await _channel.invokeMethod('isEmulator') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> _checkVirtual() async {
    try {
      return await _channel.invokeMethod('isVirtual') ?? false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> _checkSignature() async {
    try {
      final signature = await _channel.invokeMethod<String>('getSignature');
      if (signature == null) return false;
      
      // THIS IS THE CRITICAL ANTI-TAMPER CHECK
      // In a production app, you would hardcode the SHA-256 hash of your signing certificate here.
      // If someone re-signs the APK, this hash will change.
      
      // For now, we print the signature so it can be verified.
      print("APP_SIGNATURE_HASH: $signature");
      
      // Placeholder: In a real scenario, you'd compare against a hardcoded value:
      // return signature == "YOUR_GOLDEN_SIGNATURE_HASH";
      
      return true; 
    } catch (e) {
      return false;
    }
  }

  static Future<void> _triggerSelfProtect(BrowserModel model) async {
    print("TAMPER DETECTED: Wiping data and locking app...");
    
    // Wipe all sensitive data immediately
    await model.deleteAllData();
    
    // In a real app, you would set a flag to show a "PERMANENT LOCK" screen
    // and disable all browser functionality.
  }
}
