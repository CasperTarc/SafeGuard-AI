// ScreamDetector
// Core:
// 1. Microphone permission & capture of audio frames/windows (1s @ 16 kHz).
// 2. Lightweight pre-filter (dB) and buffering of recent samples.
// 3. Calling capturePcmCallback to obtain raw PCM for model confirmation.
// 4. Decision logic: combined rule (prefilter + modelThreshold), cooldown and consecutive-window logic.
//
// Notes:
// - Require permission to access microphone.
// - MFCC / heavy DSP is NOT performed here, it performed at scream_inference.dart.
//
// Research:
// - Human Scream: ~85 decibels (dB)
// - But in our logic, we use a prefilter threshold of 70 dB to catch more potential screams

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

/// Runtime configuration for the detector.
///
/// Note: triggerDb default changed to 70.0 (recommended starting point).
class ScreamDetectorConfig {
  final double triggerDb; // dB prefilter threshold
  final int clipPreMs;
  final int clipPostMs;
  final int samplePeriodMs;
  final bool saveClipOnDetect;

  const ScreamDetectorConfig({
    this.triggerDb = 70.0, // CHANGED: default 70 dB to improve recall
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
/// Default behavior: when decibel >= triggerDb, capture 1s PCM via capturePcmCallback (if provided),
/// call model.predictFromInt16(pcm) and require model score >= modelThreshold to confirm.
/// Additional features: consecutive confirmations, cooldown to avoid repeated alerts.
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

  ScreamDetector({
    required this.config,
    required this.onScreamDetected,
    this.onScreamCandidate,
    this.onDebug,
    this.model,
    this.modelThreshold = 0.20,
    this.capturePcmCallback,
    this.consecutiveRequired = 1, // default: one confirmed window needed
    this.cooldownMs = 5000, // default 5 seconds cooldown
  });

  String _fmtTs(DateTime dt) => DateFormat('yyyy-MM-dd HH:mm:ss').format(dt.toLocal());

  Future<void> start() async {
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
    if (!_running) return;
    _log('ScreamDetector.stop()');
    await _noiseSubscription?.cancel();
    _noiseSubscription = null;
    _noiseMeter = null;
    _running = false;
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