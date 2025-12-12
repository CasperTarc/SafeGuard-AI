// InactivityDetector — delegates confirmation UI to the shared helper showConfirmationDialog(...)

import 'dart:async';
import 'package:flutter/material.dart';
import 'false_alarm.dart'; // provides isConfirmationActive()
import 'ui/confirmation.dart'; // shared confirmation UI (showConfirmationDialog)

class InactivityDetector {
  final BuildContext context;
  final VoidCallback onSendAlert;
  final double movementThreshold;
  final Duration inactivityDuration;
  final Duration confirmationDuration;

  Timer? _inactivityTimer;
  bool _inInactivityWindow = false;
  double _movementBaseline = 0.0;

  bool _enabled = true;

  InactivityDetector({
    required this.context,
    required this.onSendAlert,
    this.movementThreshold = 0.1,
    this.inactivityDuration = const Duration(seconds: 12),
    this.confirmationDuration = const Duration(seconds: 10),
  });

  /// Enable the detector so start(...) will function again.
  void enable() {
    _enabled = true;
    debugPrint('InactivityDetector: enabled');
  }

  /// Disable the detector and cancel any active timers / confirmation.
  void disable() {
    _enabled = false;
    _inactivityTimer?.cancel();
    _inInactivityWindow = false;
    debugPrint('InactivityDetector: disabled and timers cancelled');
  }

  /// Whether there is either a pending inactivity window or a global confirmation/cooldown active.
  bool get hasActiveWindowOrConfirmation => _inInactivityWindow || isConfirmationActive();

  // Start the inactivity countdown.
  // onComplete is called after the confirmation dialog flow completes (sent/cancelled/timeout)
  void start({required String reason, required double baselineMagnitude, VoidCallback? onComplete}) {
    if (!_enabled) {
      debugPrint('InactivityDetector.start ignored: detector disabled');
      return;
    }

    // Avoid scheduling a new inactivity window if a confirmation/window/cooldown already active
    if (hasActiveWindowOrConfirmation) {
      debugPrint('InactivityDetector.start ignored: active window/confirmation/cooldown already present');
      return;
    }

    _inactivityTimer?.cancel();
    _inInactivityWindow = true;
    _movementBaseline = baselineMagnitude;
    debugPrint('InactivityDetector.start: reason=$reason baseline=$_movementBaseline');

    _inactivityTimer = Timer(inactivityDuration, () async {
      _inInactivityWindow = false;
      debugPrint('InactivityDetector: inactivity duration elapsed -> showing confirmation');

      // If global confirmation gate active (visible or cooldown), skip
      if (isConfirmationActive()) {
        debugPrint('InactivityDetector: suppressed confirmation since global gate active');
        onComplete?.call();
        return;
      }

      // Show the shared confirmation dialog UI. That helper manages gate + cooldown and routes
      // the result to Cancel / Sent overlays, so we only need to call it here.
      try {
        await showConfirmationDialog(
          context,
          seconds: confirmationDuration.inSeconds,
          alertType: 'inactivity',
          trigger: 'auto',
        );
      } catch (e) {
        debugPrint('InactivityDetector: error showing shared confirmation UI: $e');
      } finally {
        // Notify caller that the inactivity window / confirmation flow is complete.
        try {
          onComplete?.call();
        } catch (_) {}
      }
    });
  }

  // Immediate confirmation (used by FalseAlarmManager for core emergencies and fallbacks)
  Future<void> showImmediateConfirmation(String title, {String alertType = 'inactivity', String trigger = 'auto'}) async {
    if (!_enabled) {
      debugPrint('InactivityDetector.showImmediateConfirmation ignored: detector disabled');
      return;
    }

    if (hasActiveWindowOrConfirmation) {
      debugPrint('InactivityDetector.showImmediateConfirmation suppressed: active window/confirmation present');
      return;
    }

    try {
      await showConfirmationDialog(
        context,
        seconds: confirmationDuration.inSeconds,
        alertType: alertType,
        trigger: trigger,
      );
    } catch (e) {
      debugPrint('InactivityDetector.showImmediateConfirmation: error showing dialog: $e');
      rethrow;
    }
  }

  // Cancel the inactivity countdown, since movement was detected.
  void cancel(String reason) {
    _inactivityTimer?.cancel();
    _inInactivityWindow = false;
    debugPrint('InactivityDetector.cancel: $reason');
  }

  // Call this on accelerometer magnitude updates.
  void handleMagnitude(double magnitude) {
    if (!_inInactivityWindow) return;

    // Compare movement to baseline; if movement exceeds the threshold, cancel the inactivity window.
    final delta = (magnitude - _movementBaseline).abs();
    if (delta > movementThreshold) {
      debugPrint('InactivityDetector: movement detected (delta=${delta.toStringAsFixed(3)}) -> cancelling inactivity window');
      cancel('movement detected (delta=${delta.toStringAsFixed(3)})');
    }
  }

  /// Dispose helper to cancel timers when the detector is no longer needed.
  void dispose() {
    _inactivityTimer?.cancel();
    _inInactivityWindow = false;
    debugPrint('InactivityDetector: disposed');
  }
}