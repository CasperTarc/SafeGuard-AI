// url updated: use showCancelDialog instead of pushing '/cancel' route so Cancel appears
// as an overlay over Home (keeps Home visible behind).
//
// Only the _onCancel() method changed to call showCancelDialog(context).
// The rest of the confirmation overlay UI is unchanged.

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets.dart';
import 'sent.dart'; // imports showSentDialog
import 'cancel.dart'; // imports showCancelDialog

Future<void> showConfirmationDialog(BuildContext context, {int seconds = 10}) {
  const overlayBase = Color(0xFF1C2833);
  const double overlayOpacity = 0.75;
  final barrierColor = overlayBase.withOpacity(overlayOpacity);

  return showGeneralDialog(
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
        // TIMEOUT: show Cancel overlay (treat as cancel)
        _onCancel();
      }
    });
  }

  Future<void> _onCancel() async {
    _timer?.cancel();
    Navigator.of(context).pop(); // close confirmation overlay
    // show Cancel as an overlay (keeps Home visible behind)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showCancelDialog(context);
    });
  }

  Future<void> _onConfirm() async {
    _timer?.cancel();
    Navigator.of(context).pop(); // close confirmation overlay first
    // show sent overlay on top of Home
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showSentDialog(context);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Compute sizes and keep popup constrained to avoid overflow.
    final w = MediaQuery.of(context).size.width;
    final double maxWidth = 360.0;
    final double cardWidth = math.min(w * 0.78, maxWidth);

    final titleStyle = GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: kBlue);
    final subtitleStyle = GoogleFonts.poppins(fontSize: 12, color: kGrey);
    final countdownStyle = GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: kBlue);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: cardWidth),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: cardWidth,
              padding: const EdgeInsets.symmetric(horizontal: 0),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 0),
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
                            color: kBlue,
                            backgroundColor: kBlue.withOpacity(0.12),
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
      ),
    );
  }
}