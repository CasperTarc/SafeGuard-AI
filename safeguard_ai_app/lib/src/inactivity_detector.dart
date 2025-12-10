// InactivityDetector — delegates confirmation UI to the shared helper showConfirmationDialog(...)
// so appearance is identical across manual, shake, fall, scream and inactivity.
// Keeps inactivity countdown / movement detection behavior intact.

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
  void start({required String reason, required double baselineMagnitude}) {
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
        return;
      }

      // Show the shared confirmation dialog UI. That helper manages gate + cooldown and routes
      // the result to Cancel / Sent overlays, so we only need to call it here.
      try {
        await showConfirmationDialog(context, seconds: confirmationDuration.inSeconds);
        // showConfirmationDialog will show Cancel/Sent overlays as appropriate.
      } catch (e) {
        debugPrint('InactivityDetector: error showing shared confirmation UI: $e');
      }
    });
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
    final delta = (magnitude - _movementBaseline).abs();
    if (delta > movementThreshold) {
      cancel('Movement detected (delta=${delta.toStringAsFixed(3)})');
    }
  }

  // Show 10s confirmation popup immediately (use for core emergency).
  Future<void> showImmediateConfirmation(String title) async {
    // If gate active, do not show another confirmation
    if (isConfirmationActive()) {
      debugPrint('InactivityDetector.showImmediateConfirmation ignored: confirmation already active or cooldown');
      return;
    }

    // Cancel any inactivity timer
    _inactivityTimer?.cancel();
    _inInactivityWindow = false;

    // Show the shared confirmation UI (it handles gate/cooldown and routing to sent/cancel).
    try {
      await showConfirmationDialog(context, seconds: confirmationDuration.inSeconds);
    } catch (e) {
      debugPrint('InactivityDetector: error showing shared immediate confirmation: $e');
    }
  }

  /// Dispose timers.
  void dispose() {
    _inactivityTimer?.cancel();
  }
}