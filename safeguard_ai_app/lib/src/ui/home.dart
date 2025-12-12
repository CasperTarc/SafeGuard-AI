// Home page — updated to enable/disable shake detection when Auto Safety toggles.
// Long-press manual trigger remains enabled regardless.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../fall_detector.dart';
import '../sensor_service.dart';
import '../manual_trigger.dart';
import '../scream_detector.dart';
import '../inactivity_detector.dart';
import '../false_alarm.dart' show isConfirmationActive; // import gate query
import 'widgets.dart';
import 'confirmation.dart'; // provides showConfirmationDialog(...)
import 'sent.dart'; // provides showSentDialog(...)

class HomePageView extends StatefulWidget {
  const HomePageView({super.key});

  @override
  State<HomePageView> createState() => _HomePageViewState();
}

class _HomePageViewState extends State<HomePageView> {
  bool _autoSafety = false;

  // Automated detectors (created in initState, started only when Auto Safety ON)
  late final FallDetector _fallDetector;
  late final SensorService _sensorService;
  StreamSubscription<DateTime>? _fallSub;
  StreamSubscription<String>? _fdDebugSub;

  ScreamDetector? _screamDetector;
  InactivityDetector? _inactivityDetector;

  late final ManualTrigger _manualTrigger;
  double? _lastSampleMagnitude;

  Timer? _holdTimer;
  final Duration _holdDuration = const Duration(seconds: 5);
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();

    _fallDetector = FallDetector(debug: true);
    _fdDebugSub = _fallDetector.debugStream.listen((m) => debugPrint('[FD] $m'));
    _fallSub = _fallDetector.fallStream.listen((dt) async {
      debugPrint('[FD] FALL CONFIRMED at $dt');

      // Only vibrate if gate is not active
      if (!isConfirmationActive()) {
        try {
          await HapticFeedback.heavyImpact();
        } catch (_) {}
      }

      if (!mounted) return;

      if (_autoSafety) {
        final baseline = _lastSampleMagnitude ?? 0.0;
        try {
          if (_inactivityDetector != null) {
            _inactivityDetector!.start(reason: 'Possible Danger Detected...', baselineMagnitude: baseline);
            debugPrint('[UI] InactivityDetector.start fired for fall (baseline=$baseline)');
          } else {
            // Fallback: InactivityDetector not yet initialized; show confirmation UI directly for fall
            debugPrint('[UI] InactivityDetector not initialized yet — showing confirmation directly for fall');
            showConfirmationDialog(context, seconds: 10, alertType: 'fall', trigger: 'auto');
          }
        } catch (e) {
          debugPrint('[UI] Error starting InactivityDetector for fall: $e');
          showConfirmationDialog(context, seconds: 10, alertType: 'fall', trigger: 'auto');
        }
      } else {
        debugPrint('[UI] Auto Safety OFF: ignoring automated fall event');
      }
    });

    _sensorService = SensorService(
      fallDetector: _fallDetector,
      sampleMs: 40,
      lowPassAlpha: 0.90,
      sampleCallbackIntervalMs: 500,
      onDebug: (m) => debugPrint('[SS] $m'),
      onSample: (mag, ts) {
        _lastSampleMagnitude = mag;
        if (mag > 1.0) debugPrint('[SS] sample=${mag.toStringAsFixed(2)} at $ts');
        try {
          _inactivityDetector?.handleMagnitude(mag);
        } catch (_) {}
      },
    );

