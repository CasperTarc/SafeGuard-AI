// url=https://github.com/CasperTarc/SafeGuard-AI/blob/main/safeguard_ai_app/lib/src/false_alarm.dart
// FalseAlarm Manager — global confirmation gate + cooldown
//
// - isConfirmationActive() returns true while a confirmation dialog is visible OR
//   while a post-confirmation cooldown is still running.
// - Use startConfirmation() before showing a confirmation dialog, and call
//   endConfirmationAndStartCooldown() after the dialog completes (so the cooldown starts).
//
// FalseAlarmManager uses inactivityDetector.showImmediateConfirmation / start(...) as before,
// but now checks isConfirmationActive() to avoid scheduling/showing duplicates.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'inactivity_detector.dart';

/// Global confirmation gate + cooldown state (kept here to avoid adding a new file)
bool _globalConfirmationVisible = false;
DateTime? _globalConfirmationCooldownUntil;
Duration _globalConfirmationCooldownDuration = const Duration(seconds: 10);

/// Returns true if a confirmation is currently visible OR the cooldown period after
/// a confirmation has not yet expired.
bool isConfirmationActive() {
  if (_globalConfirmationVisible) return true;
  final until = _globalConfirmationCooldownUntil;
  if (until == null) return false;
  return DateTime.now().isBefore(until);
}

/// Mark that the app is entering a confirmation (dialog is about to show).
void startConfirmation() {
  _globalConfirmationVisible = true;
  _globalConfirmationCooldownUntil = null;
  debugPrint('Global confirmation: START (visible=true)');
}

/// Mark that confirmation ended and start the cooldown timer. If `cooldown` is provided,
/// use it; otherwise default to _globalConfirmationCooldownDuration.
void endConfirmationAndStartCooldown([Duration? cooldown]) {
  _globalConfirmationVisible = false;
  final d = cooldown ?? _globalConfirmationCooldownDuration;
  _globalConfirmationCooldownUntil = DateTime.now().add(d);
  debugPrint('Global confirmation: END -> cooldown until $_globalConfirmationCooldownUntil');
}

/// Optionally set global cooldown duration (if you want to change it at runtime)
void setGlobalConfirmationCooldownDuration(Duration d) {
  _globalConfirmationCooldownDuration = d;
  debugPrint('Global confirmation: cooldown duration set to $d');
}

/// FalseAlarmManager coordinates fall/scream/inactivity logic.
class FalseAlarmManager {
  final InactivityDetector inactivityDetector;
  final VoidCallback onSendAlert;
  final Duration correlationWindow;

  DateTime? _lastFallTime;
  final List<DateTime> _screamTimes = [];

  // Tracks whether this manager has scheduled an inactivity window (secondary trigger).
  bool _hasScheduledInactivityWindow = false;

  FalseAlarmManager({
    required this.inactivityDetector,
    required this.onSendAlert,
    this.correlationWindow = const Duration(seconds: 5),
  });

  // Internal helper: schedule immediate confirmation via inactivityDetector
  // InactivityDetector.showImmediateConfirmation will call startConfirmation()/endConfirmationAndStartCooldown
  Future<void> _scheduleImmediateConfirmation(String title) async {
    if (isConfirmationActive() || inactivityDetector.hasActiveWindowOrConfirmation) {
      debugPrint('FalseAlarmManager: suppressing immediate confirmation; gate/window active');
      return;
    }

    try {
      await inactivityDetector.showImmediateConfirmation(title);
    } catch (e) {
      debugPrint('FalseAlarmManager: error showing immediate confirmation: $e');
      // fallback: try to call onSendAlert directly
      try {
        onSendAlert();
      } catch (_) {}
    }
  }

