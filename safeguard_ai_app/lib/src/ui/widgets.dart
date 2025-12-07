// Shared UI constants and helpers used across onboarding and other UI pages.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

const kBgColor = Color(0xFFF0F0F3);
const kTitleColor = Color(0xFF1C2833);
const kBlue = Color(0xFF0096FB);
const kBlueEnd = Color(0xFF0064E0);
const kGrey = Color(0xFF677989);
const kWhite = Color(0xFFFCFCFD);
const kCTA = Color(0xFF0064E0);

const double kMaxHeroWidth = 520.0;
const double kHeroWidthFactor = 0.75;

Widget responsivePageBody(BuildContext context, Widget child) {
  return LayoutBuilder(builder: (context, constraints) {
    final availableHeight = constraints.maxHeight;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: availableHeight),
        child: IntrinsicHeight(child: child),
      ),
    );
  });
}

TextStyle titleStyle(double size, {Color color = kTitleColor, FontWeight fw = FontWeight.bold}) =>
    GoogleFonts.poppins(fontSize: size, fontWeight: fw, color: color);

double heroWidthFor(BuildContext context) {
  final screenW = MediaQuery.of(context).size.width;
  return math.min(screenW * kHeroWidthFactor, kMaxHeroWidth);
}