    _screamDetector = ScreamDetector(
      config: const ScreamDetectorConfig(),
      onScreamDetected: (evt) async {
        debugPrint('[SD] Scream detected at ${evt.timestamp} score=${evt.score}');

        // Only vibrate if gate is not active
        if (!isConfirmationActive()) {
          try {
            await HapticFeedback.heavyImpact();
          } catch (_) {}
        }

        if (!mounted) return;

        if (_autoSafety) {
          final baseline = _lastSampleMagnitude ?? 0.0;
          try {
            if (_inactivityDetector != null) {
              _inactivityDetector!.start(reason: 'Possible Danger Detected...', baselineMagnitude: baseline);
              debugPrint('[UI] InactivityDetector.start fired for scream (baseline=$baseline)');
            } else {
              // Fallback: InactivityDetector not yet initialized; show confirmation UI directly for scream
              debugPrint('[UI] InactivityDetector not initialized yet — showing confirmation directly for scream');
              showConfirmationDialog(context, seconds: 10, alertType: 'scream', trigger: 'auto');
            }
          } catch (e) {
            debugPrint('[UI] Error starting InactivityDetector for scream: $e');
            showConfirmationDialog(context, seconds: 10, alertType: 'scream', trigger: 'auto');
          }
        } else {
          debugPrint('[UI] Auto Safety OFF: ignoring automated scream event');
        }
      },
      onScreamCandidate: (candidate) {
        debugPrint('[SD] candidate db=${candidate.decibel} @ ${candidate.timestamp}');
      },
      onDebug: (m) => debugPrint('[SD] $m'),
    );

  // When creating the ManualTrigger in initState:
  _manualTrigger = ManualTrigger(
    onTriggered: (method) => _onManualTriggered(method),
    threshold: 2.0,
    requiredPeaks: 5,
    window: const Duration(seconds: 3),
    baselineAlpha: 0.1,
  );