  /// Called when a fall is detected.
  void onFallDetected({required double baselineMagnitude}) {
    final now = DateTime.now();
    debugPrint('FalseAlarmManager.onFallDetected @ $now');

    // If confirmation/cooldown is active or we already have a scheduled inactivity window, ignore.
    if (isConfirmationActive() || _hasScheduledInactivityWindow || inactivityDetector.hasActiveWindowOrConfirmation) {
      debugPrint('FalseAlarmManager: ignored onFallDetected because confirmation/window already active');
      _lastFallTime = now;
      return;
    }

    _lastFallTime = now;

    // Check for recent scream => core emergency
    if (_screamTimes.isNotEmpty) {
      final lastScream = _screamTimes.last;
      if (now.difference(lastScream).abs() <= correlationWindow) {
        debugPrint('FalseAlarmManager: core emergency (fall + recent scream)');
        _scheduleImmediateConfirmation('Core emergency (fall + scream)');
        return;
      }
    }

    // Otherwise start inactivity countdown
    _hasScheduledInactivityWindow = true;
    try {
      inactivityDetector.start(reason: 'Fall detected', baselineMagnitude: baselineMagnitude);
      debugPrint('FalseAlarmManager: scheduled inactivity window for fall');
    } catch (e) {
      debugPrint('FalseAlarmManager: failed to start inactivity detector for fall: $e — scheduling immediate confirmation');
      _hasScheduledInactivityWindow = false;
      _scheduleImmediateConfirmation('Possible Danger Detected...');
    }
  }

  /// Called when a scream is detected.
  void onScreamDetected({required double baselineMagnitude}) {
    final now = DateTime.now();
    debugPrint('FalseAlarmManager.onScreamDetected @ $now');

    if (isConfirmationActive() || _hasScheduledInactivityWindow || inactivityDetector.hasActiveWindowOrConfirmation) {
      debugPrint('FalseAlarmManager: ignored onScreamDetected because confirmation/window already active');
      _screamTimes.add(now);
      _screamTimes.removeWhere((t) => now.difference(t) > correlationWindow);
      return;
    }

    _screamTimes.add(now);
    _screamTimes.removeWhere((t) => now.difference(t) > correlationWindow);

    if (_lastFallTime != null) {
      if (now.difference(_lastFallTime!).abs() <= correlationWindow) {
        debugPrint('FalseAlarmManager: core emergency (scream + recent fall)');
        _scheduleImmediateConfirmation('Core emergency (fall + scream)');
        return;
      }
    }

    if (_screamTimes.length >= 2) {
      debugPrint('FalseAlarmManager: multiple screams within window -> immediate confirmation');
      _scheduleImmediateConfirmation('Multiple screams detected');
      return;
    }

    // Single scream -> inactivity countdown
    _hasScheduledInactivityWindow = true;
    try {
      inactivityDetector.start(reason: 'Single scream detected', baselineMagnitude: baselineMagnitude);
      debugPrint('FalseAlarmManager: scheduled inactivity window for single scream');
    } catch (e) {
      debugPrint('FalseAlarmManager: failed to start inactivity detector for scream: $e — scheduling immediate confirmation');
      _hasScheduledInactivityWindow = false;
      _scheduleImmediateConfirmation('Possible Danger Detected...');
    }
  }

  /// Cancel any ongoing inactivity/confirmation scheduling that this manager started.
  void cancelAll() {
    debugPrint('FalseAlarmManager.cancelAll() called — canceling inactivity and clearing scheduled flag');
    try {
      inactivityDetector.cancel('cancelAll called');
    } catch (e) {
      debugPrint('FalseAlarmManager: error cancelling inactivity detector: $e');
    }
    _hasScheduledInactivityWindow = false;
  }

  /// Inform the manager that a confirmation dialog has ended (so future triggers may schedule again).
  /// InactivityDetector already calls endConfirmationAndStartCooldown so this is only needed if
  /// you want FalseAlarmManager to reset its internal scheduled flag from elsewhere.
  void notifyConfirmationHidden() {
    _hasScheduledInactivityWindow = false;
  }
}