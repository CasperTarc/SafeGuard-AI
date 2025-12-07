// url=https://github.com/CasperTarc/SafeGuard-AI/blob/main/safeguard_ai_app/lib/src/ui/sent.dart
// Sent overlay dialog — shown over the Home UI (keeps Home visible behind).
// - Uses assets/images/sent_pic.png directly (no extra background box).
// - Message uses two lines: "Your emergency contact" / "will be received soon".
// - "Got it" button closes the overlay and returns to the app (Home stays underneath).
//
// Use showSentDialog(context) to present this dialog (same pattern as confirmation).

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets.dart';

Future<void> showSentDialog(BuildContext context) {
  const overlayBase = Color(0xFF1C2833);
  const double overlayOpacity = 0.75;
  final barrierColor = overlayBase.withOpacity(overlayOpacity);

  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Sent',
    barrierColor: barrierColor,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) {
      return const _SentOverlayBody();
    },
    transitionBuilder: (ctx, anim1, anim2, child) {
      final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: curved, child: ScaleTransition(scale: curved, child: child));
    },
  );
}

class _SentOverlayBody extends StatelessWidget {
  const _SentOverlayBody({Key? key}) : super(key: key);

  void _close(BuildContext context) {
    Navigator.of(context).pop(); // close overlay, Home remains underneath
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final double maxWidth = 360.0;
    final double cardWidth = math.min(w * 0.78, maxWidth);

    final titleStyle = GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: kBlue);
    final subtitleStyle = GoogleFonts.poppins(fontSize: 13, color: kGrey);

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
                  // Directly use sent_pic.png (no extra colored background)
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Image.asset(
                      'assets/images/sent_pic.png',
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Alert Sent Successfully', style: titleStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  // Two-line message as requested
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Your emergency contact\n', style: subtitleStyle),
                        TextSpan(text: 'will be received soon', style: subtitleStyle),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _close(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0064E0),
                        foregroundColor: const Color(0xFFFCFCFD),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text('Got it', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                    ),
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