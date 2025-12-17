// Confirmation overlay — ensures a single dialog + cooldown across the app.
// This version: fire-and-forget Firestore logging (so UI routing is immediate).
// Important: pass the correct alertType and trigger from callers.
//
// - For automatic detectors, call with alertType 'scream' | 'fall' | 'inactivity' and trigger 'auto'.
// - For manual triggers, call with alertType 'long_press' | 'shake' (or similar) and trigger 'manual'.
// - The helper stores `type` exactly as given, and `trigger` as 'auto' or 'manual'.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // for HapticFeedback
import 'package:google_fonts/google_fonts.dart';

import '../false_alarm.dart'; // startConfirmation(), endConfirmationAndStartCooldown(), isConfirmationActive()
import '../firebase_alerts.dart'; // writeAlertToFirestore(...)
import 'widgets.dart';
import 'cancel.dart'; // showCancelDialog(...)
import 'sent.dart'; // showSentDialog(...)

Future<void> _playEntryHapticPattern() async {
  try {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    await HapticFeedback.lightImpact();
  } catch (_) {
    // ignore
  }
}

/// Show the confirmation overlay and log the final outcome to Firestore (non-blocking).
/// - [alertType] should describe the event (fall/scream/inactivity or manual methods).
/// - [trigger] should be 'auto' or 'manual'.
Future<void> showConfirmationDialog(
  BuildContext context, {
  int seconds = 10,
  String alertType = 'manual',
  String trigger = 'manual',
}) async {
  if (isConfirmationActive()) {
    debugPrint('showConfirmationDialog suppressed because gate/cooldown active');
    return;
  }

  startConfirmation();
  _playEntryHapticPattern();

  String? result;
  try {
    const overlayBase = Color(0xFF1C2833);
    const double overlayOpacity = 0.75;
    final barrierColor = overlayBase.withOpacity(overlayOpacity);

    result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Confirmation',
      barrierColor: barrierColor,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (ctx, anim1, anim2) {
        return _ConfirmationOverlayBody(seconds: seconds);
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
        return FadeTransition(opacity: curved, child: ScaleTransition(scale: curved, child: child));
      },
    );
  } finally {
    endConfirmationAndStartCooldown();
  }

  final String outcome =
      (result == 'send') ? 'sent' : (result == 'cancelled') ? 'cancelled' : 'timeout';

  // Fire-and-forget: ensure overlays show immediately, but log the event in background.
  writeAlertToFirestore(
    type: alertType,
    trigger: trigger,
    outcome: outcome,
  ).catchError((e, st) {
    debugPrint('showConfirmationDialog: firestore write failed: $e\n$st');
  });

  // Route to UI overlays as before
  if (result == 'send') {
    try {
      await showSentDialog(context);
    } catch (e) {
      debugPrint('showConfirmationDialog: failed to show Sent overlay: $e');
    }
  } else {
    try {
      await showCancelDialog(context);
    } catch (e) {
      debugPrint('showConfirmationDialog: failed to show Cancel overlay: $e');
    }
  }
}

class _ConfirmationOverlayBody extends StatefulWidget {
  final int seconds;
  const _ConfirmationOverlayBody({this.seconds = 10});

  @override
  State<_ConfirmationOverlayBody> createState() => _ConfirmationOverlayBodyState();
}

class _ConfirmationOverlayBodyState extends State<_ConfirmationOverlayBody> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _startCountdown();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _remaining = widget.seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _remaining = math.max(0, _remaining - 1));
      if (_remaining == 0) {
        _timer?.cancel();
        if (Navigator.of(context).canPop()) Navigator.of(context).pop('auto');
      }
    });
  }

  void _onCancel() {
    _timer?.cancel();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop('cancelled');
  }

  void _onConfirm() {
    _timer?.cancel();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop('send');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final double maxWidth = 360.0;
    final double cardWidth = math.min(w * 0.78, maxWidth);

    final titleStyle = GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF0064E0));
    final subtitleStyle = GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF6B6F76));
    final countdownStyle = GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: const Color(0xFF0064E0));

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: cardWidth),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: cardWidth,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Possible Danger Detected...', style: titleStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 6),
                  Text('Sending in ${_remaining}s', style: subtitleStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: Stack(alignment: Alignment.center, children: [
                      SizedBox(
                        width: 88,
                        height: 88,
                        child: CircularProgressIndicator(
                          value: (widget.seconds - _remaining) / widget.seconds,
                          strokeWidth: 6,
                          color: const Color(0xFF0064E0),
                          backgroundColor: const Color(0xFF0064E0).withOpacity(0.12),
                        ),
                      ),
                      Image.asset(
                        'assets/images/timer_confirmation.png',
                        width: 56,
                        height: 56,
                        errorBuilder: (c, e, s) {
                          return Text('${_remaining}s', style: countdownStyle);
                        },
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _onCancel,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFBCC0C7),
                              foregroundColor: const Color(0xFFFCFCFD),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              elevation: 0,
                            ),
                            child: Text('Cancel', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: _onConfirm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0064E0),
                              foregroundColor: const Color(0xFFFCFCFD),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              elevation: 0,
                            ),
                            child: Text('Confirm', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 14)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}