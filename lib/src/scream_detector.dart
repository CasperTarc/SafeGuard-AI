// ScreamDetector (patched)
// - Adds enable()/disable() and an internal _enabled flag so Home can reliably
//   stop the detector and ensure no further processing occurs when disabled.
// - start()/stop() behavior preserved; enable() calls start() and disable() calls stop().

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'scream_inference.dart';

/// Event emitted when detection is confirmed.
class ScreamEvent {
  final DateTime timestamp;
  final double score; // if model confirmed -> model score, else decibel (fallback)
  final String? clipPath;
  ScreamEvent({required this.timestamp, required this.score, this.clipPath});
  @override
  String toString() => 'ScreamEvent(ts=$timestamp score=${score.toStringAsFixed(3)} clip=$clipPath)';
}

/// Candidate snippet (useful for labeling / saving)
class ScreamCandidate {
  final DateTime timestamp;
  final double decibel;
  final String? temporaryClipPath;
  ScreamCandidate({required this.timestamp, required this.decibel, this.temporaryClipPath});
}

class ScreamDetectorConfig {
  final double triggerDb; // dB prefilter threshold
  final int clipPreMs;
  final int clipPostMs;
  final int samplePeriodMs;
  final bool saveClipOnDetect;

  const ScreamDetectorConfig({
    this.triggerDb = 70.0,
    this.clipPreMs = 500,
    this.clipPostMs = 1500,
    this.samplePeriodMs = 50,
    this.saveClipOnDetect = false,
  });
}

typedef OnScreamDetected = void Function(ScreamEvent event);
typedef OnScreamCandidate = void Function(ScreamCandidate candidate);
typedef OnDebugCallback = void Function(String message);
typedef CapturePcmCallback = Future<List<int>?> Function(); // return 1s int16 PCM, mono

/// ScreamDetector: combines loudness prefilter with optional model confirmation (AI).
class ScreamDetector {
  final ScreamDetectorConfig config;
  final OnScreamDetected onScreamDetected;
  final OnScreamCandidate? onScreamCandidate;
  final OnDebugCallback? onDebug;

  // Optional ML confirmation
  final ScreamInference? model;
  final double modelThreshold; // e.g., 0.20
  final CapturePcmCallback? capturePcmCallback;

  // Optional robustness controls
  final int consecutiveRequired; // require N consecutive model-confirmed windows
  final int cooldownMs; // ms to ignore further confirmed detections after an alert

  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSubscription;
  final List<_TimeDb> _recentSamples = [];
  final int _maxSamples = 2000;
  bool _running = false;

  // internal state for confirmation logic
  int _consecutiveCount = 0;
  DateTime? _lastConfirmedAt;
  bool _confirming = false;

  // New: enabled flag so callers can disable the detector without disposing it
  bool _enabled = false;

  ScreamDetector({
    required this.config,
    required this.onScreamDetected,
    this.onScreamCandidate,
    this.onDebug,
    this.model,
    this.modelThreshold = 0.20,
    this.capturePcmCallback,
    this.consecutiveRequired = 1,
    this.cooldownMs = 5000,
  });

