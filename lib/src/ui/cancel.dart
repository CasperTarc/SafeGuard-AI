// Cancel overlay dialog + full-screen page wrapper (CancelPageView)
// - Uses assets/images/cancel_pic.png sized to 120x120
// - Message text split into two lines:
//     "Your emergency contact"
//     "will not received any alert"
// - "Got it" button text is bold.
// - Keeps both showCancelDialog(...) overlay API and CancelPageView route wrapper.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets.dart';

Future<void> showCancelDialog(BuildContext context) {
  const overlayBase = Color(0xFF1C2833);
  const double overlayOpacity = 0.75;
  final barrierColor = overlayBase.withOpacity(overlayOpacity);

  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Cancel',
    barrierColor: barrierColor,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) {
      return const _CancelOverlayBody();
    },
    transitionBuilder: (ctx, anim1, anim2, child) {
      final curved = CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: curved, child: ScaleTransition(scale: curved, child: child));
    },
  );
}

class _CancelOverlayBody extends StatelessWidget {
  const _CancelOverlayBody({Key? key}) : super(key: key);

  void _close(BuildContext context) {
    Navigator.of(context).pop(); // close overlay, Home remains underneath
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final double maxWidth = 360.0;
    final double cardWidth = math.min(w * 0.78, maxWidth);

    final titleStyle = GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF1C2833));
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
                  // Use cancel_pic.png sized to 120x120
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Image.asset(
                      'assets/images/cancel_pic.png',
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Cancel', style: titleStyle, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  // Two-line message as requested
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Your emergency contact\n', style: subtitleStyle),
                        TextSpan(text: 'will not received any alert', style: subtitleStyle),
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

/// Full-screen page version so we can register a '/cancel' route in main.dart.
/// It simply renders the same card in a Scaffold (no overlay), so navigation via route works.
class CancelPageView extends StatelessWidget {
  const CancelPageView({super.key});

  @override
  Widget build(BuildContext context) {
    // Show the same content as the overlay, but in a full-screen scaffold.
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F3),
      body: SafeArea(
        child: Center(
          child: _CancelOverlayBody(),
        ),
      ),
    );
  }
}