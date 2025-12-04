// FalseAlarm Mitigation
// Core:
// 1. When both fall + scream detected within 5s windows -> immediate shows 10s confirmation popup. (User can (confirm = timeout) or cancel it)
// Secondary triggers:
// 2. Either single fall OR single scream -> starts inactivity detection (inactivity_detector.dart)
//   2.1.0 If fall only: Starts 12s inactivity timer -> if no movement, shows 10s confirmation popup.
//   2.2.1 If scream only: When 2 screams detected within 5s windows -> immediate 10s confirmation popup.
//   2.2.2 If scream only: Single scream -> starts 12s inactivity timer -> if no movement, shows 10s confirmation popup.
//
// Note:
// - Inactivity detection as secondary trigger, not primary trigger.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'inactivity_detector.dart';

class FalseAlarmManager {
  final InactivityDetector inactivityDetector;
  final VoidCallback onSendAlert;
  final Duration correlationWindow;

  DateTime? _lastFallTime;
  final List<DateTime> _screamTimes = [];

  FalseAlarmManager({
    required this.inactivityDetector,
    required this.onSendAlert,
    this.correlationWindow = const Duration(seconds: 5),
  });

  // Called when a fall is detected.
  // baselineMagnitude is used to start inactivity countdown if needed.
  void onFallDetected({required double baselineMagnitude}) {
    final now = DateTime.now();
    debugPrint('FalseAlarmManager.onFallDetected @ $now');
    _lastFallTime = now;

    // Check for recent scream
    if (_screamTimes.isNotEmpty) {
      final lastScream = _screamTimes.last;
      if (now.difference(lastScream).abs() <= correlationWindow) {
        // Core emergency trigger
        debugPrint('FalseAlarmManager: core emergency (fall + recent scream)');
        inactivityDetector.showImmediateConfirmation('Core emergency (fall + scream)');
        return;
      }
    }

    // Otherwise start inactivity countdown (secondary trigger)
    inactivityDetector.start(reason: 'Fall detected', baselineMagnitude: baselineMagnitude);
  }

  // Called when a scream is detected.
  // baselineMagnitude is used when starting inactivity for single scream.
  void onScreamDetected({required double baselineMagnitude}) {
    final now = DateTime.now();
    debugPrint('FalseAlarmManager.onScreamDetected @ $now');
    _screamTimes.add(now);

    // Remove old scream times outside correlation window to keep list small
    _screamTimes.removeWhere((t) => now.difference(t) > correlationWindow);

    // Check for recent fall
    if (_lastFallTime != null) {
      if (now.difference(_lastFallTime!).abs() <= correlationWindow) {
        debugPrint('FalseAlarmManager: core emergency (scream + recent fall)');
        inactivityDetector.showImmediateConfirmation('Core emergency (fall + scream)');
        return;
      }
    }

    // If we have 2 or more screams within correlation window -> immediate confirmation
    if (_screamTimes.length >= 2) {
      debugPrint('FalseAlarmManager: multiple screams within correlation window -> immediate confirmation');
      inactivityDetector.showImmediateConfirmation('Multiple screams detected');
      return;
    }

    // Otherwise single scream -> start inactivity countdown
    inactivityDetector.start(reason: 'Single scream detected', baselineMagnitude: baselineMagnitude);
  }

  // Cancel any ongoing inactivity/confirmation
  void cancelAll() {
    inactivityDetector.cancel('cancelAll called');
  }
}