  String _fmtTs(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm:ss').format(dt.toLocal());

  /// Enable the detector (calls start).
  /// This requests microphone permission and begins listening.
  Future<void> enable() async {
    if (_enabled) return;
    _enabled = true;
    await start();
  }

  /// Disable the detector (calls stop) and prevent further processing.
  Future<void> disable() async {
    if (!_enabled) return;
    _enabled = false;
    await stop();
  }

  Future<void> start() async {
    if (!_enabled) {
      // If caller called start without enabling we enable implicitly.
      _enabled = true;
    }
    if (_running) return;
    _log('ScreamDetector.start()');

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _log('Microphone permission denied.');
      throw Exception('Microphone permission not granted');
    }

    _noiseMeter = NoiseMeter();
    try {
      _noiseSubscription = _noiseMeter!.noise.listen(
        _onNoiseReading,
        onError: (err) => _log('Noise meter error: $err'),
      );
      _running = true;
      _log('ScreamDetector started (triggerDb=${config.triggerDb} dB)');
    } catch (e) {
      _log('Error starting NoiseMeter: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    if (!_running && _noiseSubscription == null) {
      _running = false;
      return;
    }
    _log('ScreamDetector.stop()');
    try {
      await _noiseSubscription?.cancel();
    } catch (_) {}
    _noiseSubscription = null;
    _noiseMeter = null;
    _running = false;
    _confirming = false;
    _consecutiveCount = 0;
  }

  void dispose() {
    _log('ScreamDetector.dispose()');
    _noiseSubscription?.cancel();
    _noiseSubscription = null;
    _noiseMeter = null;
    _recentSamples.clear();
  }

  // Called for each NoiseReading from the NoiseMeter stream.
  void _onNoiseReading(NoiseReading reading) async {
    // Defensive: ignore readings when disabled
    if (!_enabled) return;

    final ts = DateTime.now();
    final double db = reading.meanDecibel ?? reading.maxDecibel ?? 0.0;

    if (_recentSamples.isNotEmpty) {
      final last = _recentSamples.last;
      final elapsed = ts.difference(last.time).inMilliseconds;
      if (elapsed < config.samplePeriodMs) return;
    }

    _pushSample(ts, db);
    _debug('[Noise] ${_fmtTs(ts)} db=${db.toStringAsFixed(1)}');

    // Pre-filter by loudness
    if (db >= config.triggerDb) {
      _log('Prefilter hit: db=${db.toStringAsFixed(1)} at ${_fmtTs(ts)}');

      final candidate = ScreamCandidate(timestamp: ts, decibel: db, temporaryClipPath: null);
      try {
        onScreamCandidate?.call(candidate);
      } catch (e) {
        _log('onScreamCandidate callback error: $e');
      }

      // Check cooldown: if last confirmed was within cooldownMs, ignore
      if (_lastConfirmedAt != null) {
        final sinceLast = ts.difference(_lastConfirmedAt!).inMilliseconds;
        if (sinceLast < cooldownMs) {
          _debug('In cooldown ($sinceLast ms since last confirmed). Skipping confirmation.');
          return;
        }
      }

      // If a model and capture function are provided, use AI confirmation
      if (model != null && capturePcmCallback != null) {
        // Avoid overlapping confirmations
        if (_confirming) {
          _debug('Already confirming a candidate; skipping this prefilter hit.');
          return;
        }
        _confirming = true;
        try {
          final List<int>? pcm = await capturePcmCallback!();
          if (pcm != null && pcm.isNotEmpty) {
            final double score = await model!.predictFromInt16(pcm);
            _log('Model score: ${score.toStringAsFixed(3)} (threshold ${modelThreshold.toStringAsFixed(2)})');

            if (score >= modelThreshold) {
              _consecutiveCount += 1;
              _debug('Consecutive confirmed count: $_consecutiveCount / $consecutiveRequired');
              if (_consecutiveCount >= consecutiveRequired) {
                // Confirmed detection
                _lastConfirmedAt = DateTime.now();
                _consecutiveCount = 0; // reset counter after confirming
                final event = ScreamEvent(timestamp: ts, score: score, clipPath: null);
                try {
                  onScreamDetected.call(event);
                } catch (e) {
                  _log('onScreamDetected callback error: $e');
                }
              }
            } else {
              // model rejected -> reset consecutive count
              _debug('Model rejected candidate (score below threshold). Resetting consecutive count.');
              _consecutiveCount = 0;
            }
          } else {
            // If no PCM returned, fallback to dB-only detection (as a last resort)
            _debug('capturePcmCallback returned no PCM; falling back to dB-only detection.');
            final event = ScreamEvent(timestamp: ts, score: db, clipPath: null);
            try {
              onScreamDetected.call(event);
            } catch (e) {
              _log('onScreamDetected callback error: $e');
            }
          }
        } catch (e) {
          // On error during capture/model, fallback to dB-only detection and reset state
          _log('Error during model confirmation: $e. Falling back to dB-only detection.');
          _consecutiveCount = 0;
          final event = ScreamEvent(timestamp: ts, score: db, clipPath: null);
          try {
            onScreamDetected.call(event);
          } catch (_) {}
        } finally {
          _confirming = false;
        }
      } else {
        // No model/capture -> pure dB detection (legacy fallback)
        final event = ScreamEvent(timestamp: ts, score: db, clipPath: null);
        try {
          onScreamDetected.call(event);
        } catch (e) {
          _log('onScreamDetected callback error: $e');
        }
      }
    }
  }

  void _pushSample(DateTime time, double db) {
    _recentSamples.add(_TimeDb(time: time, db: db));
    if (_recentSamples.length > _maxSamples) _recentSamples.removeAt(0);
  }

  void _log(String s) => _debug('[ScreamDetector] $s');

  void _debug(String s) {
    if (onDebug != null) {
      try {
        onDebug!(s);
      } catch (_) {}
    } else {
      if (kDebugMode) print(s);
    }
  }
}

class _TimeDb {
  final DateTime time;
  final double db;
  _TimeDb({required this.time, required this.db});
}