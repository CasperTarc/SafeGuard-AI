// Bottom navigation — adjusted sizing & spacing (smaller container, tighter icon gaps).
// - Container is smaller and centered with radius 60.
// - Icons are slightly smaller and have reduced horizontal gaps.
// - Uses onTrigger asset variants depending on currentIndex.

import 'dart:math' as math;
import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({required this.currentIndex, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0, left: 12, right: 12),
      child: Center(
        child: LayoutBuilder(builder: (context, constraints) {
          final maxW = constraints.maxWidth;
          // Make container smaller than previous (closer to Figma): ~72% width (capped)
          final containerWidth = math.min(maxW * 0.72, 420.0);

          // Slightly smaller icons and tighter padding
          const double iconSize = 20;
          const double centerIconSize = 24;

          return Container(
            width: containerWidth,
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0064E0),
              borderRadius: BorderRadius.circular(60),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 6))],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Alert icon (left)
                GestureDetector(
                  onTap: () => onTap(0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Image.asset(
                      currentIndex == 0 ? 'assets/images/bottom_nav_alert_onTrigger.png' : 'assets/images/bottom_nav_alert.png',
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // Home icon (center)
                GestureDetector(
                  onTap: () => onTap(1),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Image.asset(
                      currentIndex == 1 ? 'assets/images/bottom_nav_home_onTrigger.png' : 'assets/images/bottom_nav_home.png',
                      width: centerIconSize,
                      height: centerIconSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // Setting icon (right)
                GestureDetector(
                  onTap: () => onTap(2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Image.asset(
                      currentIndex == 2 ? 'assets/images/bottom_nav_setting_onTrigger.png' : 'assets/images/bottom_nav_setting.png',
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}