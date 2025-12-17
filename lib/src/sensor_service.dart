// SensorService
// Core:
//  - Read device accelerometer, compute into a single magnitude per sample,
//  - Then forward them to a FallDetector via fallDetector.addSample(magnitude, timestamp).
//  - Remove gravity baseline (9.80665 m/s^2) in calculation.
//
// Research [BASELINE] (lowPassAlpha):
//  - Normal walking: ~ 0.1–0.5 g
//  - Swinging phone: ~ 1.2–1.5 g
//  - Phone hit against object: ~ 1.5–3 g
//  - Robbery / push the user: ~ 3–6 g
//  - Real fall: ~ 2.5–6 g

import 'dart:async';
import 'dart:math' as math;

import 'package:sensors_plus/sensors_plus.dart';
import 'fall_detector.dart';

// Passing debug messages and raw sample for debug.
typedef SensorDebugCallback = void Function(String message);

// Passing processed magnitude and timestamp for each sample.
typedef SensorSampleCallback = void Function(double magnitude, DateTime timestamp);

class SensorService {
  final FallDetector fallDetector;

  // To forwards processed sensor values to detector. (Typical values: 20-100ms)
  // Default changed to 40ms as a balanced starting point (responsiveness vs battery).
  final int sampleMs;

  // Low-pass smoothing factor in (0..1). Closer to 1 => stronger smoothing.
  // Default changed to 0.90 as a balanced starting point (stable baseline, still responsive).
  final double lowPassAlpha;

  // How often the onSample callback should be invoked (milliseconds).
  // Set to 1000 by default (once per second) to reduce log/UI flood.
  final int sampleCallbackIntervalMs;

  // Debug callbacks
  final SensorDebugCallback? onDebug;
  final SensorSampleCallback? onSample;

  // Factory to obtain the accelerometer stream.
  // To provide a fake StreamController stream. Default uses sensors_plus API.
  final Stream<AccelerometerEvent> Function() accelerometerStreamFactory;

  StreamSubscription<AccelerometerEvent>? _sub;
  DateTime? _lastSampleTime;
  double? _smoothedMagnitude;
  bool _running = false;

  // Track last time we invoked onSample to throttle calls to UI/debug listeners.
  DateTime? _lastSampleCallbackTime;

  SensorService({
    required this.fallDetector,
    this.sampleMs = 40,
    this.lowPassAlpha = 0.90,
    this.onDebug,
    this.onSample,
    Stream<AccelerometerEvent> Function()? accelerometerStreamFactory,
    this.sampleCallbackIntervalMs = 1000,
  }) : accelerometerStreamFactory =
            accelerometerStreamFactory ?? accelerometerEventStream,
        assert(sampleMs > 0),
        assert(lowPassAlpha >= 0 && lowPassAlpha <= 1),
        assert(sampleCallbackIntervalMs >= 0);

  bool get isRunning => _running;

  // Start listening to device accelerometer and forward processed magnitudes.
  void start() {
    if (_running) return;
    _running = true;
    _lastSampleTime = null;
    _smoothedMagnitude = null;
    _lastSampleCallbackTime = null;

    onDebug?.call(
      'SensorService: starting (sampleMs=$sampleMs, lowPassAlpha=$lowPassAlpha, gravityComp=enabled, callbackIntervalMs=$sampleCallbackIntervalMs)',
    );

    // Subscribe to the raw accelerometer stream.
    _sub = accelerometerStreamFactory().listen(
      _handleEvent,
      onError: (e) {
        onDebug?.call('SensorService: accelerometer error: $e');
      },
      onDone: () {
        onDebug?.call('SensorService: accelerometer stream done');
      },
    );
  }

  // Stop listening. Keeps instance usable (can start() again).
  void stop() {
    if (!_running) return;
    _sub?.cancel();
    _sub = null;
    _running = false;
    onDebug?.call('SensorService: stopped');
  }

  // Dispose permanently and release resources.
  void dispose() {
    stop();
    _smoothedMagnitude = null;
    _lastSampleTime = null;
    _lastSampleCallbackTime = null;
  }

  void _handleEvent(AccelerometerEvent ev) {
    final now = DateTime.now();

    // Limits the processing rate to prevent excessive resource usage, ensuring minimum sampleMs elapsed.
    if (_lastSampleTime != null) {
      final elapsed = now.difference(_lastSampleTime!).inMilliseconds;
      if (elapsed < sampleMs) {
        return;
      }
    }
    _lastSampleTime = now;

    // Compute vector magnitude: sqrt(x^2 + y^2 + z^2) -> single value representing overall force.
    final rawMag = math.sqrt(ev.x * ev.x + ev.y * ev.y + ev.z * ev.z);

    // Remove gravity baseline (9.80665 m/s^2), clamp at zero.
    final magNoGravity = (rawMag - 9.80665).clamp(0.0, double.infinity);

    // Apply low-pass smoothing (EMA).
    // Produce a smoothed baseline value that represents the recent, slowly-changing acceleration level (used as a reference).
    final smoothed = (_smoothedMagnitude == null || lowPassAlpha >= 1.0)
        ? magNoGravity // initialize to current value
        : (lowPassAlpha * _smoothedMagnitude! +
            (1 - lowPassAlpha) * magNoGravity); // EMA calculation to give slow motion
    _smoothedMagnitude =
        smoothed; // stored it back into _smoothedMagnitude for the next sample

    // Throttled forward to onSample callback (UI/debug). Calls at most once per sampleCallbackIntervalMs.
    try {
      if (onSample != null) {
        final shouldCallSample = _shouldCallSampleCallback(now);
        if (shouldCallSample) {
          _lastSampleCallbackTime = now;
          onSample!.call(smoothed, now);
        }
      }
    } catch (_) {
      // keep pipeline robust
    }

    // Forward to FallDetector: Add sample (magnitude, timestamp).
    try {
      fallDetector.addSample(smoothed, now);
    } catch (e) {
      onDebug?.call('SensorService: error forwarding to FallDetector: $e');
    }
  }

  bool _shouldCallSampleCallback(DateTime now) {
    if (_lastSampleCallbackTime == null) return true;
    final elapsed = now.difference(_lastSampleCallbackTime!).inMilliseconds;
    return elapsed >= sampleCallbackIntervalMs;
  }
}