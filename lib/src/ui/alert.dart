// Alert page (static). Shows contact card + history list.
// Uses edit_pic_alert.png for card background and fall_pic_alert.png, scream_pic_alert.png for history icons.

import 'package:flutter/material.dart';
import 'widgets.dart';
import 'package:google_fonts/google_fonts.dart';

class AlertPageView extends StatelessWidget {
  const AlertPageView({super.key});

  Widget _historyTile(String title, String time, String asset, String status) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12), boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 6))
      ]),
      child: Row(
        children: [
          Image.asset(asset, width: 36, height: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(time, style: GoogleFonts.poppins(color: kGrey, fontSize: 12)),
            ]),
          ),
          Text(status, style: GoogleFonts.poppins(color: status == 'Sent' ? Colors.green : Colors.red)),
        ],
      ),
    );
  }

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
            // Contact card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                image: const DecorationImage(image: AssetImage('assets/images/edit_pic_alert.png'), fit: BoxFit.cover),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 6))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Justin Kow', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: kWhite)),
                const SizedBox(height: 6),
                Text('012-3456789', style: GoogleFonts.poppins(color: kWhite)),
                const SizedBox(height: 8),
                Text('Added by: You', style: GoogleFonts.poppins(color: kWhite, fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 14),
            Text('History', style: titleStyle(14, color: kGrey, fw: FontWeight.w600)),
            const SizedBox(height: 8),
            _historyTile('Fall', 'Today • 11:00 am', 'assets/images/fall_pic_alert.png', 'Sent'),
            _historyTile('Scream', 'Today • 10:00 am', 'assets/images/scream_pic_alert.png', 'Cancelled'),
            _historyTile('Fall', '11 Sept • 04:00 pm', 'assets/images/fall_pic_alert.png', 'Sent'),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}