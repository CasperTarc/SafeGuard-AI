// Settings page (static visuals). Duration pickers are purely visual (no logic).

import 'package:flutter/material.dart';
import 'widgets.dart';
import 'package:google_fonts/google_fonts.dart';

class SettingPageView extends StatelessWidget {
  const SettingPageView({super.key});

  Widget _durationTile(String title, String current) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: kWhite, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: kBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
            child: Text(current, style: GoogleFonts.poppins(color: kBlue)),
          )
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
            Text('Setting', style: titleStyle(20, color: kTitleColor)),
            const SizedBox(height: 12),
            _durationTile('Inactive Time Alert', '12s'),
            _durationTile('Confirmation Time Alert', '10s'),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}