    // Start listening for shake events, but enable/disable shake detection according to _autoSafety.
    _manualTrigger.startListening();
    // Ensure shake detection is disabled when auto safety is ON (initially _autoSafety=false so enabled).
    _manualTrigger.setShakeEnabled(!_autoSafety);
    debugPrint('[UI] ManualTrigger started (shakeEnabled=${_manualTrigger.isShakeEnabled})');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _inactivityDetector = InactivityDetector(
        context: context,
        onSendAlert: () {
          try {
            showSentDialog(context);
          } catch (e) {
            debugPrint('[UI] showSentDialog error: $e');
          }
        },
      );
    });
  }

  @override
  void dispose() {
    _fallSub?.cancel();
    _fdDebugSub?.cancel();

    try {
      _sensorService.dispose();
      _fallDetector.dispose();
    } catch (_) {}

    try {
      _screamDetector?.disable(); // ensure stopped
      _screamDetector?.dispose();
    } catch (_) {}

    try {
      _inactivityDetector?.disable();
      _inactivityDetector?.dispose();
    } catch (_) {}

    _manualTrigger.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  // Fire the trigger programmatically (long-press) uses ManualTrigger.fireTrigger()
  // which now calls onTriggered('long_press').

  // _onManualTriggered updated signature:
  void _onManualTriggered(String method) async {
    debugPrint('[MT] Manual trigger fired -> _onManualTriggered(method=$method)');

    // If a confirmation is already active, ignore manual triggers to avoid duplicates
    if (isConfirmationActive()) {
      debugPrint('[MT] Manual trigger ignored because confirmation already active');
      return;
    }

    // Only vibrate if gate not active (double-check)
    if (!isConfirmationActive()) {
      try {
        await HapticFeedback.heavyImpact();
      } catch (_) {}
    }

    if (!mounted) return;

    // method will be 'long_press' or 'shake' — pass it straight to confirmation dialog.
    showConfirmationDialog(context, seconds: 10, alertType: method, trigger: 'manual');
  }

  // Toggle controls automated detection components only.
  void _onAutoSafetyToggled(bool enabled) async {
    setState(() => _autoSafety = enabled);

    // Enable / disable shake detection when auto safety toggles:
    // - Auto Safety ON  => disable shake (so shakes won't interrupt automated tests)
    // - Auto Safety OFF => enable shake
    _manualTrigger.setShakeEnabled(!enabled);

    if (enabled) {
      try {
        _sensorService.start();
        _fallDetector.enable();
        debugPrint('[UI] Auto Safety ON: SensorService started, FallDetector enabled');
      } catch (e) {
        debugPrint('[UI] Error starting SensorService / enabling FallDetector: $e');
      }

      try {
        await _screamDetector?.enable();
        debugPrint('[UI] Auto Safety ON: ScreamDetector enabled');
      } catch (e) {
        debugPrint('[UI] Error enabling ScreamDetector: $e');
      }

      // Inactivity detector remains created and will be started per-trigger.
      _inactivityDetector?.enable();
    } else {
      // STOP automated detectors
      try {
        _sensorService.stop();
        _fallDetector.disable();
        debugPrint('[UI] Auto Safety OFF: SensorService stopped, FallDetector disabled');
      } catch (e) {
        debugPrint('[UI] Error stopping SensorService / disabling FallDetector: $e');
      }

      try {
        await _screamDetector?.disable();
        debugPrint('[UI] Auto Safety OFF: ScreamDetector disabled');
      } catch (e) {
        debugPrint('[UI] Error disabling ScreamDetector: $e');
      }

      // Cancel any pending inactivity windows and disable it
      try {
        _inactivityDetector?.disable();
        debugPrint('[UI] Auto Safety OFF: InactivityDetector disabled and cancelled');
      } catch (e) {
        debugPrint('[UI] Error disabling InactivityDetector: $e');
      }
    }
  }

  void _startHold() {
    if (_isHolding) return;
    _isHolding = true;
    debugPrint('[UI] Hold started (will fire in ${_holdDuration.inSeconds}s unless released)');
    _holdTimer = Timer(_holdDuration, () {
      debugPrint('[UI] Hold duration completed -> firing manual trigger');
      try {
        _manualTrigger.fireTrigger();
      } catch (e) {
        debugPrint('[UI] manualTrigger.fireTrigger() error: $e');
      } finally {
        _isHolding = false;
      }
    });
  }

  void _cancelHold() {
    if (!_isHolding) return;
    _holdTimer?.cancel();
    _holdTimer = null;
    _isHolding = false;
    debugPrint('[UI] Hold cancelled (user released early)');
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }

  void _onLongPressButtonTap() {
    // Removed SnackBar message: short tap does nothing now.
    // Long-press hold still triggers the manual trigger after _holdDuration.
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final screenH = MediaQuery.of(context).size.height;

    final targetHeroHeight = screenH * 0.56;
    final targetHeroWidth = screenW * 0.92;
    final heroSize = math.min(targetHeroHeight, math.min(targetHeroWidth, kMaxHeroWidth));
    final double cornerRadius = 60.0;
    const double heroVerticalPadding = 22.0;

    return responsivePageBody(
      context,
      Container(
        color: Colors.transparent,
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Top bar: logo + toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
              child: Row(
                children: [
                  Image.asset('assets/images/logo_with_text.png', height: 32, fit: BoxFit.contain),
                  const Spacer(),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 64,
                        height: 34,
                        child: Transform.scale(
                          scale: 0.88,
                          child: Switch.adaptive(
                            value: _autoSafety,
                            activeColor: kBlue,
                            onChanged: (v) => _onAutoSafetyToggled(v),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Auto Safety Mode', style: GoogleFonts.poppins(fontSize: 10.5, color: kGrey)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Title above hero
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.w700, color: kTitleColor),
                    children: [
                      const TextSpan(text: 'Feel '),
                      TextSpan(text: 'Unsafe', style: TextStyle(color: kBlue)),
                      const TextSpan(text: '\nToday ?'),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: heroVerticalPadding),

            // Hero image
            Center(
              child: SizedBox(
                width: heroSize,
                height: heroSize,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(cornerRadius),
                  child: Image.asset('assets/images/long_press_pic.png', fit: BoxFit.cover),
                ),
              ),
            ),

            SizedBox(height: heroVerticalPadding),

            // Long Press button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 8),
              child: Listener(
                onPointerDown: (_) => _startHold(),
                onPointerUp: (_) {
                  if (_isHolding) _cancelHold();
                },
                onPointerCancel: (_) => _cancelHold(),
                child: GestureDetector(
                  onTap: _onLongPressButtonTap,
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6EFFF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    child: Text('Long Press', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}