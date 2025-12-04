// FallDetector
// Core:
// - Detect a sudden impact spike in the accelerometer magnitude (SMV > 2g) ~ (19.6 m/s^2).
// - Confirm fall if followed by a period of inactivity. (SMV < 0.3g for 8s).
// - If no motion change after fall, trigger inactivity.
//
// Extra:
// - Debounce (Delay) multiple falls within a short time window (10s).
// - Testing and debugging detection logic.

import 'dart:async';
import 'dart:math' as math;
import 'package:intl/intl.dart';

// Emit event immediately when an impact spike is detected.
class ImpactEvent {
  final DateTime timestamp;
  final double peakMagnitude;

  ImpactEvent({required this.timestamp, required this.peakMagnitude});

  @override
  String toString() =>
      'ImpactEvent(ts:${timestamp.toIso8601String()}, peak:${peakMagnitude.toStringAsFixed(2)} m/s^2)';
}

class FallDetector {
  static const double g = 9.80665;
  final double impactThreshold; // 2.0g
  final double inactivityThreshold; // 0.3g

  final Duration inactivityWindow; // default 8s
  final Duration minTimeBetweenFalls; // delay between reported falls

  final StreamController<ImpactEvent> _impactController =
      StreamController.broadcast();
  final StreamController<DateTime> _fallController =
      StreamController.broadcast();

  // Debug messages for tests / UI
  final StreamController<String> _debugController =
      StreamController.broadcast();

  // Internal state
  bool _awaitingInactivity = false;
  Timer? _inactivityTimer;
  DateTime? _lastFallTime;
  DateTime? _lastImpactTime;
  double _lastImpactPeak = 0.0;
  final bool debug;

  FallDetector({
    double? impactThreshold,
    double? inactivityThreshold,
    this.inactivityWindow = const Duration(seconds: 8),
    this.minTimeBetweenFalls = const Duration(seconds: 10),
    this.debug = false,
  }) : impactThreshold = impactThreshold ?? (2.0 * g),
       inactivityThreshold = inactivityThreshold ?? (0.3 * g);

  // Streams
  Stream<ImpactEvent> get impactStream => _impactController.stream;
  Stream<DateTime> get fallStream => _fallController.stream;
  Stream<String> get debugStream => _debugController.stream;

  // Format timestamp for debug messages.
  String _friendlyTimestamp(DateTime dt) {
    final local = dt.toLocal();
    return DateFormat('yyyy-MM-dd EEE h:mma').format(local);
  }

  // Add a new accelerometer magnitude sample for processing.
  void addSample(double magnitude, DateTime timestamp) {
    // Debounce: Ignore processing if recently reported fall (to prevent duplicates).
    if (_lastFallTime != null &&
        timestamp.difference(_lastFallTime!).abs() < minTimeBetweenFalls) {
      _maybeDebug(
        'Ignored sample: in cooldown (${timestamp.difference(_lastFallTime!).inSeconds}s)',
      );
      return;
    }

    // Confirmation mode: already detected an impact and are awaiting inactivity.
    if (_awaitingInactivity) {
      // Treat a new strong spike as continuation of current candidate.
      if (magnitude >= impactThreshold) {
        _lastImpactPeak = math.max(_lastImpactPeak, magnitude);
        _lastImpactTime = timestamp;

        final event = ImpactEvent(
          timestamp: timestamp,
          peakMagnitude: _lastImpactPeak,
        );
        _maybeDebug(
          'Impact update: new strong (2nd) spike while awaiting -> peak=${_lastImpactPeak.toStringAsFixed(2)}',
        );
        // Emit updated impact candidate
        _impactController.add(event);

        // Restart inactivity timer from this new impact
        _startInactivityWait(timestamp);
        return;
      }

      // If motion resumed above inactivity threshold, cancel confirmation.
      if (magnitude > inactivityThreshold) {
        _maybeDebug(
          'Motion resumed (m=${magnitude.toStringAsFixed(2)}), cancelling confirmation',
        );
        _cancelInactivityWait();
        return;
      } else {
        // Still below inactivity threshold -> continue waiting.
        _maybeDebugIfEnabled(
          'Still inactive (m=${magnitude.toStringAsFixed(2)})',
        );
        return;
      }
    }

    // Not awaiting: look for a new impact spike.
    if (magnitude >= impactThreshold) {
      _lastImpactPeak = math.max(_lastImpactPeak, magnitude);
      _lastImpactTime = timestamp;

      final event = ImpactEvent(
        timestamp: timestamp,
        peakMagnitude: _lastImpactPeak,
      );
      _maybeDebug(
        'Impact detected: Peak = ${_lastImpactPeak.toStringAsFixed(2)}',
      );
      // Emit immediate impact candidate
      _impactController.add(event);

      // Start inactivity confirmation timer
      _startInactivityWait(timestamp);
    } else {
      _maybeDebugIfEnabled(
        'Sample below impact threshold (m=${magnitude.toStringAsFixed(2)})',
      );
    }
  }

  // Start or restart the inactivity confirmation timer.
  void _startInactivityWait(DateTime impactTime) {
    _awaitingInactivity = true;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(inactivityWindow, () {
      _reportFall(impactTime);
      _awaitingInactivity = false;
      _inactivityTimer = null;
      _lastImpactPeak = 0.0;
    });
    _maybeDebug('Started inactivity timer (${inactivityWindow.inSeconds}s)');
  }

  // Cancel any pending inactivity confirmation.
  void _cancelInactivityWait() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _awaitingInactivity = false;
    _lastImpactPeak = 0.0;
    _lastImpactTime = null;
    _maybeDebug('Cancelled inactivity wait');
  }

  // No motion detected in inactivityWindow, emit confirmed fall message.
  void _reportFall(DateTime at) {
    _lastFallTime = at;
    // Emit confirmed fall event for other subscribers
    _fallController.add(at);
    if (debug) {
      final friendly = _friendlyTimestamp(at);
      final msg = '[confirmed] Confirmed fall at $friendly';
      _debugController.add(msg);
    }
  }

  // Reset detector internal state
  void reset() {
    _cancelInactivityWait();
    _lastFallTime = null;
    _maybeDebug('Detector reset');
  }

  // Dispose resources when detector is no longer used.
  void dispose() {
    _inactivityTimer?.cancel();
    _impactController.close();
    _fallController.close();
    _debugController.close();
  }

  // Internal debug helpers
  void _maybeDebug(String message) {
    if (debug) {
      _debugController.add(message);
    }
  }

  void _maybeDebugIfEnabled(String message) {
    if (debug) _maybeDebug(message);
  }
}
