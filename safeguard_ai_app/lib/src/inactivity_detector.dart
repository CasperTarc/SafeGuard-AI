// InactivityDetector
// Core:
// 1. Acts as a secondary detector after a fall / scream.
// 2. It only activates after a trigger (fall / scream) is detected.
// 3. Starts a 12s inactivity countdown timer.
// 4. If accelerometer > threshold(0.1ms^2) within 12s windows -> cancels inactivity.
// 5. Else, shows a 10s confirmation popup to send alert or cancel.

import 'dart:async';
import 'package:flutter/material.dart';

class InactivityDetector {
  final BuildContext context;
  final VoidCallback onSendAlert;
  final double movementThreshold;
  final Duration inactivityDuration;
  final Duration confirmationDuration;

  Timer? _inactivityTimer;
  Timer? _confirmationTimer;
  bool _inInactivityWindow = false;
  bool _confirmationVisible = false;
  double _movementBaseline = 0.0;
  int _confirmationRemaining = 0;

  InactivityDetector({
    required this.context,
    required this.onSendAlert,
    this.movementThreshold = 0.1,
    this.inactivityDuration = const Duration(seconds: 12),
    this.confirmationDuration = const Duration(seconds: 10),
  });

  // Start the inactivity countdown.
  // baselineMagnitude = magnitude value when the countdown starts.
  void start({required String reason, required double baselineMagnitude}) {
    _inactivityTimer?.cancel();
    _confirmationTimer?.cancel();
    _confirmationVisible = false;
    _inInactivityWindow = true;
    _movementBaseline = baselineMagnitude;
    debugPrint('InactivityDetector.start: reason=$reason baseline=$_movementBaseline');

    _inactivityTimer = Timer(inactivityDuration, () {
      _inInactivityWindow = false;
      debugPrint('InactivityDetector: inactivity duration elapsed -> showing confirmation');
      showConfirmationDialog(title: 'Confirm emergency alert', message: reason);
    });
  }

  // Cancel the inactivity countdown, since movement was detected.
  void cancel(String reason) {
    _inactivityTimer?.cancel();
    _inInactivityWindow = false;
    debugPrint('InactivityDetector.cancel: $reason');
  }

  // Call this on accelerometer magnitude updates.
  // During inactivity window (movement exceeds threshold), cancels the inactivity.
  void handleMagnitude(double magnitude) {
    if (!_inInactivityWindow) return;
    final delta = (magnitude - _movementBaseline).abs();
    if (delta > movementThreshold) {
      cancel('Movement detected (delta=${delta.toStringAsFixed(3)})');
    }
  }

  // Show 10s confirmation popup immediately (use for core emergency).
  Future<void> showImmediateConfirmation(String title) async {
    // Cancel any inactivity timer
    _inactivityTimer?.cancel();
    _inInactivityWindow = false;
    await showConfirmationDialog(title: title, message: 'Immediate confirmation');
  }

  // Internal: show a 10s confirmation dialog with cancel / send now options.
  Future<void> showConfirmationDialog({String title = 'Confirm emergency alert', String message = ''}) async {
    if (!context.mounted) return;
    _confirmationVisible = true;
    _confirmationRemaining = confirmationDuration.inSeconds;

    // Ensure existing confirmation timer is cancelled
    _confirmationTimer?.cancel();

    // Start the periodic timer that will tick the countdown.
    _confirmationTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _confirmationRemaining--;
      if (_confirmationRemaining <= 0) {
        t.cancel();
        // If dialog still present, pop it with 'auto'
        if (Navigator.of(context).canPop()) Navigator.of(context).pop('auto');
      } else {
        // Trigger UI updates if needed (we don't have direct access to a dialog state here).
      }
    });

    // Show dialog; we use barrierDismissible: false so user must explicitly Cancel or Send.
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (c, setState) {
          // The dialog reads the outside _confirmationRemaining variable.
          return AlertDialog(
            title: Text(title),
            content: Text('$message\n\nSending alert in $_confirmationRemaining s.'),
            actions: [
              TextButton(
                onPressed: () {
                  _confirmationTimer?.cancel();
                  _confirmationVisible = false;
                  Navigator.of(ctx).pop('cancelled');
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  _confirmationTimer?.cancel();
                  _confirmationVisible = false;
                  Navigator.of(ctx).pop('send');
                },
                child: const Text('Send now'),
              ),
            ],
          );
        });
      },
    );

    _confirmationTimer?.cancel();
    _confirmationVisible = false;

    if (result == 'cancelled') {
      debugPrint('InactivityDetector: confirmation cancelled by user');
      return;
    }
    // 'send' or 'auto' or null treated as send
    debugPrint('InactivityDetector: confirmation accepted -> sending alert');
    onSendAlert();
  }

  /// Dispose timers.
  void dispose() {
    _inactivityTimer?.cancel();
    _confirmationTimer?.cancel();
  }
}