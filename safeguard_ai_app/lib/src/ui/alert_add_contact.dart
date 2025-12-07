// Add Contact page (static). Shows "Add a New Contact" tile using phone_pic_alert.png.

import 'package:flutter/material.dart';
import 'widgets.dart';
import 'package:google_fonts/google_fonts.dart';

class AlertAddContactPage extends StatelessWidget {
  const AlertAddContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return responsivePageBody(
      context,
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Alert', style: titleStyle(20, color: kTitleColor)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 6))
              ]),
              child: Column(children: [
                Image.asset('assets/images/phone_pic_alert.png', width: 72),
                const SizedBox(height: 12),
                Text('Add a New Contact', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('Tap to add', style: GoogleFonts.poppins(color: kGrey)),
              ]),
            ),
            const SizedBox(height: 12),
            Text('History', style: titleStyle(14, color: kGrey, fw: FontWeight.w600)),
            const SizedBox(height: 8),
            // reuse alert history visuals
            Container(height: 280, color: Colors.transparent), // placeholder for scrollable history
            const Spacer(),
          ],
        ),
      ),
    );
  }
}