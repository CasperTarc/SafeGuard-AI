// Home page — ManualTrigger always active. Auto Safety toggle controls only automated detectors.
// Long-press still fires ManualTrigger.fireTrigger() after 5s hold.
// Change: removed the SnackBar message that warned "Auto Safety is OFF - enable it..." when Auto Safety is OFF.
// Now the Long Press tap only shows a message when Auto Safety is ON; when OFF it does nothing.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../fall_detector.dart';
import '../sensor_service.dart';
import '../manual_trigger.dart';
import 'widgets.dart';
import 'confirmation.dart'; // provides showConfirmationDialog(...)

class HomePageView extends StatefulWidget {
  const HomePageView({super.key});

  @override
  State<HomePageView> createState() => _HomePageViewState();
}

class _HomePageViewState extends State<HomePageView> {
  bool _autoSafety = false;

  // Automated detectors (started only when Auto Safety is ON)
  late final FallDetector _fallDetector;
  late final SensorService _sensorService;
  StreamSubscription<DateTime>? _fallSub;
  StreamSubscription<String>? _fdDebugSub;

  // ManualTrigger (handles shake detection and manual fire) — ALWAYS listening
  late final ManualTrigger _manualTrigger;

  // Long-press hold logic (5s)
  Timer? _holdTimer;
  final Duration _holdDuration = const Duration(seconds: 5);
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();

    // FallDetector (kept for automated detectors; only started when Auto Safety ON)
    _fallDetector = FallDetector(debug: true);
    _fdDebugSub = _fallDetector.debugStream.listen((m) => debugPrint('[FD] $m'));
    _fallSub = _fallDetector.fallStream.listen((dt) async {
      debugPrint('[FD] FALL CONFIRMED at $dt');
      try { await HapticFeedback.heavyImpact(); } catch (_) {}
      if (mounted) {
        showConfirmationDialog(context);
      }
    });

    // SensorService — created but not started; Auto Safety toggle controls start/stop.
    _sensor_service_init();

    // ManualTrigger: always started so manual long-press and shake work even if Auto Safety is OFF.
    _manualTrigger = ManualTrigger(
      onTriggered: _onManualTriggered,
      threshold: 2.0,
      requiredPeaks: 5,
      window: const Duration(seconds: 3),
      baselineAlpha: 0.1,
    );
    _manualTrigger.startListening();
    debugPrint('[UI] ManualTrigger started (manual long-press + shake available regardless of Auto Safety)');
  }

  void _sensor_service_init() {
    _sensorService = SensorService(
      fallDetector: _fallDetector,
      sampleMs: 40,
      lowPassAlpha: 0.90,
      sampleCallbackIntervalMs: 1000,
      onDebug: (m) => debugPrint('[SS] $m'),
      onSample: (mag, ts) {
        if (mag > 1.0) debugPrint('[SS] sample=${mag.toStringAsFixed(2)} at $ts');
      },
    );
  }

  @override
  void dispose() {
    _fallSub?.cancel();
    _fdDebugSub?.cancel();
    try {
      _sensorService.dispose();
      _fallDetector.dispose();
    } catch (_) {}
    _manualTrigger.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  // Called when the manual trigger (shake or long-press) activates
  void _onManualTriggered() async {
    debugPrint('[MT] Manual trigger fired -> _onManualTriggered()');
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
    if (!mounted) return;
    showConfirmationDialog(context);
  }

  // Toggle controls only the automated detection components.
  void _onAutoSafetyToggled(bool enabled) {
    setState(() => _autoSafety = enabled);
    if (enabled) {
      try {
        _sensorService.start();
        debugPrint('[UI] Auto Safety ON: SensorService started (automated detectors running)');
      } catch (e) {
        debugPrint('[UI] Error starting SensorService: $e');
      }
    } else {
      try {
        _sensorService.stop();
        debugPrint('[UI] Auto Safety OFF: SensorService stopped (automated detectors halted)');
      } catch (e) {
        debugPrint('[UI] Error stopping SensorService: $e');
      }
    }
  }

  // Long-press: start hold timer on pointer down (Listener ensures correct pointer events in emulator)
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

  // Cancel hold if user releases early
  void _cancelHold() {
    if (!_isHolding) return;
    _holdTimer?.cancel();
    _holdTimer = null;
    _isHolding = false;
    debugPrint('[UI] Hold cancelled (user released early)');
    try { HapticFeedback.selectionClick(); } catch (_) {}
  }

  // Long Press button tap: show guidance ONLY when Auto Safety is ON.
  // If Auto Safety is OFF, do nothing (user asked to remove the OFF message).
  void _onLongPressButtonTap() {
    if (!_autoSafety) return;
    final msg = 'Auto Safety is ON — automatic detection will run while the app is foregrounded.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
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

            // Long Press button — use Listener for low-level pointer events (hold) and tap for guidance
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 8),
              child: Listener(
                onPointerDown: (_) => _startHold(),
                onPointerUp: (_) {
                  // If it was a short tap, show guidance; if released after hold completion _isHolding=false already.
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