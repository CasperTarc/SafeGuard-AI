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
  final double impactThreshold; // 2.0g by default
  final double inactivityThreshold; // 0.3g by default

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

  // New: throttle interval for frequent debug messages (ms).
  // Set to 0 to disable throttling (old behaviour).
  final int debugIntervalMs;
  DateTime? _lastDebugTime;

  // --- New enabled flag: when false the detector ignores all samples ---
  bool _enabled = false;

  FallDetector({
    double? impactThreshold,
    double? inactivityThreshold,
    this.inactivityWindow = const Duration(seconds: 8),
    this.minTimeBetweenFalls = const Duration(seconds: 10),
    this.debug = false,
    this.debugIntervalMs = 1000, // default: 1 second between frequent debug emits
  })  : impactThreshold = impactThreshold ?? (2.0 * g),
        inactivityThreshold = inactivityThreshold ?? (0.3 * g);

  // Streams
  Stream<ImpactEvent> get impactStream => _impactController.stream;
  Stream<DateTime> get fallStream => _fallController.stream;
  Stream<String> get debugStream => _debugController.stream;

  // Expose enabled state and control methods
  /// Enable the fall detector. When enabled it will process incoming samples.
  void enable() {
    _enabled = true;
    if (debug) _maybeDebugImmediate('FallDetector: enabled');
  }

  /// Disable the fall detector. When disabled it will ignore incoming samples.
  void disable() {
    _enabled = false;
    // Cancel any pending inactivity wait to avoid ghost reports
    _cancelInactivityWait();
    if (debug) _maybeDebugImmediate('FallDetector: disabled');
  }

  bool get isEnabled => _enabled;

  String _friendlyTimestamp(DateTime dt) {
    final local = dt.toLocal();
    return DateFormat('yyyy-MM-dd EEE h:mma').format(local);
  }

  void addSample(double magnitude, DateTime timestamp) {
    // Guard: ignore all samples if detector disabled
    if (!_enabled) {
      // For debugging you can optionally emit a low-level message here:
      // if (debug) _maybeDebugIfEnabled('Sample ignored: detector disabled');
      return;
    }

    // Debounce: Ignore processing if recently reported fall (to prevent duplicates).
    if (_lastFallTime != null &&
        timestamp.difference(_lastFallTime!).abs() < minTimeBetweenFalls) {
      _maybeDebugImmediate('Ignored sample: in cooldown (${timestamp.difference(_lastFallTime!).inSeconds}s)');
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
        _maybeDebugImmediate('Impact update: new strong (2nd) spike while awaiting -> peak=${_lastImpactPeak.toStringAsFixed(2)}');
        // Emit updated impact candidate
        _impactController.add(event);

        // Restart inactivity timer from this new impact
        _startInactivityWait(timestamp);
        return;
      }

      // If motion resumed above inactivity threshold, cancel confirmation.
      if (magnitude > inactivityThreshold) {
        _maybeDebugImmediate('Motion resumed (m=${magnitude.toStringAsFixed(2)}), cancelling confirmation');
        _cancelInactivityWait();
        return;
      } else {
        // Still below inactivity threshold -> continue waiting.
        _maybeDebugIfEnabled('Still inactive (m=${magnitude.toStringAsFixed(2)})');
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
      _maybeDebugImmediate('Impact detected: Peak = ${_lastImpactPeak.toStringAsFixed(2)}');
      // Emit immediate impact candidate
      _impactController.add(event);

      // Start inactivity confirmation timer
      _startInactivityWait(timestamp);
    } else {
      _maybeDebugIfEnabled('Sample below impact threshold (m=${magnitude.toStringAsFixed(2)})');
    }
  }

  void _startInactivityWait(DateTime impactTime) {
    _awaitingInactivity = true;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(inactivityWindow, () {
      _reportFall(impactTime);
      _awaitingInactivity = false;
      _inactivityTimer = null;
      _lastImpactPeak = 0.0;
    });
    _maybeDebugImmediate('Started inactivity timer (${inactivityWindow.inSeconds}s)');
  }

  void _cancelInactivityWait() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _awaitingInactivity = false;
    _lastImpactPeak = 0.0;
    _lastImpactTime = null;
    _maybeDebugImmediate('Cancelled inactivity wait');
  }

  void _reportFall(DateTime at) {
    _lastFallTime = at;
    // Emit confirmed fall event for other subscribers
    _fallController.add(at);
    if (debug) {
      final friendly = _friendlyTimestamp(at);
      final msg = '[confirmed] Confirmed fall at $friendly';
      _debugController.add(msg);
      // mark last debug time so next frequent messages will be throttled
      _lastDebugTime = DateTime.now();
    }
  }

  void reset() {
    _cancelInactivityWait();
    _lastFallTime = null;
    _maybeDebugImmediate('Detector reset');
  }

  void dispose() {
    _inactivityTimer?.cancel();
    _impactController.close();
    _fallController.close();
    _debugController.close();
  }

  // Emit messages that are considered important and should always go out immediately
  void _maybeDebugImmediate(String message) {
    if (!debug) return;
    try {
      _debugController.add(message);
    } catch (_) {}
  }

  // Emit less-critical debug messages at most once per debugIntervalMs
  void _maybeDebugIfEnabled(String message) {
    if (!debug) return;
    // If debugIntervalMs is 0, behave like previous (no throttling)
    if (debugIntervalMs <= 0) {
      _maybeDebugImmediate(message);
      return;
    }
    final now = DateTime.now();
    if (_lastDebugTime == null) {
      _lastDebugTime = now;
      _maybeDebugImmediate(message);
      return;
    }
    final elapsed = now.difference(_lastDebugTime!).inMilliseconds;
    if (elapsed >= debugIntervalMs) {
      _lastDebugTime = now;
      _maybeDebugImmediate(message);
    }
    // otherwise drop the message (throttle)
  }
}